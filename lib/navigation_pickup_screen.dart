import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'active_trip_driver_screen.dart';

class NavigationPickupScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const NavigationPickupScreen({super.key, required this.trip});
  @override
  State<NavigationPickupScreen> createState() => _NavigationPickupScreenState();
}

class _NavigationPickupScreenState extends State<NavigationPickupScreen> {
  bool _isConfirming = false;

  final LatLng _pickup    = const LatLng(7.1907, 125.4553);
  final LatLng _driverPos = const LatLng(7.1940, 125.4590);

  String get _passengerName =>
      widget.trip['commuter_name'] ?? 'Passenger';

  String get _passengerInitials {
    final parts = _passengerName.trim().split(' ');
    return parts.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  }

  String get _pickupLocation =>
      widget.trip['pickup_location'] ?? 'Pickup Location';

  String get _paymentMethod =>
      (widget.trip['payment_method'] ?? 'cash').toUpperCase();

  double get _fare {
    final f = widget.trip['fare'];
    if (f == null) return 25.0;
    if (f is double) return f;
    if (f is int) return f.toDouble();
    return double.tryParse(f.toString()) ?? 25.0;
  }

  Future<void> _confirmArrival() async {
    setState(() => _isConfirming = true);
    final tripId = widget.trip['trip_id'] ?? '';
    if (tripId.isNotEmpty) {
      await TripService.updateTripStatus(tripId, 'pickup');
    }
    if (!mounted) return;
    setState(() => _isConfirming = false);
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => ActiveTripDriverScreen(trip: widget.trip),
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [

          // ── Map ──────────────────────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _driverPos,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.todago_flutter',
                ),
                PolylineLayer(polylines: [
                  Polyline(
                    points: [_driverPos, _pickup],
                    color: AppColors.primary,
                    strokeWidth: 5,
                  ),
                ]),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _driverPos,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: const Icon(Icons.electric_rickshaw_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                    ),
                    Marker(
                      point: _pickup,
                      width: 44,
                      height: 44,
                      child: Column(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: const Icon(Icons.person_pin_circle,
                              color: AppColors.backgroundDark, size: 20),
                        ),
                        Container(width: 2, height: 10, color: AppColors.primary),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Back button ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ── Top nav info card ────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 70, // offset to not overlap the back button
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.navigation_rounded,
                        color: AppColors.backgroundDark, size: 13),
                    const SizedBox(width: 4),
                    Text('NAVIGATING', style: GoogleFonts.poppins(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: AppColors.backgroundDark, letterSpacing: 0.5,
                    )),
                  ]),
                ),
                const SizedBox(width: 10),
                _navStat('0.8 km', 'Distance'),
                const SizedBox(width: 14),
                _navStat('2 min', 'ETA'),
              ]),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
          ),

          // ── Bottom passenger card ────────────────────────────────────────
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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: SafeArea(
                top: false,
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

                  // Pickup address
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Text('Pickup Location', style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textHint,
                    )),
                  ]),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_pickupLocation, style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.backgroundDark,
                    )),
                  ),

                  const SizedBox(height: 14),

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
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_passengerName, style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: AppColors.backgroundDark,
                        )),
                        Text(
                          '${widget.trip['service_type']?.toString().toUpperCase() ?? 'SOLO'} RIDE · $_paymentMethod Payment',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textHint),
                        ),
                      ],
                    )),
                    Row(children: [
                      _iconBtn(Icons.phone_rounded, Colors.green),
                      const SizedBox(width: 8),
                      _iconBtn(Icons.chat_bubble_rounded, AppColors.primary),
                    ]),
                  ]),

                  const SizedBox(height: 16),

                  // Trip stats
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _tripStat('2 min', 'ETA'),
                    _dividerV(),
                    _tripStat('0.8 km', 'Distance'),
                    _dividerV(),
                    _tripStat('₱${_fare.toStringAsFixed(0)}', 'Fare'),
                  ]),

                  const SizedBox(height: 16),

                  // Confirm arrival button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isConfirming ? null : _confirmArrival,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isConfirming
                            ? AppColors.backgroundDark.withOpacity(0.7)
                            : AppColors.backgroundDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isConfirming
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text('Confirm Arrival',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    )),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ]),
              ),
            ).animate().slideY(
                begin: 0.3, end: 0,
                duration: 400.ms, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }

  Widget _navStat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w900,
        color: AppColors.backgroundDark,
      )),
      Text(label, style: GoogleFonts.poppins(
          fontSize: 10, color: AppColors.textHint)),
    ],
  );

  Widget _iconBtn(IconData icon, Color color) => Container(
    width: 38, height: 38,
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Icon(icon, color: color, size: 18),
  );

  Widget _tripStat(String value, String label) => Column(children: [
    Text(value, style: GoogleFonts.poppins(
      fontSize: 18, fontWeight: FontWeight.w800,
      color: AppColors.backgroundDark,
    )),
    Text(label, style: GoogleFonts.poppins(
        fontSize: 11, color: AppColors.textHint)),
  ]);

  Widget _dividerV() =>
      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));
}