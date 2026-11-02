import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todago/driver_wallet_screen.dart';
import 'package:todago/admin_cashouts_screen.dart';

void main() {
  testWidgets(
      'driver balance refreshes within five seconds and again when the app resumes',
      (tester) async {
    var balance = 0;
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: DriverWalletScreen(
      fetchWallet: () async {
        calls++;
        return {
          'success': true,
          'wallet': {
            'available': balance,
            'reserved': 0,
            'paid': 0,
            'requests': []
          }
        };
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('₱0.00'), findsOneWidget);
    balance = 60;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('₱60.00'), findsOneWidget);
    final beforeResume = calls;
    balance = 120;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, greaterThan(beforeResume));
    expect(find.text('₱120.00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a driver cannot submit below PHP 50, and a network retry keeps the same request key',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final submissions = <Map<String, dynamic>>[];
    await tester.pumpWidget(MaterialApp(
        home: DriverWalletScreen(
      fetchWallet: () async => {
        'success': true,
        'wallet': {'available': 100, 'reserved': 0, 'paid': 0, 'requests': []}
      },
      createCashOut: (body) async {
        submissions.add(body);
        return {'success': false, 'message': 'Connection interrupted'};
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash out • Minimum ₱50'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '49');
    await tester.enterText(fields.at(1), 'Test Driver');
    await tester.enterText(fields.at(2), '09123456789');
    await tester.tap(find.text('Request cash-out'));
    await tester.pumpAndSettle();
    expect(submissions, isEmpty);
    expect(
        find.text('Enter ₱50–₱50,000, up to 2 decimal places'), findsOneWidget);
    await tester.enterText(fields.at(0), '50');
    await tester.tap(find.text('Request cash-out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request cash-out'));
    await tester.pumpAndSettle();
    expect(submissions.length, 2);
    expect(submissions[0]['requestKey'], submissions[1]['requestKey']);
    expect(submissions[0]['accountNumber'], '09123456789');
    expect(submissions[0]['amount'], '50');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'payout admin records a transfer and it moves from the queue to history',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final row = <String, dynamic>{
      'cashout_id': 'request-1',
      'driver_name': 'Test Driver',
      'amount': 50,
      'provider': 'gcash',
      'account_name': 'Test Driver',
      'account_number': '09123456789',
      'status': 'processing',
      'created_at': '2026-11-02'
    };
    var sent = false;
    await tester.pumpWidget(MaterialApp(
        home: AdminCashoutsScreen(
      fetchRequests: (history) async => {
        'success': true,
        'requests':
            [(ifIncluded(history, row) ? row : null)].whereType<Map>().toList()
      },
      submitReview: (id, body) async {
        expect(id, 'request-1');
        expect(body['action'], 'paid');
        expect(body['reference'], '123456789');
        sent = true;
        row['status'] = 'paid';
        row['payment_reference'] = body['reference'];
        return {'success': true};
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record successful payment'));
    await tester.pumpAndSettle();
    final recordButton = find.widgetWithText(FilledButton, 'Record paid');
    expect(tester.widget<FilledButton>(recordButton).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, '123456789');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Record paid'));
    await tester.pumpAndSettle();
    expect(sent, true);
    expect(find.text('Record successful payment'), findsNothing);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Status: paid'), findsOneWidget);
    expect(find.text('Transfer reference: 123456789'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

bool ifIncluded(bool history, Map<String, dynamic> row) => history
    ? ['paid', 'rejected', 'cancelled'].contains(row['status'])
    : ['pending', 'processing'].contains(row['status']);
