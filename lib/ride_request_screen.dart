import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'navigation_pickup_screen.dart';

class RideRequestScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  const RideRequestScreen({
    super.key,
    required this.trip,
    required this.onAccept,
    required this.onDecline,
  });

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
        _handleDecline();
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _handleDecline() async {
    _timer?.cancel();
    await widget.onDecline();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleAccept() async {
    _timer?.cancel();
    await widget.onAccept();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => NavigationPickupScreen(trip: widget.trip),
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
    final commuterName = widget.trip['commuter_name'] ?? 'Passenger';
    final commuterRating = (widget.trip['commuter_rating'] ?? 4.5).toDouble();
    final pickup = widget.trip['pickup_location'] ?? 'Pickup Location';
    final destination = widget.trip['destination'] ?? 'Destination';
    final fare = (widget.trip['fare'] ?? 25.0).toDouble();
    final serviceType = widget.trip['service_type'] ?? 'solo';
    final paymentMethod = widget.trip['payment_method'] ?? 'cash';

    // Commission calculation
    const double commissionPct = 10.0;
    final commissionAmt = fare * commissionPct / 100;
    final driverEarnings = fare - commissionAmt;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.6),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2B3C),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // ── Yellow header ─────────────────────────────────────────
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
                  ),
                  const SizedBox(height: 12),
                  Text('New Ride Request!', style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: AppColors.backgroundDark,
                  )),
                  const SizedBox(height: 10),
                  // Countdown
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
                          value: _progress, strokeWidth: 2,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(children: [
                      Text('RIDE TYPE', style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white38, letterSpacing: 1.5,
                      )),
                      Text(serviceType.toUpperCase(), style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
                      )),
                    ]),
                  ),
                ]),
              ),

              // ── Passenger info ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  // Passenger row — REAL name from DB
                  Row(children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF243548),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text(
                        commuterName.isNotEmpty
                            ? commuterName.trim().split(' ').take(2)
                                .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
                                .join()
                            : 'P',
                        style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      )),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Real commuter name
                      Text(commuterName, style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                      )),
                      Row(children: [
                        ...List.generate(5, (i) => Icon(
                          i < commuterRating.floor()
                              ? Icons.star_rounded : Icons.star_half_rounded,
                          size: 13, color: AppColors.primary,
                        )),
                        const SizedBox(width: 4),
                        Text('${commuterRating.toStringAsFixed(1)}',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textHint)),
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _pill('Verified', Colors.green),
                      const SizedBox(height: 4),
                      _pill(paymentMethod.toUpperCase(), AppColors.primary),
                    ]),
                  ]),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF243548)),
                  const SizedBox(height: 14),

                  // Trip route
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Trip Details', style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.textHint, letterSpacing: 1,
                    )),
                  ),
                  const SizedBox(height: 12),

                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(children: [
                      Container(width: 10, height: 10,
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle)),
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
                            fontSize: 9, color: AppColors.textHint, letterSpacing: 1)),
                        Text(pickup, style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                      ]),
                      const SizedBox(height: 20),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('DESTINATION', style: GoogleFonts.poppins(
                            fontSize: 9, color: AppColors.textHint, letterSpacing: 1)),
                        Text(destination, style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                      ]),
                    ])),
                  ]),

                  const SizedBox(height: 16),

                  // Fare breakdown with REAL commission
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2B3C),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2E4158)),
                    ),
                    child: Column(children: [
                      Row(children: [
                        const Icon(Icons.receipt_long_rounded,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 6),
                        Text('FARE BREAKDOWN', style: GoogleFonts.poppins(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.textHint, letterSpacing: 1,
                        )),
                      ]),
                      const SizedBox(height: 10),
                      _fareRow('Passenger Fare',
                          '₱${fare.toStringAsFixed(2)}', Colors.white),
                      const SizedBox(height: 6),
                      _fareRow('TodaGo Commission (${commissionPct.toInt()}%)',
                          '- ₱${commissionAmt.toStringAsFixed(2)}', AppColors.error),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Color(0xFF2E4158), height: 1),
                      ),
                      _fareRow('Your Earnings',
                          '₱${driverEarnings.toStringAsFixed(2)}',
                          AppColors.success, bold: true, large: true),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // DECLINE + ACCEPT
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleDecline,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF243548),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.close_rounded,
                                color: Colors.white54, size: 18),
                            const SizedBox(width: 8),
                            Text('DECLINE', style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: Colors.white54,
                            )),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _handleAccept,
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
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w700, color: color,
    )),
  );

  Widget _fareRow(String label, String value, Color valueColor,
      {bool bold = false, bool large = false}) =>
      Row(children: [
        Text(label, style: GoogleFonts.poppins(
            fontSize: 11, color: AppColors.textHint)),
        const Spacer(),
        Text(value, style: GoogleFonts.poppins(
          fontSize: large ? 16 : 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: valueColor,
        )),
      ]);
}