import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'driver_auth_service.dart';
import 'map_service.dart';
import 'trip_service.dart';
import 'splash_screen.dart';
import 'ride_request_screen.dart';
import 'navigation_pickup_screen.dart';
import 'ai_chat_screen.dart';
import 'driver_profile_screen.dart';
import 'profile_avatar.dart';
import 'profile_photo_service.dart';
import 'reservation_notification_service.dart';
import 'report_issue_dialog.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  bool _isUpdating = false;
  bool _isShowingPopup = false;
  late AnimationController _pulse;

  String _driverName = 'Driver';
  String _todaBody = '';
  String? _driverPhotoPath;
  Map<String, dynamic>? _driverProfile;
  double _avgRating = 0.0;
  int _totalTrips = 0;
  int _tripsToday = 0;
  int _onlineSecondsToday = 0;
  double _earningsToday = 0.0;
  List<Map<String, dynamic>> _peakHours = [];

  Timer? _pollTimer;
  Timer? _scheduledSyncTimer;
  Timer? _statsTimer;
  Timer? _peakHoursTimer;
  Timer? _onlineTickTimer;
  Timer? _locationRefreshTimer;
  StreamSubscription<LatLng>? _locationSyncSub;
  DateTime? _lastLocationSync;
  bool _isLocationSyncing = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadDriver();
    _loadTodayStats();
    _loadPeakHours();
    _startStatsRealtime();
    _syncScheduledReservations();
    _scheduledSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) _syncScheduledReservations();
    });
  }

  Future<void> _loadDriver() async {
    final d = await DriverAuthService.fetchProfile();
    final photoPath = await ProfilePhotoService.getPhotoPath(
      ProfilePhotoService.driverPhotoKey,
    );
    if (d != null && mounted) {
      final serverPhoto = _profilePhotoSource(d);
      setState(() {
        _driverProfile = d;
        _driverName = d['driver_name']?.toString() ?? 'Driver';
        _todaBody = d['toda_body_number']?.toString() ?? '';
        _driverPhotoPath = serverPhoto ?? photoPath;
        _avgRating = _asDouble(d['avg_rating']);
        _totalTrips = _asInt(d['total_trips']);
        _isOnline = ['online', 'on_trip'].contains(d['status']?.toString());
      });
      if (_isOnline) {
        _startPolling();
        _startOnlineLocationSync();
      } else {
        _stopPolling();
        _stopOnlineLocationSync();
      }
    }
  }

  String? _profilePhotoSource(Map<String, dynamic>? data) {
    final value = data?['profile_photo_url']?.toString();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  // ── Online / Offline toggle ───────────────────────────────────────────────
  Future<void> _toggleOnline() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    final newStatus = _isOnline ? 'offline' : 'online';
    final onlineLocation =
        newStatus == 'online' ? await MapService.getCurrentLocation() : null;
    final ok = await TripService.updateDriverStatus(newStatus,
        location: onlineLocation);
    if (!mounted) return;
    setState(() => _isUpdating = false);
    if (ok) {
      setState(() => _isOnline = !_isOnline);
      await _loadTodayStats();
      if (_isOnline) {
        _startPolling();
        _startOnlineLocationSync(initialLocation: onlineLocation);
        _snack('You are now ONLINE 🟢 — waiting for passengers', Colors.green);
      } else {
        _stopPolling();
        _stopOnlineLocationSync();
        _snack('You are now OFFLINE', Colors.grey[700]!);
      }
    } else {
      _snack(
          'Could not update status. Check your connection.', AppColors.error);
    }
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_isOnline && mounted && !_isShowingPopup) _checkForRide();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startOnlineLocationSync({LatLng? initialLocation}) {
    _locationSyncSub?.cancel();
    _locationRefreshTimer?.cancel();
    _lastLocationSync = null;

    if (initialLocation != null) {
      _syncOnlineLocation(initialLocation, force: true);
    } else {
      MapService.getCurrentLocation().then((pos) {
        if (mounted && _isOnline && pos != null) {
          _syncOnlineLocation(pos, force: true);
        }
      });
    }

    _locationSyncSub = MapService.positionStream().listen(
      (pos) => _syncOnlineLocation(pos),
      onError: (_) {},
    );
    _locationRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || !_isOnline) return;
      MapService.getCurrentLocation().then((pos) {
        if (mounted && _isOnline && pos != null) {
          _syncOnlineLocation(pos, force: true);
        }
      });
    });
  }

  void _stopOnlineLocationSync() {
    _locationRefreshTimer?.cancel();
    _locationRefreshTimer = null;
    _locationSyncSub?.cancel();
    _locationSyncSub = null;
    _lastLocationSync = null;
    _isLocationSyncing = false;
  }

  Future<void> _syncOnlineLocation(
    LatLng pos, {
    bool force = false,
  }) async {
    if (!_isOnline || _isLocationSyncing) return;

    final now = DateTime.now();
    if (!force &&
        _lastLocationSync != null &&
        now.difference(_lastLocationSync!) < const Duration(seconds: 20)) {
      return;
    }

    _lastLocationSync = now;
    _isLocationSyncing = true;
    try {
      await TripService.updateOnlineDriverLocation(pos);
    } finally {
      _isLocationSyncing = false;
    }
  }

  Future<void> _checkForRide() async {
    if (_isShowingPopup) return;
    final trip = await TripService.fetchPendingTrip();
    if (trip == null || !mounted) return;
    if (trip['trip_type']?.toString() == 'scheduled') {
      await ReservationNotificationService.scheduleReservationReminders(
        trip,
        forDriver: true,
      );
      if (!mounted) return;
    }
    setState(() => _isShowingPopup = true);
    var acceptedOk = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => RideRequestScreen(
        trip: trip,
        onAccept: () async {
          acceptedOk =
              await TripService.acceptTrip(trip['trip_id']?.toString() ?? '');
        },
        onDecline: () async {
          await TripService.declineTrip(trip['trip_id']?.toString() ?? '');
        },
      ),
    );
    if (!mounted) return;
    setState(() => _isShowingPopup = false);
    if (accepted == true && acceptedOk) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, __, ___) => NavigationPickupScreen(trip: trip),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ));
    } else if (accepted == true) {
      _snack('Passenger cancelled this request.', AppColors.error);
      await TripService.updateDriverStatus('online');
    }
  }

  Future<void> _syncScheduledReservations() async {
    final trips = await TripService.getDriverScheduledReservations();
    if (trips.isEmpty) return;
    await ReservationNotificationService.scheduleForTrips(
      trips,
      forDriver: true,
    );
  }

  void _startStatsRealtime() {
    _statsTimer?.cancel();
    _onlineTickTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadTodayStats();
    });
    _peakHoursTimer?.cancel();
    _peakHoursTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _loadPeakHours();
    });
    _onlineTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isOnline) {
        setState(() => _onlineSecondsToday++);
      }
    });
  }

  Future<void> _loadTodayStats() async {
    final stats = await DriverAuthService.fetchTodayStats();
    if (stats == null || !mounted) return;
    setState(() {
      _tripsToday = _asInt(stats['trips_today']);
      _onlineSecondsToday = _asInt(stats['online_seconds_today']);
      _earningsToday = _asDouble(
        stats['driver_earnings_today'] ?? stats['earnings_today'],
      );
      _avgRating = _asDouble(stats['avg_rating'] ?? _avgRating);
      _totalTrips = _asInt(stats['total_trips'] ?? _totalTrips);
      final status = stats['status']?.toString();
      if (status != null && status.isNotEmpty) {
        _isOnline = status == 'online' || status == 'on_trip';
      }
    });
  }

  Future<void> _loadPeakHours() async {
    final hours = await DriverAuthService.fetchPeakHours();
    if (!mounted) return;
    setState(() => _peakHours = hours);
  }

  String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  Future<void> _logout() async {
    _stopPolling();
    _stopOnlineLocationSync();
    if (_isOnline) await TripService.updateDriverStatus('offline');
    await DriverAuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style:
              GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  void dispose() {
    _scheduledSyncTimer?.cancel();
    _statsTimer?.cancel();
    _peakHoursTimer?.cancel();
    _onlineTickTimer?.cancel();
    _stopPolling();
    _stopOnlineLocationSync();
    _pulse.dispose();
    super.dispose();
  }

  String get _initials => _driverName
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();

  // ── Open FAQ chatbot ──────────────────────────────────────────────────────
  void _openChat() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => AIChatScreen(
        userType: 'driver',
        userName: _driverName,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  void _openProfile() {
    Navigator.of(context)
        .push(PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              DriverProfileScreen(initialDriver: _driverProfile),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ))
        .then((_) => _loadDriver());
  }

  void _openReportIssue() {
    showReportIssueDialog(
      context: context,
      reporterRole: 'driver',
    );
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _asDouble(value);
    return 'PHP ${amount.toStringAsFixed(0)}';
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),

      // ── Floating FAQ chatbot button ────────────────────────────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: _openChat,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.question_answer_rounded,
                  color: AppColors.backgroundDark, size: 26),
              // Online dot
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ]),
          ),
        ).animate().fadeIn(delay: 500.ms).scale(
            begin: const Offset(0.6, 0.6),
            end: const Offset(1, 1),
            duration: 400.ms,
            curve: Curves.elasticOut),
      ),

      body: SafeArea(
        child: Column(children: [
          // ── Top bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              _iconBox(Icons.person_rounded, _openProfile),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (_isOnline ? Colors.green : Colors.grey)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isOnline ? Colors.green : Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(_isOnline ? 'ONLINE' : 'OFFLINE',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isOnline ? Colors.green : Colors.grey)),
                ]),
              ),
              const Spacer(),
              _iconBox(Icons.report_problem_outlined, _openReportIssue),
              const SizedBox(width: 8),
              _iconBox(Icons.settings_outlined, _logout),
            ]).animate().fadeIn(duration: 400.ms),
          ),

          const SizedBox(height: 16),

          // ── Stats bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF252540),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                _statItem(
                  "Today's Earnings",
                  'PHP ${_earningsToday.toStringAsFixed(2)}',
                  _tripsToday > 0 ? '$_tripsToday trips today' : 'No trips yet',
                  Icons.attach_money_rounded,
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                _statItem(
                  'Trips Today',
                  '$_tripsToday',
                  _avgRating > 0
                      ? '${_avgRating.toStringAsFixed(1)} ⭐'
                      : '$_totalTrips total trips',
                  Icons.trending_up_rounded,
                ),
              ]),
            ),
          ).animate().fadeIn(delay: 100.ms),

          // ── GO ONLINE button ──────────────────────────────────────────────
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _isUpdating ? null : _toggleOnline,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse ring when online
                      if (_isOnline)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 220 + (_pulse.value * 30),
                          height: 220 + (_pulse.value * 30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green
                                .withValues(alpha: 0.07 * (1 - _pulse.value)),
                          ),
                        ),
                      // Main circle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnline ? Colors.green : AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isOnline ? Colors.green : AppColors.primary)
                                      .withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 8,
                            )
                          ],
                        ),
                        child: _isUpdating
                            ? const Center(
                                child: SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3, color: Colors.white),
                              ))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!_isOnline)
                                    const Icon(Icons.location_on_rounded,
                                        color: AppColors.backgroundDark,
                                        size: 40)
                                  else
                                    SizedBox(
                                      width: 46,
                                      height: 46,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _isOnline ? 'ONLINE' : 'GO ONLINE',
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                      color: _isOnline
                                          ? Colors.white
                                          : AppColors.backgroundDark,
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
                                              .withValues(alpha: 0.7),
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
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              duration: 600.ms,
              curve: Curves.elasticOut),

          // ── Driver info card ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252540),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              Row(children: [
                ProfileAvatar(
                  initials: _initials,
                  imagePath: _driverPhotoPath,
                  size: 46,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  foregroundColor: AppColors.primary,
                  onTap: _openProfile,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_driverName,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
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
                          Text('· $_todaBody',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.white38)),
                        ]),
                      ]),
                ),

                // ── FAQ help chip ──────────────────────────────────────────
                GestureDetector(
                  onTap: _openChat,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.question_answer_rounded,
                          color: AppColors.primary, size: 14),
                      const SizedBox(width: 4),
                      Text('FAQ Help',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _bottomStat('Online Time', _formatDuration(_onlineSecondsToday),
                    Icons.access_time_rounded),
                _bottomStat('Trips Today', '$_tripsToday', Icons.route_rounded),
                _bottomStat(
                    'Earnings',
                    'PHP ${_earningsToday.toStringAsFixed(0)}',
                    Icons.attach_money_rounded),
              ]),
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white10),
              const SizedBox(height: 12),
              _peakHoursSummary(),
            ]),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
        ]),
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────
  Widget _peakHoursSummary() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.access_time_filled_rounded,
            color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text('Peak Hour Analysis',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
        ),
        Text('30 days',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
            )),
      ]),
      const SizedBox(height: 10),
      if (_peakHours.isEmpty)
        Text('No peak hour data yet',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white38))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            _peakHours.length,
            (index) => _peakHourChip(_peakHours[index], index),
          ),
        ),
    ]);
  }

  Widget _peakHourChip(Map<String, dynamic> hour, int index) {
    final requests = _asInt(hour['total_requests']);
    final completed = _asInt(hour['completed_trips']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('#${index + 1} ${hour['hour_label'] ?? 'Hour'}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            )),
        const SizedBox(height: 2),
        Text('$completed/$requests trips',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
        Text(_money(hour['gross_revenue']),
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.white38)),
      ]),
    );
  }

  Widget _iconBox(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF252540),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  Widget _statItem(String label, String value, String sub, IconData icon) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: AppColors.primary, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style:
                      GoogleFonts.poppins(fontSize: 10, color: Colors.white54)),
            ]),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            Text(sub,
                style:
                    GoogleFonts.poppins(fontSize: 10, color: Colors.white54)),
          ]),
        ),
      );

  Widget _bottomStat(String label, String value, IconData icon) => Expanded(
        child: Column(children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.white38)),
        ]),
      );
}
