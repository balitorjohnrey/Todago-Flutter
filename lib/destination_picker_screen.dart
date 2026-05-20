import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'service_selection_screen.dart';
import 'map_service.dart';

class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key});
  @override
  State<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  GoogleMapController? _mapCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  LatLng? _myLocation;
  LatLng? _destination;
  String _pickupName   = 'Your Location';
  String _destName     = '';
  MapRoute? _route;

  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching   = false;
  bool _isRouting     = false;
  bool _showSugg      = false;
  bool _loadingLoc    = true;

  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final loc = await MapService.getCurrentLocation();
    if (!mounted) return;
    final pos = loc ?? const LatLng(7.1907, 125.4553);
    setState(() { _myLocation = pos; _loadingLoc = false; });
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
    final address = await MapService.reverseGeocode(pos);
    if (mounted) setState(() => _pickupName = address);
    _updateMyMarker(pos);
  }

  void _updateMyMarker(LatLng pos) {
    final marker = Marker(
      markerId: const MarkerId('my_location'),
      position: pos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      infoWindow: InfoWindow(title: 'You', snippet: _pickupName),
    );
    setState(() {
      _markers = { marker, ..._markers.where((m) => m.markerId.value != 'my_location') };
    });
  }

  void _updateDestMarker(LatLng pos, String name) {
    final marker = Marker(
      markerId: const MarkerId('destination'),
      position: pos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: 'Destination', snippet: name),
    );
    setState(() {
      _markers = { marker, ..._markers.where((m) => m.markerId.value != 'destination') };
    });
  }

  void _updatePolyline(List<LatLng> points) {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: const Color(0xFFF5B731),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });
  }

  // ── Search ────────────────────────────────────────────────────────────────
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _suggestions = []; _showSugg = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() { _isSearching = true; _showSugg = true; });
    final results = await MapService.searchPlaces(q);
    if (mounted) setState(() { _suggestions = results; _isSearching = false; });
  }

  // ── Select destination ────────────────────────────────────────────────────
  Future<void> _selectDestination(PlaceSuggestion place) async {
    _searchFocus.unfocus();
    setState(() { _showSugg = false; _suggestions = []; _isRouting = true;
                  _searchCtrl.text = place.mainText; _destName = place.mainText; });

    final coords = await MapService.getPlaceLatLng(place.placeId);
    if (!mounted || coords == null) { setState(() => _isRouting = false); return; }

    setState(() => _destination = coords);
    _updateDestMarker(coords, place.mainText);

    if (_myLocation != null) {
      // Fit camera to show both points
      final bounds = LatLngBounds(
        southwest: LatLng(
          _myLocation!.latitude  < coords.latitude  ? _myLocation!.latitude  : coords.latitude,
          _myLocation!.longitude < coords.longitude ? _myLocation!.longitude : coords.longitude,
        ),
        northeast: LatLng(
          _myLocation!.latitude  > coords.latitude  ? _myLocation!.latitude  : coords.latitude,
          _myLocation!.longitude > coords.longitude ? _myLocation!.longitude : coords.longitude,
        ),
      );
      _mapCtrl?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
      final route = await MapService.fetchRoute(_myLocation!, coords);
      if (mounted && route != null) {
        setState(() { _route = route; _isRouting = false; });
        _updatePolyline(route.points);
      } else {
        setState(() => _isRouting = false);
      }
    } else {
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(coords, 14));
      setState(() => _isRouting = false);
    }
  }

  void _confirmDestination() {
    if (_destination == null) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => ServiceSelectionScreen(
        pickupName: _pickupName,
        destinationName: _destName,
        pickupLatLng: _myLocation,
        destinationLatLng: _destination,
        etaMinutes: _route?.etaMinutes,
        distanceKm: _route?.distanceKm,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  String _estimateFare(double km) =>
      (15 + (km * 5)).round().clamp(15, 300).toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [

        // ── Google Map ────────────────────────────────────────────────────
        Positioned.fill(
          child: _loadingLoc
              ? Container(color: const Color(0xFFE8EFF5),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Getting your location...', style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.backgroundDark,
                        fontWeight: FontWeight.w500)),
                  ])))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _myLocation ?? const LatLng(7.1907, 125.4553),
                    zoom: 16,
                  ),
                  onMapCreated: (ctrl) {
                    _mapCtrl = ctrl;
                    if (_myLocation != null) {
                      ctrl.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 16));
                      _updateMyMarker(_myLocation!);
                    }
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onTap: (_) {
                    _searchFocus.unfocus();
                    setState(() => _showSugg = false);
                  },
                ),
        ),

        // ── Top search panel ──────────────────────────────────────────────
        Positioned(top: 0, left: 0, right: 0,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18),
                          blurRadius: 10, offset: const Offset(0, 2))]),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.black87, size: 18)),
                ),
                const SizedBox(width: 10),
                // Search bar — WHITE with BLACK text
                Expanded(child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18),
                        blurRadius: 12, offset: const Offset(0, 3))]),
                  child: Row(children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search_rounded, color: Colors.black54, size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.poppins(
                          fontSize: 15, color: Colors.black,
                          fontWeight: FontWeight.w500),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: 'Where to go?',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 15, color: Colors.black45),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.zero),
                    )),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() {
                            _suggestions = []; _showSugg = false;
                            _destination = null; _route = null;
                            _polylines = {};
                            _markers = _markers
                                .where((m) => m.markerId.value != 'destination')
                                .toSet();
                          });
                        },
                        child: const Padding(padding: EdgeInsets.all(12),
                          child: Icon(Icons.close_rounded,
                              color: Colors.black45, size: 18))),
                  ]),
                )),
              ]),

              // Suggestions
              if (_showSugg)
                Container(
                  margin: const EdgeInsets.only(top: 6, left: 54),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
                        blurRadius: 14, offset: const Offset(0, 4))]),
                  child: _isSearching && _suggestions.isEmpty
                      ? const Padding(padding: EdgeInsets.all(16),
                          child: Center(child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                  color: AppColors.primary))))
                      : _suggestions.isEmpty
                          ? Padding(padding: const EdgeInsets.all(16),
                              child: Text('No results found',
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54)))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
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
                                          color: AppColors.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(9)),
                                        child: const Icon(Icons.location_on_rounded,
                                            color: AppColors.primary, size: 18)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.mainText, style: GoogleFonts.poppins(
                                              fontSize: 13, fontWeight: FontWeight.w600,
                                              color: Colors.black87)),
                                          if (s.secondaryText.isNotEmpty)
                                            Text(s.secondaryText,
                                                style: GoogleFonts.poppins(
                                                    fontSize: 11, color: Colors.black45),
                                                maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ])),
                                      const Icon(Icons.chevron_right_rounded,
                                          color: Colors.black26, size: 18),
                                    ]),
                                  ));
                              }),
                ).animate().fadeIn(duration: 200.ms),
            ]),
          ))),

        // ── Routing indicator ─────────────────────────────────────────────
        if (_isRouting)
          Positioned(top: 110, left: 0, right: 0,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark, borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 10),
                Text('Getting road route...', style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
              ])))),

        // ── My location button ────────────────────────────────────────────
        if (!_loadingLoc && _destination == null)
          Positioned(bottom: 28, right: 16,
            child: GestureDetector(
              onTap: () {
                if (_myLocation != null) {
                  _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 16));
                }
              },
              child: Container(width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.backgroundDark, size: 22)))),

        // ── Bottom route card ─────────────────────────────────────────────
        if (_destination != null)
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))]),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEEE))),
                  child: Column(children: [
                    Row(children: [
                      Container(width: 11, height: 11,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle,
                            border: Border.all(color: AppColors.backgroundDark, width: 2))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('FROM', style: GoogleFonts.poppins(
                            fontSize: 9, color: Colors.black45, letterSpacing: 1.2,
                            fontWeight: FontWeight.w700)),
                        Text(_pickupName, style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                    ]),
                    Padding(padding: const EdgeInsets.only(left: 4.5),
                      child: Column(children: List.generate(3, (_) =>
                          Container(width: 1.5, height: 5,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: Colors.grey[300])))),
                    Row(children: [
                      Container(width: 11, height: 11,
                        decoration: BoxDecoration(color: AppColors.backgroundDark,
                            borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('TO', style: GoogleFonts.poppins(
                            fontSize: 9, color: Colors.black45, letterSpacing: 1.2,
                            fontWeight: FontWeight.w700)),
                        Text(_destName, style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                if (_route != null)
                  Row(children: [
                    _statBox('${_route!.etaMinutes} min',
                        _route!.durationText.isNotEmpty ? _route!.durationText : 'ETA',
                        Icons.schedule_rounded, AppColors.primary),
                    const SizedBox(width: 8),
                    _statBox('${_route!.distanceKm.toStringAsFixed(1)} km',
                        _route!.distanceText.isNotEmpty ? _route!.distanceText : 'Distance',
                        Icons.route_rounded, Colors.blue),
                    const SizedBox(width: 8),
                    _statBox('~₱${_estimateFare(_route!.distanceKm)}', 'Est. Fare',
                        Icons.payments_rounded, Colors.green),
                  ])
                else if (_isRouting)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      const SizedBox(width: 10),
                      Text('Calculating route...', style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.black54)),
                    ])),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isRouting ? null : _confirmDestination,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundDark,
                      disabledBackgroundColor: AppColors.backgroundDark.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.electric_rickshaw_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Confirm Destination', style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  )),
              ]),
            ).animate().slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut)),
      ]),
    );
  }

  Widget _statBox(String value, String label, IconData icon, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.black45)),
        ]),
      ));
}