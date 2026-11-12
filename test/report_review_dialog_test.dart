import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todago/admin_auth_service.dart';
import 'package:todago/report_review_dialog.dart';

Future<void> openReview(WidgetTester tester, Map<String, dynamic> report,
    void Function(ReportReviewDecision?) onDecision) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () async =>
                      onDecision(await showDialog<ReportReviewDecision>(
                    context: context,
                    builder: (_) => ReportReviewDialog(report: report),
                  )),
                  child: const Text('Review'),
                ))),
  ));
  await tester.tap(find.text('Review'));
  await tester.pumpAndSettle();
}

void main() {
  for (final target in ['passenger', 'driver']) {
    testWidgets(
        'admin must choose a $target penalty duration and can include notes',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ReportReviewDecision? decision;
      await openReview(
          tester,
          {
            'reporter_role': target == 'passenger' ? 'driver' : 'passenger',
            'subject_role': target,
            'subject_id': 'account-1',
            'title': 'Incident report',
            'details': 'Full incident details for admin review.',
          },
          (result) => decision = result);
      final validate =
          find.widgetWithText(FilledButton, 'Validate & apply penalty');
      expect(tester.widget<FilledButton>(validate).onPressed, isNull);
      expect(
        tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).map(
              (chip) => (chip.label as Text).data,
            ),
        [
          '1 hour',
          '3 hours',
          '5 hours',
          '12 hours',
          '24 hours',
          '1 week',
          'Permanent'
        ],
      );
      expect(
          find.text('Full incident details for admin review.'), findsOneWidget);
      final isDriver = target == 'driver';
      final choice =
          find.widgetWithText(ChoiceChip, isDriver ? 'Permanent' : '5 hours');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(choice).selected, isTrue);
      expect(
          find.text(isDriver
              ? 'This restriction has no expiry.'
              : 'This restriction expires automatically.'),
          findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Reviewed incident');
      await tester.tap(validate);
      await tester.pumpAndSettle();
      expect(decision?.duration, isDriver ? 'permanent' : '5h');
      expect(decision?.notes, 'Reviewed incident');
    });
  }

  testWidgets(
      'cancel applies no decision and an unlinked account cannot receive a penalty',
      (tester) async {
    ReportReviewDecision? decision;
    await openReview(
        tester,
        {
          'reporter_role': 'passenger',
          'subject_role': 'driver',
        },
        (result) => decision = result);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Validate & apply penalty'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(decision, isNull);
    expect(find.byType(ReportReviewDialog), findsNothing);
  });

  testWidgets('system alerts can be validated without an account penalty',
      (tester) async {
    ReportReviewDecision? decision;
    await openReview(
        tester,
        {
          'reporter_role': 'system',
          'subject_role': 'driver',
        },
        (result) => decision = result);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Validate report'));
    await tester.pumpAndSettle();
    expect(decision, isNotNull);
    expect(decision?.duration, isNull);
  });

  test('admin API transmits the selected duration and review notes', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'admin-test-token');
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await http.runWithClient(() async {
      final result = await AdminAuthService.updateReportStatus(
        issueId: 'incident-1',
        status: 'validated',
        penaltyDuration: 'permanent',
        adminNotes: 'Reviewed',
      );
      expect(result.success, isTrue);
    },
        () => MockClient((request) async {
              expect(request.method, 'PATCH');
              expect(request.url.path, '/api/admin/reports/incident-1/status');
              expect(
                  request.headers['Authorization'], 'Bearer admin-test-token');
              expect(jsonDecode(request.body), {
                'status': 'validated',
                'penaltyDuration': 'permanent',
                'adminNotes': 'Reviewed',
              });
              return http.Response('{"success":true}', 200);
            }));
  });
}
