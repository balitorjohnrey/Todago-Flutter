import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  State<PassengerWaitingScreen> createState() =>
      _PassengerWaitingScreenState();
}

class _PassengerWaitingScreenState extends State<PassengerWaitingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Timer? _pollTimer;
  Timer? _dotsTimer;
  Timer? _waitTimer;

  int _dotsCount = 1;
  int _waitSeconds = 0;
  bool _isCancelling = false;

  // ── FIX: Track if we've ever confirmed the trip exists in DB ─────────────
  // When getActiveTrip() returns null AFTER trip was confirmed, it means
  // the driver cancelled/declined — not a network glitch.
  bool _tripConfirmedInDb = false;
  int _nullResponseCount = 0; // how many consecutive nulls after confirmation

  final LatLng _pickup = const LatLng(7.1907, 125.4553);
  final LatLng _driver = const LatLng(7.1940, 125.4580);

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
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _dotsCount = (_dotsCount % 3) + 1);
    });

    _waitTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _waitSeconds++);
    });

    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      await _checkTripStatus();
    });
  }

  Future<void> _checkTripStatus() async {
    try {
      final trip = await TripService.getActiveTrip();

      if (!mounted) return;

      // ── FIX: Handle null response properly ───────────────────────────────
      if (trip == null) {
        if (_tripConfirmedInDb) {
          // Trip existed but now returned null → driver cancelled/declined
          _nullResponseCount++;
          // Wait 2 consecutive nulls to avoid false positives from network blips
          if (_nullResponseCount >= 2) {
            _pollTimer?.cancel();
            _showDriverCancelledDialog();
          }
        }
        // If trip was never confirmed in DB yet, it's just not created yet
        // (race condition) — keep polling
        return;
      }

      // Trip exists in DB — mark as confirmed
      _tripConfirmedInDb = true;
      _nullResponseCount = 0;

      final status = trip['status']?.toString() ?? '';

      if (status == 'cancelled') {
        // Explicitly cancelled
        _pollTimer?.cancel();
        _showDriverCancelledDialog();
        return;
      }

      // Driver accepted → move to live tracking
      if (status == 'accepted' ||
          status == 'pickup' ||
          status == 'ongoing') {
        _pollTimer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => LiveTripTrackingScreen(
            tripId: trip['trip_id']?.toString() ?? widget.tripId,
            driverName:
                trip['driver_name']?.toString() ?? widget.driverName,
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
      }
    } catch (_) {
      // Network error — keep polling silently
    }
  }

  void _showDriverCancelledDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Driver Declined',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'The driver declined your ride request. Please try booking another driver.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _goHome();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.backgroundDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Book Again',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _goHome() {
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

  Future<void> _cancelRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Ride?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to cancel this booking?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No',
                style: GoogleFonts.poppins(color: AppColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Yes, Cancel',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    _pollTimer?.cancel();

    if (widget.tripId.isNotEmpty) {
      await TripService.updateTripStatus(widget.tripId, 'cancelled');
    }
    if (!mounted) return;
    _goHome();
  }

  String get _waitTime {
    if (_waitSeconds < 60) return '${_waitSeconds}s';
    return '${_waitSeconds ~/ 60}m ${_waitSeconds % 60}s';
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dotsTimer?.cancel();
    _waitTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2), // ← visible while map loads
      body: Stack(children: [

        // ── Map with error fallback ──────────────────────────────────────
        _buildMap(),

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
                    blurRadius: 12,
                    offset: const Offset(0, 3),
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
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      'Waiting for driver${'.' * _dotsCount}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.backgroundDark,
                      ),
                    ),
                    Text('Wait time: $_waitTime',
                        style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textHint,
                        )),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        )),
                  ),
                ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
            ),
          ),
        ),

        // ── Bottom driver card ───────────────────────────────────────────
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child:
                Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 16),

              // Driver info row
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(_initials,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.driverName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.backgroundDark,
                        )),
                    Row(children: [
                      if (widget.driverRating > 0) ...[
                        const Icon(Icons.star_rounded,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 3),
                        Text(widget.driverRating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.backgroundDark,
                            )),
                        Text(' · ',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textHint)),
                      ],
                      Flexible(
                        child: Text(widget.todaBodyNumber,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textHint,
                            )),
                      ),
                    ]),
                    if (widget.plateNo.isNotEmpty)
                      Text('Plate: ${widget.plateNo}',
                          style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textHint,
                          )),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text('Pending',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange,
                      )),
                ),
              ]),

              const SizedBox(height: 16),

              // Trip info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  _tripInfoItem(Icons.route_rounded,
                      '${widget.distanceKm.toStringAsFixed(1)} km', 'Distance'),
                  _dividerV(),
                  _tripInfoItem(Icons.schedule_rounded,
                      '${widget.etaMinutes} min', 'ETA'),
                  _dividerV(),
                  _tripInfoItem(Icons.payments_rounded,
                      '₱${widget.fare.toStringAsFixed(0)}', 'Fare'),
                ]),
              ),

              const SizedBox(height: 14),

              // Auto-checking indicator
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Waiting for driver to accept...',
                    style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textHint,
                    )),
              ]),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton(
                  onPressed: _isCancelling ? null : _cancelRide,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Colors.grey[300]!, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Cancel Ride',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          )),
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

  // ── Map with fallback if FlutterMap crashes ──────────────────────────────
  Widget _buildMap() {
    try {
      return FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(7.1920, 125.4560),
          initialZoom: 14.5,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.todago.app',
          ),
          PolylineLayer(polylines: [
            Polyline(
              points: [_driver, _pickup],
              color: AppColors.primary,
              strokeWidth: 4,
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: _driver, width: 40, height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.electric_rickshaw_rounded,
                    color: AppColors.primary, size: 20),
              ),
            ),
            Marker(
              point: _pickup, width: 36, height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ]),
        ],
      );
    } catch (_) {
      return Container(color: const Color(0xFFE8EDF2));
    }
  }

  Widget _tripInfoItem(IconData icon, String value, String label) =>
      Expanded(child: Column(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.backgroundDark,
            )),
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 10, color: AppColors.textHint,
            )),
      ]));

  Widget _dividerV() =>
      Container(width: 1, height: 40, color: const Color(0xFFEEEEEE));
}