import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:google_fonts/src/google_fonts_descriptor.dart';
import 'package:google_fonts/src/google_fonts_family_with_variant.dart';
import 'package:google_fonts/src/google_fonts_variant.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todago/active_trip_driver_screen.dart';
import 'package:todago/driver_trip_history_screen.dart';
import 'package:todago/rate_driver_screen.dart';
import 'package:todago/rate_passenger_screen.dart';
import 'package:todago/report_issue_dialog.dart';

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
                GoogleFontsVariant(fontWeight: weight, fontStyle: style)),
  ];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  font_loader.assetManifest = _FontManifest([
    for (final variant in variants) '${variant.toApiFilenamePrefix()}.ttf',
  ]);
  messenger.setMockMessageHandler('flutter/assets', (_) async => ByteData(0));
  for (final variant in variants) {
    await font_loader.loadFontIfNecessary(GoogleFontsDescriptor(
        familyWithVariant: variant, file: GoogleFontsFile('', 0)));
  }
  messenger.setMockMessageHandler('flutter/assets', null);
  font_loader.assetManifest = null;
}

const _trip = {
  'trip_id': 'trip-1',
  'driver_id': 'driver-1',
  'commuter_id': 'passenger-1',
  'driver_name': 'Driver One',
  'commuter_name': 'Passenger One',
  'pickup_location': 'Panabo',
  'destination': 'Carmen',
  'fare': 60,
  'status': 'completed',
  'payment_status': 'paid',
  'request_timestamp': '2026-11-09T02:30:00Z',
};

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openDashboardReport(WidgetTester tester, String role) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
    builder: (context) => TextButton(
      onPressed: () =>
          showReportIssueDialog(context: context, reporterRole: role),
      child: const Text('Open report'),
    ),
  ))));
  await _tap(tester, 'Open report');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_prepareFonts);
  setUp(() {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (call) async => call.arguments['key'] == 'driver_auth_token'
                ? 'driver-token'
                : 'passenger-token');
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            null);
  });

  for (final role in ['driver', 'passenger']) {
    testWidgets(
        '$role dashboard reports require a selected trip and preserve it on a failed submission',
        (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reports = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        await _openDashboardReport(tester, role);
        await _tap(tester, 'Send to Admin');
        expect(reports, isEmpty);
        expect(find.text('Select the trip to identify the reported account.'),
            findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        final person = role == 'driver' ? 'Passenger One' : 'Driver One';
        await tester.tap(find.textContaining('$person ·').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Incident details');
        await _tap(tester, 'Send to Admin');
        expect(find.text('Please retry'), findsOneWidget);
        expect(find.text('Incident details'), findsOneWidget);
        expect(find.textContaining('$person ·'), findsOneWidget);
        await _tap(tester, 'Send to Admin');
        expect(reports, hasLength(2));
        for (final report in reports) {
          expect(report['tripId'], 'trip-1');
          expect(report['subjectId'],
              role == 'driver' ? 'passenger-1' : 'driver-1');
          expect(
              report['subjectRole'], role == 'driver' ? 'passenger' : 'driver');
          expect(report['details'], 'Incident details');
        }
        expect(find.text('Send to Admin'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((request) async {
                expect(request.headers['Authorization'], 'Bearer $role-token');
                if (request.method == 'GET') {
                  expect(request.url.path,
                      '/api/trips/${role == 'driver' ? 'driver' : 'commuter'}/history');
                  return http.Response(
                      jsonEncode({
                        'success': true,
                        'trips': [_trip]
                      }),
                      200);
                }
                reports.add(jsonDecode(request.body) as Map<String, dynamic>);
                return reports.length == 1
                    ? http.Response(
                        '{"success":false,"message":"Please retry"}', 500)
                    : http.Response(
                        '{"success":true,"message":"Sent to admin"}', 201);
              }));
    });
  }

  testWidgets(
      'driver can rate the passenger and report before or after rating without losing the trip',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var ratings = 0, reports = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: RatePassengerScreen(trip: _trip, earnings: 60)));
      await tester.pumpAndSettle();
      for (var step = 0; step < 2; step++) {
        await _tap(tester, 'Report Passenger');
        expect(find.text('Reported account: Passenger One'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        await _tap(tester, 'Send to Admin');
        if (step == 0) {
          await tester.tap(find.byTooltip('4 stars'));
          await tester.pumpAndSettle();
          await _tap(tester, 'Submit Rating');
          expect(find.text('Thanks for your feedback!'), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
          expect(find.byType(RatePassengerScreen), findsOneWidget);
        }
      }
      expect(ratings, 1);
      expect(reports, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer driver-token');
              if (request.method == 'GET') {
                return http.Response(
                    '{"success":true,"hasRated":false,"feedback":null}', 200);
              }
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              if (request.url.path.endsWith('/rate')) {
                expect(body['rating'], 4);
                ratings++;
              } else {
                expect(body['tripId'], 'trip-1');
                expect(body['subjectId'], 'passenger-1');
                reports++;
              }
              return http.Response('{"success":true,"message":"Saved"}', 201);
            }));
  });

  testWidgets(
      'passenger can report the driver before and after submitting a rating',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var ratings = 0, reports = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: RateDriverScreen(
              tripId: 'trip-1',
              driverName: 'Driver One',
              driverRating: 4,
              todaBodyNumber: '123',
              plateNo: 'ABC123',
              destination: 'Carmen',
              fare: 60)));
      await tester.pumpAndSettle();
      await _tap(tester, 'Report Driver');
      expect(find.text('Reported account: Driver One'), findsOneWidget);
      await _tap(tester, 'Send to Admin');
      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(4));
      await tester.pumpAndSettle();
      await _tap(tester, 'Submit Rating');
      expect(find.text('Thanks for your feedback!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(RateDriverScreen), findsOneWidget);
      await _tap(tester, 'Report Driver');
      await _tap(tester, 'Send to Admin');
      expect(ratings, 1);
      expect(reports, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              expect(
                  request.headers['Authorization'], 'Bearer passenger-token');
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              if (request.url.path.endsWith('/rate')) {
                expect(body['rating'], 5);
                ratings++;
              } else {
                expect(body['tripId'], 'trip-1');
                expect(body['subjectRole'], 'driver');
                reports++;
              }
              return http.Response('{"success":true,"message":"Saved"}', 201);
            }));
  });

  testWidgets('past driver trips keep report and rating actions for paid rides',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: DriverTripHistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Your passenger rating: 4/5'), findsOneWidget);
      expect(find.text('View Rating'), findsOneWidget);
      expect(find.text('Report Passenger'), findsOneWidget);
      expect(find.text('Unpaid Passenger'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async => http.Response(
            jsonEncode({
              'success': true,
              'trips': [
                {..._trip, 'passenger_rating_score': 4},
                {
                  ..._trip,
                  'trip_id': 'trip-unpaid',
                  'payment_status': 'unpaid',
                  'commuter_name': 'Unpaid Passenger'
                },
              ],
            }),
            200)));
  });

  for (final completion in ['collection', 'polling']) {
    testWidgets(
        'driver reaches feedback after confirmed payment through $completion',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const location = MethodChannel('flutter.baseflow.com/geolocator');
      const updates = MethodChannel('flutter.baseflow.com/geolocator_updates');
      messenger.setMockMethodCallHandler(location, (_) async => false);
      messenger.setMockMethodCallHandler(updates, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(location, null);
        messenger.setMockMethodCallHandler(updates, null);
      });
      var collections = 0;
      await http.runWithClient(() async {
        final activeTrip = {
          ..._trip,
          'status': 'arrived',
          'payment_status': 'unpaid',
          'payment_method': 'cash'
        };
        await tester.pumpWidget(MaterialApp(
            home: ActiveTripDriverScreen(trip: activeTrip)));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(RatePassengerScreen), findsNothing);
        if (completion == 'collection') {
          await tester.ensureVisible(find.text('Collect Payment'));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(find.text('Collect Payment'));
        } else {
          await tester.pump(const Duration(seconds: 5));
        }
        await tester.pumpAndSettle();
        expect(find.byType(RatePassengerScreen), findsOneWidget);
        expect(find.text('Report Passenger'), findsOneWidget);
        expect(find.text('Submit Rating'), findsOneWidget);
        expect(collections, completion == 'collection' ? 1 : 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/payment/collect')) {
                  collections++;
                  return http.Response(
                      '{"success":true,"earnings":{"your_earnings":60}}', 200);
                }
                if (request.url.path.endsWith('/rating')) {
                  return http.Response(
                      '{"success":true,"hasRated":false,"feedback":null}', 200);
                }
                return http.Response(
                    jsonEncode({'success': true, 'trip': _trip}), 200);
              }));
    });
  }
}
