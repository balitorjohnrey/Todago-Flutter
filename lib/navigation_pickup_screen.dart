import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'active_trip_driver_screen.dart';
import 'map_service.dart';

class NavigationPickupScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const NavigationPickupScreen({super.key, required this.trip});
  @override
  State<NavigationPickupScreen> createState() => _NavigationPickupScreenState();
}

class _NavigationPickupScreenState extends State<NavigationPickupScreen> {
  GoogleMapController? _mapCtrl;
  LatLng? _myLocation;
  LatLng? _pickupPoint;
  MapRoute? _route;
  bool _isConfirming = false;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  StreamSubscription<LatLng>? _locSub;

  String get _passengerName  => widget.trip['commuter_name']?.toString()   ?? 'Passenger';
  String get _pickupLocation => widget.trip['pickup_location']?.toString() ?? 'Pickup Location';
  String get _paymentMethod  => (widget.trip['payment_method']?.toString() ?? 'cash').toUpperCase();
  String get _passengerInitials => _passengerName.trim().split(' ')
      .take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  double get _fare {
    final f = widget.trip['fare'];
    if (f == null) return 25.0;
    if (f is double) return f;
    if (f is int) return f.toDouble();
    return double.tryParse(f.toString()) ?? 25.0;
  }

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final loc = await MapService.getCurrentLocation();
    if (!mounted) return;
    final myPos    = loc ?? const LatLng(7.1907, 125.4553);
    final pickup   = LatLng(myPos.latitude - 0.006, myPos.longitude - 0.004);
    setState(() { _myLocation = myPos; _pickupPoint = pickup; });
    _updateMarkers(myPos, pickup);
    final route = await MapService.fetchRoute(myPos, pickup);
    if (mounted && route != null) {
      setState(() => _route = route);
      _updatePolyline(route.points);
      _fitBounds(myPos, pickup);
    }
    _locSub = MapService.positionStream().listen((pos) async {
      if (!mounted) return;
      setState(() => _myLocation = pos);
      _markers = { ..._markers.where((m) => m.markerId.value != 'driver'),
        Marker(markerId: const MarkerId('driver'), position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'You (Driver)'))};
      if (_pickupPoint != null) {
        final r = await MapService.fetchRoute(pos, _pickupPoint!);
        if (mounted && r != null) { setState(() => _route = r); _updatePolyline(r.points); }
      }
    });
  }

  void _updateMarkers(LatLng driver, LatLng pickup) {
    setState(() {
      _markers = {
        Marker(markerId: const MarkerId('driver'), position: driver,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'You (Driver)')),
        Marker(markerId: const MarkerId('pickup'), position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: _passengerName, snippet: 'Pickup')),
      };
    });
  }

  void _updatePolyline(List<LatLng> pts) {
    setState(() {
      _polylines = { Polyline(
        polylineId: const PolylineId('route'), points: pts,
        color: const Color(0xFFF5B731), width: 5,
        jointType: JointType.round, startCap: Cap.roundCap, endCap: Cap.roundCap) };
    });
  }

  void _fitBounds(LatLng a, LatLng b) {
    final bounds = LatLngBounds(
      southwest: LatLng(a.latitude < b.latitude ? a.latitude : b.latitude,
                        a.longitude < b.longitude ? a.longitude : b.longitude),
      northeast: LatLng(a.latitude > b.latitude ? a.latitude : b.latitude,
                        a.longitude > b.longitude ? a.longitude : b.longitude),
    );
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  void dispose() { _locSub?.cancel(); _mapCtrl?.dispose(); super.dispose(); }

  Future<void> _confirmArrival() async {
    setState(() => _isConfirming = true);
    final tripId = widget.trip['trip_id']?.toString() ?? '';
    if (tripId.isNotEmpty) await TripService.updateTripStatus(tripId, 'pickup');
    if (!mounted) return;
    setState(() => _isConfirming = false);
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => ActiveTripDriverScreen(trip: widget.trip),
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final eta  = _route?.etaMinutes ?? 2;
    final dist = _route?.distanceKm ?? 0.8;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: _myLocation == null
          ? Container(color: const Color(0xFFE8EFF5),
              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)))
          : GoogleMap(
              initialCameraPosition: CameraPosition(target: _myLocation!, zoom: 15),
              onMapCreated: (ctrl) { _mapCtrl = ctrl; },
              markers: _markers, polylines: _polylines,
              myLocationEnabled: true, myLocationButtonEnabled: false,
              zoomControlsEnabled: false, mapToolbarEnabled: false)),

        // Top card
        Positioned(top: 0, left: 0, right: 0,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14, offset: const Offset(0,4))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.navigation_rounded, color: AppColors.backgroundDark, size: 14),
                    const SizedBox(width: 4),
                    Text('NAVIGATING TO PICKUP', style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: AppColors.backgroundDark, letterSpacing: 0.5)),
                  ])),
                const SizedBox(height: 12),
                Row(children: [
                  _navStat('${dist.toStringAsFixed(1)} km', 'Distance'),
                  const SizedBox(width: 24),
                  _navStat('$eta min', 'ETA'),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_pickupLocation, style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.backgroundDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ])).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0)))),

        // Bottom card
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0,-4))]),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(_passengerInitials, style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.backgroundDark)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_passengerName, style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.backgroundDark)),
                  Text('${widget.trip["service_type"]?.toString().toUpperCase() ?? "SOLO"} · $_paymentMethod',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
                ])),
                Row(children: [
                  _iconBtn(Icons.phone_rounded, Colors.green),
                  const SizedBox(width: 8),
                  _iconBtn(Icons.chat_bubble_rounded, AppColors.primary),
                ]),
              ]),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _tripStat('$eta min', 'ETA'), _divV(),
                _tripStat('${dist.toStringAsFixed(1)} km', 'Distance'), _divV(),
                _tripStat('₱${_fare.toStringAsFixed(0)}', 'Fare'),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isConfirming ? null : _confirmArrival,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConfirming ? AppColors.backgroundDark.withOpacity(0.7) : AppColors.backgroundDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: _isConfirming
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Confirm Arrival', style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ]))),
            ]))).animate().slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut)),
      ]),
    );
  }

  Widget _navStat(String v, String l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(v, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.backgroundDark)),
    Text(l, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint))]);
  Widget _iconBtn(IconData icon, Color c) => Container(width: 38, height: 38,
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.withOpacity(0.3))),
    child: Icon(icon, color: c, size: 18));
  Widget _tripStat(String v, String l) => Column(children: [
    Text(v, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.backgroundDark)),
    Text(l, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint))]);
  Widget _divV() => Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));
}