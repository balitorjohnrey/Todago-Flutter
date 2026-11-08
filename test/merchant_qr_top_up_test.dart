import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:todago/merchant_qr_checkout_screen.dart';
import 'package:todago/merchant_qr_checkout_session.dart';
import 'package:todago/merchant_qr_top_up_screen.dart';
import 'package:todago/wallet_migration.dart';
import 'support/fake_qr_webview.dart';

Map<String, dynamic> payment(
        {double amount = 73.45,
        String status = 'pending',
        String? reference}) =>
    {
      'success': true,
      'testMode': false,
      'transactionId': 'request-one',
      'status': status,
      'payment': {
        'kind': 'merchant_qr',
        'provider': 'qrph',
        'amount': amount,
        'reference': reference
      }
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeQrWebViewPlatform web;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WebViewPlatform.instance = web = FakeQrWebViewPlatform();
  });

  test('clears only retired local preview wallets and preserves other settings',
      () async {
    SharedPreferences.setMockInitialValues({
      'todago_demo_wallet_v1_alice': 'old',
      'todago_demo_wallet_v1_bob': 'old',
      'auth_setting': 'keep',
      'saved_ride': 'keep'
    });
    await WalletMigration.clearLocalPreviewBalances();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('todago_demo_wallet_v1_alice'), false);
    expect(preferences.containsKey('todago_demo_wallet_v1_bob'), false);
    expect(preferences.getString('auth_setting'), 'keep');
    expect(preferences.getString('saved_ride'), 'keep');
  });

  test(
      'custom decimal amounts are supported and return links remain session-bound',
      () {
    final session = MerchantQrCheckoutSession(amount: 73.45);
    expect(session.isCompletion(session.completionUri), true);
    expect(session.isCompletion(session.completionUri.replace(scheme: 'http')),
        false);
    expect(
        session
            .isCompletion(session.completionUri.replace(query: 'session=old')),
        false);
    for (final amount in [0.0, 19.99, 50000.01, double.nan, double.infinity]) {
      expect(
          () => MerchantQrCheckoutSession(amount: amount), throwsArgumentError);
    }
  });

  testWidgets(
      'custom amount replaces presets; Done only opens the reference screen',
      (tester) async {
    String? result;
    double? requested;
    await _open(
        tester,
        MerchantQrTopUpScreen(
          loadConfiguration: () async => {'success': true, 'available': true},
          createTopUp: (amount) async {
            requested = amount;
            return payment(amount: amount);
          },
          checkTopUp: (_) async => payment(),
        ),
        (value) => result = value);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Top-Up Now'))
            .onPressed,
        isNull);
    await tester.enterText(
        find.byKey(const ValueKey('top-up-amount')), '73.45');
    await tester.pump();
    await tester.ensureVisible(find.text('Top-Up Now'));
    await tester.tap(find.text('Top-Up Now'));
    await tester.pumpAndSettle();
    expect(requested, 73.45);
    expect(find.byType(MerchantQrCheckoutScreen), findsOneWidget);
    expect(web.controller.loaded.host, 'todago-qrph.johnmejio11.chatgpt.site');
    expect(web.controller.loaded.queryParameters.containsKey('amount'), false);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Payment reference'), findsOneWidget);
    expect(find.text('Pending payment confirmation'), findsOneWidget);
    expect(result, isNull);
    expect(find.textContaining('Preview credit'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'submitting a reference stays pending; only server confirmation finishes',
      (tester) async {
    var confirmed = false;
    String? result;
    String? submitted;
    await _open(
        tester,
        MerchantQrTopUpScreen(
          transactionId: 'request-one',
          loadConfiguration: () async => {'success': true, 'available': true},
          checkTopUp: (_) async =>
              payment(status: confirmed ? 'completed' : 'pending'),
          submitReference: (id, reference) async {
            submitted = reference;
            return payment();
          },
        ),
        (value) => result = value);
    await tester.enterText(find.byType(TextField), 'INSTAPAY202611080001');
    await tester.ensureVisible(find.text('Submit reference'));
    await tester.tap(find.text('Submit reference'));
    await tester.pumpAndSettle();
    expect(submitted, 'INSTAPAY202611080001');
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(result, isNull);
    confirmed = true;
    await tester.tap(find.byTooltip('Check payment'));
    await tester.pumpAndSettle();
    expect(result, 'completed');
  });

  testWidgets(
      'unconfigured server and failed creation cannot expose a payable QR',
      (tester) async {
    for (final available in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: MerchantQrTopUpScreen(
        key: ValueKey(available),
        loadConfiguration: () async =>
            {'success': true, 'available': available},
        createTopUp: (_) async =>
            {'success': false, 'message': 'Top-ups unavailable'},
      )));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('top-up-amount')), '73.45');
      await tester.pump();
      await tester.ensureVisible(find.text('Top-Up Now'));
      if (available) {
        await tester.tap(find.text('Top-Up Now'));
        await tester.pumpAndSettle();
        expect(find.text('Top-ups unavailable'), findsOneWidget);
      } else {
        expect(
            tester
                .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Top-Up Now'))
                .onPressed,
            isNull);
      }
      expect(find.byType(MerchantQrCheckoutScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('invalid custom amounts cannot start a top-up', (tester) async {
    var created = 0;
    await tester.pumpWidget(MaterialApp(
        home: MerchantQrTopUpScreen(
      loadConfiguration: () async => {'success': true, 'available': true},
      createTopUp: (_) async {
        created++;
        return payment();
      },
    )));
    await tester.pumpAndSettle();
    for (final amount in ['', '0', '19.99', '50001']) {
      await tester.enterText(
          find.byKey(const ValueKey('top-up-amount')), amount);
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Top-Up Now'))
              .onPressed,
          isNull);
    }
    expect(created, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Back and app resume do not finish an unpaid top-up',
      (tester) async {
    String? result;
    await _open(
        tester,
        MerchantQrTopUpScreen(
          loadConfiguration: () async => {'success': true, 'available': true},
          createTopUp: (_) async => payment(),
          checkTopUp: (_) async => payment(),
        ),
        (value) => result = value);
    await tester.enterText(
        find.byKey(const ValueKey('top-up-amount')), '73.45');
    await tester.pump();
    await tester.ensureVisible(find.text('Top-Up Now'));
    await tester.tap(find.text('Top-Up Now'));
    await tester.pumpAndSettle();
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(find.byType(MerchantQrCheckoutScreen), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.byTooltip('Back to top-up'));
    await tester.pumpAndSettle();
    await web.controller.done();
    await tester.pumpAndSettle();
    expect(find.byType(MerchantQrTopUpScreen), findsOneWidget);
    await tester.tap(find.text('Back to wallet'));
    await tester.pumpAndSettle();
    expect(result, 'pending');
  });

  testWidgets(
      'wrong sessions, frames and external apps cannot finish the hosted QR page',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: MerchantQrCheckoutScreen(amount: 73.45)));
    await tester.pumpAndSettle();
    for (final uri in [
      Uri.parse('gcash://pay'),
      Uri.parse('https://example.com/'),
      web.controller.completion.replace(query: 'session=old'),
      web.controller.completion.replace(port: 444),
      web.controller.completion
          .replace(query: '${web.controller.completion.query}&amount=50000')
    ]) {
      expect(await web.controller.navigate(uri), NavigationDecision.prevent);
    }
    expect(
        await web.controller
            .navigate(web.controller.completion, mainFrame: false),
        NavigationDecision.prevent);
    expect(find.byType(MerchantQrCheckoutScreen), findsOneWidget);
    web.controller.fail();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(web.controller.loads, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('custom amount and reference forms fit a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final resumed in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: MerchantQrTopUpScreen(
        key: ValueKey(resumed),
        transactionId: resumed ? 'request-one' : null,
        loadConfiguration: () async => {'success': true, 'available': true},
        checkTopUp: (_) async => payment(),
      )));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
          find.text(resumed ? 'Submit reference' : 'Top-Up Now'));
      expect(tester.takeException(), isNull);
      expect(find.text('Back to wallet').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Future<void> _open(WidgetTester tester, Widget screen,
    void Function(String?) completed) async {
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      completed(await Navigator.of(context).push<String>(
                          MaterialPageRoute(builder: (_) => screen)));
                    },
                    child: const Text('Open top-up')),
              ))));
  await tester.tap(find.text('Open top-up'));
  await tester.pumpAndSettle();
}
