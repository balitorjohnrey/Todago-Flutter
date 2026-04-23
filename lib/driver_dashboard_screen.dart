import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'ride_request_screen.dart';
import 'dart:async';
import 'splash_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  bool _isSearching = false;
  Timer? _rideRequestTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rideRequestTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleOnline() {
    setState(() {
      _isOnline = !_isOnline;
      _isSearching = _isOnline;
    });

    if (_isOnline) {
      // Show ride request popup after 4 seconds of searching
      _rideRequestTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted || !_isOnline) return;
        Navigator.of(context).push(PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => const RideRequestScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ));
      });
    } else {
      _rideRequestTimer?.cancel();
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // Hamburger
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF252540),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_rounded,
                        color: Colors.white, size: 20),
                  ),

                  const Spacer(),

                  // Online badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? AppColors.success.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isOnline ? AppColors.success : Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _isOnline ? AppColors.success : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(_isOnline ? 'ONLINE' : 'OFFLINE',
                            style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: _isOnline ? AppColors.success : Colors.grey,
                            )),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Notification
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF252540),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),

                  // Settings
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF252540),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_outlined,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 16),

            // ── Stats Row ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF252540),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildStat(
                      label: "Today's Earnings",
                      value: '₱850.00',
                      sub: '+12% vs yesterday',
                      icon: Icons.attach_money_rounded,
                      subColor: AppColors.success,
                    )),
                    Container(width: 1, height: 40, color: Colors.white12),
                    Expanded(child: _buildStat(
                      label: 'Acceptance Rate',
                      value: '94%',
                      sub: '17 of 18 trips',
                      icon: Icons.trending_up_rounded,
                      subColor: Colors.white54,
                    )),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            // ── Big GO ONLINE Button ───────────────────────────────────────────
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _toggleOnline,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulse ring (only when online)
                          if (_isOnline)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 220 + (_pulseController.value * 30),
                              height: 220 + (_pulseController.value * 30),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success.withOpacity(
                                    0.1 * (1 - _pulseController.value)),
                              ),
                            ),

                          // Main circle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOnline
                                  ? AppColors.success
                                  : AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isOnline
                                      ? AppColors.success
                                      : AppColors.primary).withOpacity(0.4),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!_isOnline)
                                  const Icon(Icons.location_on_rounded,
                                      color: AppColors.backgroundDark, size: 40),
                                if (_isOnline)
                                  const SizedBox(
                                    width: 60, height: 60,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 4,
                                      color: Colors.white,
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Text(
                                  _isOnline ? 'ONLINE' : 'GO ONLINE',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22, fontWeight: FontWeight.w900,
                                    color: _isOnline
                                        ? Colors.white
                                        : AppColors.backgroundDark,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isOnline
                                      ? 'Searching for rides...'
                                      : 'Tap to start accepting rides',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: _isOnline
                                        ? Colors.white70
                                        : AppColors.backgroundDark.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms)
                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1),
                    duration: 600.ms, curve: Curves.elasticOut),

            // ── Driver Info Card ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF252540),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('JR',
                              style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w800,
                                color: Colors.white,
                              )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Juan Reyes',
                                style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppColors.primary, size: 14),
                                const SizedBox(width: 2),
                                Text('4.9',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.white70,
                                    )),
                                const SizedBox(width: 6),
                                Text('• TRI-2024-CAL',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.white38,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      _buildBottomStat('Online Time', '2h 34m',
                          Icons.access_time_rounded),
                      _buildBottomStat('Trips Today', '17',
                          Icons.route_rounded),
                      _buildBottomStat('Avg. Fare', '₱50',
                          Icons.attach_money_rounded),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStat({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color subColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 14),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.poppins(
                fontSize: 10, color: Colors.white54,
              )),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white,
          )),
          Text(sub, style: GoogleFonts.poppins(
            fontSize: 10, color: subColor, fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }

  Widget _buildBottomStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
          )),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 10, color: Colors.white38,
          )),
        ],
      ),
    );
  }
}