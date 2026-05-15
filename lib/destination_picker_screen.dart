import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'app_theme.dart';
import 'service_selection_screen.dart';

// ── Models ────────────────────────────────────────────────────────────────────
class PlaceSuggestion {
  final String displayName;
  final String shortName;
  final double lat;
  final double lon;

  PlaceSuggestion({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lon,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> j) {
    final parts = (j['display_name'] as String).split(', ');
    final short = parts.take(3).join(', ');
    return PlaceSuggestion(
      displayName: j['display_name'] as String,
      shortName: short,
      lat: double.parse(j['lat'] as String),
      lon: double.parse(j['lon'] as String),
    );
  }
}

class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final int etaMinutes;

  RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.etaMinutes,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────
class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key});

  @override
  State<DestinationPickerScreen> createState() =>
      _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  final MapController _mapCtrl = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  LatLng? _currentLocation;
  LatLng? _destination;
  String _destinationName = '';
  String _pickupName = 'Your Location';

  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isRouting = false;
  bool _showSuggestions = false;
  bool _loadingLocation = true;
  RouteInfo? _route;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Get real GPS location ─────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setDefaultLocation();
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _setDefaultLocation();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentLocation = loc;
        _loadingLocation = false;
      });

      // Move map to real location
      await Future.delayed(const Duration(milliseconds: 300));
      _mapCtrl.move(loc, 16.0);

      // Get human-readable address
      _reverseGeocode(loc);
    } catch (e) {
      debugPrint('[Location] Error: $e');
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    // Panabo City fallback
    final loc = const LatLng(7.1907, 125.4553);
    if (!mounted) return;
    setState(() {
      _currentLocation = loc;
      _loadingLocation = false;
    });
    _mapCtrl.move(loc, 15.0);
  }

  // ── Reverse geocode: coords → address ─────────────────────────────────────
  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}'
        '&format=json&zoom=18&addressdetails=1',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'TodaGoApp/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final parts = <String>[];
        if (addr['road'] != null) parts.add(addr['road'] as String);
        if (addr['suburb'] != null) parts.add(addr['suburb'] as String);
        if (addr['city'] != null)
          parts.add(addr['city'] as String);
        else if (addr['town'] != null)
          parts.add(addr['town'] as String);
        setState(() => _pickupName =
            parts.isNotEmpty ? parts.join(', ') : 'Your Location');
      }
    } catch (e) {
      debugPrint('[Geocode] Reverse geocode error: $e');
    }
  }

  // ── Search via Nominatim ───────────────────────────────────────────────────
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 500), () => _searchPlaces(q));
  }

  Future<void> _searchPlaces(String q) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _showSuggestions = true;
    });
    try {
      // Bias search toward Philippines / Davao region
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q + ' Philippines')}'
        '&format=json&limit=7&countrycodes=ph'
        '&viewbox=125.0,6.5,126.5,8.5&bounded=0'
        '&addressdetails=1',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'TodaGoApp/1.0'})
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _suggestions = list
              .map((j) => PlaceSuggestion.fromJson(j))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[Search] Error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── User picks a suggestion ────────────────────────────────────────────────
  Future<void> _selectDestination(PlaceSuggestion place) async {
    final dest = LatLng(place.lat, place.lon);
    setState(() {
      _destination = dest;
      _destinationName = place.shortName;
      _showSuggestions = false;
      _suggestions = [];
      _searchCtrl.text = place.shortName;
      _route = null;
    });
    _searchFocus.unfocus();

    if (_currentLocation != null) {
      // Fit map to show both A and B
      try {
        final bounds =
            LatLngBounds.fromPoints([_currentLocation!, dest]);
        _mapCtrl.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(60, 120, 60, 280),
          ),
        );
      } catch (_) {
        _mapCtrl.move(dest, 14);
      }
      // Fetch real road route
      await _fetchRoadRoute();
    } else {
      _mapCtrl.move(dest, 14);
    }
  }

  // ── OSRM real road routing ─────────────────────────────────────────────────
  Future<void> _fetchRoadRoute() async {
    if (_currentLocation == null || _destination == null) return;
    setState(() => _isRouting = true);

    final from = _currentLocation!;
    final to = _destination!;

    try {
      // OSRM public API — returns road-following route
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving'
        '/${from.longitude},${from.latitude}'
        ';${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );

      final res = await http
          .get(uri, headers: {'User-Agent': 'TodaGoApp/1.0'})
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSecs   = (route['duration'] as num).toDouble();

          // Decode GeoJSON coordinates [lon, lat] → LatLng(lat, lon)
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coords   = geometry['coordinates'] as List;
          final points   = coords.map((c) {
            final pair = c as List;
            return LatLng(
              (pair[1] as num).toDouble(), // lat
              (pair[0] as num).toDouble(), // lon
            );
          }).toList();

          if (mounted) {
            setState(() {
              _route = RouteInfo(
                points: points,
                distanceKm: distanceMeters / 1000,
                etaMinutes: (durationSecs / 60).ceil(),
              );
            });
          }
          return;
        }
      }

      // OSRM failed — try GraphHopper fallback
      await _fetchGraphHopperRoute(from, to);
    } catch (e) {
      debugPrint('[Route] OSRM error: $e');
      // Straight line fallback as last resort
      _straightLineFallback(from, to);
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  // ── GraphHopper fallback ───────────────────────────────────────────────────
  Future<void> _fetchGraphHopperRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://graphhopper.com/api/1/route'
        '?point=${from.latitude},${from.longitude}'
        '&point=${to.latitude},${to.longitude}'
        '&vehicle=car&locale=en&key=&type=json'
        '&points_encoded=false',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'TodaGoApp/1.0'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && mounted) {
        final data  = jsonDecode(res.body);
        final paths = data['paths'] as List?;
        if (paths != null && paths.isNotEmpty) {
          final path  = paths.first;
          final dist  = (path['distance'] as num).toDouble();
          final time  = (path['time'] as num).toDouble(); // ms
          final pts   = (path['points']['coordinates'] as List)
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();
          setState(() {
            _route = RouteInfo(
              points: pts,
              distanceKm: dist / 1000,
              etaMinutes: (time / 60000).ceil(),
            );
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('[Route] GraphHopper error: $e');
    }
    _straightLineFallback(from, to);
  }

  // ── Straight line last resort ──────────────────────────────────────────────
  void _straightLineFallback(LatLng from, LatLng to) {
    final dist =
        const Distance().as(LengthUnit.Kilometer, from, to);
    if (!mounted) return;
    setState(() {
      _route = RouteInfo(
        points: [from, to],
        distanceKm: dist,
        etaMinutes: (dist / 0.4).ceil(),
      );
    });
  }

  // ── Confirm → go to service selection ────────────────────────────────────
  void _confirmDestination() {
    if (_destination == null) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => ServiceSelectionScreen(
        pickupName: _pickupName,
        destinationName: _destinationName,
        pickupLatLng: _currentLocation,
        destinationLatLng: _destination,
        etaMinutes: _route?.etaMinutes,
        distanceKm: _route?.distanceKm,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1), end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  // ── Estimated fare ────────────────────────────────────────────────────────
  String _estimateFare(double km) {
    final fare = (15 + (km * 5)).round().clamp(15, 300);
    return fare.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [

        // ═══ FULL-SCREEN MAP ══════════════════════════════════════════════
        Positioned.fill(
          child: _loadingLocation
              ? Container(
                  color: const Color(0xFFE8EFF5),
                  child: Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text('Getting your location...',
                          style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.backgroundDark,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  )),
                )
              : FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _currentLocation ??
                        const LatLng(7.1907, 125.4553),
                    initialZoom: 16.0,
                    onTap: (_, __) {
                      _searchFocus.unfocus();
                      setState(() => _showSuggestions = false);
                    },
                  ),
                  children: [
                    // Map tiles
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.todago.app',
                    ),

                    // Road-following polyline
                    if (_route != null && _route!.points.length > 1)
                      PolylineLayer(polylines: [
                        // Shadow
                        Polyline(
                          points: _route!.points,
                          color: Colors.black.withOpacity(0.15),
                          strokeWidth: 9,
                        ),
                        // Main route
                        Polyline(
                          points: _route!.points,
                          color: AppColors.primary,
                          strokeWidth: 5.5,
                        ),
                        // Center highlight
                        Polyline(
                          points: _route!.points,
                          color: Colors.white.withOpacity(0.4),
                          strokeWidth: 2,
                        ),
                      ]),

                    MarkerLayer(markers: [
                      // ── Current location marker ──────────────────────
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          width: 48, height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(
                                color: AppColors.primary.withOpacity(0.45),
                                blurRadius: 12, spreadRadius: 2,
                              )],
                            ),
                            child: const Icon(
                              Icons.my_location_rounded,
                              color: AppColors.backgroundDark,
                              size: 22,
                            ),
                          ),
                        ),

                      // ── Destination marker ───────────────────────────
                      if (_destination != null)
                        Marker(
                          point: _destination!,
                          width: 48, height: 58,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundDark,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                  boxShadow: [BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                  )],
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              Container(
                                width: 3, height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundDark,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ]),
                  ],
                ),
        ),

        // ═══ TOP SEARCH PANEL ═════════════════════════════════════════════
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Back button + Search bar row
                  Row(children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 10, offset: const Offset(0, 2),
                          )],
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.black87, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // ── Search bar — white bg, black text ───────────────
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 12, offset: const Offset(0, 3),
                          )],
                        ),
                        child: Row(children: [
                          const SizedBox(width: 14),
                          const Icon(Icons.search_rounded,
                              color: Colors.black54, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              onChanged: _onSearchChanged,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.black,          // ← black text
                                fontWeight: FontWeight.w500,
                              ),
                              cursorColor: AppColors.primary,
                              decoration: InputDecoration(
                                hintText: 'Where to go?',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.black45,      // ← visible hint
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          // Clear button
                          if (_searchCtrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _suggestions = [];
                                  _showSuggestions = false;
                                  _destination = null;
                                  _route = null;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.close_rounded,
                                    color: Colors.black45, size: 18),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ]),

                  // ── Suggestions dropdown ──────────────────────────────
                  if (_showSuggestions)
                    Container(
                      margin: const EdgeInsets.only(top: 6, left: 54),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 14, offset: const Offset(0, 4),
                        )],
                      ),
                      child: _isSearching && _suggestions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              )),
                            )
                          : _suggestions.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text('No results found',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      )),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: _suggestions.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(
                                          height: 1,
                                          color: Color(0xFFF0F0F0)),
                                  itemBuilder: (_, i) {
                                    final s = _suggestions[i];
                                    return GestureDetector(
                                      onTap: () => _selectDestination(s),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        child: Row(children: [
                                          Container(
                                            width: 34, height: 34,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: const Icon(
                                              Icons.location_on_rounded,
                                              color: AppColors.primary,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(s.shortName,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  )),
                                              const SizedBox(height: 2),
                                              Text(s.displayName,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.black45,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ],
                                          )),
                                          const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.black26, size: 18),
                                        ]),
                                      ),
                                    );
                                  },
                                ),
                    ).animate().fadeIn(duration: 200.ms),
                ],
              ),
            ),
          ),
        ),

        // ═══ ROUTING INDICATOR ════════════════════════════════════════════
        if (_isRouting)
          Positioned(
            top: 110, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.2), blurRadius: 8,
                  )],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
                  const SizedBox(width: 10),
                  Text('Finding road route...',
                      style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.white,
                        fontWeight: FontWeight.w600,
                      )),
                ]),
              ),
            ),
          ),

        // ═══ MY LOCATION BUTTON ═══════════════════════════════════════════
        if (!_loadingLocation && _destination == null)
          Positioned(
            bottom: 28, right: 16,
            child: GestureDetector(
              onTap: () {
                if (_currentLocation != null) {
                  _mapCtrl.move(_currentLocation!, 16);
                }
              },
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.2), blurRadius: 8,
                  )],
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.backgroundDark, size: 22),
              ),
            ),
          ),

        // ═══ BOTTOM ROUTE INFO + CONFIRM ══════════════════════════════════
        if (_destination != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                )],
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Drag handle
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
                const SizedBox(height: 14),

                // ── Route card ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(children: [
                    // FROM
                    Row(children: [
                      Container(
                        width: 11, height: 11,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.backgroundDark, width: 2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FROM', style: GoogleFonts.poppins(
                            fontSize: 9, color: Colors.black45,
                            letterSpacing: 1.2, fontWeight: FontWeight.w700,
                          )),
                          Text(_pickupName, style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      )),
                    ]),

                    // Dashed connector
                    Padding(
                      padding: const EdgeInsets.only(left: 4.5),
                      child: Column(children: List.generate(3, (_) =>
                        Container(
                          width: 1.5, height: 5,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: Colors.grey[300],
                        ),
                      )),
                    ),

                    // TO
                    Row(children: [
                      Container(
                        width: 11, height: 11,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TO', style: GoogleFonts.poppins(
                            fontSize: 9, color: Colors.black45,
                            letterSpacing: 1.2, fontWeight: FontWeight.w700,
                          )),
                          Text(_destinationName, style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      )),
                    ]),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Stats row ────────────────────────────────────────────
                if (_route != null)
                  Row(children: [
                    _statBox('${_route!.etaMinutes} min', 'ETA',
                        Icons.schedule_rounded, AppColors.primary),
                    const SizedBox(width: 8),
                    _statBox(
                        '${_route!.distanceKm.toStringAsFixed(1)} km',
                        'Distance',
                        Icons.route_rounded,
                        Colors.blue),
                    const SizedBox(width: 8),
                    _statBox('~₱${_estimateFare(_route!.distanceKm)}',
                        'Est. Fare',
                        Icons.payments_rounded,
                        Colors.green),
                  ])
                else if (_isRouting)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary)),
                        const SizedBox(width: 10),
                        Text('Calculating route...',
                            style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.black54,
                            )),
                      ]),
                  ),

                const SizedBox(height: 12),

                // ── Confirm button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isRouting ? null : _confirmDestination,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundDark,
                      disabledBackgroundColor:
                          AppColors.backgroundDark.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.electric_rickshaw_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Confirm Destination',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                      ]),
                  ),
                ),
              ]),
            ).animate().slideY(
                begin: 0.3, end: 0,
                duration: 400.ms, curve: Curves.easeOut),
          ),
      ]),
    );
  }

  Widget _statBox(
          String value, String label, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: Colors.black87,
            )),
            Text(label, style: GoogleFonts.poppins(
              fontSize: 10, color: Colors.black45,
            )),
          ]),
        ),
      );
}