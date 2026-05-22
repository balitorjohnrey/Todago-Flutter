import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'live_trip_tracking_screen.dart';
import 'passenger_home_screen.dart';
import 'map_service.dart';

class PassengerWaitingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final double driverRating;
  final String todaBodyNumber;
  final String plateNo;
  final int etaMinutes;
  final double distanceKm;
  final double fare;
  final String serviceType;

  const PassengerWaitingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverRating,
    required this.todaBodyNumber,
    required this.plateNo,
    required this.etaMinutes,
    required this.distanceKm,
    required this.fare,
    required this.serviceType,
  });

  @override
  State<PassengerWaitingScreen> createState() => _PassengerWaitingScreenState();
}

class _PassengerWaitingScreenState extends State<PassengerWaitingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  GoogleMapController? _mapCtrl;
  LatLng? _myLocation;
  MapRoute? _route;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Timer? _pollTimer;
  Timer? _dotsTimer;
  Timer? _waitTimer;
  StreamSubscription<LatLng>? _locSub;

  int _dotsCount = 1;
  int _waitSeconds = 0;
  bool _isCancelling = false;
  bool _isNavigating = false;

  String get _initials => widget.driverName
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();
  String get _waitTime => _waitSeconds < 60
      ? '${_waitSeconds}s'
      : '${_waitSeconds ~/ 60}m ${_waitSeconds % 60}s';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _dotsCount = (_dotsCount % 3) + 1);
    });
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _waitSeconds++);
    });
    _init();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
    Future.delayed(const Duration(seconds: 1), _checkStatus);
  }

  Future<void> _init() async {
    final loc = await MapService.getCurrentLocation();
    if (!mounted) return;
    final myPos = loc ?? const LatLng(7.1907, 125.4553);
    final driverPos = LatLng(myPos.latitude + 0.008, myPos.longitude + 0.006);
    setState(() {
      _myLocation = myPos;
    });
    _updateMarkers(myPos, driverPos);
    final route = await MapService.fetchRoute(driverPos, myPos);
    if (mounted && route != null) {
      setState(() => _route = route);
      _updatePolyline(route.points);
      _fitBounds(driverPos, myPos);
    }
    _locSub = MapService.positionStream().listen((pos) {
      if (!mounted) return;
      setState(() => _myLocation = pos);
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'passenger'),
        Marker(
          markerId: const MarkerId('passenger'),
          position: pos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      };
    });
  }

  void _updateMarkers(LatLng my, LatLng driver) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('passenger'),
          position: my,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: 'You'),
        ),
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow:
              InfoWindow(title: widget.driverName, snippet: 'Coming to you'),
        ),
      };
    });
  }

  void _updatePolyline(List<LatLng> pts) {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: pts,
          color: const Color(0xFF1A73E8),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });
  }

  void _fitBounds(LatLng a, LatLng b) {
    final bounds = LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<void> _checkStatus() async {
    if (_isNavigating || !mounted) return;
    try {
      final trip = await TripService.getActiveTrip();
      if (!mounted || _isNavigating) return;
      if (trip != null) {
        final status = trip['status']?.toString() ?? '';
        if (status == 'accepted' || status == 'pickup' || status == 'ongoing') {
          _isNavigating = true;
          _stopTimers();
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => LiveTripTrackingScreen(
                tripId: trip['trip_id']?.toString() ?? widget.tripId,
                driverName:
                    trip['driver_name']?.toString() ?? widget.driverName,
                driverRating: widget.driverRating,
                todaBodyNumber: trip['toda_body_number']?.toString() ??
                    widget.todaBodyNumber,
                plateNo: trip['plate_no']?.toString() ?? widget.plateNo,
                etaMinutes: widget.etaMinutes,
                distanceKm: widget.distanceKm,
              ),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        } else if (status == 'cancelled') {
          _isNavigating = true;
          _stopTimers();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Driver declined. Please try again.',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
            (_) => false,
          );
        }
      }
    } catch (_) {}
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _dotsTimer?.cancel();
    _waitTimer?.cancel();
    _locSub?.cancel();
  }

  Future<void> _cancelRide() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    _stopTimers();
    if (widget.tripId.isNotEmpty) {
      await TripService.updateTripStatus(widget.tripId, 'cancelled');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PassengerHomeScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _stopTimers();
    _pulseCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          Positioned.fill(
            child: _myLocation == null
                ? Container(
                    color: const Color(0xFFE8EFF5),
                    child: const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: _myLocation!, zoom: 15),
                    onMapCreated: (ctrl) => _mapCtrl = ctrl,
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
          ),

          // ── Top status bar ───────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(31),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(
                              (102 + (153 * _pulseCtrl.value).round())
                                  .clamp(0, 255),
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Waiting for driver${'.' * _dotsCount}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.backgroundDark,
                            ),
                          ),
                          Text(
                            'Wait time: $_waitTime',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.etaMinutes} min',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom card ──────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Driver row
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            _initials,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.driverName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.backgroundDark,
                              ),
                            ),
                            Text(
                              widget.todaBodyNumber,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                            ),
                            if (widget.plateNo.isNotEmpty)
                              Text(
                                'Plate: ${widget.plateNo}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange.withAlpha(77)),
                        ),
                        child: Text(
                          'Waiting',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Distance / ETA / Fare row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _info(
                          '${widget.distanceKm.toStringAsFixed(1)} km',
                          'Distance',
                          Icons.route_rounded,
                        ),
                        _divV(),
                        _info(
                          '${widget.etaMinutes} min',
                          'ETA',
                          Icons.schedule_rounded,
                        ),
                        _divV(),
                        _info(
                          '₱${widget.fare.toStringAsFixed(0)}',
                          'Fare',
                          Icons.payments_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Poll indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Checking every 4 seconds...',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isCancelling ? null : _cancelRide,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isCancelling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Cancel Ride',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String v, String l, IconData icon) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              v,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              ),
            ),
            Text(
              l,
              style:
                  GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint),
            ),
          ],
        ),
      );

  Widget _divV() => Container(
        width: 1,
        height: 40,
        color: const Color(0xFFEEEEEE),
      );
}
