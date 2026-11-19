import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todago/ai_chat_screen.dart';
import 'package:todago/faq_service.dart';

import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareTestFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (call) async => call.method == 'initialize' ? false : true,
    );
  });

  Future<void> openChat(WidgetTester tester, String role) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: AIChatScreen(userType: role, userName: 'Test'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> send(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets(
      'guest can ask where FAQ answers come from using a quick question',
      (tester) async {
    await openChat(tester, 'guest');
    final question =
        FaqService.entries.firstWhere((e) => e.id == 'faq_sources');
    final chip = find.text(question.question);
    final questions = find.byWidgetPredicate((widget) =>
        widget is ListView && widget.scrollDirection == Axis.horizontal);
    await tester.scrollUntilVisible(chip, 250,
        scrollable:
            find.descendant(of: questions, matching: find.byType(Scrollable)));
    final visibleChip =
        tester.getRect(chip).intersect(tester.getRect(questions));
    expect(visibleChip.isEmpty, isFalse);
    await tester.tapAt(visibleChip.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(question.answer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('FAQ about where to find trips takes priority over place search',
      (tester) async {
    await openChat(tester, 'passenger');
    await send(tester, 'Where can I find my past trips?');
    final answer =
        FaqService.entries.firstWhere((e) => e.id == 'passenger_history');
    expect(find.text(answer.answer), findsOneWidget);
    expect(find.text('View routes on map'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'missing top-up gets troubleshooting instead of funding instructions',
      (tester) async {
    await openChat(tester, 'passenger');
    await send(tester, 'my top-up is not received');
    final answer =
        FaqService.entries.firstWhere((e) => e.id == 'missing_top_up');
    expect(find.text(answer.answer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a FAQ answer opens the attributed online source list',
      (tester) async {
    await openChat(tester, 'passenger');
    await send(tester, 'How do I book a ride?');
    final button = find.text('Sources');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Answer sources'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.textContaining('Angkas (n.d.'), findsOneWidget);
    expect(
        find.textContaining('Requesting a passenger service'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
