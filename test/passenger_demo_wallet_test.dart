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
import 'package:todago/demo_wallet_store.dart';
import 'package:todago/merchant_qr_top_up_screen.dart';
import 'package:todago/passenger_home_screen.dart';

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
      'Top-Up Now updates the actual passenger demo wallet without a payment request; refresh and reset preserve real funds',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
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
      await tester.ensureVisible(find.text('Proceed to Top Up'));
      await tester.tap(find.text('Proceed to Top Up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top-Up Now'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Wallet Balance'), findsOneWidget);
      expect(find.text('₱20.00'), findsWidgets);
      expect((await DemoWalletStore.load('alice')).balance, 20);
      expect((await DemoWalletStore.load('bob')).balance, 0);
      expect(requests.where((request) => request.method != 'GET'), isEmpty);
      expect(
          requests.where((request) =>
              request.url.path.contains('payment-methods') ||
              request.url.path.endsWith('/top-up')),
          isEmpty);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.text('Demo Wallet Balance'), findsOneWidget);
      expect(find.text('₱20.00'), findsWidgets);
      await tester.tap(find.text('Reset demo wallet'));
      await tester.pumpAndSettle();
      expect(find.text('TodaGo Wallet Balance'), findsOneWidget);
      expect(find.text('₱75.00'), findsWidgets);
      expect((await DemoWalletStore.load('alice')).active, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              requests.add(request);
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'user': user,
                    'trips': [],
                    'wallet': {'balance': 75, 'transactions': [], 'stats': {}},
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
