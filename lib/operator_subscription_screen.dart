import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class OperatorSubscriptionScreen extends StatefulWidget {
  const OperatorSubscriptionScreen({super.key});
  @override
  State<OperatorSubscriptionScreen> createState() =>
      _OperatorSubscriptionScreenState();
}

class _OperatorSubscriptionScreenState
    extends State<OperatorSubscriptionScreen> {
  int _selected = 1; // 0=Basic, 1=Pro (default highlight Pro)
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'Basic',
      'price': 'Free',
      'priceNum': 0,
      'period': 'Forever',
      'badge': null,
      'commission': '10%',
      'commissionNote': 'Standard rate per gross revenue',
      'color': const Color(0xFF243548),
      'textColor': Colors.white,
      'features': [
        {'text': 'Fleet dashboard', 'included': true},
        {'text': 'Driver management', 'included': true},
        {'text': 'Basic reports', 'included': true},
        {'text': 'Live fleet map', 'included': false},
        {'text': 'Advanced analytics', 'included': false},
        {'text': 'Reduced commission (8%)', 'included': false},
        {'text': 'Priority support', 'included': false},
      ],
    },
    {
      'name': 'Pro',
      'price': '₱999',
      'priceNum': 999,
      'period': '/month',
      'badge': 'RECOMMENDED',
      'commission': '8%',
      'commissionNote': '2% savings on every peso earned',
      'color': AppColors.primary,
      'textColor': AppColors.backgroundDark,
      'features': [
        {'text': 'Everything in Basic', 'included': true},
        {'text': 'Live fleet map', 'included': true},
        {'text': 'Advanced analytics', 'included': true},
        {'text': 'Reduced commission (8%)', 'included': true},
        {'text': 'Priority dispatch for drivers', 'included': true},
        {'text': 'Priority support 24/7', 'included': true},
        {'text': 'Commission ledger & reports', 'included': true},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: GestureDetector(
            onTap: () {},
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.workspace_premium_rounded,
                                color: AppColors.backgroundDark, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Operator Plans',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20, fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  )),
                              Text('Choose the right plan for your TODA',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.white54,
                                  )),
                            ],
                          )),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white54, size: 16),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // Current subscription badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Text('Current plan: ',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: Colors.white54)),
                            Text('Basic (Free)',
                                style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Active',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  )),
                            ),
                          ]),
                        ),
                      ]),
                    ),

                    // ── Plan cards ───────────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [

                          // Plan toggle cards
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(_plans.length, (i) {
                              final plan = _plans[i];
                              final sel = _selected == i;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selected = i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: EdgeInsets.only(
                                        right: i == 0 ? 8 : 0,
                                        left: i == 1 ? 8 : 0),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AppColors.primary
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: sel
                                            ? AppColors.primary
                                            : const Color(0xFFEEEEEE),
                                        width: sel ? 2 : 1,
                                      ),
                                      boxShadow: sel
                                          ? [BoxShadow(
                                              color: AppColors.primary
                                                  .withOpacity(0.3),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            )]
                                          : [],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (plan['badge'] != null)
                                          Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: sel
                                                  ? AppColors.backgroundDark
                                                  : AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(plan['badge']!,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w800,
                                                  color: sel
                                                      ? AppColors.primary
                                                      : AppColors.backgroundDark,
                                                  letterSpacing: 0.5,
                                                )),
                                          ),
                                        Text(plan['name']!,
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: sel
                                                  ? AppColors.backgroundDark
                                                  : AppColors.backgroundDark,
                                            )),
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(plan['price']!,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  color: sel
                                                      ? AppColors.backgroundDark
                                                      : AppColors.backgroundDark,
                                                  height: 1,
                                                )),
                                            if (plan['period'] != 'Forever')
                                              Text(plan['period']!,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: sel
                                                        ? AppColors
                                                            .backgroundDark
                                                            .withOpacity(0.6)
                                                        : AppColors.textHint,
                                                  )),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Commission highlight
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: sel
                                                ? AppColors.backgroundDark
                                                    .withOpacity(0.15)
                                                : AppColors.primary
                                                    .withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(children: [
                                            Icon(Icons.percent_rounded,
                                                size: 12,
                                                color: sel
                                                    ? AppColors.backgroundDark
                                                    : AppColors.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${plan['commission']} commission',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: sel
                                                    ? AppColors.backgroundDark
                                                    : AppColors.primary,
                                              ),
                                            ),
                                          ]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ).animate().fadeIn(
                                      delay: Duration(
                                          milliseconds: 100 + i * 80),
                                      duration: 400.ms),
                              );
                            }),
                          ),

                          const SizedBox(height: 20),

                          // Feature list for selected plan
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: const Color(0xFFEEEEEE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_plans[_selected]['name']} Plan Includes:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.backgroundDark,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ...(_plans[_selected]['features']
                                        as List<Map<String, dynamic>>)
                                    .map((f) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 10),
                                          child: Row(children: [
                                            Container(
                                              width: 22, height: 22,
                                              decoration: BoxDecoration(
                                                color: (f['included'] as bool)
                                                    ? Colors.green
                                                        .withOpacity(0.1)
                                                    : Colors.grey[100],
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                (f['included'] as bool)
                                                    ? Icons.check_rounded
                                                    : Icons.close_rounded,
                                                size: 13,
                                                color: (f['included'] as bool)
                                                    ? Colors.green
                                                    : Colors.grey[400],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              f['text'] as String,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: (f['included'] as bool)
                                                    ? AppColors.backgroundDark
                                                    : Colors.grey[400],
                                                fontWeight:
                                                    (f['included'] as bool)
                                                        ? FontWeight.w500
                                                        : FontWeight.w400,
                                              ),
                                            ),
                                          ]),
                                        )),
                              ],
                            ),
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                          const SizedBox(height: 16),

                          // Commission savings callout (Pro only)
                          if (_selected == 1)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.15),
                                    AppColors.primary.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color:
                                        AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Column(children: [
                                Row(children: [
                                  const Icon(Icons.savings_rounded,
                                      color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Savings Example',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.backgroundDark,
                                      )),
                                ]),
                                const SizedBox(height: 10),
                                _savingsRow(
                                    'Gross Revenue', '₱92,500', null),
                                _savingsRow('Basic (10%)', '-₱9,250',
                                    Colors.red),
                                _savingsRow(
                                    'Pro (8%)', '-₱7,400', Colors.green),
                                const Divider(height: 16),
                                _savingsRow(
                                    'You save per month', '₱1,850 🎉',
                                    Colors.green),
                              ]),
                            ).animate().fadeIn(
                                delay: 250.ms, duration: 400.ms),

                          const SizedBox(height: 20),

                          // Subscribe button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _plans[_selected]['priceNum'] == 0
                                  ? null
                                  : _isProcessing
                                      ? null
                                      : _subscribe,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor:
                                    Colors.grey[200],
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.backgroundDark))
                                  : Text(
                                      _plans[_selected]['priceNum'] == 0
                                          ? 'Current Plan (Basic)'
                                          : 'Subscribe to Pro — ₱999/mo',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _plans[_selected]
                                                    ['priceNum'] ==
                                                0
                                            ? Colors.grey[500]
                                            : AppColors.backgroundDark,
                                      )),
                            ),
                          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                          if (_plans[_selected]['priceNum'] != 0) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_rounded,
                                    size: 12,
                                    color: AppColors.textHint),
                                const SizedBox(width: 4),
                                Text(
                                  'Secure payment · Cancel anytime',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _savingsRow(String label, String value, Color? valueColor) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.backgroundDark,
              )),
        ]),
      );

  Future<void> _subscribe() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isProcessing = false);

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.workspace_premium_rounded,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text('Subscribed to Pro! Commission reduced to 8% ✅',
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }
}