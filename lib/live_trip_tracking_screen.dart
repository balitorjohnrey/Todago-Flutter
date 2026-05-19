import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'passenger_home_screen.dart';

class LiveTripTrackingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final double driverRating;
  final String todaBodyNumber;
  final String plateNo;
  final int etaMinutes;
  final double distanceKm;

  const LiveTripTrackingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverRating,
    required this.todaBodyNumber,
    required this.plateNo,
    required this.etaMinutes,
    required this.distanceKm,
  });

  @override
  State<LiveTripTrackingScreen> createState() => _LiveTripTrackingScreenState();
}

class _LiveTripTrackingScreenState extends State<LiveTripTrackingScreen> {
  GoogleMapController? _mapController;

  static const LatLng _pickup      = LatLng(7.1907, 125.4553);
  static const LatLng _driver      = LatLng(7.1940, 125.4580);
  static const LatLng _destination = LatLng(7.1850, 125.4500);

  // ── Trip status polling ───────────────────────────────────────────────────
  Timer? _pollTimer;
  String _tripStatus = 'requested';

  @override
  void initState() {
    super.initState();
    if (widget.tripId.isNotEmpty) {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      final trip = await TripService.getActiveTrip();

      if (!mounted) return;

      if (trip == null) {
        _pollTimer?.cancel();
        await _checkIfCompleted();
        return;
      }

      final newStatus = trip['status'] as String? ?? 'requested';
      if (newStatus != _tripStatus) {
        setState(() => _tripStatus = newStatus);

        if (newStatus == 'completed') {
          _pollTimer?.cancel();
          _showTripCompletedDialog();
        } else if (newStatus == 'cancelled') {
          _pollTimer?.cancel();
          _showTripCancelledDialog();
        }
      }
    });
  }

  Future<void> _checkIfCompleted() async {
    try {
      final history = await TripService.getCommuterHistory();
      if (!mounted) return;
      if (history.isNotEmpty) {
        final last   = history.first;
        final status = last['status']?.toString() ?? '';
        if (status == 'completed') {
          _showTripCompletedDialog();
          return;
        }
      }
    } catch (_) {}
    _showTripCancelledDialog();
  }

  void _showTripCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Trip Cancelled',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'The driver cancelled or declined your ride. Please book again.',
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
            child: Text('Back to Home',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTripCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Trip Completed! 🎉',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'You have arrived at your destination. Thanks for riding with TodaGo!',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _goHome();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Done',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: AppColors.backgroundDark)),
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

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.driverName.trim().split(' ');
    return parts
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  String get _statusLabel {
    switch (_tripStatus) {
      case 'requested': return 'Waiting for driver to accept...';
      case 'accepted':  return 'Driver is on the way!';
      case 'pickup':    return 'Driver arrived at pickup!';
      case 'ongoing':   return 'Enjoy your ride!';
      case 'completed': return 'Trip completed!';
      default:          return 'Connecting...';
    }
  }

  Color get _statusColor {
    switch (_tripStatus) {
      case 'requested': return Colors.orange;
      case 'accepted':  return AppColors.primary;
      case 'pickup':    return Colors.blue;
      case 'ongoing':   return AppColors.success;
      case 'completed': return AppColors.success;
      default:          return AppColors.textHint;
    }
  }

  Future<void> _cancelTrip(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Trip?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to cancel this ride?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.poppins(color: AppColors.textHint)),
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
    _pollTimer?.cancel();

    if (widget.tripId.isNotEmpty) {
      await TripService.updateTripStatus(widget.tripId, 'cancelled');
    }
    if (!mounted) return;
    _goHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [

          // ── Google Map fills the entire screen ───────────────────────────
          Positioned.fill(
            child: _buildMap(),
          ),

          // ── Top status + ETA bar ─────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(children: [
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _statusColor.withOpacity(0.4), width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: _statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(_statusLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _statusColor,
                          )),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  // ETA card
                  Container(
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
                      _etaItem('ETA',
                          '${widget.etaMinutes} min',
                          Icons.schedule_rounded),
                      const SizedBox(width: 24),
                      _etaItem('Distance',
                          '${widget.distanceKm.toStringAsFixed(1)} km',
                          Icons.straighten_rounded),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _cancelTrip(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.red, size: 20),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0),
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
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text(_initials,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
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
                            fontWeight: FontWeight.w700,
                            color: AppColors.backgroundDark,
                          )),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 3),
                        Text(widget.driverRating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.backgroundDark,
                              fontWeight: FontWeight.w600,
                            )),
                        if (widget.todaBodyNumber.isNotEmpty)
                          Text(' · ${widget.todaBodyNumber}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textHint,
                              )),
                      ]),
                      if (widget.plateNo.isNotEmpty)
                        Text('Plate: ${widget.plateNo}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textHint,
                            )),
                    ],
                  )),
                  Row(children: [
                    _actionBtn(Icons.phone_rounded, Colors.green),
                    const SizedBox(width: 10),
                    _actionBtn(Icons.chat_bubble_rounded, AppColors.primary),
                  ]),
                ]),

                const SizedBox(height: 16),

                // Destination
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Icon(Icons.navigation_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Heading to',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppColors.textHint,
                            )),
                        Text('Davao del Norte State College, Panabo',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.backgroundDark,
                            )),
                      ],
                    )),
                  ]),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity, height: 48,
                  child: OutlinedButton(
                    onPressed: () => _cancelTrip(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.grey[300]!, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Cancel Trip',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHint,
                        )),
                  ),
                ),
              ]),
            ).animate().slideY(
                begin: 0.3, end: 0,
                duration: 400.ms, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: const CameraPosition(
        target: LatLng(7.1907, 125.4553),
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
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination,
          icon: BitmapDescriptor.defaultMarker,
        ),
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_driver, _pickup, _destination],
          color: AppColors.primary,
          width: 4,
        ),
      },
    );
  }

  Widget _etaItem(String label, String value, IconData icon) =>
      Row(children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: AppColors.textHint)),
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
        ]),
      ]);

  Widget _actionBtn(IconData icon, Color color) => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      );
}