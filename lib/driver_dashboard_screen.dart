import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'driver_auth_service.dart';
import 'trip_service.dart';
import 'splash_screen.dart';
import 'ride_request_screen.dart';
import 'navigation_pickup_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  bool _isUpdatingStatus = false;
  bool _isShowingRequest = false;   // guard — only one popup at a time
  late AnimationController _pulseController;

  String _driverName = 'Driver';
  String _todaBodyNumber = '';
  double _avgRating = 0.0;
  int _totalTrips = 0;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    final driver = await DriverAuthService.getDriver();
    if (driver != null && mounted) {
      setState(() {
        _driverName       = driver['driver_name']?.toString() ?? 'Driver';
        _todaBodyNumber   = driver['toda_body_number']?.toString() ?? '';
        _avgRating        = (driver['avg_rating'] ?? 0.0).toDouble();
        _totalTrips       = (driver['total_trips'] ?? 0) as int;
      });
    }
  }

  // ── Poll every 4 seconds for pending trips ──────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!_isOnline || !mounted || _isShowingRequest) return;
      await _checkForTrip();
    });
  }

  Future<void> _checkForTrip() async {
    final trip = await TripService.fetchPendingTrip();
    if (trip == null || !mounted || _isShowingRequest) return;

    setState(() => _isShowingRequest = true);

    await Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => RideRequestScreen(
        trip: trip,
        onAccept: () async {
          final accepted = await TripService.acceptTrip(
              trip['trip_id']?.toString() ?? '');
          if (accepted && mounted) {
            // Navigate to pickup navigation
            Navigator.of(context).pushReplacement(PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  NavigationPickupScreen(trip: trip),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (_, anim, __, child) =>
                  SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 1), end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
            ));
          }
        },
        onDecline: () async {
          await TripService.declineTrip(
              trip['trip_id']?.toString() ?? '');
        },
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));

    if (mounted) setState(() => _isShowingRequest = false);
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _toggleOnline() async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    final newStatus = _isOnline ? 'offline' : 'online';
    final success = await TripService.updateDriverStatus(newStatus);

    if (!mounted) return;
    setState(() => _isUpdatingStatus = false);

    if (success) {
      setState(() => _isOnline = !_isOnline);
      if (_isOnline) {
        _startPolling();
        _showSnack('You are now ONLINE — waiting for passengers 🟢',
            Colors.green);
      } else {
        _stopPolling();
        _showSnack('You are now OFFLINE', Colors.grey[700]!);
      }
    } else {
      _showSnack('Failed to update status. Check connection.', AppColors.error);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _logout() async {
    _stopPolling();
    if (_isOnline) await TripService.updateDriverStatus('offline');
    await DriverAuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _stopPolling();
    _pulseController.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = _driverName.trim().split(' ');
    return parts.take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(children: [

          // ── Top bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? Colors.green.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isOnline ? Colors.green : Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(_isOnline ? 'ONLINE' : 'OFFLINE',
                      style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: _isOnline ? Colors.green : Colors.grey,
                      )),
                ]),
              ),
              const Spacer(),
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
            ]).animate().fadeIn(duration: 400.ms),
          ),

          const SizedBox(height: 16),

          // ── Stats row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF252540),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Expanded(child: _stat(
                  "Today's Earnings", '₱0.00',
                  'Start accepting rides', Icons.attach_money_rounded,
                )),
                Container(width: 1, height: 40, color: Colors.white12),
                Expanded(child: _stat(
                  'Total Trips', '$_totalTrips',
                  _avgRating > 0
                      ? '${_avgRating.toStringAsFixed(1)} ⭐ rating'
                      : 'No rating yet',
                  Icons.trending_up_rounded,
                )),
              ]),
            ),
          ).animate().fadeIn(delay: 100.ms),

          // ── GO ONLINE button ──────────────────────────────────────────
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _isUpdatingStatus ? null : _toggleOnline,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isOnline)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 220 + (_pulseController.value * 30),
                          height: 220 + (_pulseController.value * 30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.withOpacity(
                                0.07 * (1 - _pulseController.value)),
                          ),
                        ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 210, height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnline
                              ? Colors.green : AppColors.primary,
                          boxShadow: [BoxShadow(
                            color: (_isOnline
                                ? Colors.green
                                : AppColors.primary).withOpacity(0.4),
                            blurRadius: 40, spreadRadius: 8,
                          )],
                        ),
                        child: _isUpdatingStatus
                            ? const Center(child: SizedBox(
                                width: 36, height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white,
                                )))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!_isOnline)
                                    const Icon(Icons.location_on_rounded,
                                        color: AppColors.backgroundDark,
                                        size: 40),
                                  if (_isOnline) ...[
                                    SizedBox(
                                      width: 50, height: 50,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white.withOpacity(0.7),
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Text(
                                    _isOnline ? 'ONLINE' : 'GO ONLINE',
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: _isOnline
                                          ? Colors.white
                                          : AppColors.backgroundDark,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isOnline
                                        ? 'Waiting for rides...'
                                        : 'Tap to start accepting rides',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: _isOnline
                                          ? Colors.white70
                                          : AppColors.backgroundDark
                                              .withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).scale(
              begin: const Offset(0.85, 0.85), end: const Offset(1, 1),
              duration: 600.ms, curve: Curves.elasticOut),

          // ── Driver info card ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252540),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(_initials,
                      style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_driverName, style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
                  Row(children: [
                    if (_avgRating > 0) ...[
                      const Icon(Icons.star_rounded,
                          color: AppColors.primary, size: 14),
                      const SizedBox(width: 2),
                      Text(_avgRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.white70)),
                      const SizedBox(width: 6),
                    ],
                    Text('· $_todaBodyNumber',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.white38)),
                  ]),
                ])),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _bottomStat('Online Time', '0h 0m', Icons.access_time_rounded),
                _bottomStat('Trips Today', '0', Icons.route_rounded),
                _bottomStat('Earnings', '₱0', Icons.attach_money_rounded),
              ]),
            ]),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, String sub, IconData icon) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 14),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.poppins(
                fontSize: 10, color: Colors.white54)),
          ]),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white,
          )),
          Text(sub, style: GoogleFonts.poppins(
            fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500,
          )),
        ]),
      );

  Widget _bottomStat(String label, String value, IconData icon) =>
      Expanded(child: Column(children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
        )),
        Text(label, style: GoogleFonts.poppins(
          fontSize: 10, color: Colors.white38,
        )),
      ]));
}