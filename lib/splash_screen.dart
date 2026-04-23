import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showGetStarted = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _initApp();
  }

  Future<void> _initApp() async {
    // Show button after animations
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _showGetStarted = true);

    // Auto-navigate if already logged in
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      _navigateTo(HomeScreen());
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle radial glow behind logo
            Positioned(
              top: MediaQuery.of(context).size.height * 0.22,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Column(
              children: [
                const Spacer(flex: 2),

                // App Icon
                _buildAppIcon()
                    .animate()
                    .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 28),

                // App Name
                Text(
                  'TodaGo',
                  style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 500.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 8),

                // Tagline
                Text(
                  'Premium Tricycle Hailing',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 500.ms)
                    .slideY(begin: 0.3, end: 0),

                const Spacer(flex: 3),

                // Bottom section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      // Get Started button
                      AnimatedOpacity(
                        opacity: _showGetStarted ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 500),
                        child: AnimatedSlide(
                          offset: _showGetStarted
                              ? Offset.zero
                              : const Offset(0, 0.3),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          child: ElevatedButton(
                            onPressed: () =>
                                _navigateTo(const LoginScreen()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.backgroundDark,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Get Started',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: AppColors.backgroundDark,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Bottom caption
                      AnimatedOpacity(
                        opacity: _showGetStarted ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 700),
                        child: Text(
                          'Safe. Reliable. Convenient.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textHint,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.bolt_rounded,
        color: Color(0xFF1A2B3C),
        size: 54,
      ),
    );
  }
}