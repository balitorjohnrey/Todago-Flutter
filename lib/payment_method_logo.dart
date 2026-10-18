import 'package:flutter/material.dart';

class PaymentMethodLogo extends StatelessWidget {
  const PaymentMethodLogo({super.key, required this.provider, this.width = 60});
  final String provider;
  final double width;

  @override
  Widget build(BuildContext context) {
    final asset = switch (provider) {
      'gcash' => 'assets/payments/gcash.png',
      'maya' || 'paymaya' => 'assets/payments/maya.png',
      _ => null,
    };
    if (asset != null) {
      return Container(
        width: width,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(6)),
        child:
            Image.asset(asset, fit: BoxFit.fitWidth, semanticLabel: provider),
      );
    }
    final icon = provider == 'qrph'
        ? Icons.qr_code_2_rounded
        : provider == 'card'
            ? Icons.credit_card_rounded
            : provider.startsWith('dob') || provider.startsWith('brankas')
                ? Icons.account_balance_rounded
                : Icons.account_balance_wallet_rounded;
    return SizedBox(width: width, height: 40, child: Icon(icon, size: 28));
  }
}
