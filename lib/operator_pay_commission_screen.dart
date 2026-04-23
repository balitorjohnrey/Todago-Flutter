import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class OperatorPayCommissionScreen extends StatefulWidget {
  const OperatorPayCommissionScreen({super.key});
  @override
  State<OperatorPayCommissionScreen> createState() =>
      _OperatorPayCommissionScreenState();
}

class _OperatorPayCommissionScreenState
    extends State<OperatorPayCommissionScreen> {
  int _selectedMethod = 0; // 0=TodaGo Wallet, 1=Bank Transfer
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(
                  24, 20, 24,
                  MediaQuery.of(context).viewInsets.bottom + 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Center(child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300], borderRadius: BorderRadius.circular(2),
                      ),
                    )),
                    const SizedBox(height: 20),

                    // Icon
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: AppColors.backgroundDark, size: 30),
                    ).animate()
                        .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1),
                            duration: 400.ms, curve: Curves.elasticOut),

                    const SizedBox(height: 14),

                    Text('Pay Commission', style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: AppColors.backgroundDark,
                    )).animate().fadeIn(delay: 80.ms, duration: 400.ms),

                    Text('Settle your TodaGo commission balance',
                        style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textHint,
                        )).animate().fadeIn(delay: 120.ms, duration: 400.ms),

                    const SizedBox(height: 24),

                    // Amount Due
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Amount Due', style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textHint,
                        )),
                        const SizedBox(height: 4),
                        Text('₱9,250', style: GoogleFonts.poppins(
                          fontSize: 30, fontWeight: FontWeight.w900,
                          color: AppColors.backgroundDark,
                        )),
                        Text('10% commission on ₱92,500 gross revenue',
                            style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textHint,
                            )),
                      ]),
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                    const SizedBox(height: 16),

                    // Payment methods
                    _paymentMethod(
                      0,
                      Icons.account_balance_wallet_rounded,
                      AppColors.primary,
                      'TodaGo Wallet',
                      'Balance: ₱12,800',
                      recommended: true,
                    ),
                    const SizedBox(height: 10),
                    _paymentMethod(
                      1,
                      Icons.account_balance_rounded,
                      Colors.blue,
                      'Bank Transfer',
                      '3–5 business days',
                    ),

                    const SizedBox(height: 20),

                    // Buttons
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDDDDDD)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Cancel', style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                          )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: _isProcessing
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.backgroundDark,
                                  ))
                              : Text('Pay Now', style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: AppColors.backgroundDark,
                                )),
                        ),
                      ),
                    ]).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentMethod(
    int idx,
    IconData icon,
    Color color,
    String title,
    String subtitle, {
    bool recommended = false,
  }) {
    final sel = _selectedMethod == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFFF8E1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? AppColors.primary : const Color(0xFFEEEEEE),
            width: sel ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.backgroundDark,
              )),
              if (recommended) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Recommended', style: GoogleFonts.poppins(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: AppColors.backgroundDark,
                  )),
                ),
              ],
            ]),
            Text(subtitle, style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.textHint,
            )),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.textHint),
        ]),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isProcessing = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text('Commission of ₱9,250 paid successfully!',
            style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w500,
            )),
      ]),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }
}