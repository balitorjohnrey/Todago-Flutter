import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'driver_selection_screen.dart';

class FindingDriverScreen extends StatefulWidget {
  final String serviceType;
  final String price;
  final double fareAmount;
  final List<Map<String, dynamic>> onlineDrivers;

  const FindingDriverScreen({
    super.key,
    required this.serviceType,
    required this.price,
    required this.fareAmount,
    required this.onlineDrivers,
  });

  @override
  State<FindingDriverScreen> createState() => _FindingDriverScreenState();
}

class _FindingDriverScreenState extends State<FindingDriverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dots = 1;
  Timer? _dotsTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat();

    // Animate dots
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dots = (_dots % 3) + 1);
    });

    // Navigate to driver selection after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      if (widget.onlineDrivers.isEmpty) {
        // No drivers — go back with error
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No drivers available. Please try again.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
        return;
      }
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => DriverSelectionScreen(
          serviceType: widget.serviceType,
          price: widget.price,
          fareAmount: widget.fareAmount,
          onlineDrivers: widget.onlineDrivers,
        ),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40, height: 40,
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

          // Animated search circle
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180 + (_controller.value * 40),
                  height: 180 + (_controller.value * 40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(
                        0.06 * (1 - _controller.value)),
                  ),
                ),
                Container(
                  width: 150 + (_controller.value * 20),
                  height: 150 + (_controller.value * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(
                        0.10 * (1 - _controller.value)),
                  ),
                ),
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 30, spreadRadius: 5,
                    )],
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
                fontSize: 24, fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 8),

          Text(
            'Searching for the best available driver nearby${'.' * _dots}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.textHint, height: 1.6,
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 24),

          // Real drivers count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: widget.onlineDrivers.isNotEmpty
                  ? Colors.green.withOpacity(0.08)
                  : Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.onlineDrivers.isNotEmpty
                    ? Colors.green.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: widget.onlineDrivers.isNotEmpty
                      ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.onlineDrivers.length} driver${widget.onlineDrivers.length != 1 ? 's' : ''} online near you',
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: widget.onlineDrivers.isNotEmpty
                      ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            ]),
          ).animate().fadeIn(delay: 400.ms),

          const Spacer(),

          // Wait info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.schedule_rounded,
                  color: AppColors.textHint, size: 18),
              const SizedBox(width: 8),
              Text('Average wait time: ', style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textHint,
              )),
              Text('2–3 minutes', style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.backgroundDark,
              )),
            ]),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel Search', style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.error, fontWeight: FontWeight.w600,
            )),
          ).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}