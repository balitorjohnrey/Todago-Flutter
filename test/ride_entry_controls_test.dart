import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:google_fonts/src/google_fonts_descriptor.dart';
import 'package:google_fonts/src/google_fonts_family_with_variant.dart';
import 'package:google_fonts/src/google_fonts_variant.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todago/admin_login_screen.dart';
import 'package:todago/app_theme.dart';
import 'package:todago/dropoff_picker_sheet.dart';
import 'package:todago/role_selection_screen.dart';
import 'package:todago/smart_ride_sheet.dart';

// Load placeholder fonts into Flutter's test engine without network or disk caches.
class _FontManifest extends Fake implements AssetManifest {
  final List<String> paths;
  _FontManifest(this.paths);

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
        ),
  ];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  font_loader.assetManifest = _FontManifest([
    for (final variant in variants) '${variant.toApiFilenamePrefix()}.ttf',
  ]);
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

// Keep the real map controller and event channels; replace only the native view.
class _TestMaps extends MethodChannelGoogleMapsFlutter {
  final _created = <int>{};

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {}

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    if (_created.add(creationId)) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel('plugins.flutter.io/google_maps_$creationId'),
        (_) async => null,
      );
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onPlatformViewCreated(creationId));
    }
    return const SizedBox.expand();
  }
}

Future<void> _openSheet(
  WidgetTester tester,
  Widget sheet, {
  ValueChanged<DropoffSelection?>? onResult,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: Builder(builder: (context) {
      return Scaffold(
        body: TextButton(
          onPressed: () async {
            final result = await showModalBottomSheet<DropoffSelection>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => sheet,
            );
            onResult?.call(result);
          },
          child: const Text('Open picker'),
        ),
      );
    }),
  ));
  await tester.tap(find.text('Open picker'));
  await tester.pumpAndSettle();
}

http.Response _placeResponse(String name, {String id = 'coord:7.3:125.68'}) {
  return http.Response(
      jsonEncode({
        'status': 'OK',
        'predictions': [
          {
            'place_id': id,
            'description': '$name, Panabo City',
            'structured_formatting': {
              'main_text': name,
              'secondary_text': 'Panabo City',
            },
          },
        ],
      }),
      200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_prepareFonts);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (call) async => call.method == 'initialize' ? false : true,
    );
  });

  testWidgets('Admin Login is reachable from the account chooser',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: const RoleSelectionScreen(successMessage: ''),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Admin Login'));
    await tester.tap(find.text('Admin Login'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(find.text('Admin Secret'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Smart Ride can close with the keyboard visible', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _openSheet(tester, const SmartRideSheet());
    await tester.enterText(find.byType(TextField), 'Take me to Gaisano');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close Smart Ride'));
    await tester.pumpAndSettle();
    expect(find.byType(SmartRideSheet), findsNothing);
    expect(find.text('Open picker'), findsOneWidget);
  });

  testWidgets('drop-off search renders on mobile and returns a selected place',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    DropoffSelection? selected;
    await http.runWithClient(() async {
      await _openSheet(
        tester,
        const DropoffPickerSheet(title: 'Passenger 2 Drop-off'),
        onResult: (result) => selected = result,
      );
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Search drop-offs'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Gaisano');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final resultTile = find.widgetWithText(ListTile, 'Gaisano');
      await tester.ensureVisible(resultTile);
      await tester.tap(resultTile);
      await tester.pumpAndSettle();
      expect(selected?.name, 'Gaisano, Panabo City');
      expect(selected?.point, const LatLng(7.3, 125.68));
    }, () => MockClient((_) async => _placeResponse('Gaisano')));
  });

  testWidgets('old search results cannot replace a newer drop-off query',
      (tester) async {
    final oldSearch = Completer<http.Response>();
    final newSearch = Completer<http.Response>();
    await http.runWithClient(() async {
      await _openSheet(
          tester, const DropoffPickerSheet(title: 'Passenger 2 Drop-off'));
      await tester.enterText(find.byType(TextField), 'Old place');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'New place');
      await tester.pump(const Duration(milliseconds: 400));
      newSearch.complete(_placeResponse('New result'));
      await tester.pumpAndSettle();
      oldSearch.complete(_placeResponse('Old result'));
      await tester.pumpAndSettle();
      expect(find.text('New result'), findsOneWidget);
      expect(find.text('Old result'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('New result'), findsNothing);
      await tester.tap(find.byTooltip('Close drop-off picker'));
      await tester.pumpAndSettle();
    },
        () => MockClient((request) =>
            request.url.queryParameters['input'] == 'Old place'
                ? oldSearch.future
                : newSearch.future));
  });

  testWidgets('failed place lookup offers recovery without closing the picker',
      (tester) async {
    await http.runWithClient(() async {
      await _openSheet(
          tester, const DropoffPickerSheet(title: 'Passenger 2 Drop-off'));
      await tester.enterText(find.byType(TextField), 'Unknown');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unknown place'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Could not locate this place'), findsOneWidget);
      expect(find.text('Pin on map'), findsOneWidget);
      expect(find.byType(DropoffPickerSheet), findsOneWidget);
      await tester.tap(find.byTooltip('Close drop-off picker'));
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async =>
            request.url.path.contains('autocomplete')
                ? _placeResponse('Unknown place', id: 'missing')
                : http.Response('{"status":"NOT_FOUND"}', 200)));
  });

  testWidgets('a map pin confirms exact coordinates when address lookup fails',
      (tester) async {
    final previousMaps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = _TestMaps();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = previousMaps);
    DropoffSelection? selected;
    await http.runWithClient(() async {
      await _openSheet(
        tester,
        const DropoffPickerSheet(title: 'Passenger 2 Drop-off'),
        onResult: (result) => selected = result,
      );
      await tester.tap(find.text('Pin on map'));
      await tester.pumpAndSettle();
      var confirm = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Confirm drop-off'));
      expect(confirm.onPressed, isNull);
      tester.widget<GoogleMap>(find.byType(GoogleMap)).onTap!(
        const LatLng(7.31234, 125.69123),
      );
      await tester.pumpAndSettle();
      final marker =
          tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.single;
      expect(marker.draggable, isTrue);
      marker.onDragEnd!(const LatLng(7.31333, 125.69222));
      await tester.pumpAndSettle();
      confirm = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Confirm drop-off'));
      expect(confirm.onPressed, isNotNull);
      await tester.tap(find.text('Confirm drop-off'));
      await tester.pumpAndSettle();
      expect(selected?.point, const LatLng(7.31333, 125.69222));
      expect(selected?.name, 'Pinned drop-off (7.31333, 125.69222)');
      expect(find.byType(DropoffPickerSheet), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => http.Response('{}', 503)));
  });
}
