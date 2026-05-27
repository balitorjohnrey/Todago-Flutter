import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'operator_auth_service.dart';
import 'operator_fleet_map_screen.dart';
import 'operator_drivers_screen.dart';
import 'splash_screen.dart';

class OperatorDashboardScreen extends StatefulWidget {
  const OperatorDashboardScreen({super.key});

  @override
  State<OperatorDashboardScreen> createState() =>
      _OperatorDashboardScreenState();
}

class _OperatorDashboardScreenState extends State<OperatorDashboardScreen> {
  Map<String, dynamic>? _operator;
  Map<String, dynamic> _stats = {};
  Timer? _refreshTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadDashboard(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final results = await Future.wait([
      OperatorAuthService.fetchProfile(),
      OperatorAuthService.fetchStats(),
    ]);
    if (!mounted) return;
    setState(() {
      _operator = results[0];
      _stats = results[1] ?? {};
      _isLoading = false;
    });
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(dynamic value) {
    final amount = _asDouble(value);
    return 'PHP ${amount.toStringAsFixed(0)}';
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  void _onFleetMap() {
    _pushOperatorTool(const OperatorFleetMapScreen());
  }

  void _onDriverManagement() {
    _pushOperatorTool(const OperatorDriversScreen());
  }

  void _pushOperatorTool(Widget screen) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => screen,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Dark Top Header ──────────────────────────────────────────────────
          Container(
            color: AppColors.backgroundDark,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.menu_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const Spacer(),
                        // Operator access badge
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Operator',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ]),
                        ),
                        // Notification
                        Stack(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.notifications_outlined,
                                  color: Colors.white, size: 20),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                    child: Text(
                                        '${_asInt(_stats['pending_drivers'])}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ))),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // TODA Association card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.shield_rounded,
                                color: AppColors.backgroundDark, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    _operator?['association_name']
                                            ?.toString() ??
                                        'TODA Association',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    )),
                                Text(
                                    '${_operator?['association_code'] ?? '-'} - ${(_operator?['toda_verified'] == true) ? 'Verified' : 'Pending Verification'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    )),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color:
                                            AppColors.success.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                          )),
                                      const SizedBox(width: 5),
                                      Text(
                                          (_operator?['toda_verified'] == true)
                                              ? 'LTFRB Registered'
                                              : 'LTFRB Pending',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.success,
                                          )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),

          // ── Scrollable Content ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fleet Status
                  Text('Fleet Status',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.backgroundDark,
                      )).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                  const SizedBox(height: 14),

                  // Stats grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _statCard(
                        icon: Icons.people_rounded,
                        iconColor: const Color(0xFF5B8CFF),
                        label: 'ACTIVE DRIVERS',
                        value: '${_asInt(_stats['active_drivers'])}',
                        sub: 'of ${_asInt(_stats['total_drivers'])} total',
                        badge: '${_asInt(_stats['offline_drivers'])} off',
                        badgeColor: AppColors.success,
                      ),
                      _statCard(
                        icon: Icons.trending_up_rounded,
                        iconColor: AppColors.primary,
                        label: 'TRIPS TODAY',
                        value: '${_asInt(_stats['trips_today'])}',
                        sub: _isLoading ? 'refreshing' : 'completed today',
                        badge: 'LIVE',
                        badgeColor: AppColors.success,
                      ),
                      _statCard(
                        icon: Icons.attach_money_rounded,
                        iconColor: AppColors.success,
                        label: 'GROSS REVENUE',
                        value: _money(_stats['gross_revenue']),
                        sub: "today's gross",
                        badge: 'TODAY',
                        badgeColor: AppColors.success,
                      ),
                      _statCard(
                        icon: Icons.pending_actions_rounded,
                        iconColor: Colors.orange,
                        label: 'PENDING DRIVERS',
                        value: '${_asInt(_stats['pending_drivers'])}',
                        sub: 'awaiting approval',
                        badge: 'QUEUE',
                        badgeColor: Colors.orange,
                      ),
                    ],
                  ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                  const SizedBox(height: 16),

                  // Avg Rating card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.star_rounded,
                                    color: AppColors.backgroundDark, size: 18),
                                const SizedBox(width: 6),
                                Text('Avg Passenger Rating',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.backgroundDark,
                                    )),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                  _asDouble(_stats['avg_rating'])
                                      .toStringAsFixed(2),
                                  style: GoogleFonts.poppins(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.backgroundDark,
                                  )),
                              Text('out of 5.0',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.backgroundDark
                                        .withOpacity(0.6),
                                  )),
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(
                                    5,
                                    (i) => Icon(
                                          i <
                                                  _asDouble(
                                                          _stats['avg_rating'])
                                                      .floor()
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          color: AppColors.backgroundDark,
                                          size: 18,
                                        )),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundDark,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Excellent',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              )),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 20),

                  // Quick Actions
                  Text('Quick Actions',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.backgroundDark,
                      )).animate().fadeIn(delay: 250.ms, duration: 400.ms),

                  const SizedBox(height: 14),

                  // Row 1: Fleet Map + Driver Management
                  Row(
                    children: [
                      Expanded(
                          child: _actionCard(
                        icon: Icons.map_rounded,
                        label: 'Live Fleet Map',
                        onTap: _onFleetMap,
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _actionCard(
                        icon: Icons.manage_accounts_rounded,
                        label: 'Driver Management',
                        onTap: _onDriverManagement,
                      )),
                    ],
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                          child: _actionCard(
                        icon: Icons.logout_rounded,
                        label: 'Logout',
                        onTap: _logout,
                        isDestructive: true,
                      )),
                    ],
                  ).animate().fadeIn(delay: 340.ms, duration: 400.ms),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 4),
            Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ))),
          ]),
          const Spacer(),
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Row(children: [
            Expanded(
                child: Text(sub,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  )),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isGold = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: isGold ? AppColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isGold
              ? Border.all(color: AppColors.primary.withOpacity(0.4))
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(
                  icon,
                  color: isDestructive
                      ? AppColors.error
                      : isGold
                          ? AppColors.primary
                          : AppColors.backgroundDark,
                  size: 26,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDestructive
                    ? AppColors.error
                    : isGold
                        ? AppColors.primary
                        : AppColors.backgroundDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
