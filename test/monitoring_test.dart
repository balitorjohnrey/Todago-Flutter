import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todago/admin_dashboard_screen.dart';
import 'package:todago/admin_monitoring_screens.dart';
import 'package:todago/app_theme.dart';
import 'package:todago/driver_alerts.dart';
import 'package:todago/driver_dashboard_screen.dart';
import 'package:todago/operator_dashboard_screen.dart';
import 'package:todago/operator_drivers_screen.dart';
import 'package:todago/passenger_home_screen.dart';
import 'package:todago/splash_screen.dart';
import 'package:todago/trip_message_screens.dart';
import 'package:todago/trip_service.dart';
import 'support/test_fonts.dart';

class _TestMaps extends MethodChannelGoogleMapsFlutter {
  final _created = <int>{};
  @override
  Future<void> updateGroundOverlays(GroundOverlayUpdates updates,
      {required int mapId}) async {}
  @override
  Widget buildViewWithConfiguration(
      int creationId, PlatformViewCreatedCallback onCreated,
      {required MapWidgetConfiguration widgetConfiguration,
      MapConfiguration mapConfiguration = const MapConfiguration(),
      MapObjects mapObjects = const MapObjects()}) {
    if (_created.add(creationId)) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              MethodChannel('plugins.flutter.io/google_maps_$creationId'),
              (_) async => null);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onCreated(creationId));
    }
    return const SizedBox.expand();
  }
}

const _driver = {
  'driver_id': 'driver-1',
  'driver_name': 'Driver One',
  'avg_rating': 4.9,
  'rating_count': 8,
  'total_trips': 12,
  'toda_body_number': 'T-1'
};
const _charge = {
  'charge_id': 'charge-1',
  'trip_id': 'trip-1',
  'driver_name': 'Driver One',
  'passenger_name': 'Passenger One',
  'label': 'Tip',
  'amount': '12.50',
  'base_fare': '17.00',
  'total_fare': '29.50',
  'intent_confirmed': true,
  'trip_status': 'completed',
  'payment_status': 'paid',
  'added_at': '2026-11-11T01:00:00Z'
};

http.Response _response(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'success': true, ...data}), 200);
http.Response _fallback(http.Request request) => _response({
      'stats': {},
      'drivers': [],
      'routes': [],
      'hours': [],
      'settings': {},
      'reports': [],
      'operator': {
        'association_name': 'Fleet One',
        'association_code': 'ONE',
        'toda_verified': true
      },
    });

