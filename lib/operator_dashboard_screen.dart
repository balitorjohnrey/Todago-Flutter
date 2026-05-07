import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'operator_fleet_map_screen.dart';
import 'operator_drivers_screen.dart';
import 'operator_financials_screen.dart';
import 'operator_subscription_screen.dart';
import 'splash_screen.dart';

class OperatorDashboardScreen extends StatefulWidget {
  /// True if the operator subscribed to Pro during the subscription screen.
  final bool isPro;
  const OperatorDashboardScreen({super.key, this.isPro = false});

  @override
  State<OperatorDashboardScreen> createState() =>
      _OperatorDashboardScreenState();
}

class _OperatorDashboardScreenState extends State<OperatorDashboardScreen> {
  late bool _isPro;

  @override
  void initState() {
    super.initState();
    _isPro = widget.isPro;
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  // ── Show upgrade-to-Pro popup when a Basic user taps a Pro-only feature ──────
  void _showUpgradeDialog(String featureName) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.primary, size: 34),
              ),
              const SizedBox(height: 16),

              Text('Pro Feature',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  )),
              const SizedBox(height: 8),

              Text(
                '$featureName is only available on the Pro plan. Upgrade now to unlock full fleet management.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textHint,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),

              // Perks
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(children: [
                  _perkRow('Live Fleet Map'),
                  _perkRow('Driver Management (advanced)'),
                  _perkRow('Financial Ledger'),
                  _perkRow('Reduced commission (8%)'),
                  _perkRow('Priority support 24/7'),
                ]),
              ),

              const SizedBox(height: 20),

              // Upgrade button
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop(); // close dialog
                    // Open subscription as a bottom sheet; await result
                    final upgraded = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          const OperatorSubscriptionScreen(isModal: true),
                    );
                    if (upgraded == true && mounted) {
                      setState(() => _isPro = true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.workspace_premium_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text('Pro unlocked! All features available.',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              )),
                        ]),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 3),
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Upgrade to Pro — ₱999/mo',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.backgroundDark,
                      )),
                ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Maybe later',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textHint,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _perkRow(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.backgroundDark,
              )),
        ]),
      );

  // ── Navigate OR show upgrade dialog based on plan ─────────────────────────
  void _onFleetMap() {
    if (_isPro) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OperatorFleetMapScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ));
    } else {
      _showUpgradeDialog('Live Fleet Map');
    }
  }

  void _onDriverManagement() {
    if (_isPro) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OperatorDriversScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ));
    } else {
      _showUpgradeDialog('Driver Management');
    }
  }

  void _onFinancials() {
    if (_isPro) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OperatorFinancialsScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ));
    } else {
      _showUpgradeDialog('Financial Ledger');
    }
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
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.menu_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const Spacer(),
                        // Plan badge
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isPro
                                ? AppColors.primary.withOpacity(0.15)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isPro
                                  ? AppColors.primary.withOpacity(0.5)
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              _isPro
                                  ? Icons.workspace_premium_rounded
                                  : Icons.shield_outlined,
                              size: 13,
                              color: _isPro
                                  ? AppColors.primary
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isPro ? 'Pro' : 'Basic',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _isPro
                                    ? AppColors.primary
                                    : Colors.white54,
                              ),
                            ),
                          ]),
                        ),
                        // Notification
                        Stack(
                          children: [
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white, size: 20),
                            ),
                            Positioned(
                              top: 4, right: 4,
                              child: Container(
                                width: 16, height: 16,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                    child: Text('3',
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
                            width: 48, height: 48,
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
                                Text('Davao-Central TODA',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    )),
                                Text('Association #001 • Verified',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    )),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.success
                                            .withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          width: 6, height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                          )),
                                      const SizedBox(width: 5),
                                      Text('LTFRB Registered',
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
                        value: '315',
                        sub: 'of 402 total',
                        badge: '+12',
                        badgeColor: AppColors.success,
                      ),
                      _statCard(
                        icon: Icons.trending_up_rounded,
                        iconColor: AppColors.primary,
                        label: 'TRIPS TODAY',
                        value: '1,850',
                        sub: 'and counting',
                        badge: '+8%',
                        badgeColor: AppColors.success,
                      ),
                      _statCard(
                        icon: Icons.attach_money_rounded,
                        iconColor: AppColors.success,
                        label: 'TODA REVENUE',
                        value: '₱92,500',
                        sub: "today's gross",
                        badge: '+15%',
                        badgeColor: AppColors.success,
                      ),
                      _statCard(
                        icon: Icons.receipt_long_rounded,
                        iconColor: AppColors.error,
                        label: 'COMMISSION DUE',
                        value: '₱9,250',
                        sub: 'to TodaGo',
                        badge: 'PENDING',
                        badgeColor: AppColors.error,
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
                                    color: AppColors.backgroundDark,
                                    size: 18),
                                const SizedBox(width: 6),
                                Text('Avg Passenger Rating',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.backgroundDark,
                                    )),
                              ]),
                              const SizedBox(height: 8),
                              Text('4.75',
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
                                          i < 4
                                              ? Icons.star_rounded
                                              : Icons.star_half_rounded,
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

                  // Row 1: Fleet Map + Driver Management (Pro-gated)
                  Row(
                    children: [
                      Expanded(child: _actionCard(
                        icon: Icons.map_rounded,
                        label: 'Live Fleet Map',
                        isPro: _isPro,
                        onTap: _onFleetMap,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _actionCard(
                        icon: Icons.manage_accounts_rounded,
                        label: 'Driver Management',
                        isPro: _isPro,
                        onTap: _onDriverManagement,
                      )),
                    ],
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  // Row 2: Financials (Pro-gated) + Subscription + Logout
                  Row(
                    children: [
                      Expanded(child: _actionCard(
                        icon: Icons.bar_chart_rounded,
                        label: 'Financials',
                        isPro: _isPro,
                        onTap: _onFinancials,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _actionCard(
                        icon: Icons.workspace_premium_rounded,
                        label: _isPro ? 'Pro Plan ✓' : 'Subscription',
                        onTap: () async {
                          if (_isPro) return; // already Pro, nothing to do
                          final upgraded =
                              await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const OperatorSubscriptionScreen(
                                isModal: true),
                          );
                          if (upgraded == true && mounted) {
                            setState(() => _isPro = true);
                          }
                        },
                        isGold: true,
                      )),
                    ],
                  ).animate().fadeIn(delay: 340.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  // Logout full-width
                  SizedBox(
                    width: double.infinity,
                    child: _actionCard(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      onTap: _logout,
                      isDestructive: true,
                    ),
                  ).animate().fadeIn(delay: 380.ms, duration: 400.ms),

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

  /// [isPro] null = not a gated feature (subscription / logout)
  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool? isPro,
    bool isDestructive = false,
    bool isGold = false,
  }) {
    // A gated feature on Basic shows a lock overlay
    final isLocked = isPro != null && !isPro;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: isGold
              ? AppColors.primary.withOpacity(0.08)
              : Colors.white,
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
                          : isLocked
                              ? Colors.grey[400]
                              : AppColors.backgroundDark,
                  size: 26,
                ),
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 9),
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
                        : isLocked
                            ? Colors.grey[400]
                            : AppColors.backgroundDark,
              ),
            ),
            if (isLocked) ...[
              const SizedBox(height: 4),
              Text('Pro only',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error.withOpacity(0.7),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}