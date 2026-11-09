import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:todago/merchant_qr_checkout_screen.dart';
import 'package:todago/passenger_qr_top_up_screen.dart';
import 'package:todago/qr_gallery.dart';
import 'support/fake_qr_webview.dart';

const qrId = 'qr_dd87466c79a3cdf98c0feb55';
const checksum =
    'f72a31f282b97813453d31fb5a55cc96d37c2d5c05cd6df171e51ec8ad986816';
Map<String, dynamic> assignment({String? paymentId}) => {
      'success': true,
      'available': true,
      'testMode': false,
      'kind': 'passenger_pool',
      'qrCodeId': qrId,
      'qrImageUrl': 'https://todago-qrph.johnmejio11.chatgpt.site/$qrId.jpg',
      'qrImageSha256': checksum,
      'latestPayment':
          paymentId == null ? null : {'paymentId': paymentId, 'amount': 20},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeQrWebViewPlatform web;
  setUp(() => WebViewPlatform.instance = web = FakeQrWebViewPlatform());

  testWidgets(
      'uses the assigned QR with no amount or receipt fields; Done cannot create credit',
      (tester) async {
    String? result;
    await open(tester, PassengerQrTopUpScreen(loadQr: () async => assignment()),
        (value) => result = value);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Submit reference'), findsNothing);
    await tester.tap(find.text('Top-Up Now'));
    await tester.pumpAndSettle();
    expect(web.controller.loaded.queryParameters['qr'], qrId);
    await web.controller.done();
    await tester.pumpAndSettle();
    expect(result, 'pending');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'only a new server-confirmed payment automatically finishes the QR screen',
      (tester) async {
    var paid = false;
    String? result;
    await open(
        tester,
        PassengerQrTopUpScreen(
            loadQr: () async =>
                assignment(paymentId: paid ? 'pay_new' : 'pay_old')),
        (value) => result = value);
    await tester.tap(find.text('Top-Up Now'));
    await tester.pumpAndSettle();
    expect(result, null);
    paid = true;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(result, 'completed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a depleted pool, failed request or invalid QR cannot expose a payable page',
      (tester) async {
    for (final response in [
      {
        'success': true,
        'available': false,
        'testMode': false,
        'kind': 'passenger_pool',
        'message': 'Your QR is being prepared'
      },
      {'success': false},
      {...assignment(), 'qrImageUrl': 'https://other.example/code.jpg'},
      {...assignment(), 'testMode': true},
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: PassengerQrTopUpScreen(
              key: UniqueKey(), loadQr: () async => response)));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Top-Up Now'))
              .onPressed,
          null);
      expect(find.byType(MerchantQrCheckoutScreen), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'native download messages must match the displayed QR and session',
      (tester) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('todago/qr_gallery');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'content://photos/qr';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final bytes = Uint8List.fromList([255, 216, 255, 217]);
    final hash = sha256.convert(bytes).toString();
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: MerchantQrCheckoutScreen(qrCodeId: qrId, imageSha256: hash)));
      await tester.pumpAndSettle();
      final bridge = web.controller.channels['TodaGoQr']!;
      final session = web.controller.loaded.queryParameters['session'];
      for (final data in [
        {'type': 'credit', 'qrId': qrId, 'session': session},
        {'type': 'download', 'qrId': qrId, 'session': 'wrong'},
        {'type': 'download', 'qrId': 'qr_other', 'session': session},
      ]) {
        bridge.onMessageReceived(JavaScriptMessage(message: jsonEncode(data)));
        await tester.pumpAndSettle();
      }
      expect(calls, isEmpty);
      bridge.onMessageReceived(JavaScriptMessage(
          message: jsonEncode(
              {'type': 'download', 'qrId': qrId, 'session': session})));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'saveQr');
      expect(calls.single.arguments['fileName'], 'TodaGo-$qrId.jpg');
      expect(find.textContaining('QR saved to Photos'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async => http.Response.bytes(bytes, 200)));
  });

  test(
      'a replaced QR image cannot be saved even when its HTTP request succeeds',
      () async {
    await http.runWithClient(() async {
      await expectLater(QrGallery.save(qrId, checksum), throwsFormatException);
    }, () => MockClient((_) async => http.Response.bytes([1, 2, 3], 200)));
  });

  testWidgets('the new top-up screen fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: PassengerQrTopUpScreen(loadQr: () async => assignment())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Top-Up Now'));
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> open(
    WidgetTester tester, Widget screen, void Function(String?) result) async {
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                child: const Text('Open'),
                onPressed: () async => result(await Navigator.of(context)
                    .push<String>(MaterialPageRoute(builder: (_) => screen))),
              )))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
