import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todago/payment_method_logo.dart';
import 'package:todago/wallet_checkout_screen.dart';
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

Map<String, dynamic> liveQrPayment() => {
      ...qrPayment,
      'testMode': false,
      'qrImageUrl':
          'data:image/png;base64,${base64Encode(File('assets/logo.png').readAsBytesSync())}',
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
    expect(find.text('Sandbox'), findsOneWidget);
    expect(find.text('TEST PAYMENT'), findsNothing);
    expect(find.byIcon(Icons.science_outlined), findsNothing);
    expect(find.text('You are about to top up ₱100.00 to your TodaGo wallet.'),
        findsOneWidget);
    expect(find.textContaining('Authorize a test payment'), findsNothing);
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
    expect(find.text('Sandbox'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Pay using QR Ph'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'live checkout proceeds from confirmation to its native QR screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WalletPaymentScreen(
      transactionId: 'example',
      payment: liveQrPayment(),
      checkPayment: (_) async => {'success': true, 'status': 'pending'},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Live payment'), findsOneWidget);
    expect(find.text('You are about to top up ₱100.00 to your TodaGo wallet.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('qrph-payment-code')), findsNothing);
    await tester.tap(find.text('Proceed to Top Up'));
    await tester.pumpAndSettle();
    expect(find.text('Scan QR Ph'), findsOneWidget);
    expect(find.text('Scan to top up'), findsOneWidget);
    expect(find.byKey(const ValueKey('qrph-payment-code')), findsOneWidget);
    expect(find.byType(WalletCheckoutScreen), findsNothing);
    expect(find.byType(PaymentMethodLogo), findsNWidgets(2));
    expect(find.byType(Image), findsNWidgets(4));
    expect(find.text('TEST PAYMENT'), findsNothing);
    expect(find.text('Sandbox'), findsNothing);
    expect(find.text('Proceed to Top Up'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back to top-up'));
    await tester.pumpAndSettle();
    expect(find.text('Proceed to Top Up'), findsOneWidget);
    expect(find.byKey(const ValueKey('qrph-payment-code')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live checkout cannot proceed with a missing or invalid QR',
      (tester) async {
    for (final source in [
      null,
      '',
      'http://example.com/qr.png',
      'file:///qr.png'
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: WalletPaymentScreen(
        key: ValueKey(source),
        transactionId: 'example',
        payment: {...liveQrPayment(), 'qrImageUrl': source},
        checkPayment: (_) async => {'success': true, 'status': 'pending'},
      )));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Proceed to Top Up'));
      expect(button.onPressed, isNull);
      expect(find.byKey(const ValueKey('qrph-payment-code')), findsNothing);
      expect(find.byType(WalletCheckoutScreen), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a QR that becomes inactive is removed after a status refresh',
      (tester) async {
    final payment = liveQrPayment();
    await tester.pumpWidget(MaterialApp(
        home: WalletPaymentScreen(
      transactionId: 'example',
      payment: payment,
      checkPayment: (_) async => {
        'success': true,
        'status': 'pending',
        'payment': {...payment, 'status': 'awaiting_payment_method'},
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proceed to Top Up'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qrph-payment-code')), findsOneWidget);
    await tester.tap(find.byTooltip('Check payment'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qrph-payment-code')), findsNothing);
    expect(find.textContaining('This QR code is no longer available'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('test and live checkout fit narrow and tall phone screens',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(320, 568), const Size(412, 915)]) {
      await tester.binding.setSurfaceSize(size);
      for (final payment in [qrPayment, liveQrPayment()]) {
        await tester.pumpWidget(MaterialApp(
            home: WalletPaymentScreen(
          transactionId: 'example',
          payment: payment,
          checkPayment: (_) async => {'success': true, 'status': 'pending'},
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Proceed to Top Up'), findsOneWidget);
        expect(find.text('Back to wallet').hitTestable(), findsOneWidget);
        if (payment['testMode'] == false) {
          await tester.ensureVisible(find.text('Proceed to Top Up'));
          await tester.tap(find.text('Proceed to Top Up'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
              find.byKey(const ValueKey('qrph-payment-code')), findsOneWidget);
          expect(find.text('Back to wallet').hitTestable(), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets(
      'an unfinished payment stays open until the server confirms completion',
      (tester) async {
    String? result;
    var confirmed = false;
    for (final payment in [qrPayment, liveQrPayment()]) {
      result = null;
      confirmed = false;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          result = await Navigator.of(context)
                              .push<String>(MaterialPageRoute(
                                  builder: (_) => WalletPaymentScreen(
                                        transactionId: 'example',
                                        payment: payment,
                                        checkPayment: (_) async => {
                                          'success': true,
                                          'status': confirmed
                                              ? 'completed'
                                              : 'pending'
                                        },
                                      )));
                        },
                        child: const Text('Start top-up')),
                  ))));
      await tester.tap(find.text('Start top-up'));
      await tester.pumpAndSettle();
      if (payment['testMode'] == false) {
        await tester.tap(find.text('Proceed to Top Up'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Check payment'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
          find.text(payment['testMode'] == true ? 'Sandbox' : 'Live payment'),
          findsOneWidget);
      confirmed = true;
      await tester.tap(find.byTooltip('Check payment'));
      await tester.pumpAndSettle();
      expect(result, 'completed');
      expect(find.text('Start top-up'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
