import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'live_trip_tracking_screen.dart';
import 'passenger_home_screen.dart';

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
  GoogleMapController? _mapController;
  late AnimationController _pulseCtrl;
  Timer? _pollTimer;
  Timer? _dotsTimer;
  Timer? _waitTimer;
  int _dotsCount   = 1;
  int _waitSeconds = 0;
  bool _isCancelling = false;
  bool _isNavigating = false;

  static const LatLng _pickup = LatLng(7.1907, 125.4553);
  static const LatLng _driver = LatLng(7.1940, 125.4580);

  String get _initials {
    final parts = widget.driverName.trim().split(' ');
    return parts
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _dotsCount = (_dotsCount % 3) + 1);
    });

    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _waitSeconds++);
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkStatus();
    });

    Future.delayed(const Duration(seconds: 1), _checkStatus);
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
          Navigator.of(context).pushReplacement(PageRouteBuilder(
            pageBuilder: (_, __, ___) => LiveTripTrackingScreen(
              tripId: trip['trip_id']?.toString() ?? widget.tripId,
              driverName: trip['driver_name']?.toString() ?? widget.driverName,
              driverRating: widget.driverRating,
              todaBodyNumber:
                  trip['toda_body_number']?.toString() ?? widget.todaBodyNumber,
              plateNo: trip['plate_no']?.toString() ?? widget.plateNo,
              etaMinutes: widget.etaMinutes,
              distanceKm: widget.distanceKm,
            ),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ));
        } else if (status == 'cancelled') {
          _isNavigating = true;
          _stopTimers();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Driver declined. Please try another driver.',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
            (_) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('[WaitingScreen] Poll error: $e');
    }
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _dotsTimer?.cancel();
    _waitTimer?.cancel();
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

  String get _waitTime {
    if (_waitSeconds < 60) return '${_waitSeconds}s';
    return '${_waitSeconds ~/ 60}m ${_waitSeconds % 60}s';
  }

  @override
  void dispose() {
    _stopTimers();
    _pulseCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [

        // ── Google Map fills the screen ──────────────────────────────────
        Positioned.fill(child: _buildMap()),

        // ── Top status bar ───────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12, offset: const Offset(0, 3),
                  )],
                ),
                child: Row(children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(
                            0.4 + 0.6 * _pulseCtrl.value),
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
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.backgroundDark,
                      ),
                    ),
                    Text('Wait time: $_waitTime',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textHint)),
                  ]),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${widget.etaMinutes} min',
                        style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        )),
                  ),
                ]),
              ),
            ),
          ),
        ),

        // ── Bottom driver card ───────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(
                color: Colors.black12, blurRadius: 20,
                offset: Offset(0, -4),
              )],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 16),

              // Driver info
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(_initials,
                      style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.driverName, style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  )),
                  Text(widget.todaBodyNumber, style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textHint,
                  )),
                  if (widget.plateNo.isNotEmpty)
                    Text('Plate: ${widget.plateNo}',
                        style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textHint,
                        )),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text('Waiting', style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  )),
                ),
              ]),

              const SizedBox(height: 16),

              // Stats
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  _info('${widget.distanceKm.toStringAsFixed(1)} km',
                      'Distance', Icons.route_rounded),
                  _divV(),
                  _info('${widget.etaMinutes} min', 'ETA',
                      Icons.schedule_rounded),
                  _divV(),
                  _info('₱${widget.fare.toStringAsFixed(0)}', 'Fare',
                      Icons.payments_rounded),
                ]),
              ),

              const SizedBox(height: 14),

              // Checking indicator
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text('Checking every 3 seconds...',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint)),
              ]),

              const SizedBox(height: 14),

              // Cancel
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton(
                  onPressed: _isCancelling ? null : _cancelRide,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Cancel Ride', style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        )),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (c) => _mapController = c,
      initialCameraPosition: const CameraPosition(
        target: LatLng(7.1920, 125.4560),
        zoom: 14.5,
      ),
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('driver'),
          position: _driver,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow),
        ),
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue),
        ),
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_driver, _pickup],
          color: AppColors.primary,
          width: 4,
        ),
      },
    );
  }

  Widget _info(String value, String label, IconData icon) =>
      Expanded(child: Column(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w800,
          color: AppColors.backgroundDark,
        )),
        Text(label, style: GoogleFonts.poppins(
          fontSize: 10, color: AppColors.textHint,
        )),
      ]));

  Widget _divV() =>
      Container(width: 1, height: 40, color: const Color(0xFFEEEEEE));
}