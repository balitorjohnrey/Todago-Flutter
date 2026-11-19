import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todago/admin_dashboard_screen.dart';
import 'package:todago/admin_report_history_screen.dart';
import 'package:todago/app_theme.dart';

import 'support/test_fonts.dart';

const _validated = <String, dynamic>{
  'issue_id': 'report-1',
  'title': 'Driver incident',
  'status': 'validated',
  'reporter_name': 'Passenger One',
  'subject_name': 'Driver One',
  'subject_id': 'driver-1',
  'details': 'The original report details.',
  'penalty_permanent': true,
  'penalty_active': true,
  'admin_notes': 'Initial review notes',
  'created_at': '2026-11-18T01:00:00Z',
  'last_review_at': '2026-11-19T01:00:00Z',
};
const _rejected = <String, dynamic>{
  'issue_id': 'report-2',
  'title': 'Passenger incident',
  'status': 'rejected',
  'subject_name': 'Passenger Two',
  'penalty_active': false,
};
const _event = <String, dynamic>{
  'action': 'validated',
  'previous_status': 'pending',
  'status': 'validated',
  'admin_id': 'admin-1',
  'notes': 'Initial review notes',
  'penalty_permanent': true,
  'created_at': '2026-11-19T01:00:00Z',
};

http.Response _response(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'success': true, ...data}), 200);

