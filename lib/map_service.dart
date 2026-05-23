import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

const String _key = 'AIzaSyCh0c5-2IrNkOJPXa9POuiZF8WrkGMmT5Y';
const String _placesBase     = 'https://maps.googleapis.com/maps/api/place';
const String _directionsBase = 'https://maps.googleapis.com/maps/api/directions/json';
const String _geocodeBase    = 'https://maps.googleapis.com/maps/api/geocode/json';

class MapRoute {
  final List<LatLng> points;
  final double distanceKm;
  final int etaMinutes;
  final String distanceText;
  final String durationText;

  MapRoute({
    required this.points,
    required this.distanceKm,
    required this.etaMinutes,
    this.distanceText = '',
    this.durationText = '',
  });
}

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });
}

class MapService {

  // ── GPS location ──────────────────────────────────────────────────────────
  static Future<LatLng?> getCurrentLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  // ── Live position stream ──────────────────────────────────────────────────
  static Stream<LatLng> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude));
  }

  // ── Google Places Autocomplete → Photon fallback ─────────────────────────
  static Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? locationBias,
  }) async {
    if (query.trim().length < 2) return [];
    final bias = locationBias ?? const LatLng(7.1907, 125.4553);

    // 1st: Google Places Autocomplete (requires billing activated)
    try {
      final uri = Uri.parse(
        '$_placesBase/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_key'
        '&language=en'
        '&components=country:ph'
        '&location=${bias.latitude},${bias.longitude}'
        '&radius=50000',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data   = jsonDecode(res.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        if (status == 'OK') {
          final predictions = data['predictions'] as List? ?? [];
          if (predictions.isNotEmpty) {
            return predictions.map((p) {
              final sf = p['structured_formatting'] as Map? ?? {};
              return PlaceSuggestion(
                placeId       : p['place_id'] as String? ?? '',
                mainText      : sf['main_text'] as String?
                                ?? p['description'] as String? ?? '',
                secondaryText : sf['secondary_text'] as String? ?? '',
                fullText      : p['description'] as String? ?? '',
              );
            }).toList();
          }
        }
      }
    } catch (_) {}

    // 2nd: Photon geocoder fallback
    return _searchPhoton(query, bias);
  }

  // ── Photon search (OSM-based, free, no key) ───────────────────────────────
  static Future<List<PlaceSuggestion>> _searchPhoton(
      String query, LatLng bias) async {
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/api/'
        '?q=${Uri.encodeComponent(query)}'
        '&lat=${bias.latitude}&lon=${bias.longitude}'
        '&zoom=14&limit=8&lang=en',
      );
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];

      final data     = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];
      final results  = <PlaceSuggestion>[];

      for (final f in features) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};

        // ── FIX 1: country filter — allow empty country too ───────────────
        final country = props['country'] as String? ?? '';
        if (country.isNotEmpty && country != 'Philippines') continue;

        // ── Coordinates ───────────────────────────────────────────────────
        final coords = (f['geometry']?['coordinates'] as List?) ?? [0.0, 0.0];
        final lon    = (coords[0] as num).toDouble();
        final lat    = (coords[1] as num).toDouble();

        // ── FIX 2: read all possible city-level keys from Photon ──────────
        final name     = props['name']     as String? ?? '';
        final street   = props['street']   as String? ?? '';
        final city     = props['city']     as String?
                      ?? props['town']     as String?
                      ?? props['locality'] as String?   // ← was missing
                      ?? props['county']   as String? ?? '';
        final district = props['district'] as String? ?? '';
        final state    = props['state']    as String? ?? '';

        // ── FIX 3: broader mainText fallback chain ────────────────────────
        final mainText = name.isNotEmpty     ? name
                       : street.isNotEmpty   ? street
                       : city.isNotEmpty     ? city
                       : district.isNotEmpty ? district
                       : state;

        if (mainText.isEmpty) continue;

        // ── Build a clean secondary text ──────────────────────────────────
        final secondaryParts = <String>[];
        if (street.isNotEmpty && mainText != street)   secondaryParts.add(street);
        if (city.isNotEmpty   && mainText != city)     secondaryParts.add(city);
        if (district.isNotEmpty && mainText != district) secondaryParts.add(district);
        if (state.isNotEmpty)                           secondaryParts.add(state);
        secondaryParts.add('Philippines');

        final secondary = secondaryParts.join(', ');

        results.add(PlaceSuggestion(
          placeId       : 'coord:$lat:$lon',
          mainText      : mainText,
          secondaryText : secondary,
          fullText      : '$mainText, $secondary',
        ));
      }

      return results;
    } catch (_) {}
    return [];
  }

  // ── Google Place Details → LatLng ─────────────────────────────────────────
  static Future<LatLng?> getPlaceLatLng(String placeId) async {
    // Photon result — coords already encoded in the ID
    if (placeId.startsWith('coord:')) {
      final parts = placeId.split(':');
      if (parts.length == 3) {
        final lat = double.tryParse(parts[1]);
        final lng = double.tryParse(parts[2]);
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
      return null;
    }
    // Google Place Details
    try {
      final uri = Uri.parse(
        '$_placesBase/details/json'
        '?place_id=$placeId'
        '&fields=geometry/location'
        '&key=$_key',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final loc  = data['result']?['geometry']?['location'];
        if (loc != null) {
          return LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Google Geocoding — coords → address ───────────────────────────────────
  static Future<String> reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse(
        '$_geocodeBase'
        '?latlng=${pos.latitude},${pos.longitude}'
        '&key=$_key'
        '&language=en',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data    = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.first['formatted_address'] as String? ?? 'Your Location';
        }
      }
    } catch (_) {}
    return 'Your Location';
  }

  // ── Road-following route (OSRM → Google Directions fallback) ─────────────
  static Future<MapRoute?> fetchRoute(LatLng from, LatLng to) async {

    // 1st: OSRM — free, no API key, real road routing
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving'
        '/${from.longitude},${from.latitude}'
        ';${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'TodaGoApp/1.0'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data   = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route  = routes.first as Map<String, dynamic>;
          final distM  = (route['distance'] as num).toDouble();
          final durS   = (route['duration'] as num).toDouble();
          final coords = (route['geometry']['coordinates'] as List)
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();
          return MapRoute(
            points       : coords,
            distanceKm   : distM / 1000,
            etaMinutes   : (durS / 60).ceil(),
            distanceText : '${(distM / 1000).toStringAsFixed(1)} km',
            durationText : '${(durS / 60).ceil()} min',
          );
        }
      }
    } catch (_) {}

    // 2nd: Google Directions API (requires billing)
    try {
      final uri = Uri.parse(
        '$_directionsBase'
        '?origin=${from.latitude},${from.longitude}'
        '&destination=${to.latitude},${to.longitude}'
        '&mode=driving&key=$_key&language=en',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data   = jsonDecode(res.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        if (status == 'OK') {
          final routes = data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final route   = routes.first as Map<String, dynamic>;
            final leg     = (route['legs'] as List).first as Map<String, dynamic>;
            final distM   = (leg['distance']['value'] as num).toDouble();
            final durS    = (leg['duration']['value'] as num).toDouble();
            final encoded = route['overview_polyline']['points'] as String;
            return MapRoute(
              points       : _decodePolyline(encoded),
              distanceKm   : distM / 1000,
              etaMinutes   : (durS / 60).ceil(),
              distanceText : leg['distance']['text'] as String? ?? '',
              durationText : leg['duration']['text']  as String? ?? '',
            );
          }
        }
      }
    } catch (_) {}

    // Last resort: straight-line estimate
    final dist = _haversineKm(from, to);
    return MapRoute(
      points     : [from, to],
      distanceKm : dist,
      etaMinutes : (dist / 0.4).ceil(),
    );
  }

  // ── Google Polyline decoder ───────────────────────────────────────────────
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ── Haversine distance (km) ───────────────────────────────────────────────
  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude  - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = _sin2(dLat / 2) +
        _cos(_rad(a.latitude)) * _cos(_rad(b.latitude)) * _sin2(dLng / 2);
    return 2 * r * _asin(_sqrt(h));
  }

  static double _rad(double d)  => d * 3.14159265358979 / 180;
  static double _sin2(double x) => _sinX(x) * _sinX(x);
  static double _sinX(double x) {
    double s = x, t = x;
    for (int i = 1; i <= 7; i++) {
      t *= -x * x / ((2 * i) * (2 * i + 1));
      s += t;
    }
    return s;
  }
  static double _cos(double x)  => _sinX(3.14159265358979 / 2 - x);
  static double _asin(double x) {
    double s = x, t = x;
    for (int i = 1; i <= 7; i++) {
      t *= (2.0*i-1)*(2.0*i-1)*x*x / ((2.0*i)*(2.0*i+1));
      s += t;
    }
    return s;
  }
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 20; i++) r = (r + x / r) / 2;
    return r;
  }
}