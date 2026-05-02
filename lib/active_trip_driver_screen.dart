import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'driver_dashboard_screen.dart';

class ActiveTripDriverScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const ActiveTripDriverScreen({super.key, required this.trip});
  @override
  State<ActiveTripDriverScreen> createState() => _ActiveTripDriverScreenState();
}

class _ActiveTripDriverScreenState extends State<ActiveTripDriverScreen> {
  bool _isCompleting = false;

  final LatLng _driverPos      = const LatLng(7.1907, 125.4553);
  final LatLng _destinationPos = const LatLng(7.1830, 125.4480); // renamed — no clash with String getter

  String get _passengerName =>
      widget.trip['commuter_name'] ?? 'Passenger';

  String get _passengerInitials {
    final parts = _passengerName.trim().split(' ');
    return parts.take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  double get _fare => (widget.trip['fare'] ?? 25.0).toDouble();
  String get _destination => widget.trip['destination'] ?? 'Destination';

  // Commission calc — static const fixes the "const on instance field" error
  static const double _commissionPct = 10.0;
  double get _commissionAmt => _fare * _commissionPct / 100;
  double get _driverEarnings => _fare - _commissionAmt;

  Future<void> _completeTrip() async {
    setState(() => _isCompleting = true);
    final tripId = widget.trip['trip_id'] ?? '';
    Map<String, dynamic> result = {'success': false};

    if (tripId.isNotEmpty) {
      result = await TripService.updateTripStatus(tripId, 'completed');
    }

    if (!mounted) return;
    setState(() => _isCompleting = false);

    // Show earnings summary
    final earnings = result['earnings'];
    final actualEarnings = earnings != null
        ? (earnings['your_earnings'] ?? _driverEarnings).toDouble()
        : _driverEarnings;
    final actualComm = earnings != null
        ? (earnings['commission_amt'] ?? _commissionAmt).toDouble()
        : _commissionAmt;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1), shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Trip Completed! 🎉', style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w800,
            color: AppColors.backgroundDark,
          )),
          const SizedBox(height: 6),
          Text('Thank you for the ride, $_passengerName!',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textHint),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              _earningsRow('Passenger Fare',
                  '₱${_fare.toStringAsFixed(2)}', Colors.black),
              const SizedBox(height: 6),
              _earningsRow('Commission (${_commissionPct.toInt()}%)',
                  '- ₱${actualComm.toStringAsFixed(2)}', Colors.red),
              const Divider(height: 16),
              _earningsRow('Your Earnings',
                  '₱${actualEarnings.toStringAsFixed(2)}',
                  Colors.green, bold: true, large: true),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const DriverDashboardScreen(),
                    transitionDuration: const Duration(milliseconds: 500),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
                  (_) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: Text('Back to Dashboard', style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
              )),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _earningsRow(String label, String value, Color valueColor,
      {bool bold = false, bool large = false}) =>
      Row(children: [
        Text(label, style: GoogleFonts.poppins(
            fontSize: 13, color: AppColors.textHint)),
        const Spacer(),
        Text(value, style: GoogleFonts.poppins(
          fontSize: large ? 18 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: valueColor,
        )),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [

        // ── Map ────────────────────────────────────────────────────────────
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(7.1870, 125.4516),
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.todago.app',
            ),
            PolylineLayer(polylines: [
              Polyline(
                points: [_driverPos, _destinationPos], // fixed: use _destinationPos
                color: AppColors.primary,
                strokeWidth: 5,
                // isDotted removed — not supported in flutter_map v6+
                // Use: pattern: StrokePattern.dotted()  if your version supports it
              ),
            ]),
            MarkerLayer(markers: [
              Marker(
                point: _driverPos, width: 40, height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.electric_rickshaw_rounded,
                      color: AppColors.primary, size: 20),
                ),
              ),
              Marker(
                point: _destinationPos, // fixed: use _destinationPos
                width: 38, height: 38,
                child: const Icon(Icons.location_on_rounded,
                    color: Colors.red, size: 38),
              ),
            ]),
          ],
        ),

        // ── Top trip-in-progress card ──────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 14, offset: const Offset(0, 4),
                  )],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 7, height: 7,
                          decoration: const BoxDecoration(
                              color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('TRIP IN PROGRESS', style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: Colors.green, letterSpacing: 0.5,
                      )),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _navStat('2 km', 'Distance'),
                    const SizedBox(width: 24),
                    _navStat('10 min', 'Time Left'),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.flag_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Text('Destination', style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint)),
                  ]),
                  const SizedBox(height: 2),
                  Text(_destination, style: GoogleFonts.poppins( // String getter — no conflict now
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.backgroundDark,
                  )),
                ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
            ),
          ),
        ),

        // ── Bottom passenger + complete ────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(
                  color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 16),

              // Passenger row
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(_passengerInitials,
                      style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: AppColors.backgroundDark,
                      ))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_passengerName, style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  )),
                  Row(children: [
                    const Icon(Icons.verified_rounded,
                        color: Colors.green, size: 13),
                    const SizedBox(width: 4),
                    Text('Verified Passenger', style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textHint)),
                  ]),
                ])),
              ]),

              const SizedBox(height: 14),

              // Call + Message
              Row(children: [
                Expanded(child: _actionBtn(
                    Icons.phone_rounded, 'Call', Colors.green, () {})),
                const SizedBox(width: 10),
                Expanded(child: _actionBtn(
                    Icons.chat_bubble_rounded, 'Message', AppColors.primary, () {})),
              ]),

              const SizedBox(height: 14),

              // Trip stats
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _tripStat('10 min', 'Time Left'),
                _dividerV(),
                _tripStat('2 km', 'Distance'),
                _dividerV(),
                _tripStat('₱${_driverEarnings.toStringAsFixed(0)}', 'Earnings'),
              ]),

              const SizedBox(height: 16),

              // Complete trip
              GestureDetector(
                onTap: _isCompleting ? null : _completeTrip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _isCompleting
                        ? Colors.green.withOpacity(0.7) : Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isCompleting
                          ? const Center(child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)))
                          : const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Slide to Complete Trip', style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                      )),
                      Text('Slide when passenger reaches destination',
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: Colors.white70)),
                    ])),
                  ]),
                ),
              ),
            ]),
          ).animate().slideY(begin: 0.3, end: 0,
              duration: 400.ms, curve: Curves.easeOut),
        ),
      ]),
    );
  }

  Widget _navStat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: GoogleFonts.poppins(
        fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.backgroundDark,
      )),
      Text(label, style: GoogleFonts.poppins(
          fontSize: 11, color: AppColors.textHint)),
    ],
  );

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: color,
            )),
          ]),
        ),
      );

  Widget _tripStat(String value, String label) => Column(children: [
    Text(value, style: GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.backgroundDark,
    )),
    Text(label, style: GoogleFonts.poppins(
        fontSize: 11, color: AppColors.textHint)),
  ]);

  Widget _dividerV() =>
      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));
}