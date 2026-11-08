import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todago/demo_wallet_store.dart';
import 'package:todago/merchant_qr_top_up_screen.dart';
import 'package:todago/wallet_checkout_screen.dart';
import 'package:todago/wallet_payment_screen.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('The merchant QR/demo flow must not use the network.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('demo credits persist per passenger and never share balances or history',
      () async {
    final alice = await DemoWalletStore.topUp('alice', 20);
    expect(alice.balance, 20);
    expect(alice.active, isTrue);
    expect((await DemoWalletStore.load('alice')).balance, 20);
    expect((await DemoWalletStore.load('bob')).active, isFalse);
    final bob = await DemoWalletStore.topUp('bob', 50);
    expect(bob.balance, 50);
    expect((await DemoWalletStore.load('alice')).balance, 20);
    expect(alice.transactions.single['demo'], isTrue);
    expect(alice.transactions.single['status'], 'demo');
    expect(alice.transactions.single['title'], 'Demo Top-up');
  });

  test(
      'concurrent demo actions preserve both credits and reset only the selected passenger',
      () async {
    await Future.wait([
      DemoWalletStore.topUp('alice', 100),
      DemoWalletStore.topUp('alice', 200),
    ]);
    final alice = await DemoWalletStore.load('alice');
    expect(alice.balance, 300);
    expect(alice.transactions.length, 2);
    await DemoWalletStore.topUp('bob', 50);
    await DemoWalletStore.reset('alice');
    expect((await DemoWalletStore.load('alice')).active, isFalse);
    expect((await DemoWalletStore.load('bob')).balance, 50);
  });

  test(
      'demo store rejects anonymous or unsupported amounts without adding funds',
      () async {
    for (final amount in [0, -20, 19, 21, 1001]) {
      await expectLater(
          DemoWalletStore.topUp('alice', amount), throwsArgumentError);
    }
    await expectLater(DemoWalletStore.topUp('', 20), throwsArgumentError);
    expect((await DemoWalletStore.load('alice')).balance, 0);
  });

  testWidgets(
      'shows the supplied merchant image offline and returns the selected demo amount using Top-Up Now',
      (tester) async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = _NoNetwork();
    addTearDown(() => HttpOverrides.global = previous);
    int? selected;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      selected = await Navigator.of(context)
                          .push<int>(MaterialPageRoute(
                        builder: (_) => const MerchantQrTopUpScreen(),
                      ));
                    },
                    child: const Text('Open top-up'))))));
    await tester.tap(find.text('Open top-up'));
    await tester.pumpAndSettle();
    for (final amount in [20, 50, 100, 200, 500, 1000]) {
      expect(find.widgetWithText(ChoiceChip, '₱$amount'), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, '₱50'));
    await tester.ensureVisible(find.text('Proceed to Top Up'));
    await tester.tap(find.text('Proceed to Top Up'));
    await tester.pumpAndSettle();
    expect(find.image(const AssetImage(MerchantQrTopUpScreen.qrAsset)),
        findsOneWidget);
    expect(find.text('₱50.00'), findsOneWidget);
    expect(find.textContaining('No real payment is required'), findsOneWidget);
    expect(find.textContaining('uses real money'), findsOneWidget);
    expect(find.byType(WalletCheckoutScreen), findsNothing);
    expect(find.byType(WalletPaymentScreen), findsNothing);
    expect(find.text('Simulate Top-Up'), findsNothing);
    await tester.tap(find.text('Top-Up Now'));
    await tester.pumpAndSettle();
    expect(selected, 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewing and closing the merchant QR never claims a demo credit',
      (tester) async {
    int? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context)
                          .push<int>(MaterialPageRoute(
                        builder: (_) => const MerchantQrTopUpScreen(),
                      ));
                    },
                    child: const Text('Open top-up'))))));
    await tester.tap(find.text('Open top-up'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Proceed to Top Up'));
    await tester.tap(find.text('Proceed to Top Up'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View full-size QR'));
    await tester.tap(find.text('View full-size QR'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to wallet'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect((await DemoWalletStore.load('alice')).balance, 0);
  });

  testWidgets(
      'returning to the QR preview or full-size view completes the demo only once',
      (tester) async {
    for (final fullSize in [false, true]) {
      var completions = 0;
      int? amount;
      await tester.pumpWidget(MaterialApp(
        key: ValueKey(fullSize),
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async {
                    amount =
                        await Navigator.of(context).push<int>(MaterialPageRoute(
                      builder: (_) => const MerchantQrTopUpScreen(),
                    ));
                    if (amount != null) completions++;
                  },
                  child: const Text('Open top-up'),
                ))),
      ));
      await tester.tap(find.text('Open top-up'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '₱100'));
      await tester.ensureVisible(find.text('Proceed to Top Up'));
      await tester.tap(find.text('Proceed to Top Up'));
      await tester.pumpAndSettle();
      if (fullSize) {
        await tester.ensureVisible(find.text('View full-size QR'));
        await tester.tap(find.text('View full-size QR'));
        await tester.pumpAndSettle();
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(amount, 100);
      expect(completions, 1);
      expect(find.byType(MerchantQrTopUpScreen), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(completions, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'selection, overlays and a disabled auto-finish switch do not credit on resume',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MerchantQrTopUpScreen()));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(MerchantQrTopUpScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Proceed to Top Up'));
    await tester.tap(find.text('Proceed to Top Up'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(MerchantQrTopUpScreen), findsOneWidget);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(MerchantQrTopUpScreen), findsOneWidget);
    expect((await DemoWalletStore.load('alice')).balance, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('merchant QR and demo action fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MerchantQrTopUpScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Proceed to Top Up'));
    await tester.tap(find.text('Proceed to Top Up'));
    await tester.pumpAndSettle();
    expect(find.text('Top-Up Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