Future<void> _open(WidgetTester tester, Widget screen,
    {Size size = const Size(800, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: screen));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _confirm(String title) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, title));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareTestFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues(
      {'admin_auth_token': 'admin-token'}));

  testWidgets(
      'admin Reports opens history with authenticated pagination and status filters',
      (tester) async {
    final queries = <Map<String, String>>[];
    await http.runWithClient(() async {
      await _open(tester, const AdminDashboardScreen());
      await _tap(tester, find.text('Report History'));
      expect(find.byType(AdminReportHistoryScreen), findsOneWidget);
      expect(find.text('Driver incident'), findsOneWidget);
      await _tap(tester, find.text('Load more reports'));
      expect(find.text('Driver incident'), findsOneWidget);
      expect(find.text('Passenger incident'), findsOneWidget);
      expect(queries.last['offset'], '25');
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Rejected'));
      expect(queries.last['status'], 'rejected');
      expect(find.text('Passenger incident'), findsOneWidget);
      expect(find.text('Driver incident'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/reports/history')) {
                expect(request.headers['Authorization'], 'Bearer admin-token');
                queries.add(request.url.queryParameters);
                final first = request.url.queryParameters['status'] == 'all' &&
                    request.url.queryParameters['offset'] == '0';
                return _response({
                  'reports': [first ? _validated : _rejected],
                  'has_more': first,
                  'next_offset': 25
                });
              }
              return _response(
                  {'stats': {}, 'drivers': [], 'reports': [], 'settings': {}});
            }));
  });

  testWidgets(
      'undo requires a reason, cancel has no effect, and original validation stays in history',
      (tester) async {
    var undone = false, posts = 0;
    await http.runWithClient(() async {
      await _open(
          tester, const AdminReportReviewHistoryScreen(issueId: 'report-1'));
      expect(find.text('Active penalty · Permanent'), findsOneWidget);
      await _tap(tester, find.widgetWithText(FilledButton, 'Undo penalty'));
      await _tap(tester, _confirm('Undo penalty'));
      expect(find.text('Enter a reason.'), findsOneWidget);
      expect(posts, 0);
      await _tap(tester, find.text('Cancel'));
      expect(posts, 0);
      await _tap(tester, find.widgetWithText(FilledButton, 'Undo penalty'));
      await tester.enterText(
          find.byType(TextFormField), '  Mistaken identity  ');
      await _tap(tester, _confirm('Undo penalty'));
      expect(posts, 1);
      expect(find.widgetWithText(FilledButton, 'Undo penalty'), findsNothing);
      expect(find.text('Status: Validated'), findsOneWidget);
      expect(find.text('Admin notes: Initial review notes'), findsOneWidget);
      expect(find.text('Reason: Mistaken identity'), findsOneWidget);
      expect(find.text('Penalty undone'), findsNWidgets(2));
      expect(find.text('Original penalty: Permanent'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer admin-token');
              if (request.method == 'POST') {
                expect(request.url.path,
                    '/api/admin/reports/report-1/undo-penalty');
                expect(
                    jsonDecode(request.body), {'reason': 'Mistaken identity'});
                posts++;
                undone = true;
                return _response(
                    {'message': 'Penalty undone for this report.'});
              }
              return _response({
                'report': {
                  ..._validated,
                  if (undone) ...{
                    'penalty_active': false,
                    'penalty_revoked_at': '2026-11-19T02:00:00Z',
                    'penalty_revoke_reason': 'Mistaken identity'
                  }
                },
                'history': [
                  _event,
                  if (undone)
                    {
                      ..._event,
                      'action': 'penalty_revoked',
                      'notes': 'Mistaken identity'
                    }
                ]
              });
            }));
  });

  testWidgets('a failed undo keeps the penalty visible and allows retry',
      (tester) async {
    await http.runWithClient(() async {
      await _open(
          tester, const AdminReportReviewHistoryScreen(issueId: 'report-1'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Undo penalty'));
      await tester.enterText(
          find.byType(TextFormField), 'Correction after review');
      await _tap(tester, _confirm('Undo penalty'));
      expect(find.text('Unable to record reversal. Please retry.'),
          findsOneWidget);
      expect(find.text('Active penalty · Permanent'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Undo penalty'), findsOneWidget);
      expect(find.text('Reason: Correction after review'), findsNothing);
    },
        () => MockClient((request) async => request.method == 'POST'
            ? http.Response(
                '{"success":false,"message":"Unable to record reversal. Please retry."}',
                500)
            : _response({
                'report': _validated,
                'history': [_event]
              })));
  });

  testWidgets(
      'rejected reports can be reopened without losing the rejection notes',
      (tester) async {
    var reopened = false;
    await http.runWithClient(() async {
      await _open(
          tester, const AdminReportReviewHistoryScreen(issueId: 'report-2'));
      expect(find.widgetWithText(FilledButton, 'Undo penalty'), findsNothing);
      await _tap(tester, find.widgetWithText(OutlinedButton, 'Reopen report'));
      await tester.enterText(
          find.byType(TextFormField), 'New evidence submitted');
      await _tap(tester, _confirm('Reopen report'));
      expect(reopened, isTrue);
      expect(find.text('Status: Pending'), findsOneWidget);
      expect(find.text('Notes: Insufficient evidence'), findsOneWidget);
      expect(find.text('Reopened'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'PATCH') {
                expect(jsonDecode(request.body), {
                  'status': 'pending',
                  'adminNotes': 'New evidence submitted'
                });
                reopened = true;
                return _response({'message': 'Report reopened.'});
              }
              return _response({
                'report': {..._rejected, if (reopened) 'status': 'pending'},
                'history': [
                  {
                    'action': 'rejected',
                    'status': 'rejected',
                    'notes': 'Insufficient evidence'
                  },
                  if (reopened)
                    {
                      'action': 'reopened',
                      'previous_status': 'rejected',
                      'status': 'pending',
                      'notes': 'New evidence submitted'
                    }
                ]
              });
            }));
  });

  testWidgets(
      'history loading errors are retryable rather than shown as an empty history',
      (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await _open(tester, const AdminReportHistoryScreen());
      expect(find.text('Unable to load report history. Tap refresh to retry.'),
          findsOneWidget);
      expect(find.text('No reviewed reports in this category.'), findsNothing);
      await _tap(tester, find.byTooltip('Refresh report history'));
      expect(find.text('Driver incident'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async => ++calls == 1
            ? http.Response('{}', 500)
            : _response({
                'reports': [_validated],
                'has_more': false
              })));
  });

  testWidgets(
      'history details and undo dialog fit a narrow phone with large text',
      (tester) async {
    await http.runWithClient(() async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.theme,
          home: Builder(
              builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: const AdminReportReviewHistoryScreen(
                      issueId: 'report-1')))));
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Undo penalty'));
      await tester.enterText(
          find.byType(TextFormField), 'Reason for correction');
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('Cancel'));
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async => _response({
              'report': _validated,
              'history': [_event]
            })));
  });
}
