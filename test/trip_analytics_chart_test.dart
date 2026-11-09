import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todago/trip_analytics_chart.dart';

void main() {
  testWidgets('bar lengths use the same scale and include unfinished requests',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TripAnalyticsChart(peakHours: true, data: [
          {
            'hour_label': '9 AM - 10 AM',
            'total_requests': 10,
            'completed_trips': 6,
            'cancelled_trips': 2,
          },
          {
            'hour_label': '10 AM - 11 AM',
            'total_requests': 5,
            'completed_trips': 4,
            'cancelled_trips': 1,
          },
        ]),
      ),
    ));
    expect(find.text('10 requests'), findsOneWidget);
    expect(find.text('Other requests'), findsOneWidget);
    expect(
        find.bySemanticsLabel(
            '9 AM - 10 AM: 10 total, 6 completed, 2 cancelled, 2 other requests'),
        findsOneWidget);
    final completedSegments = find.byWidgetPredicate((widget) =>
        widget is Container && widget.color == const Color(0xFF278752));
    // The legend is the first square; the following two segments show 6 and 4.
    final firstWidth = tester.getSize(completedSegments.at(1)).width;
    final secondWidth = tester.getSize(completedSegments.at(2)).width;
    expect(firstWidth / secondWidth, closeTo(1.5, 0.01));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('zero counts show an honest empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: TripAnalyticsChart(data: [
      {'route_from': 'Terminal', 'route_to': 'College', 'total_trips': 0},
    ]))));
    expect(find.text('No trip data to chart yet'), findsOneWidget);
    expect(find.byType(ClipRRect), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
