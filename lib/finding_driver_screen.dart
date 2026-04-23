import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'driver_selection_screen.dart';

class FindingDriverScreen extends StatefulWidget {
  final String serviceType;
  final String price;
  const FindingDriverScreen(
      {super.key, required this.serviceType, required this.price});

  @override
  State<FindingDriverScreen> createState() => _FindingDriverScreenState();
}

class _FindingDriverScreenState extends State<FindingDriverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Auto-navigate to live tracking after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => DriverSelectionScreen(
              serviceType: widget.serviceType,
              price: widget.price,
            ),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.backgroundDark, size: 18),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Animated logo
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulse ring
                  Container(
                    width: 180 + (_controller.value * 40),
                    height: 180 + (_controller.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary
                          .withOpacity(0.08 * (1 - _controller.value)),
                    ),
                  ),
                  // Middle ring
                  Container(
                    width: 150 + (_controller.value * 20),
                    height: 150 + (_controller.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary
                          .withOpacity(0.12 * (1 - _controller.value)),
                    ),
                  ),
                  // Main icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: AppColors.backgroundDark, size: 52),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Text('Finding Your Driver',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 8),

            Text('Searching for the best available driver\nnear you...',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textHint,
                  height: 1.6,
                )).animate().fadeIn(delay: 300.ms),

            const Spacer(),

            // Wait time info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: AppColors.textHint, size: 18),
                  const SizedBox(width: 8),
                  Text('Average wait time: ',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textHint,
                      )),
                  Text('2–3 minutes',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.backgroundDark,
                      )),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 16),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel Search',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  )),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
