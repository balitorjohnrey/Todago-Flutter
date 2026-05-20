import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

const String _googleApiKey = 'AIzaSyCh0c5-2IrNkOJPXa9POuiZF8WrkGMmT5Y';

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
  // ── Get real GPS location ─────────────────────────────────────────────────
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

  // ── Stream position updates ───────────────────────────────────────────────
  static Stream<LatLng> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude));
  }

  // ── Places Autocomplete ───────────────────────────────────────────────────
  static Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:ph'
        '&location=7.1907,125.4553'  // bias toward Davao
        '&radius=50000'
        '&key=$_googleApiKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final predictions = data['predictions'] as List? ?? [];
        return predictions.map((p) {
          final structured = p['structured_formatting'] ?? {};
          return PlaceSuggestion(
            placeId: p['place_id'] as String? ?? '',
            mainText: structured['main_text'] as String? ?? p['description'] as String? ?? '',
            secondaryText: structured['secondary_text'] as String? ?? '',
            fullText: p['description'] as String? ?? '',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Get lat/lng from Place ID ─────────────────────────────────────────────
  static Future<LatLng?> getPlaceLatLng(String placeId) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=$_googleApiKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final loc = data['result']?['geometry']?['location'];
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

  // ── Reverse geocode ───────────────────────────────────────────────────────
  static Future<String> reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${pos.latitude},${pos.longitude}'
        '&key=$_googleApiKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.first['formatted_address'] as String? ?? 'Your Location';
        }
      }
    } catch (_) {}
    return 'Your Location';
  }

  // ── Fetch road-following route via Google Directions API ──────────────────
  static Future<MapRoute?> fetchRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${from.latitude},${from.longitude}'
        '&destination=${to.latitude},${to.longitude}'
        '&mode=driving'
        '&key=$_googleApiKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first;
          final leg   = route['legs'].first;

          final distMeters = (leg['distance']['value'] as num).toDouble();
          final durSecs    = (leg['duration']['value'] as num).toDouble();
          final distText   = leg['distance']['text'] as String? ?? '';
          final durText    = leg['duration']['text'] as String? ?? '';

          // Decode polyline
          final encodedPoly = route['overview_polyline']['points'] as String;
          final points = _decodePolyline(encodedPoly);

          return MapRoute(
            points: points,
            distanceKm: distMeters / 1000,
            etaMinutes: (durSecs / 60).ceil(),
            distanceText: distText,
            durationText: durText,
          );
        }
      }
    } catch (_) {}

    // Fallback: straight line
    final dist = _haversineKm(from, to);
    return MapRoute(
      points: [from, to],
      distanceKm: dist,
      etaMinutes: (dist / 0.4).ceil(),
    );
  }

  // ── Google Polyline decoder ───────────────────────────────────────────────
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ── Haversine straight-line distance (km) ─────────────────────────────────
  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _toRad(b.latitude  - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinLat = _sin(dLat / 2);
    final sinLng = _sin(dLng / 2);
    final h = sinLat * sinLat +
        _cos(_toRad(a.latitude)) * _cos(_toRad(b.latitude)) * sinLng * sinLng;
    return 2 * r * _asin(_sqrt(h));
  }

  static double _toRad(double d) => d * 3.14159265358979 / 180;
  static double _sin(double x) {
    double s = x, term = x;
    for (int i = 1; i <= 7; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      s += term;
    }
    return s;
  }
  static double _cos(double x) => _sin(3.14159265358979 / 2 - x);
  static double _asin(double x) {
    double s = x, term = x;
    for (int i = 1; i <= 7; i++) {
      term *= (2.0 * i - 1) * (2.0 * i - 1) * x * x / ((2.0 * i) * (2.0 * i + 1));
      s += term;
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