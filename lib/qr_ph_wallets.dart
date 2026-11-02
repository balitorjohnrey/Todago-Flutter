import 'package:flutter/material.dart';
import 'payment_method_logo.dart';

class QrPhWallets extends StatelessWidget {
  const QrPhWallets({super.key});

  @override
  Widget build(BuildContext context) => const Column(children: [
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 8,
            children: [
              PaymentMethodLogo(provider: 'gcash', width: 90),
              PaymentMethodLogo(provider: 'maya', width: 90),
            ]),
        SizedBox(height: 8),
        Text('GCash • Maya • QR Ph participating banks',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      ]);
}
