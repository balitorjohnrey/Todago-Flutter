import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'passenger_home_screen.dart';
import 'rate_driver_screen.dart';   // NEW
import 'map_service.dart';

class LiveTripTrackingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final double driverRating;
  final String todaBodyNumber;
  final String plateNo;
  final int etaMinutes;
  final double distanceKm;
  final String? destination;
  final double? fare;

  const LiveTripTrackingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverRating,
    required this.todaBodyNumber,
    required this.plateNo,
    required this.etaMinutes,
    required this.distanceKm,
    this.destination,
    this.fare,
  });

  @override
  State<LiveTripTrackingScreen> createState() => _LiveTripTrackingScreenState();
}

class _LiveTripTrackingScreenState extends State<LiveTripTrackingScreen> {
  GoogleMapController? _mapCtrl;
  LatLng? _myLocation;
  LatLng? _driverPos;
  MapRoute? _route;
  String _tripStatus = 'accepted';
  bool _isFetchingRoute = false;

  String _destination = '';
  double _fare = 0;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Timer? _pollTimer;
  Timer? _routeRefreshTimer;
  StreamSubscription<LatLng>? _locSub;

  int get _liveEta => _route?.etaMinutes ?? widget.etaMinutes;
  double get _liveDist => _route?.distanceKm ?? widget.distanceKm;

  @override
  void initState() {
    super.initState();
    _destination = widget.destination ?? '';
    _fare = widget.fare ?? 0;
    _init();
  }

