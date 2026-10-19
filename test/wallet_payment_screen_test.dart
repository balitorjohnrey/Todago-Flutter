import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todago/wallet_payment_screen.dart';

const qrPayment = <String, dynamic>{
  'provider': 'qrph',
  'kind': 'qr',
  'amount': 100,
  'currency': 'PHP',
  'status': 'awaiting_next_action',
  'testMode': true,
  'qrImageUrl': 'data:image/png;base64,real-qr-must-not-render-in-test',
  'testUrl': 'https://test-sources.paymongo.com/example',
};

void main() {
  testWidgets(
      'test QR checkout clearly shows simulation and hides the payable QR',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WalletPaymentScreen(
      transactionId: 'example',
      payment: qrPayment,
      checkPayment: (_) async => {'success': true, 'status': 'pending'},
    )));
    await tester.pumpAndSettle();
    expect(find.text('TEST PAYMENT'), findsOneWidget);
    expect(find.text('Open test simulator'), findsOneWidget);
    expect(find.text('Pay using QR Ph'), findsNothing);
    expect(find.text('TodaGo wallet top-up'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'an unfinished payment stays open until the server confirms completion',
      (tester) async {
    String? result;
    var confirmed = false;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        result = await Navigator.of(context)
                            .push<String>(MaterialPageRoute(
                                builder: (_) => WalletPaymentScreen(
                                      transactionId: 'example',
                                      payment: qrPayment,
                                      checkPayment: (_) async => {
                                        'success': true,
                                        'status':
                                            confirmed ? 'completed' : 'pending'
                                      },
                                    )));
                      },
                      child: const Text('Start top-up')),
                ))));
    await tester.tap(find.text('Start top-up'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Check payment'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('TEST PAYMENT'), findsOneWidget);
    confirmed = true;
    await tester.tap(find.byTooltip('Check payment'));
    await tester.pumpAndSettle();
    expect(result, 'completed');
    expect(find.text('Start top-up'), findsOneWidget);
  });
}
