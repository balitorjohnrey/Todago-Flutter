import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'driver_auth_service.dart';
import 'trip_service.dart';
import 'splash_screen.dart';
import 'ride_request_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  bool _isUpdatingStatus = false;
  late AnimationController _pulseController;

  // Real driver data from backend
  Map<String, dynamic>? _driver;
  String _driverName = 'Driver';
  String _todaBodyNumber = '';
  double _avgRating = 0.0;
  int _totalTrips = 0;

  // Polling for ride requests
  Timer? _pollTimer;
  Map<String, dynamic>? _pendingTrip;

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
        _driver = driver;
        _driverName  = driver['driver_name'] ?? 'Driver';
        _todaBodyNumber = driver['toda_body_number'] ?? '';
        _avgRating   = (driver['avg_rating'] ?? 0.0).toDouble();
        _totalTrips  = driver['total_trips'] ?? 0;
      });
    }
  }

  // Poll backend every 5 seconds for new ride requests when online
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isOnline || !mounted) return;
      final trip = await TripService.fetchPendingTrip();
      if (trip != null && mounted && _pendingTrip == null) {
        setState(() => _pendingTrip = trip);
        _showRideRequest(trip);
      }
    });
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
    setState(() {
      _isUpdatingStatus = false;
      if (success) {
        _isOnline = !_isOnline;
        _pendingTrip = null;
      }
    });

    if (_isOnline) {
      _startPolling();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('You are now ONLINE — searching for passengers',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
    } else {
      _stopPolling();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('You are now OFFLINE',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.grey[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _showRideRequest(Map<String, dynamic> trip) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => RideRequestScreen(
        trip: trip,
        onAccept: () async {
          final accepted = await TripService.acceptTrip(trip['trip_id']);
          if (accepted && mounted) {
            setState(() => _pendingTrip = null);
          }
        },
        onDecline: () async {
          await TripService.declineTrip(trip['trip_id']);
          if (mounted) setState(() => _pendingTrip = null);
        },
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  Future<void> _logout() async {
    _stopPolling();
    if (_isOnline) await TripService.updateDriverStatus('offline');
    await DriverAuthService.logout();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()), (_) => false,
    );
  }

  @override
  void dispose() {
    _stopPolling();
    _pulseController.dispose();
    super.dispose();
  }

  String get _firstName =>
      _driverName.trim().split(' ').first;

  String get _initials {
    final parts = _driverName.trim().split(' ');
    return parts.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(children: [

          // ── Top Bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF252540),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
              ),
              const Spacer(),
              // Online status badge
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
                child: Row(mainAxisSize: MainAxisSize.min, children: [
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

          // ── Stats Row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF252540),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Expanded(child: _buildStat(
                  label: "Today's Earnings",
                  value: '₱0.00',
                  sub: 'Start accepting rides',
                  icon: Icons.attach_money_rounded,
                  subColor: AppColors.textHint,
                )),
                Container(width: 1, height: 40, color: Colors.white12),
                Expanded(child: _buildStat(
                  label: 'Total Trips',
                  value: '$_totalTrips',
                  sub: _avgRating > 0
                      ? '${_avgRating.toStringAsFixed(1)} ⭐ rating'
                      : 'No rating yet',
                  icon: Icons.trending_up_rounded,
                  subColor: Colors.white54,
                )),
              ]),
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

          // ── GO ONLINE Button ───────────────────────────────────────────
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _isUpdatingStatus ? null : _toggleOnline,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isOnline)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 220 + (_pulseController.value * 30),
                            height: 220 + (_pulseController.value * 30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success.withOpacity(
                                  0.08 * (1 - _pulseController.value)),
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 210, height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isOnline ? AppColors.success : AppColors.primary,
                            boxShadow: [BoxShadow(
                              color: (_isOnline
                                  ? AppColors.success
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
                                          color: AppColors.backgroundDark, size: 40),
                                    if (_isOnline)
                                      const SizedBox(
                                        width: 60, height: 60,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 4, color: Colors.white,
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

          // ── Driver Info Card ───────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252540),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              Row(children: [
                // Avatar with real initials
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(_initials,
                      style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Real driver name from backend
                  Text(_driverName, style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
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

              // Bottom stats row
              Row(children: [
                _buildBottomStat('Online Time', '0h 0m',
                    Icons.access_time_rounded),
                _buildBottomStat('Trips Today', '0',
                    Icons.route_rounded),
                _buildBottomStat('Earnings', '₱0',
                    Icons.attach_money_rounded),
              ]),
            ]),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms)
              .slideY(begin: 0.2, end: 0),
        ]),
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
          fontSize: 10, color: subColor, fontWeight: FontWeight.w500,
        )),
      ]),
    );
  }

  Widget _buildBottomStat(String label, String value, IconData icon) {
    return Expanded(child: Column(children: [
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
}