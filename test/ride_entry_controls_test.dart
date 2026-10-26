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
import 'package:todago/live_map_screen.dart';
import 'package:todago/map_service.dart';
import 'package:todago/map_place_taps.dart';
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
  final calls = <MethodCall>[];

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
        (call) async {
          calls.add(call);
          return null;
        },
      );
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onPlatformViewCreated(creationId));
    }
    return const SizedBox.expand();
  }
}

_TestMaps _installTestMaps() {
  final previous = GoogleMapsFlutterPlatform.instance;
  final maps = _TestMaps();
  GoogleMapsFlutterPlatform.instance = maps;
  addTearDown(() => GoogleMapsFlutterPlatform.instance = previous);
  return maps;
}

Future<_TestMaps> _openExplorer(WidgetTester tester) async {
  final maps = _installTestMaps();
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: const LiveMapScreen(),
  ));
  await tester.pumpAndSettle();
  return maps;
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

const _collegeId = 'college-exact-id';
const _collegeName = 'Davao del Norte State College';
const _collegePoint = LatLng(7.31430, 125.67020);
const _origin = LatLng(7.29937, 125.68191);

http.Response _collegeDetails() => http.Response(
    jsonEncode({
      'status': 'OK',
      'result': {
        'place_id': _collegeId,
        'name': _collegeName,
        'formatted_address': 'New Visayas, Panabo City',
        'geometry': {
          'location': {'lat': 7.31430, 'lng': 125.67020}
        },
        'rating': 4.7,
        'user_ratings_total': 115,
        'types': ['university', 'point_of_interest', 'establishment'],
        'opening_hours': {
          'open_now': false,
          'weekday_text': ['Monday: 8 AM - 5 PM']
        },
        'wheelchair_accessible_entrance': true,
        'photos': [
          {
            'photo_reference': 'college-photo',
            'html_attributions': [
              '<a href="https://example.com/photographer">Campus photographer</a>'
            ]
          }
        ],
        'formatted_phone_number': '084 123 4567',
        'website': 'https://example.com/college',
      },
    }),
    200);

http.Response _roadRoute({bool stopsAtRoad = false}) => http.Response(
    jsonEncode({
      'code': 'Ok',
      'routes': [
        {
          'distance': 4200,
          'duration': 720,
          'geometry': {
            'coordinates': [
              [125.68191, 7.29937],
              [125.675, 7.305],
              [125.67020, stopsAtRoad ? 7.312683 : 7.31430],
            ]
          },
        }
      ],
    }),
    200);

