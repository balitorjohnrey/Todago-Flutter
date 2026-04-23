import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'operator_pay_commission_screen.dart';

class OperatorFinancialsScreen extends StatefulWidget {
  const OperatorFinancialsScreen({super.key});
  @override
  State<OperatorFinancialsScreen> createState() => _OperatorFinancialsScreenState();
}

class _OperatorFinancialsScreenState extends State<OperatorFinancialsScreen> {
  int _periodTab = 0; // 0=Today, 1=This Week, 2=This Month

  final List<Map<String, dynamic>> _transactions = [
    {
      'day': 'Tue, Mar 31',
      'status': 'PENDING',
      'trips': 1850,
      'gross': 92500.0,
      'commission': 9250.0,
      'net': 83250.0,
    },
    {
      'day': 'Mon, Mar 30',
      'status': 'PAID',
      'trips': 1720,
      'gross': 86000.0,
      'commission': 8600.0,
      'net': 77400.0,
    },
    {
      'day': 'Sun, Mar 29',
      'status': 'PAID',
      'trips': 1540,
      'gross': 77000.0,
      'commission': 7700.0,
      'net': 69300.0,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(children: [
        // ── Header ───────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: AppColors.backgroundDark, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Financial Ledger', style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  )),
                  const Spacer(),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.download_rounded,
                        color: AppColors.backgroundDark, size: 18),
                  ),
                ]),
                const SizedBox(height: 14),
                // Period tabs
                Row(children: [
                  _periodBtn('Today', 0),
                  const SizedBox(width: 8),
                  _periodBtn('This Week', 1),
                  const SizedBox(width: 8),
                  _periodBtn('This Month', 2),
                ]),
                const SizedBox(height: 14),
              ]),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Commission Due Alert ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('COMMISSION BALANCE DUE', style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white70, letterSpacing: 1,
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Text('₱9,250', style: GoogleFonts.poppins(
                    fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1,
                  )),
                  const SizedBox(height: 4),
                  Text('10% commission on ₱92,500 gross revenue',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const OperatorPayCommissionScreen(),
                      transitionDuration: const Duration(milliseconds: 400),
                      transitionsBuilder: (_, anim, __, child) => SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                        child: child,
                      ),
                    )),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Pay Commission Balance', style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ]),
                    ),
                  ),
                ]),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 16),

              // ── Revenue Summary ────────────────────────────────────────────
              Row(children: [
                Expanded(child: _revCard(
                  'GROSS REVENUE', '₱92,500', 'today\'s total',
                  Icons.trending_up_rounded, Colors.green,
                )),
                const SizedBox(width: 12),
                Expanded(child: _revCard(
                  'NET PAYOUT', '₱83,250', 'after commission',
                  Icons.payments_rounded, Colors.blue,
                )),
              ]).animate().fadeIn(delay: 150.ms, duration: 400.ms),

              const SizedBox(height: 20),

              Text('Transaction History', style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.backgroundDark,
              )).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 12),

              // ── Transaction rows ──────────────────────────────────────────
              ..._transactions.asMap().entries.map((e) {
                final i = e.key;
                final t = e.value;
                final isPending = t['status'] == 'PENDING';
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(t['day'] as String, style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.backgroundDark,
                      )),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(t['status'] as String, style: GoogleFonts.poppins(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: isPending ? AppColors.primary : Colors.green,
                        )),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _txRow('Total Trips', '${t['trips']}'),
                    _txRow('Gross Revenue', '₱${(t['gross'] as double).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'),
                    _txRow('TodaGo Commission (10%)',
                        '-₱${(t['commission'] as double).toStringAsFixed(0)}',
                        isNeg: true),
                    const Divider(height: 16, color: Color(0xFFF5F5F5)),
                    _txRow('Net Payout to Drivers',
                        '₱${(t['net'] as double).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                        isBold: true),
                  ]),
                ).animate().fadeIn(delay: Duration(milliseconds: 250 + i * 80), duration: 400.ms);
              }),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _periodBtn(String label, int idx) {
    final sel = _periodTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _periodTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.backgroundDark : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: sel ? Colors.white : AppColors.textHint,
        )),
      ),
    );
  }

  Widget _revCard(String label, String value, String sub, IconData icon, Color color) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: AppColors.textHint, letterSpacing: 0.5,
          )),
        ]),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.backgroundDark,
        )),
        Text(sub, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
      ]),
    );

  Widget _txRow(String label, String value, {bool isNeg = false, bool isBold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          color: isBold ? AppColors.backgroundDark : AppColors.textHint,
        )),
        const Spacer(),
        Text(value, style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: isNeg ? AppColors.error : AppColors.backgroundDark,
        )),
      ]),
    );
}