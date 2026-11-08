import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todago/payment_method_logo.dart';
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
    expect(find.text('Proceed to Top Up'), findsOneWidget);
    expect(find.text('Open test simulator'), findsNothing);
    expect(find.text('Pay using QR Ph'), findsNothing);
    expect(find.text('QR Ph'), findsOneWidget);
    expect(find.byType(PaymentMethodLogo), findsNothing);
    expect(find.byType(Image), findsOneWidget,
        reason: 'Only the TodaGo logo is shown in test mode');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a test payment cannot proceed without a valid PayMongo test link',
      (tester) async {
    for (final url in [
      null,
      '',
      'http://test-sources.paymongo.com/example',
      'https://paymongo.com.example.org/example',
      'https://user@paymongo.com/example'
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: WalletPaymentScreen(
        key: ValueKey(url),
        transactionId: 'example',
        payment: {...qrPayment, 'testUrl': url},
        checkPayment: (_) async => {'success': true, 'status': 'pending'},
      )));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Proceed to Top Up'));
      expect(button.onPressed, isNull);
      expect(find.byType(Image), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an expired test action cannot start another authorization',
      (tester) async {
    final payment = Map<String, dynamic>.from(qrPayment)
      ..['status'] = 'awaiting_payment_method';
    await tester.pumpWidget(MaterialApp(
        home: WalletPaymentScreen(
      transactionId: 'example',
      payment: payment,
      checkPayment: (_) async => {'success': true, 'status': 'pending'},
    )));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Proceed to Top Up'));
    expect(button.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a response without a confirmed payment mode cannot expose a payable QR',
      (tester) async {
    final payment = {...qrPayment}..remove('testMode');
    await tester.pumpWidget(MaterialApp(
        home: WalletPaymentScreen(
      transactionId: 'example',
      payment: payment,
      checkPayment: (_) async => {'success': true, 'status': 'pending'},
    )));
    await tester.pumpAndSettle();
    expect(find.text('TEST PAYMENT'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Pay using QR Ph'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live checkout displays the supplied QR and payment-app logos',
      (tester) async {
    final imageBytes = File('assets/logo.png').readAsBytesSync();
    await tester.pumpWidget(MaterialApp(
        home: WalletPaymentScreen(
      transactionId: 'example',
      payment: {
        ...qrPayment,
        'testMode': false,
        'qrImageUrl': 'data:image/png;base64,${base64Encode(imageBytes)}',
      },
      checkPayment: (_) async => {'success': true, 'status': 'pending'},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Pay using QR Ph'), findsOneWidget);
    expect(find.byType(PaymentMethodLogo), findsNWidgets(2));
    expect(find.byType(Image), findsNWidgets(4));
    expect(find.text('TEST PAYMENT'), findsNothing);
    expect(find.text('Proceed to Top Up'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('test checkout fits narrow and tall phone screens',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(320, 568), const Size(412, 915)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(
          home: WalletPaymentScreen(
        transactionId: 'example',
        payment: qrPayment,
        checkPayment: (_) async => {'success': true, 'status': 'pending'},
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Proceed to Top Up'), findsOneWidget);
      expect(find.text('Back to wallet').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
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