Future<void> _open(WidgetTester tester, Widget screen,
    {Size size = const Size(800, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: screen));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareTestFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({
        'admin_auth_token': 'admin-token',
        'operator_auth_token': 'operator-token',
        'driver_auth_token': 'driver-token',
      }));

  testWidgets(
      'admin sees ranked drivers and per-trip itemized charges with pagination',
      (tester) async {
    final queries = <Map<String, String>>[];
    await http.runWithClient(() async {
      await _open(tester, const AdminDashboardScreen());
      await _tap(tester, 'Analytics');
      expect(find.text('Top Rated Drivers'), findsOneWidget);
      expect(find.text('4.90 / 5'), findsOneWidget);
      expect(find.text('12 completed trips'), findsOneWidget);
      await _tap(tester, 'Driver Two');
      expect(find.text('Driver profile'), findsOneWidget);
      expect(find.text('09170000002'), findsOneWidget);
      expect(find.text('PLATE-2'), findsOneWidget);
      await tester.tap(find.byTooltip('Close profile'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Fares');
      await _tap(tester, 'Trip Additional Charges');
      expect(find.byType(TripChargesScreen), findsOneWidget);
      expect(find.text('Base fare'), findsOneWidget);
      expect(find.text('PHP 29.50'), findsOneWidget);
      expect(find.text('Intentionally added by the passenger at booking.'),
          findsOneWidget);
      await _tap(tester, 'Load more charges');
      expect(find.text('Trip: trip-2'), findsOneWidget);
      expect(queries.last['offset'], '25');
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tip').last);
      await tester.pumpAndSettle();
      expect(queries.last['label'], 'Tip');
      expect(queries.last['offset'], '0');
      expect(find.text('Trip: trip-2'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/monitoring/drivers')) {
                expect(request.headers['Authorization'], 'Bearer admin-token');
                return _response({
                  'drivers': [
                    _driver,
                    {
                      ..._driver,
                      'driver_id': 'driver-2',
                      'driver_name': 'Driver Two',
                      'rating_count': 0,
                      'total_trips': 0,
                    }
                  ]
                });
              }
              if (request.url.path ==
                  '/api/admin/monitoring/drivers/driver-2') {
                expect(request.headers['Authorization'], 'Bearer admin-token');
                return _response({
                  'driver': {
                    'driver_name': 'Driver Two',
                    'phone': '09170000002',
                    'plate_no': 'PLATE-2',
                  }
                });
              }
              if (request.url.path.endsWith('/monitoring/charges')) {
                queries.add(request.url.queryParameters);
                final more = request.url.queryParameters['offset'] == '25';
                return _response({
                  'charges': [
                    if (!more)
                      _charge
                    else
                      {..._charge, 'trip_id': 'trip-2', 'label': 'Others'}
                  ],
                  'summary': {
                    'charge_count': 2,
                    'total_amount': '25.00',
                    'tip_amount': '12.50'
                  },
                  'has_more': !more,
                  'next_offset': more ? 50 : 25
                });
              }
              return _fallback(request);
            }));
  });

  testWidgets(
      'operator dashboard uses its own authenticated performance endpoint',
      (tester) async {
    var performanceRequests = 0;
    await http.runWithClient(() async {
      await _open(tester, const OperatorDashboardScreen());
      expect(find.text('Top Rated Drivers'), findsOneWidget);
      expect(find.text('Driver One'), findsOneWidget);
      expect(find.text('8 ratings'), findsOneWidget);
      await _tap(tester, 'Driver One');
      expect(find.text('Driver profile'), findsOneWidget);
      expect(find.text('Fleet One'), findsWidgets);
      await tester.tap(find.byTooltip('Close profile'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(performanceRequests, greaterThanOrEqualTo(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/analytics/drivers')) {
                performanceRequests++;
                expect(request.url.path, '/api/operator/analytics/drivers');
                expect(
                    request.headers['Authorization'], 'Bearer operator-token');
                return _response({
                  'drivers': [_driver]
                });
              }
              if (request.url.path ==
                  '/api/operator/analytics/drivers/driver-1') {
                expect(
                    request.headers['Authorization'], 'Bearer operator-token');
                return _response({
                  'driver': {
                    ..._driver,
                    'association_name': 'Fleet One',
                    'is_verified': true
                  }
                });
              }
              return _fallback(request);
            }));
  });

  testWidgets(
      'operator menu opens on a phone and logout requires confirmation',
      (tester) async {
    const storage = FlutterSecureStorage();
    FlutterSecureStorage.setMockInitialValues({
      'operator_auth_token': 'operator-token',
    });
    await http.runWithClient(() async {
      await _open(tester, const OperatorDashboardScreen(),
          size: const Size(390, 844));
      final menu = find.byTooltip('Open operator menu');
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final drawer = find.byType(Drawer);
      expect(drawer, findsOneWidget);

      await tester.tap(find.descendant(
          of: drawer, matching: find.text('Driver Management')));
      await tester.pumpAndSettle();
      expect(find.byType(OperatorDriversScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded));
      await tester.pumpAndSettle();

      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: drawer, matching: find.text('Log out')));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await _tap(tester, 'Cancel');
      expect(await storage.read(key: 'operator_auth_token'), 'operator-token');
      expect(find.byType(OperatorDashboardScreen), findsOneWidget);

      await _tap(tester, 'Log out');
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Log out')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(await storage.read(key: 'operator_auth_token'), isNull);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(OperatorDashboardScreen), findsNothing);
    }, () => MockClient((request) async => _fallback(request)));
  });

  testWidgets(
      'passenger Messages opens saved trip chat and retries a failed send',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(
        {'auth_token': 'passenger-token'});
    final previousMaps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = _TestMaps();
    const gps = MethodChannel('flutter.baseflow.com/geolocator');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(gps,
        (call) async => call.method == 'isLocationServiceEnabled' ? true : 0);
    addTearDown(() {
      messenger.setMockMethodCallHandler(gps, null);
      GoogleMapsFlutterPlatform.instance = previousMaps;
    });
    final requestIds = <String>[];
    const conversation = {
      'trip_id': 'trip-1',
      'peer_name': 'Driver One',
      'destination': 'Panabo Public Market',
      'activity_at': '2026-11-11T04:00:00Z',
    };
    var closed = false;
    var driverReplied = false;
    await http.runWithClient(() async {
      await _open(tester, const PassengerHomeScreen(),
          size: const Size(360, 800));
      expect(find.text('FAQ Chatbot'), findsOneWidget);
      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();
      expect(find.byType(TripInboxScreen), findsOneWidget);
      await _tap(tester, 'Driver One');
      expect(find.text('No messages yet'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Meet me at the gate.');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(requestIds.length, 1);
      expect(
          find.text('Could not send the message. Try again.'), findsOneWidget);
      expect(find.text('Meet me at the gate.'), findsOneWidget);

      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(requestIds.length, 2);
      expect(requestIds.toSet().length, 1);
      expect(find.text('Meet me at the gate.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);

      driverReplied = true;
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('I am on my way.'), findsOneWidget);
      closed = true;
      await tester.tap(find.byTooltip('Refresh messages'));
      await tester.pumpAndSettle();
      expect(find.text('This trip conversation is closed.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Meet me at the gate.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              switch (request.url.path) {
                case '/api/trips/conversations':
                  expect(request.headers['Authorization'],
                      'Bearer passenger-token');
                  return _response({
                    'conversations': [conversation]
                  });
                case '/api/trips/trip-1/messages':
                  expect(request.headers['Authorization'],
                      'Bearer passenger-token');
                  if (request.method == 'POST') {
                    final body =
                        jsonDecode(request.body) as Map<String, dynamic>;
                    expect(body['message'], 'Meet me at the gate.');
                    requestIds.add(body['requestId'] as String);
                    return requestIds.length == 1
                        ? http.Response('{}', 503)
                        : _response({});
                  }
                  return _response({
                    'conversation': {...conversation, 'can_send': !closed},
                    'messages': [
                      if (driverReplied)
                        {
                          'message_id': '2',
                          'sender_role': 'driver',
                          'body': 'I am on my way.',
                          'created_at': '2026-11-11T04:01:00Z',
                        },
                      if (requestIds.length > 1)
                        {
                          'message_id': '1',
                          'sender_role': 'passenger',
                          'body': 'Meet me at the gate.',
                          'created_at': '2026-11-11T04:00:00Z',
                        },
                    ],
                  });
                default:
                  return _response({
                    'trips': [],
                    'wallet': {'balance': 0}
                  });
              }
            }));
  });

  testWidgets(
      'new GPS alerts appear automatically with coordinates and open the matching log',
      (tester) async {
    final previousMaps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = _TestMaps();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = previousMaps);
    var reportRequests = 0;
    await http.runWithClient(() async {
      await _open(tester, const AdminDashboardScreen());
      expect(find.text('1 GPS alert'), findsNothing);
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('1 GPS alert'), findsOneWidget);
      expect(find.text('Location: 7.31, 125.67'), findsOneWidget);
      expect(find.textContaining('GPS alert: Driver One'), findsOneWidget);
      await _tap(tester, 'View location and GPS log');
      expect(find.byType(GpsActivityScreen), findsOneWidget);
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers.single.position, const LatLng(7.31, 125.67));
      expect(find.widgetWithText(SelectableText, '7.310000, 125.670000'),
          findsOneWidget);
      expect(find.textContaining('Outside designated route'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/admin/reports')) {
                reportRequests++;
                return _response({
                  'reports': [
                    if (reportRequests > 1)
                      {
                        'issue_id': 'gps-1',
                        'report_type': 'driver_route_deviation',
                        'reporter_role': 'system',
                        'title': 'Driver outside designated route',
                        'subject_name': 'Driver One',
                        'subject_id': 'driver-1',
                        'trip_id': 'trip-1',
                        'priority': 'high',
                        'metadata': {
                          'lat': 7.31,
                          'lng': 125.67,
                          'observed_at': '2026-11-11T01:00:00Z'
                        },
                      }
                  ]
                });
              }
              if (request.url.path.endsWith('/monitoring/gps')) {
                expect(request.url.queryParameters['driverId'], 'driver-1');
                expect(request.url.queryParameters['tripId'], 'trip-1');
                expect(request.headers['Authorization'], 'Bearer admin-token');
                return _response({
                  'locations': [
                    {
                      'location_id': 'gps-location',
                      'driver_name': 'Driver One',
                      'latitude': 7.31,
                      'longitude': 125.67,
                      'route_deviation': true,
                      'within_service_area': true,
                      'route_distance_m': 1100,
                      'observed_at': '2026-11-11T01:00:00Z'
                    }
                  ],
                  'has_more': false
                });
              }
              return _fallback(request);
            }));
  });

  testWidgets('a Tagum GPS entry is red and opens a message to its driver',
      (tester) async {
    final previousMaps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = _TestMaps();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = previousMaps);
    final sends = <Map<String, dynamic>>[];
    const message = 'Please return to Panabo City or Carmen.';
    await http.runWithClient(() async {
      await _open(tester, const GpsActivityScreen(),
          size: const Size(360, 800));
      final row = find.widgetWithText(ListTile, 'Driver One · PLATE-1');
      expect(
        tester
            .widget<Icon>(find.descendant(
              of: row,
              matching: find.byIcon(Icons.warning_amber_rounded),
            ))
            .color,
        const Color(0xFFB42318),
      );
      await _tap(tester, 'Driver One · PLATE-1');
      expect(find.text('GPS update details'), findsOneWidget);
      expect(find.text('Panabo City and Carmen'), findsOneWidget);
      expect(find.text('Fleet One'), findsOneWidget);
      await _tap(tester, 'Message driver');
      expect(find.text('To: Driver One'), findsOneWidget);
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).controller!.text,
          contains('outside the TodaGo service area'));
      await tester.enterText(field, message);
      await _tap(tester, 'Send message');
      expect(find.text('Unable to send the message. Please retry.'),
          findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, message);
      await _tap(tester, 'Send message');
      expect(find.text('Message sent to Driver One.'), findsOneWidget);
      expect(sends, hasLength(2));
      expect(sends.last, sends.first);
      expect(sends.first['message'], message);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer admin-token');
              if (request.method == 'POST') {
                expect(request.url.path,
                    '/api/admin/monitoring/gps/tagum-1/messages');
                sends.add(jsonDecode(request.body) as Map<String, dynamic>);
                return sends.length == 1
                    ? http.Response('{}', 503)
                    : _response({});
              }
              return _response({
                'locations': [
                  {
                    'location_id': 'tagum-1',
                    'driver_name': 'Driver One',
                    'plate_no': 'PLATE-1',
                    'toda_body_number': 'T-1',
                    'association_name': 'Fleet One',
                    'latitude': 7.456748,
                    'longitude': 125.795412,
                    'source': 'online_driver_location',
                    'observed_at': '2026-11-11T03:53:52Z',
                    'within_service_area': false,
                    'allowed_service_areas': ['Panabo City', 'Carmen'],
                    'can_message_driver': true,
                  }
                ],
                'has_more': false,
              });
            }));
  });

  testWidgets(
      'going online in Tagum warns the driver and admin messages appear in the inbox',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const location = MethodChannel('flutter.baseflow.com/geolocator');
    const locationUpdates =
        MethodChannel('flutter.baseflow.com/geolocator_updates');
    const notifications =
        MethodChannel('dexterous.com/flutter/local_notifications');
    final messenger = tester.binding.defaultBinaryMessenger;
    final notificationTitles = <String>[];
    messenger.setMockMethodCallHandler(
        location,
        (call) async => switch (call.method) {
              'isLocationServiceEnabled' => true,
              'checkPermission' => 2,
              'getCurrentPosition' => {
                  'latitude': 7.456748,
                  'longitude': 125.795412,
                  'timestamp': DateTime(2026).millisecondsSinceEpoch,
                  'accuracy': 5.0,
                },
              _ => null,
            });
    messenger.setMockMethodCallHandler(locationUpdates, (_) async => null);
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'show')
        notificationTitles.add(call.arguments['title'] as String);
      return null;
    });
    addTearDown(() {
      DriverAlerts.clearServiceArea();
      for (final channel in [location, locationUpdates, notifications]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });

    var online = false;
    var withinArea = false;
    var sample = 0;
    var sent = false;
    var read = false;
    const message = 'Please return to Panabo City or Carmen.';
    final area = () => {
          'within_service_area': withinArea,
          'allowed_service_areas': ['Panabo City', 'Carmen'],
          'observed_at':
              DateTime.utc(2026, 11, 11, 4, 0, sample++).toIso8601String(),
        };
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.theme, home: const DriverDashboardScreen()));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('GO ONLINE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final warning =
          find.textContaining('Outside service area', findRichText: true);
      expect(warning, findsOneWidget);
      expect(find.textContaining('Panabo City or Carmen', findRichText: true),
          findsOneWidget);
      expect(notificationTitles, ['Outside service area']);

      await TripService.updateOnlineDriverLocation(
          const LatLng(7.456748, 125.795412));
      await tester.pump();
      expect(notificationTitles, ['Outside service area']);
      withinArea = true;
      await TripService.updateOnlineDriverLocation(
          const LatLng(7.3209196, 125.670569));
      await tester.pump();
      expect(warning, findsNothing);

      sent = true;
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(notificationTitles,
          ['Outside service area', 'Message from TodaGo Admin']);
      await tester.tap(find.text('Admin messages · New'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('TodaGo Admin · New'), findsOneWidget);
      await tester.tap(find.text('TodaGo Admin · New'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.widgetWithText(SelectableText, message), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(read, true);
      expect(find.text('TodaGo Admin · New'), findsNothing);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('FAQ Chatbot'), findsOneWidget);
      await tester.tap(find.byTooltip('Messages'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Passenger One'), findsOneWidget);
      expect(find.text('Meet me at the gate.'), findsOneWidget);
      await tester.tap(find.text('Passenger One'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(TripConversationScreen), findsOneWidget);
      expect(find.text('This trip conversation is closed.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              switch (request.url.path) {
                case '/api/driver/status':
                  final body = jsonDecode(request.body);
                  expect(body['status'], 'online');
                  expect(body['lat'], 7.456748);
                  expect(body['lng'], 125.795412);
                  online = true;
                  return _response({'service_area': area()});
                case '/api/driver/location':
                  return _response({'service_area': area()});
                case '/api/driver/me':
                  return _response({
                    'driver': {'driver_name': 'Driver One', 'status': 'offline'}
                  });
                case '/api/driver/stats/today':
                  return _response({
                    'stats': {'status': online ? 'online' : 'offline'}
                  });
                case '/api/driver/messages':
                  expect(
                      request.headers['Authorization'], 'Bearer driver-token');
                  return _response({
                    'messages': [
                      if (sent)
                        {
                          'message_id': 'test-admin-message',
                          'body': message,
                          'created_at': '2026-11-11T04:00:00Z',
                          'read_at': read ? '2026-11-11T04:00:20Z' : null,
                        },
                    ]
                  });
                case '/api/driver/messages/test-admin-message/read':
                  expect(request.method, 'PATCH');
                  expect(
                      request.headers['Authorization'], 'Bearer driver-token');
                  read = true;
                  return _response({});
                case '/api/trips/conversations':
                  expect(
                      request.headers['Authorization'], 'Bearer driver-token');
                  return _response({
                    'conversations': [
                      {
                        'trip_id': 'trip-1',
                        'peer_name': 'Passenger One',
                        'last_message': 'Meet me at the gate.',
                      }
                    ],
                  });
                case '/api/trips/trip-1/messages':
                  expect(
                      request.headers['Authorization'], 'Bearer driver-token');
                  return _response({
                    'conversation': {
                      'peer_name': 'Passenger One',
                      'can_send': false
                    },
                    'messages': [
                      {
                        'message_id': '1',
                        'sender_role': 'passenger',
                        'body': 'Meet me at the gate.',
                      }
                    ],
                  });
                default:
                  return _fallback(request);
              }
            }));
  });

  testWidgets(
      'charge loading failures show a retryable error instead of an empty success',
      (tester) async {
    var unavailable = true;
    await http.runWithClient(() async {
      await _open(tester, const TripChargesScreen());
      expect(find.text('Unable to load charges. Refresh to try again.'),
          findsOneWidget);
      expect(find.text('No additional charges in this period.'), findsNothing);
      unavailable = false;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Trip: trip-1'), findsOneWidget);
      expect(find.text('Unable to load charges. Refresh to try again.'),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((_) async => unavailable
            ? http.Response('{}', 503)
            : _response({
                'charges': [_charge],
                'summary': {},
                'has_more': false
              })));
  });
}
