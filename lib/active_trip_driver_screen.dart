import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'driver_dashboard_screen.dart';

class ActiveTripDriverScreen extends StatelessWidget {
  const ActiveTripDriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driverPos = const LatLng(7.1907, 125.4553);
    final destination = const LatLng(7.1830, 125.4480);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        // ── Map ───────────────────────────────────────────────────────────
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
                points: [driverPos, destination],
                color: AppColors.primary,
                strokeWidth: 5,
                // Replace isDotted with the StrokePattern
                pattern: const StrokePattern.dotted(),
              ),
            ]),
            MarkerLayer(markers: [
              // Driver (current position)
              Marker(
                point: driverPos,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: const Icon(Icons.electric_rickshaw_rounded,
                      color: AppColors.primary, size: 20),
                ),
              ),
              // Destination
              Marker(
                point: destination,
                width: 38,
                height: 38,
                child: const Icon(Icons.location_on_rounded,
                    color: Colors.red, size: 38),
              ),
            ]),
          ],
        ),

        // ── Top trip in progress card ─────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('TRIP IN PROGRESS',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.green,
                                letterSpacing: 0.5,
                              )),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        _navStat('2 km', 'ETA'),
                        const SizedBox(width: 24),
                        _navStat('10 min', 'Time'),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.flag_rounded,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Text('Destination',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textHint,
                            )),
                      ]),
                      const SizedBox(height: 2),
                      Text('Davao del Norte State College',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.backgroundDark,
                          )),
                    ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
            ),
          ),
        ),

        // ── Bottom passenger card ─────────────────────────────────────────
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
                )
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Center(
                  child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 16),

              // Passenger row
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.backgroundDark, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Maria Santos',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.backgroundDark,
                          )),
                      Row(children: [
                        const Icon(Icons.verified_rounded,
                            color: Colors.green, size: 13),
                        const SizedBox(width: 4),
                        Text('Verified Passenger',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textHint,
                            )),
                      ]),
                    ])),
              ]),

              const SizedBox(height: 14),

              // Call + Message buttons
              Row(children: [
                Expanded(
                    child: _actionBtn(
                  Icons.phone_rounded,
                  'Call',
                  Colors.green,
                  () {},
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _actionBtn(
                  Icons.chat_bubble_rounded,
                  'Message',
                  AppColors.primary,
                  () {},
                )),
              ]),

              const SizedBox(height: 14),

              // Trip stats
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _tripStat('10 min', 'Distance'),
                _dividerV(),
                _tripStat('2 km', 'Distance'),
                _dividerV(),
                _tripStat('₱25', 'Earning'),
              ]),

              const SizedBox(height: 16),

              // Slide to complete
              _slideToComplete(context),
            ]),
          ).animate().slideY(
              begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut),
        ),
      ]),
    );
  }

  Widget _navStat(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.backgroundDark,
              )),
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
        ],
      );

  Widget _actionBtn(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
          ]),
        ),
      );

  Widget _tripStat(String value, String label) => Column(children: [
        Text(value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.backgroundDark,
            )),
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
      ]);

  Widget _dividerV() =>
      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));

  Widget _slideToComplete(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DriverDashboardScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
          (_) => false,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Slide to Complete Trip',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                  Text('Slide when passenger reaches destination',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.white70)),
                ])),
          ]),
        ),
      );
}
