import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todago/identity_verification_screen.dart';

void main() {
  testWidgets('approval waits for the user to tap Back to TodaGo',
      (tester) async {
    bool? result;
    var approved = false;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        result = await Navigator.of(context)
                            .push<bool>(MaterialPageRoute(
                          builder: (_) => IdentityVerificationScreen(
                            verificationUrl:
                                Uri.parse('https://verify.didit.me/example'),
                            verificationContent:
                                const Text('In-app verification'),
                            checkStatus: () async => {
                              'status': approved ? 'approved' : 'pending',
                              'isVerified': approved,
                            },
                          ),
                        ));
                      },
                      child: const Text('Start verification')),
                ))));
    await tester.tap(find.text('Start verification'));
    await tester.pumpAndSettle();
    expect(find.text('In-app verification'), findsOneWidget);
    expect(find.text('Back to TodaGo'), findsNothing);
    approved = true;
    await tester.tap(find.byTooltip('Check verification status'));
    await tester.pumpAndSettle();
    expect(find.text('Verification passed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Back to TodaGo'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Back to TodaGo'));
    await tester.pumpAndSettle();
    expect(result, true);
    expect(find.text('Start verification'), findsOneWidget);
  });

  for (final status in [
    'pending',
    'completed',
    'needs_review',
    'declined',
    'expired'
  ]) {
    testWidgets('$status does not show approval', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: IdentityVerificationScreen(
        verificationUrl:
            Uri.parse('https://verify.didit.me/example?status=Approved'),
        verificationContent: const Text('In-app verification'),
        checkStatus: () async => {'status': status, 'isVerified': false},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Verification passed'), findsNothing);
      expect(find.text('Back to TodaGo'), findsNothing);
      expect(find.text('Return and verify later'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a status failure can recover without leaving verification',
      (tester) async {
    var fail = true;
    await tester.pumpWidget(MaterialApp(
        home: IdentityVerificationScreen(
      verificationUrl: Uri.parse('https://verify.didit.me/example'),
      verificationContent: const Text('In-app verification'),
      checkStatus: () async {
        if (fail) throw StateError('Temporary network error');
        return {'status': 'approved', 'isVerified': true};
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Temporary network error'), findsOneWidget);
    expect(find.text('Verification passed'), findsNothing);
    fail = false;
    await tester.tap(find.byTooltip('Check verification status'));
    await tester.pumpAndSettle();
    expect(find.text('Verification passed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
