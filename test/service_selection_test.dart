import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todago/app_theme.dart';
import 'package:todago/driver_selection_screen.dart';
import 'package:todago/service_selection_screen.dart';
import 'package:todago/ride_request_screen.dart';
import 'package:todago/rate_driver_screen.dart';
import 'support/test_fonts.dart';

http.Response _response(Map<String, dynamic> data) =>
    http.Response(jsonEncode(data), 200);

MockClient _client({ValueChanged<Map<String, dynamic>>? onBooking}) =>
    MockClient((request) async {
      if (request.url.path.endsWith('/request')) {
        onBooking?.call(jsonDecode(request.body) as Map<String, dynamic>);
        return _response(
            {'success': false, 'message': 'Test request captured'});
      }
      if (request.url.path.endsWith('/settings')) {
        return _response({'success': true, 'settings': {}});
      }
      return _response({
        'success': true,
        'drivers': [
          {'driver_id': 'driver-1', 'driver_name': 'Test Driver'}
        ],
      });
    });

Future<void> _openServices(WidgetTester tester) async {
  // Leave room for the test engine's wide placeholder font glyphs.
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: const ServiceSelectionScreen(distanceKm: 2),
  ));
  await tester.pumpAndSettle();
}

Future<void> _selectOption(
    WidgetTester tester, String fieldLabel, String option) async {
  final dropdown =
      find.widgetWithText(DropdownButtonFormField<String>, fieldLabel);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _findDriver(WidgetTester tester) async {
  await tester.tap(find.text('Find a Driver'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareTestFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('fare type highlights the matching rate and books Pregnant fare',
      (tester) async {
    Map<String, dynamic>? booking;
    await http.runWithClient(() async {
      await _openServices(tester);
      final regular = find.bySemanticsLabel('Regular base fare');
      final discounted = find.bySemanticsLabel('Discounted base fare');

      void expectSelectedRate({required bool discount}) {
        expect(tester.getSemantics(regular),
            isSemantics(value: 'PHP 17', isSelected: !discount));
        expect(tester.getSemantics(discounted),
            isSemantics(value: 'PHP 15', isSelected: discount));
      }

      expectSelectedRate(discount: false);
      for (final option in ['PWD', 'Student', 'Senior', 'Pregnant']) {
        await _selectOption(tester, 'Fare Type', option);
        expectSelectedRate(discount: true);
      }
      await _selectOption(tester, 'Fare Type', 'Regular');
      expectSelectedRate(discount: false);

      await _selectOption(tester, 'Fare Type', 'Pregnant');
      await _findDriver(tester);
      expect(find.text('Pregnant'), findsOneWidget);
      expect(find.text('PHP 15'), findsOneWidget);
      final confirm = find.text('Confirm Driver & Start Ride');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(booking?['passengerFareType'], 'pregnant');
      expect(booking?['fare'], 15);
      await tester.pumpWidget(const SizedBox());
    }, () => _client(onBooking: (value) => booking = value));
  });

  testWidgets(
      'driver breakdown and completed ride summary preserve the itemized fare',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: RideRequestScreen(
          trip: const {
            'fare': '29.50',
            'other_fee_amount': '12.50',
            'other_fee_label': 'Tip'
          },
          onAccept: () async {},
          onDecline: () async {},
        )));
    await tester.pumpAndSettle();
    expect(find.text('Base fare'), findsOneWidget);
    expect(find.text('PHP 17.00'), findsOneWidget);
    expect(find.text('PHP 12.50'), findsOneWidget);
    expect(find.text('₱29.50'), findsOneWidget);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.theme,
          home: const RateDriverScreen(
            tripId: 'trip-1',
            driverName: 'Driver',
            driverRating: 4.9,
            todaBodyNumber: 'T-1',
            plateNo: 'PLATE',
            destination: 'Destination',
            fare: 29.5,
          )));
      await tester.pumpAndSettle();
      expect(find.text('PHP 29.50'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient(
            (_) async => _response({'success': true, 'hasRated': false})));
  });

  testWidgets('optional tip keeps its label and exact amount through booking',
      (tester) async {
    Map<String, dynamic>? booking;
    await http.runWithClient(() async {
      await _openServices(tester);
      await _selectOption(tester, 'Charge type', 'Tip');
      final amount = find.widgetWithText(TextField, 'Amount');
      expect(tester.widget<TextField>(amount).controller!.text, isEmpty);
      expect(find.text('Added to fare: Tip - PHP 0'), findsNothing);

      await tester.enterText(amount, '12.50');
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(
          find.descendant(of: amount, matching: find.byType(EditableText)));
      expect(editable.style.color, AppColors.backgroundDark);
      expect(find.text('Added to fare: Tip - PHP 12.50'), findsOneWidget);

      await _findDriver(tester);
      expect(find.byType(DriverSelectionScreen), findsOneWidget);
      expect(find.text('Tip PHP 12.50'), findsOneWidget);
      expect(find.text('PHP 29.50'), findsOneWidget);
      final confirm = find.text('Confirm Driver & Start Ride');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(booking?['otherFeeLabel'], 'Tip');
      expect(booking?['otherFeeAmount'], 12.5);
      expect(booking?['fare'], 29.5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => _client(onBooking: (value) => booking = value));
  });

  testWidgets('manual charges keep their category and None removes the charge',
      (tester) async {
    Map<String, dynamic>? booking;
    await http.runWithClient(() async {
      await _openServices(tester);
      final amount = find.widgetWithText(TextField, 'Amount');
      await _selectOption(tester, 'Charge type', 'Baggage');
      expect(tester.widget<TextField>(amount).controller!.text, '10');
      await tester.enterText(amount, '13.75');
      await tester.pumpAndSettle();
      expect(find.text('Added to fare: Baggage - PHP 13.75'), findsOneWidget);

      await _selectOption(tester, 'Charge type', 'Heavy items');
      expect(tester.widget<TextField>(amount).controller!.text, '20');
      await _selectOption(tester, 'Charge type', 'Others');
      await tester.enterText(amount, '42.25');
      await tester.pumpAndSettle();
      expect(find.text('Added to fare: Others - PHP 42.25'), findsOneWidget);
      for (final invalid in ['42.259', '4.2.5', '-5', '10001']) {
        await tester.enterText(amount, invalid);
        expect(tester.widget<TextField>(amount).controller!.text, '42.25');
      }

      await _selectOption(tester, 'Charge type', 'None');
      expect(tester.widget<TextField>(amount).controller!.text, isEmpty);
      expect(tester.widget<TextField>(amount).enabled, isFalse);
      expect(find.textContaining('Added to fare:'), findsNothing);
      await _findDriver(tester);
      expect(find.text('Additional Charge'), findsNothing);
      final confirm = find.text('Confirm Driver & Start Ride');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(booking?['otherFeeAmount'], 0);
      expect(booking?.containsKey('otherFeeLabel'), isFalse);
      expect(booking?['fare'], 17);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => _client(onBooking: (value) => booking = value));
  });
}
