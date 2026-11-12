import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todago/admin_cashouts_screen.dart';
import 'package:todago/admin_dashboard_screen.dart';
import 'package:todago/main.dart';
import 'package:todago/operator_dashboard_screen.dart';
import 'package:todago/splash_screen.dart';

import 'support/test_fonts.dart';

String _token({required bool expired}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({
        'exp': expired ? now - 3600 : now + 3600,
      })))
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

Future<void> _startApp(WidgetTester tester) async {
  await tester.pumpWidget(const TodaGoApp());
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareTestFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('TodaGo app renders splash screen', (WidgetTester tester) async {
    await _startApp(tester);
    expect(find.text('TodaGo'), findsOneWidget);
    expect(find.text('Premium Tricycle Hailing'), findsOneWidget);
  });

  testWidgets('operator stays signed in through Home and an offline restart',
      (tester) async {
    const storage = FlutterSecureStorage();
    final token = _token(expired: false);
    FlutterSecureStorage.setMockInitialValues({
      'operator_auth_token': token,
      'operator_data': jsonEncode({'association_name': 'My Fleet'}),
    });
    var offline = false;
    await http.runWithClient(() async {
      await _startApp(tester);
      expect(find.byType(OperatorDashboardScreen), findsOneWidget);
      expect(find.text('My Fleet'), findsOneWidget);

      offline = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(OperatorDashboardScreen), findsOneWidget);
      expect(await storage.read(key: 'operator_auth_token'), token);

      await tester.pumpWidget(const SizedBox());
      await _startApp(tester);
      expect(find.byType(OperatorDashboardScreen), findsOneWidget);
      expect(find.text('My Fleet'), findsOneWidget);
      expect(await storage.read(key: 'operator_auth_token'), token);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer $token');
              if (offline) throw http.ClientException('Offline', request.url);
              return http.Response(
                  '{"success":true,"operator":{"association_name":"My Fleet"}}',
                  200);
            }));
  });

  for (final status in [401, 403, 503]) {
    testWidgets(
        'startup does not restore a rejected or expired token ($status)',
        (tester) async {
      const storage = FlutterSecureStorage();
      final token = _token(expired: status == 503);
      FlutterSecureStorage.setMockInitialValues({'operator_auth_token': token});
      await http.runWithClient(() async {
        await _startApp(tester);
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(OperatorDashboardScreen), findsNothing);
        expect(await storage.read(key: 'operator_auth_token'),
            status == 503 ? token : isNull);
      }, () => MockClient((_) async => http.Response('{}', status)));
    });
  }

  for (final payoutAdmin in [false, true]) {
    testWidgets('startup restores the ${payoutAdmin ? 'payout ' : ''}admin',
        (tester) async {
      final token = _token(expired: false);
      FlutterSecureStorage.setMockInitialValues({
        payoutAdmin ? 'payout_admin_auth_token' : 'admin_auth_token': token,
      });
      await http.runWithClient(() async {
        await _startApp(tester);
        expect(
            find.byType(
                payoutAdmin ? AdminCashoutsScreen : AdminDashboardScreen),
            findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((_) async => http.Response('{"success":true}', 200)));
    });
  }
}
