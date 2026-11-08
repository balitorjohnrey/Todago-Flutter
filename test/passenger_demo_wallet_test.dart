import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:google_fonts/src/google_fonts_descriptor.dart';
import 'package:google_fonts/src/google_fonts_family_with_variant.dart';
import 'package:google_fonts/src/google_fonts_variant.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:todago/merchant_qr_top_up_screen.dart';
import 'package:todago/passenger_home_screen.dart';

import 'support/fake_qr_webview.dart';

class _NoMap extends MethodChannelGoogleMapsFlutter {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) =>
      const SizedBox.expand();
}

class _Fonts extends Fake implements AssetManifest {
  _Fonts(this.paths);
  final List<String> paths;
  @override
  List<String> listAssets() => paths;
}

Future<void> _prepareFonts() async {
  final variants = [
    for (final weight in FontWeight.values)
      for (final style in FontStyle.values)
        GoogleFontsFamilyWithVariant(
          family: 'Poppins',
          googleFontsVariant:
              GoogleFontsVariant(fontWeight: weight, fontStyle: style),
        )
  ];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  font_loader.assetManifest = _Fonts(
      [for (final variant in variants) '${variant.toApiFilenamePrefix()}.ttf']);
  messenger.setMockMessageHandler('flutter/assets', (_) async => ByteData(0));
  for (final variant in variants) {
    await font_loader.loadFontIfNecessary(GoogleFontsDescriptor(
      familyWithVariant: variant,
      file: GoogleFontsFile('', 0),
    ));
  }
  messenger.setMockMessageHandler('flutter/assets', null);
  font_loader.assetManifest = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Done cannot add funds; only a confirmed server balance is shown and old local preview data is removed',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'todago_demo_wallet_v1_alice': jsonEncode({
        'balanceCents': 999000,
        'transactions': [
          {'demo': true, 'title': 'Old preview'}
        ]
      })
    });
    WebViewPlatform.instance = FakeQrWebViewPlatform();
    await _prepareFonts();
    final previousMaps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = _NoMap();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = previousMaps);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const user = {
      'id': 'alice',
      'full_name': 'Demo Passenger',
      'email': 'alice@example.com'
    };
    const storage =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    const gps = MethodChannel('flutter.baseflow.com/geolocator');
    const notifications =
        MethodChannel('dexterous.com/flutter/local_notifications');
    messenger.setMockMethodCallHandler(storage, (call) async {
      if (call.method != 'read') return null;
      return call.arguments['key'] == 'auth_token'
          ? 'test-token'
          : call.arguments['key'] == 'user_data'
              ? jsonEncode(user)
              : null;
    });
    messenger.setMockMethodCallHandler(gps,
        (call) async => call.method == 'isLocationServiceEnabled' ? true : 0);
    messenger.setMockMethodCallHandler(notifications, (_) async => true);
    addTearDown(() {
      messenger.setMockMethodCallHandler(storage, null);
      messenger.setMockMethodCallHandler(gps, null);
      messenger.setMockMethodCallHandler(notifications, null);
    });
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <http.Request>[];
    var confirmed = false;
    var hasReference = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: PassengerHomeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wallet').last);
      await tester.pumpAndSettle();
      expect(find.text('TodaGo Wallet Balance'), findsOneWidget);
      expect(find.text('₱75.00'), findsWidgets);
      await tester.tap(find.text('Top Up'));
      await tester.pumpAndSettle();
      expect(find.byType(MerchantQrTopUpScreen), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('top-up-amount')), '73.45');
      await tester.pump();
      await tester.ensureVisible(find.text('Top-Up Now'));
      await tester.tap(find.text('Top-Up Now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Payment reference'), findsOneWidget);
      expect(confirmed, false);
      await tester.enterText(find.byType(TextField), 'INSTAPAY202611080001');
      await tester.ensureVisible(find.text('Submit reference'));
      await tester.tap(find.text('Submit reference'));
      await tester.pumpAndSettle();
      expect(find.text('Pending payment confirmation'), findsOneWidget);
      await tester.tap(find.text('Back to wallet'));
      await tester.pumpAndSettle();
      expect(find.text('₱75.00'), findsWidgets);
      await tester.ensureVisible(find.text('QR Ph Top-up'));
      await tester.tap(find.text('QR Ph Top-up'));
      await tester.pumpAndSettle();
      expect(find.text('Payment reference'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'INSTAPAY202611080001');
      confirmed = true;
      await tester.tap(find.byTooltip('Check payment'));
      await tester.pumpAndSettle();
      expect(find.text('TodaGo Wallet Balance'), findsOneWidget);
      expect(find.text('₱148.45'), findsWidgets);
      expect(find.text('Reset preview balance'), findsNothing);
      expect(
          (await SharedPreferences.getInstance())
              .containsKey('todago_demo_wallet_v1_alice'),
          false);
      expect(
          requests.where((request) =>
              request.url.host != 'todago-backend-production.up.railway.app'),
          isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              requests.add(request);
              if (request.url.path.contains('/in-store-qr/')) {
                if (request.method == 'POST' &&
                    request.url.path.endsWith('/reference')) {
                  hasReference = true;
                }
                return http.Response(
                    jsonEncode(request.url.path.endsWith('/configuration')
                        ? {'success': true, 'available': true}
                        : {
                            'success': true,
                            'testMode': false,
                            'transactionId': 'request-one',
                            'status': confirmed ? 'completed' : 'pending',
                            'payment': {
                              'kind': 'merchant_qr',
                              'amount': 73.45,
                              'provider': 'qrph',
                              'reference':
                                  hasReference ? 'INSTAPAY202611080001' : null,
                            }
                          }),
                    200,
                    headers: {'content-type': 'application/json'});
              }
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'user': user,
                    'trips': [],
                    'wallet': {
                      'balance': confirmed ? 148.45 : 75,
                      'transactions': [
                        {
                          'id': 'request-one',
                          'type': 'topup',
                          'provider': 'qrph',
                          'status': confirmed ? 'completed' : 'pending',
                          'title': 'QR Ph Top-up',
                          'subtitle': 'Awaiting payment confirmation',
                          'amount': 73.45,
                          'native_checkout': true,
                          'merchant_checkout': true,
                          'occurred_at': '2026-11-08T12:00:00Z',
                        }
                      ],
                      'stats': {}
                    },
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
