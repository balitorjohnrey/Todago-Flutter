import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'live_trip_tracking_screen.dart';

class DriverSelectionScreen extends StatefulWidget {
  final String serviceType;
  final String price;
  const DriverSelectionScreen({
    super.key,
    required this.serviceType,
    required this.price,
  });

  @override
  State<DriverSelectionScreen> createState() => _DriverSelectionScreenState();
}

class _DriverSelectionScreenState extends State<DriverSelectionScreen> {
  int _selected = 0;

  final List<Map<String, dynamic>> _drivers = [
    {
      'initials': 'MC',
      'name': 'Maria Cruz',
      'id': 'TRI-2023-QC',
      'rating': 4.8,
      'reviews': 273,
      'eta': 3,
      'distance': 1.2,
      'verified': true,
      'badge': Colors.teal,
    },
    {
      'initials': 'JR',
      'name': 'Juan Reyes',
      'id': 'TRI-2024-CAL',
      'rating': 4.9,
      'reviews': 189,
      'eta': 5,
      'distance': 2.1,
      'verified': true,
      'badge': AppColors.backgroundDark,
    },
    {
      'initials': 'PL',
      'name': 'Pedro Lopez',
      'id': 'TRI-2022-PAN',
      'rating': 4.6,
      'reviews': 94,
      'eta': 7,
      'distance': 3.0,
      'verified': false,
      'badge': Colors.indigo,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final driver = _drivers[_selected];
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Dim overlay background
          Container(color: AppColors.backgroundDark.withOpacity(0.85)),

          // Main bottom sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header card ─────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(children: [
                      // Close button
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.textHint),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Icon
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: AppColors.backgroundDark, size: 36),
                      ).animate()
                          .scale(begin: const Offset(0.6, 0.6),
                              end: const Offset(1.0, 1.0),
                              duration: 500.ms, curve: Curves.elasticOut)
                          .fadeIn(duration: 300.ms),

                      const SizedBox(height: 12),

                      Text('Drivers Found!',
                          style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: AppColors.backgroundDark,
                          )).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                      Text('Select your preferred driver to continue',
                          style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textHint,
                          )).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                    ]),
                  ),

                  // ── Driver cards ─────────────────────────────────────────
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      itemCount: _drivers.length,
                      itemBuilder: (_, i) {
                        final d = _drivers[i];
                        final sel = _selected == i;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 260,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: sel ? AppColors.primary : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(sel ? 0.08 : 0.04),
                                  blurRadius: 12, offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar + Name row
                                Row(children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: d['badge'] as Color,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(child: Text(
                                      d['initials'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14, fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    )),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d['name'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14, fontWeight: FontWeight.w700,
                                            color: AppColors.backgroundDark,
                                          )),
                                      Text(d['id'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 10, color: AppColors.textHint,
                                          )),
                                    ],
                                  )),
                                ]),
                                const SizedBox(height: 8),

                                // Stars + Rating
                                Row(children: [
                                  ...List.generate(5, (si) {
                                    final rating = d['rating'] as double;
                                    if (si < rating.floor()) {
                                      return const Icon(Icons.star_rounded,
                                          size: 14, color: AppColors.primary);
                                    } else if (si < rating) {
                                      return const Icon(Icons.star_half_rounded,
                                          size: 14, color: AppColors.primary);
                                    } else {
                                      return const Icon(Icons.star_outline_rounded,
                                          size: 14, color: AppColors.primary);
                                    }
                                  }),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${d['rating']} (${d['reviews']} trips)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11, color: AppColors.textHint,
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 8),

                                // ETA + Distance + Verified
                                Row(children: [
                                  _driverStat('${d['eta']}', 'min'),
                                  const SizedBox(width: 14),
                                  _driverStat('${d['distance']}', 'km'),
                                  const Spacer(),
                                  if (d['verified'] as bool)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min,
                                          children: [
                                        const Icon(Icons.verified_rounded,
                                            size: 11, color: Colors.green),
                                        const SizedBox(width: 3),
                                        Text('Verified',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10, fontWeight: FontWeight.w700,
                                              color: Colors.green,
                                            )),
                                      ]),
                                    ),
                                ]),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: 200 + i * 80),
                              duration: 400.ms,
                            ).slideX(begin: 0.1, end: 0);
                      },
                    ),
                  ),

                  // ── Summary card ─────────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Column(children: [
                      _summaryRow('Service Type', widget.serviceType),
                      const SizedBox(height: 8),
                      _summaryRow('Estimated Time',
                          '${driver['eta']} min away'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Color(0xFFF0F0F0), height: 1),
                      ),
                      Row(children: [
                        Text('Estimated Fare',
                            style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppColors.backgroundDark,
                            )),
                        const Spacer(),
                        Text(widget.price,
                            style: GoogleFonts.poppins(
                              fontSize: 22, fontWeight: FontWeight.w900,
                              color: AppColors.backgroundDark,
                            )),
                      ]),
                    ]),
                  ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                  // ── Confirm button ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                const LiveTripTrackingScreen(),
                            transitionDuration:
                                const Duration(milliseconds: 500),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.backgroundDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text('Confirm Driver & Start Ride',
                            style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                      ),
                    ),
                  ).animate().fadeIn(delay: 450.ms, duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),

                  // Fare note
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    child: Text(
                      'Fare may vary based on actual distance and traffic',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint,
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

  Widget _driverStat(String value, String unit) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(value, style: GoogleFonts.poppins(
        fontSize: 16, fontWeight: FontWeight.w800,
        color: AppColors.backgroundDark,
      )),
      const SizedBox(width: 2),
      Text(unit, style: GoogleFonts.poppins(
        fontSize: 11, color: AppColors.textHint,
      )),
    ],
  );

  Widget _summaryRow(String label, String value) => Row(children: [
    Text(label, style: GoogleFonts.poppins(
      fontSize: 13, color: AppColors.textHint,
    )),
    const Spacer(),
    Text(value, style: GoogleFonts.poppins(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: AppColors.backgroundDark,
    )),
  ]);
}