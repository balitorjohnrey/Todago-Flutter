import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'navigation_pickup_screen.dart';

class RideRequestScreen extends StatefulWidget {
  const RideRequestScreen({super.key});
  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  int _countdown = 15;
  Timer? _timer;
  double _progress = 1.0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _countdown--;
        _progress = _countdown / 15;
      });
      if (_countdown <= 0) {
        t.cancel();
        _decline();
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _decline() {
    _timer?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  void _accept() {
    _timer?.cancel();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const NavigationPickupScreen(),
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, anim, __, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.6),
      body: GestureDetector(
        onTap: () {},
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A2B3C),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Yellow header ────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.navigation_rounded,
                            color: AppColors.primary, size: 32),
                      ).animate()
                          .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1),
                              duration: 500.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 12),

                      Text('New Ride Request!', style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.w900,
                        color: AppColors.backgroundDark,
                      )).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                      const SizedBox(height: 10),

                      // Countdown pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              value: _progress,
                              strokeWidth: 2,
                              backgroundColor: Colors.black26,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.backgroundDark),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Auto-decline in ${_countdown}s',
                              style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: AppColors.backgroundDark,
                              )),
                        ]),
                      ),

                      const SizedBox(height: 14),

                      // Ride type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(children: [
                          Text('RIDE TYPE', style: GoogleFonts.poppins(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.white38, letterSpacing: 1.5,
                          )),
                          Text('SOLO RIDE', style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.w900,
                            color: Colors.white,
                          )),
                        ]),
                      ),
                    ]),
                  ),

                  // ── Passenger info ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [

                      // Passenger row
                      Row(children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF243548),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Maria Santos', style: GoogleFonts.poppins(
                            fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                          )),
                          Row(children: [
                            ...List.generate(5, (i) => Icon(
                              i < 4 ? Icons.star_rounded : Icons.star_half_rounded,
                              size: 13, color: AppColors.primary,
                            )),
                            const SizedBox(width: 4),
                            Text('4.9 · 63 trips', style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textHint,
                            )),
                          ]),
                        ]),
                        const Spacer(),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _pill('Verified', Colors.green),
                          const SizedBox(height: 4),
                          _pill('Cash', AppColors.primary),
                        ]),
                      ]),

                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF243548)),
                      const SizedBox(height: 14),

                      // Trip details
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Trip Details', style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.textHint, letterSpacing: 1,
                        )),
                      ),
                      const SizedBox(height: 12),

                      // Pickup
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Column(children: [
                          Container(width: 10, height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle,
                            )),
                          Container(width: 1.5, height: 36, color: const Color(0xFF2E4158)),
                          Container(width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(3),
                            )),
                        ]),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('PICKUP', style: GoogleFonts.poppins(
                              fontSize: 9, color: AppColors.textHint, letterSpacing: 1,
                            )),
                            Text('Panabo Bus Terminal', style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                            )),
                            Text('0.8 km away · 2 min', style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.primary,
                            )),
                          ]),
                          const SizedBox(height: 20),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('DESTINATION', style: GoogleFonts.poppins(
                              fontSize: 9, color: AppColors.textHint, letterSpacing: 1,
                            )),
                            Text('Davao del Norte State College',
                                style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                                )),
                            Text('Est. 10 min trip', style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textHint,
                            )),
                          ]),
                        ])),
                      ]),

                      const SizedBox(height: 20),

                      // Decline + Accept
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _decline,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF243548),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                                const SizedBox(width: 8),
                                Text('DECLINE', style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white54,
                                )),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _accept,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.navigation_rounded,
                                    color: AppColors.backgroundDark, size: 18),
                                const SizedBox(width: 8),
                                Text('ACCEPT', style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: AppColors.backgroundDark,
                                )),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ],
              ),
            ).animate()
                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1),
                    duration: 400.ms, curve: Curves.easeOut)
                .fadeIn(duration: 300.ms),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w700, color: color,
    )),
  );
}