  Future<void> _init() async {
    final loc = await MapService.getCurrentLocation();
    if (!mounted) return;
    final myPos = loc ?? const LatLng(7.1907, 125.4553);
    final driverPos = LatLng(myPos.latitude + 0.008, myPos.longitude + 0.006);
    setState(() { _myLocation = myPos; _driverPos = driverPos; });
    _updateMarkers(myPos, driverPos);
    await _fetchAndDrawRoute(driverPos, myPos);
    _fitBounds(driverPos, myPos);

    _locSub = MapService.positionStream().listen((pos) async {
      if (!mounted) return;
      setState(() => _myLocation = pos);
      _updatePassengerMarker(pos);
      if (_driverPos != null && !_isFetchingRoute) {
        await _fetchAndDrawRoute(_driverPos!, pos);
      }
    });

    if (widget.tripId.isNotEmpty) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted) return;
        await _pollTrip();
      });
    }

    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || _driverPos == null || _myLocation == null) return;
      await _fetchAndDrawRoute(_driverPos!, _myLocation!);
    });
  }

  Future<void> _pollTrip() async {
    try {
      final trip = await TripService.getActiveTrip();
      if (!mounted) return;
      if (trip == null) { _pollTimer?.cancel(); _checkIfCompleted(); return; }

      if (trip['destination'] != null && trip['destination'].toString().isNotEmpty) {
        _destination = trip['destination'].toString();
      }
      if (trip['fare'] != null) {
        _fare = double.tryParse(trip['fare'].toString()) ?? _fare;
      }

      final status = trip['status']?.toString() ?? '';
      if (status != _tripStatus) {
        setState(() => _tripStatus = status);
        if (status == 'completed') { _pollTimer?.cancel(); _navigateToRating(); return; }
        if (status == 'cancelled') { _pollTimer?.cancel(); _showCancelled(); return; }
      }

      final driverLat = double.tryParse(trip['driver_lat']?.toString() ?? '');
      final driverLng = double.tryParse(trip['driver_lng']?.toString() ?? '');
      if (driverLat != null && driverLng != null) {
        final newDriverPos = LatLng(driverLat, driverLng);
        setState(() => _driverPos = newDriverPos);
        _updateDriverMarker(newDriverPos);
        if (_myLocation != null && !_isFetchingRoute) {
          await _fetchAndDrawRoute(newDriverPos, _myLocation!);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchAndDrawRoute(LatLng from, LatLng to) async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;
    try {
      final route = await MapService.fetchRoute(from, to);
      if (mounted && route != null) { setState(() => _route = route); _updatePolyline(route.points); }
    } finally { _isFetchingRoute = false; }
  }

  void _updateMarkers(LatLng passenger, LatLng driver) {
    setState(() {
      _markers = {
        Marker(markerId: const MarkerId('passenger'), position: passenger,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
            infoWindow: const InfoWindow(title: 'You')),
        Marker(markerId: const MarkerId('driver'), position: driver,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(title: widget.driverName, snippet: 'Driver')),
      };
    });
  }

  void _updatePassengerMarker(LatLng pos) {
    setState(() {
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'passenger'),
        Marker(markerId: const MarkerId('passenger'), position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
            infoWindow: const InfoWindow(title: 'You')),
      };
    });
  }

  void _updateDriverMarker(LatLng pos) {
    setState(() {
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'driver'),
        Marker(markerId: const MarkerId('driver'), position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(title: widget.driverName, snippet: 'Driver')),
      };
    });
  }

  void _updatePolyline(List<LatLng> pts) {
    setState(() {
      _polylines = {
        Polyline(polylineId: const PolylineId('route'), points: pts,
            color: const Color(0xFF1A73E8), width: 5,
            jointType: JointType.round, startCap: Cap.roundCap, endCap: Cap.roundCap),
      };
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

  // ── Trip completed → navigate to RateDriverScreen ─────────────────────────
  void _navigateToRating() {
    _stopTimers();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => RateDriverScreen(
        tripId:         widget.tripId,
        driverName:     widget.driverName,
        driverRating:   widget.driverRating,
        todaBodyNumber: widget.todaBodyNumber,
        plateNo:        widget.plateNo,
        destination:    _destination.isNotEmpty ? _destination : 'Your Destination',
        fare:           _fare > 0 ? _fare : 25.0,
      ),
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  Future<void> _checkIfCompleted() async {
    try {
      final history = await TripService.getCommuterHistory();
      if (!mounted) return;
      if (history.isNotEmpty && history.first['status'] == 'completed') {
        _navigateToRating();
        return;
      }
    } catch (_) {}
    _showCancelled();
  }

  void _showCancelled() => showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Trip Cancelled', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      content: Text('The driver cancelled. Please book again.', style: GoogleFonts.poppins(fontSize: 14)),
      actions: [ElevatedButton(
        onPressed: () { Navigator.pop(context); _goHome(); },
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.backgroundDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text('Back to Home', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)),
      )],
    ));

  void _goHome() => Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const PassengerHomeScreen(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ), (_) => false);

  Future<void> _cancelTrip(BuildContext ctx) async {
    final confirm = await showDialog<bool>(context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Trip?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure?', style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('No', style: GoogleFonts.poppins(color: AppColors.textHint))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Yes, Cancel', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ));
    if (confirm != true) return;
    _stopTimers();
    if (widget.tripId.isNotEmpty) await TripService.updateTripStatus(widget.tripId, 'cancelled');
    if (!mounted) return;
    _goHome();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _locSub?.cancel();
  }

  @override
  void dispose() { _stopTimers(); _mapCtrl?.dispose(); super.dispose(); }

  String get _initials => widget.driverName.trim().split(' ')
      .take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

  String get _statusLabel {
    switch (_tripStatus) {
      case 'requested': return 'Waiting for driver to accept...';
      case 'accepted':  return 'Driver is on the way!';
      case 'pickup':    return 'Driver arrived at pickup!';
      case 'ongoing':   return 'Enjoy your ride!';
      default:          return 'Connecting...';
    }
  }

  Color get _statusColor {
    switch (_tripStatus) {
      case 'requested': return Colors.orange;
      case 'accepted':  return AppColors.primary;
      case 'pickup':    return Colors.blue;
      case 'ongoing':   return AppColors.success;
      default:          return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: _myLocation == null
          ? Container(color: const Color(0xFFE8EFF5),
              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)))
          : GoogleMap(
              initialCameraPosition: CameraPosition(target: _myLocation!, zoom: 15),
              onMapCreated: (ctrl) {
                _mapCtrl = ctrl;
                if (_driverPos != null && _myLocation != null) _fitBounds(_driverPos!, _myLocation!);
              },
              markers: _markers, polylines: _polylines,
              myLocationEnabled: true, myLocationButtonEnabled: false,
              zoomControlsEnabled: false, mapToolbarEnabled: false)),

        Positioned(top: 0, left: 0, right: 0,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withOpacity(0.4), width: 1.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_statusLabel, style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor)),
                ])),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12),
                        blurRadius: 12, offset: const Offset(0, 3))]),
                child: Row(children: [
                  _etaItem('ETA', '$_liveEta min', Icons.schedule_rounded),
                  const SizedBox(width: 24),
                  _etaItem('Distance', '${_liveDist.toStringAsFixed(1)} km', Icons.straighten_rounded),
                  const Spacer(),
                  GestureDetector(
                    onTap: () { if (_driverPos != null && _myLocation != null) _fitBounds(_driverPos!, _myLocation!); },
                    child: Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFF0F2F5), shape: BoxShape.circle),
                        child: const Icon(Icons.my_location_rounded, size: 18, color: Colors.black54))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _cancelTrip(context),
                    child: Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle,
                            border: Border.all(color: Colors.red.withOpacity(0.3))),
                        child: const Icon(Icons.close_rounded, color: Colors.red, size: 20))),
                ])),
            ]),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0))),

        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))]),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 50, height: 50,
                    decoration: BoxDecoration(color: AppColors.backgroundDark, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(_initials, style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.driverName, style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.backgroundDark)),
                  Row(children: [
                    const Icon(Icons.star_rounded, color: AppColors.primary, size: 14),
                    const SizedBox(width: 3),
                    Text(widget.driverRating.toStringAsFixed(1), style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.backgroundDark, fontWeight: FontWeight.w600)),
                    if (widget.todaBodyNumber.isNotEmpty)
                      Text(' · ${widget.todaBodyNumber}', style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textHint)),
                  ]),
                  if (widget.plateNo.isNotEmpty)
                    Text('Plate: ${widget.plateNo}', style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint)),
                ])),
                Row(children: [
                  _actionBtn(Icons.phone_rounded, Colors.green),
                  const SizedBox(width: 10),
                  _actionBtn(Icons.chat_bubble_rounded, AppColors.primary),
                ]),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEEE))),
                child: Row(children: [
                  const Icon(Icons.navigation_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Text('Your driver is heading to you', style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.backgroundDark)),
                ])),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, height: 48,
                child: OutlinedButton(
                  onPressed: () => _cancelTrip(context),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text('Cancel Trip', style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textHint)))),
            ])).animate().slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut)),
      ]),
    );
  }

  Widget _etaItem(String label, String value, IconData icon) => Row(children: [
    Icon(icon, size: 16, color: AppColors.textHint), const SizedBox(width: 6),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
      Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.backgroundDark)),
    ])]);

  Widget _actionBtn(IconData icon, Color color) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Icon(icon, color: color, size: 20));
}