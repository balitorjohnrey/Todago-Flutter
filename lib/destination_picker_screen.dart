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
  RouteInfo({required this.points, required this.distanceKm, required this.etaMinutes});
}

// ── Screen ────────────────────────────────────────────────────────────────────
class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key});
  @override
  State<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
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

  // ── Get current GPS location ───────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    try {
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
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
      _mapCtrl.move(_currentLocation!, 15);
      _reverseGeocode(_currentLocation!);
    } catch (_) {
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    // Default: Panabo City, Davao del Norte
    setState(() => _currentLocation = const LatLng(7.1907, 125.4553));
    _mapCtrl.move(_currentLocation!, 14);
  }

  // ── Reverse geocode to get address from coords ────────────────────────────
  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}'
        '&format=json&zoom=16',
      );
      final res = await http.get(url, headers: {'User-Agent': 'TodaGo/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['address'];
        final parts = <String>[];
        if (addr['road'] != null) parts.add(addr['road']);
        if (addr['suburb'] != null) parts.add(addr['suburb']);
        if (addr['city'] != null) parts.add(addr['city']);
        if (mounted) setState(() => _pickupName = parts.join(', '));
      }
    } catch (_) {}
  }

  // ── Search Nominatim ───────────────────────────────────────────────────────
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() { _isSearching = true; _showSuggestions = true; });
    try {
      // Bias results toward Davao region
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q + ' Davao Philippines')}'
        '&format=json&limit=6&countrycodes=ph'
        '&viewbox=124.0,6.5,126.5,8.5&bounded=0',
      );
      final res = await http.get(url, headers: {'User-Agent': 'TodaGo/1.0'})
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _suggestions = list
              .map((j) => PlaceSuggestion.fromJson(j as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Select destination ─────────────────────────────────────────────────────
  Future<void> _selectDestination(PlaceSuggestion place) async {
    setState(() {
      _destination = LatLng(place.lat, place.lon);
      _destinationName = place.shortName;
      _showSuggestions = false;
      _suggestions = [];
      _searchCtrl.text = place.shortName;
      _route = null;
    });
    _searchFocus.unfocus();

    // Fit map to show both points
    if (_currentLocation != null) {
      final bounds = LatLngBounds.fromPoints([_currentLocation!, _destination!]);
      _mapCtrl.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
      );
      await _fetchRoute();
    } else {
      _mapCtrl.move(_destination!, 14);
    }
  }

  // ── Fetch route from OSRM ──────────────────────────────────────────────────
  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;
    setState(() => _isRouting = true);
    try {
      final from = _currentLocation!;
      final to   = _destination!;
      final url  = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving'
        '/${from.longitude},${from.latitude}'
        ';${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(url, headers: {'User-Agent': 'TodaGo/1.0'})
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final route = (data['routes'] as List).first;
        final distMeters = (route['distance'] as num).toDouble();
        final durSecs    = (route['duration'] as num).toDouble();
        final coords = (route['geometry']['coordinates'] as List)
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
        setState(() {
          _route = RouteInfo(
            points: coords,
            distanceKm: distMeters / 1000,
            etaMinutes: (durSecs / 60).ceil(),
          );
        });
      }
    } catch (_) {
      // Fallback: straight line
      if (_currentLocation != null && _destination != null) {
        final dist = const Distance().as(
          LengthUnit.Kilometer, _currentLocation!, _destination!,
        );
        setState(() => _route = RouteInfo(
          points: [_currentLocation!, _destination!],
          distanceKm: dist,
          etaMinutes: (dist / 0.4).ceil(), // ~24 km/h tricycle speed
        ));
      }
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  // ── Confirm and go to service selection ────────────────────────────────────
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
      transitionsBuilder: (_, anim, __, child) =>
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1), end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [

        // ── Full-screen Map ──────────────────────────────────────────────
        if (_currentLocation != null)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _currentLocation!,
                initialZoom: 14.5,
                onTap: (_, __) {
                  _searchFocus.unfocus();
                  setState(() => _showSuggestions = false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.todago.app',
                ),

                // Route polyline
                if (_route != null)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: _route!.points,
                      color: AppColors.primary,
                      strokeWidth: 5,
                      borderColor: AppColors.backgroundDark,
                      borderStrokeWidth: 1.5,
                    ),
                  ]),

                // Markers
                MarkerLayer(markers: [
                  // Current location
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 44, height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10, spreadRadius: 2,
                          )],
                        ),
                        child: const Icon(Icons.person_pin_circle_rounded,
                            color: AppColors.backgroundDark, size: 22),
                      ),
                    ),
                  // Destination
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 44, height: 52,
                      child: Column(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundDark,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                            )],
                          ),
                          child: const Icon(Icons.location_on_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        Container(width: 2.5, height: 10,
                            color: AppColors.backgroundDark),
                      ]),
                    ),
                ]),
              ],
            ),
          )
        else
          // Loading map
          Container(
            color: AppColors.background,
            child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text('Getting your location...',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
              ],
            )),
          ),

        // ── Top search panel ─────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(children: [

                // Back + Search bar
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                        )],
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: AppColors.backgroundDark, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12, offset: const Offset(0, 3),
                        )],
                      ),
                      child: Row(children: [
                        const SizedBox(width: 14),
                        const Icon(Icons.search_rounded,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            style: GoogleFonts.poppins(
                              fontSize: 15, color: AppColors.backgroundDark,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Where to go?',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 15, color: AppColors.textHint,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
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
                                  color: AppColors.textHint, size: 18),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ]),

                // Search suggestions dropdown
                if (_showSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 6, left: 52),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12, offset: const Offset(0, 4),
                      )],
                    ),
                    child: _isSearching && _suggestions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            )),
                          )
                        : _suggestions.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text('No results found',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: AppColors.textHint)),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _suggestions.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: Color(0xFFF0F0F0)),
                                itemBuilder: (_, i) {
                                  final s = _suggestions[i];
                                  return GestureDetector(
                                    onTap: () => _selectDestination(s),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: Row(children: [
                                        Container(
                                          width: 32, height: 32,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.location_on_rounded,
                                              color: AppColors.primary, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.shortName, style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.backgroundDark,
                                            )),
                                            Text(s.displayName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11, color: AppColors.textHint,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        )),
                                      ]),
                                    ),
                                  );
                                },
                              ),
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0),

              ]),
            ),
          ),
        ),

        // ── Routing indicator ────────────────────────────────────────────
        if (_isRouting)
          Positioned(
            top: 110, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  )],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
                  const SizedBox(width: 8),
                  Text('Getting route...', style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600,
                  )),
                ]),
              ),
            ),
          ),

        // ── Bottom route info + confirm ──────────────────────────────────
        if (_destination != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(
                  color: Colors.black12, blurRadius: 20, offset: Offset(0, -4),
                )],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Drag handle
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),

                const SizedBox(height: 16),

                // Route card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(children: [
                    // Pickup row
                    Row(children: [
                      Container(
                        width: 10, height: 10,
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
                            fontSize: 9, color: AppColors.textHint,
                            letterSpacing: 1, fontWeight: FontWeight.w700,
                          )),
                          Text(_pickupName, style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: AppColors.backgroundDark,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      )),
                    ]),

                    // Dashed line
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Column(children: List.generate(3, (_) =>
                        Container(
                          width: 1.5, height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: Colors.grey[300],
                        ),
                      )),
                    ),

                    // Destination row
                    Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TO', style: GoogleFonts.poppins(
                            fontSize: 9, color: AppColors.textHint,
                            letterSpacing: 1, fontWeight: FontWeight.w700,
                          )),
                          Text(_destinationName, style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: AppColors.backgroundDark,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      )),
                    ]),
                  ]),
                ),

                const SizedBox(height: 12),

                // ETA + Distance stats
                if (_route != null)
                  Row(children: [
                    _statBox('${_route!.etaMinutes} min', 'ETA',
                        Icons.schedule_rounded, AppColors.primary),
                    const SizedBox(width: 10),
                    _statBox(
                      '${_route!.distanceKm.toStringAsFixed(1)} km',
                      'Distance', Icons.route_rounded, Colors.blue),
                    const SizedBox(width: 10),
                    _statBox('~₱${_estimateFare(_route!.distanceKm)}',
                        'Est. Fare', Icons.payments_rounded, Colors.green),
                  ])
                else if (_isRouting)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)),
                      const SizedBox(width: 10),
                      Text('Calculating route...', style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textHint,
                      )),
                    ]),
                  ),

                const SizedBox(height: 14),

                // Confirm button
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isRouting ? null : _confirmDestination,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundDark,
                      disabledBackgroundColor: AppColors.backgroundDark.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.electric_rickshaw_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Confirm Destination', style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                      )),
                    ]),
                  ),
                ),

              ]),
            ).animate().slideY(begin: 0.3, end: 0,
                duration: 400.ms, curve: Curves.easeOut),
          ),

        // ── My location button ───────────────────────────────────────────
        if (_destination == null)
          Positioned(
            bottom: 24, right: 16,
            child: FloatingActionButton(
              mini: false,
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: () {
                if (_currentLocation != null) {
                  _mapCtrl.move(_currentLocation!, 15);
                }
              },
              child: const Icon(Icons.my_location_rounded,
                  color: AppColors.backgroundDark),
            ),
          ),
      ]),
    );
  }

  String _estimateFare(double km) {
    // Base fare ₱15 + ₱5/km
    final fare = 15 + (km * 5).round();
    return fare.clamp(15, 200).toString();
  }

  Widget _statBox(String value, String label, IconData icon, Color color) =>
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
              color: AppColors.backgroundDark,
            )),
            Text(label, style: GoogleFonts.poppins(
              fontSize: 10, color: AppColors.textHint,
            )),
          ]),
        ),
      );
}