void _mockLocation({bool denied = false}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('flutter.baseflow.com/geolocator');
  messenger.setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'isLocationServiceEnabled':
        return true;
      case 'checkPermission':
      case 'requestPermission':
        return denied ? 0 : 2;
      case 'getCurrentPosition':
        return {
          'latitude': _origin.latitude,
          'longitude': _origin.longitude,
          'timestamp': DateTime(2026).millisecondsSinceEpoch,
          'accuracy': 1.0,
          'altitude': 0.0,
          'heading': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
        };
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

Future<void> _tapCollege(WidgetTester tester, _TestMaps maps,
    {bool settle = true}) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    MapPlaceTaps.channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall('placeTapped', {
      'mapId': maps._created.single,
      'placeId': _collegeId,
      'name': _collegeName,
      'latitude': _collegePoint.latitude,
      'longitude': _collegePoint.longitude,
    })),
    (_) {},
  );
  if (settle) await tester.pumpAndSettle();
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

  testWidgets(
      'a visible map icon opens the explorer without choosing an account',
      (tester) async {
    _installTestMaps();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: const RoleSelectionScreen(successMessage: ''),
    ));
    await tester.pumpAndSettle();
    final shortcut = find.byTooltip('Explore map without an account');
    expect(shortcut.hitTestable(), findsOneWidget);
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(find.byType(LiveMapScreen), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).myLocationEnabled,
        isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Choose Your Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map search selects a place and keeps directions inside Todago',
      (tester) async {
    Uri? directions;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        directions = Uri.parse(call.arguments['url'] as String);
        return true;
      },
    );
    addTearDown(() => messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'), null));
    _mockLocation();
    await http.runWithClient(() async {
      final maps = await _openExplorer(tester);
      await tester.enterText(find.byType(TextField), 'Gaisano');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(ListTile, 'Gaisano'));
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers.single.position, const LatLng(7.3, 125.68));
      expect(
          maps.calls
              .lastWhere((call) => call.method == 'camera#animate')
              .arguments['cameraUpdate'],
          [
            'newLatLngZoom',
            [7.3, 125.68],
            16.0
          ]);
      expect(find.text('Panabo City'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      await tester.tap(find.text('Get Directions'));
      await tester.pumpAndSettle();
      expect(directions, isNull);
      expect(find.byType(LiveMapScreen), findsOneWidget);
      expect(find.text('From: Your location'), findsOneWidget);
      expect(find.text('To: Gaisano'), findsOneWidget);
      final routedMap = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(routedMap.polylines.single.points.length, 3);
      expect(
          routedMap.markers
              .firstWhere((m) => m.markerId.value == 'explore-origin')
              .position,
          _origin);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.host == 'router.project-osrm.org') {
                return _roadRoute();
              }
              if (request.url.path.contains('/directions/')) {
                expect(
                    request.url.queryParameters['destination'], '7.3,125.68');
                expect(
                    request.url.queryParameters['origin'], '7.29937,125.68191');
                return http.Response('{"status":"REQUEST_DENIED"}', 200);
              }
              expect(request.url.queryParameters.containsKey('components'),
                  isFalse);
              return _placeResponse('Gaisano');
            }));
  });

  testWidgets('tapping a native college POI loads real place fields and photos',
      (tester) async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      final maps = await _openExplorer(tester);
      await _tapCollege(tester, maps);
      expect(find.text(_collegeName), findsNWidgets(2));
      expect(find.text('Dropped pin'), findsNothing);
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text(' (115 reviews)'), findsOneWidget);
      expect(find.text('university · Closed now'), findsOneWidget);
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Image &&
              widget.semanticLabel == 'Photo of $_collegeName'),
          findsOneWidget);
      expect(find.text('Campus photographer'), findsOneWidget);
      expect(
          tester
              .widget<GoogleMap>(find.byType(GoogleMap))
              .markers
              .single
              .position,
          _collegePoint);
      expect(requests.single.queryParameters['place_id'], _collegeId);
      expect(requests.single.queryParameters['fields'], contains('rating'));
      expect(requests.single.queryParameters['fields'], contains('photos'));
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requests.add(request.url);
              return _collegeDetails();
            }));
  });

  testWidgets('college directions retain its place ID and exact coordinates',
      (tester) async {
    _mockLocation();
    Uri? routeRequest;
    Uri? fallbackRequest;
    await http.runWithClient(() async {
      final maps = await _openExplorer(tester);
      await _tapCollege(tester, maps);
      await tester.tap(find.text('Get Directions'));
      await tester.pumpAndSettle();
      expect(
          routeRequest?.queryParameters['destination'], 'place_id:$_collegeId');
      expect(routeRequest?.queryParameters['origin'], '7.29937,125.68191');
      expect(
          fallbackRequest?.path, contains('125.68191,7.29937;125.6702,7.3143'));
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.polylines.single.points.last, _collegePoint);
      expect(
          map.markers
              .firstWhere((m) => m.markerId.value == 'explore-place')
              .position,
          _collegePoint);
      expect(find.text('To: $_collegeName'), findsOneWidget);
      expect(find.textContaining('4.2 km'), findsOneWidget);
      expect(
          maps.calls
              .lastWhere((c) => c.method == 'camera#animate')
              .arguments['cameraUpdate'][0],
          'newLatLngBounds');
      await tester.tap(find.byTooltip('Close directions'));
      await tester.pumpAndSettle();
      expect(find.text('4.7'), findsOneWidget);
      expect(
          tester.widget<GoogleMap>(find.byType(GoogleMap)).polylines, isEmpty);
      await tester.tap(find.byTooltip('Close place'));
      await tester.pumpAndSettle();
      expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).markers, isEmpty);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/details/')) {
                return _collegeDetails();
              }
              if (request.url.host == 'router.project-osrm.org') {
                fallbackRequest = request.url;
                return _roadRoute();
              }
              routeRequest = request.url;
              return http.Response('{"status":"REQUEST_DENIED"}', 200);
            }));
  });

  testWidgets('a road endpoint never replaces the selected campus pin',
      (tester) async {
    _mockLocation();
    await http.runWithClient(() async {
      final maps = await _openExplorer(tester);
      await _tapCollege(tester, maps);
      await tester.tap(find.text('Get Directions'));
      await tester.pumpAndSettle();
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(
          map.markers
              .firstWhere((m) => m.markerId.value == 'explore-place')
              .position,
          _collegePoint);
      expect(
          map.polylines.single.points.last, const LatLng(7.312683, 125.67020));
      expect(find.textContaining('Check the entrance and final access'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/details/')) {
                return _collegeDetails();
              }
              if (request.url.host == 'router.project-osrm.org') {
                return _roadRoute(stopsAtRoad: true);
              }
              return http.Response('{"status":"REQUEST_DENIED"}', 200);
            }));
  });

  test('Google routes preserve the place ID and decode road geometry',
      () async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      final route = await MapService.fetchRoute(_origin, _collegePoint,
          destinationPlaceId: _collegeId, allowEstimate: false);
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['destination'],
          'place_id:$_collegeId');
      expect(route?.points,
          [_origin, const LatLng(7.305, 125.675), _collegePoint]);
      expect(route?.distanceKm, 4.2);
      expect(route?.etaMinutes, 15);
      expect(route?.destinationOffsetMeters, closeTo(0, 0.1));
    },
        () => MockClient((request) async {
              requests.add(request.url);
              return http.Response(
                  jsonEncode({
                    'status': 'OK',
                    'routes': [
                      {
                        'overview_polyline': {
                          'points': r'atpk@}fb~Veb@dj@cy@~\'
                        },
                        'legs': [
                          {
                            'distance': {'value': 4200, 'text': '4.2 km'},
                            'duration': {'value': 720},
                            'duration_in_traffic': {'value': 840},
                          }
                        ],
                      }
                    ],
                  }),
                  200);
            }));
  });

  testWidgets(
      'directions with location denied show recovery without inventing an origin',
      (tester) async {
    _mockLocation(denied: true);
    var routeCalls = 0;
    await http.runWithClient(() async {
      final maps = await _openExplorer(tester);
      await _tapCollege(tester, maps);
      await tester.tap(find.text('Get Directions'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Your location is unavailable'), findsOneWidget);
      expect(find.text('Retry directions'), findsOneWidget);
      expect(find.byType(LiveMapScreen), findsOneWidget);
      expect(routeCalls, 0);
      expect(
          tester.widget<GoogleMap>(find.byType(GoogleMap)).polylines, isEmpty);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/directions/') ||
                  request.url.host == 'router.project-osrm.org') {
                routeCalls++;
              }
              return _collegeDetails();
            }));
  });

  testWidgets('failed routing never draws a straight line as road directions',
      (tester) async {
    _mockLocation();
    await http.runWithClient(() async {
      final maps = await _openExplorer(tester);
      await _tapCollege(tester, maps);
      await tester.tap(find.text('Get Directions'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No road route is available'), findsOneWidget);
      expect(
          tester.widget<GoogleMap>(find.byType(GoogleMap)).polylines, isEmpty);
      expect(find.byType(LiveMapScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async =>
            request.url.path.contains('/details/')
                ? _collegeDetails()
                : http.Response('{}', 503)));
  });

  testWidgets('an unavailable Places API preserves the native college identity',
      (tester) async {
    await http.runWithClient(() async {
      final maps = await _openExplorer(tester);
      await _tapCollege(tester, maps);
      expect(find.text(_collegeName), findsNWidgets(2));
      expect(find.textContaining('Place information is unavailable'),
          findsOneWidget);
      expect(find.text('4.7'), findsNothing);
      expect(
          tester
              .widget<GoogleMap>(find.byType(GoogleMap))
              .markers
              .single
              .position,
          _collegePoint);
      expect(find.text('Get Directions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient(
            (_) async => http.Response('{"status":"REQUEST_DENIED"}', 200)));
  });

  testWidgets('late place details cannot replace a newer pin', (tester) async {
    final details = Completer<http.Response>();
    await http.runWithClient(() async {
      final maps = await _openExplorer(tester);
      // Deliver the native event without waiting for the pending HTTP response.
      await _tapCollege(tester, maps, settle: false);
      await tester.pump();
      tester
          .widget<GoogleMap>(find.byType(GoogleMap))
          .onLongPress!(const LatLng(7.32, 125.70));
      await tester.pump();
      details.complete(_collegeDetails());
      await tester.pumpAndSettle();
      expect(find.text('Dropped pin'), findsOneWidget);
      expect(find.text(_collegeName), findsNothing);
      expect(
          tester
              .widget<GoogleMap>(find.byType(GoogleMap))
              .markers
              .single
              .position,
          const LatLng(7.32, 125.70));
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async =>
            request.url.path.contains('/details/')
                ? await details.future
                : http.Response('{"status":"ZERO_RESULTS"}', 200)));
  });

  testWidgets('late directions cannot overwrite a newer destination',
      (tester) async {
    _mockLocation();
    final route = Completer<http.Response>();
    await http.runWithClient(() async {
      final maps = await _openExplorer(tester);
      await _tapCollege(tester, maps);
      await tester.tap(find.text('Get Directions'));
      await tester.pump();
      tester
          .widget<GoogleMap>(find.byType(GoogleMap))
          .onLongPress!(const LatLng(7.32, 125.70));
      await tester.pump();
      route.complete(_roadRoute());
      await tester.pumpAndSettle();
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.polylines, isEmpty);
      expect(map.markers.single.position, const LatLng(7.32, 125.70));
      expect(find.text('Dropped pin'), findsOneWidget);
      expect(find.text('Close directions'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/details/')) {
                return _collegeDetails();
              }
              if (request.url.host == 'router.project-osrm.org') {
                return route.future;
              }
              return http.Response('{"status":"ZERO_RESULTS"}', 200);
            }));
  });

  testWidgets('map search ignores old responses and clears results',
      (tester) async {
    final oldSearch = Completer<http.Response>();
    final newSearch = Completer<http.Response>();
    await http.runWithClient(() async {
      await _openExplorer(tester);
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
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) =>
            request.url.queryParameters['input'] == 'Old place'
                ? oldSearch.future
                : newSearch.future));
  });

  testWidgets('failed map lookup keeps the explorer open and allows pinning',
      (tester) async {
    await http.runWithClient(() async {
      await _openExplorer(tester);
      await tester.enterText(find.byType(TextField), 'Unknown');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Unknown place'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Could not locate this place'), findsOneWidget);
      tester
          .widget<GoogleMap>(find.byType(GoogleMap))
          .onTap!(const LatLng(7.31234, 125.69123));
      await tester.pumpAndSettle();
      expect(find.text('Dropped pin'), findsOneWidget);
      expect(find.text('7.31234, 125.69123'), findsOneWidget);
      expect(
          tester
              .widget<GoogleMap>(find.byType(GoogleMap))
              .markers
              .single
              .position,
          const LatLng(7.31234, 125.69123));
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async =>
            request.url.path.contains('autocomplete')
                ? _placeResponse('Unknown place', id: 'missing')
                : http.Response('{"status":"NOT_FOUND"}', 200)));
  });

  testWidgets('a slow address lookup cannot overwrite a newer map pin',
      (tester) async {
    final oldAddress = Completer<http.Response>();
    final newAddress = Completer<http.Response>();
    await http.runWithClient(() async {
      await _openExplorer(tester);
      tester
          .widget<GoogleMap>(find.byType(GoogleMap))
          .onTap!(const LatLng(7.31, 125.69));
      await tester.pump();
      tester
          .widget<GoogleMap>(find.byType(GoogleMap))
          .onLongPress!(const LatLng(7.32, 125.70));
      await tester.pump();
      newAddress.complete(http.Response(
          '{"results":[{"formatted_address":"New address"}]}', 200));
      await tester.pumpAndSettle();
      oldAddress.complete(http.Response(
          '{"results":[{"formatted_address":"Old address"}]}', 200));
      await tester.pumpAndSettle();
      expect(find.text('New address'), findsOneWidget);
      expect(find.text('Old address'), findsNothing);
      await tester.tap(find.byTooltip('Close place'));
      await tester.pumpAndSettle();
      expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).markers, isEmpty);
    },
        () => MockClient((request) =>
            request.url.queryParameters['latlng'] == '7.31,125.69'
                ? oldAddress.future
                : newAddress.future));
  });

  testWidgets(
      'location denial leaves map browsing available with no initial prompt',
      (tester) async {
    final gpsCalls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    messenger.setMockMethodCallHandler(channel, (call) async {
      gpsCalls.add(call.method);
      return call.method == 'isLocationServiceEnabled' ? true : 0;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await _openExplorer(tester);
    expect(gpsCalls, isEmpty);
    await tester.tap(find.byTooltip('My location'));
    await tester.pumpAndSettle();
    expect(gpsCalls, contains('requestPermission'));
    expect(find.textContaining('Your location is unavailable'), findsOneWidget);
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).myLocationEnabled,
        isFalse);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map layers and traffic can be changed while browsing',
      (tester) async {
    await _openExplorer(tester);
    await tester.tap(find.byTooltip('Hide traffic'));
    await tester.pumpAndSettle();
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).trafficEnabled,
        isFalse);
    await tester.tap(find.byTooltip('Map layers'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.widgetWithText(CheckedPopupMenuItem<MapType>, 'Satellite'));
    await tester.pumpAndSettle();
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).mapType,
        MapType.hybrid);
    expect(tester.takeException(), isNull);
  });

  test('global fallback includes international places; ride search stays local',
      () async {
    await http.runWithClient(() async {
      final global = await MapService.searchPlaces('Singapore',
          restrictToPhilippines: false);
      expect(global.single.mainText, 'Singapore');
      expect(global.single.secondaryText, 'Singapore');
      expect(await MapService.getPlaceLatLng(global.single.placeId),
          const LatLng(1.28, 103.85));
      expect(await MapService.searchPlaces('Singapore'), isEmpty);
    },
        () => MockClient((request) async {
              if (request.url.host == 'maps.googleapis.com') {
                return http.Response('{"status":"ZERO_RESULTS"}', 200);
              }
              return http.Response(
                  jsonEncode({
                    'features': [
                      {
                        'properties': {
                          'name': 'Singapore',
                          'country': 'Singapore'
                        },
                        'geometry': {
                          'coordinates': [103.85, 1.28]
                        },
                      }
                    ],
                  }),
                  200);
            }));
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
