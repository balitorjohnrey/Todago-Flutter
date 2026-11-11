import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todago/admin_dashboard_screen.dart';
import 'package:todago/admin_monitoring_screens.dart';
import 'package:todago/app_theme.dart';
import 'package:todago/operator_dashboard_screen.dart';
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

Future<void> _open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1000);
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
                  'drivers': [_driver]
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
              return _fallback(request);
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
      expect(find.text('7.310000, 125.670000'), findsOneWidget);
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
