import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todago/trip_analytics_chart.dart';

void main() {
  testWidgets('hourly trends use all 24 hours in chronological order',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TripAnalyticsChart(peakHours: true, data: [
          {
            'hour_label': '10 AM - 11 AM',
            'total_requests': 5,
            'completed_trips': 4,
            'cancelled_trips': 1,
          },
          {
            'hour_of_day': 9,
            'total_requests': 10,
            'completed_trips': 6,
            'cancelled_trips': 2,
          },
        ]),
      ),
    ));
    expect(find.text('Rides by hour'), findsOneWidget);
    expect(find.text('Other requests'), findsNothing);
    expect(
        find.bySemanticsLabel(
            'Average per hour. Completed 0.42, Cancelled 0.13.'),
        findsOneWidget);
    expect(
        find.bySemanticsLabel(
            '9 AM – 10 AM, 8 rides, 6 completed, 2 cancelled'),
        findsOneWidget);

    final plot =
        tester.getRect(find.byKey(const ValueKey('trip-analytics-plot')));
    await tester
        .tapAt(Offset(plot.left + plot.width * 10.5 / 24, plot.center.dy));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('^10 AM – 11 AM, 5 rides')),
        findsOneWidget);

    await tester.tap(find.byTooltip('Next hour'));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('^11 AM – 12 PM, 0 rides')),
        findsOneWidget);
    expect(find.text('0 completed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('route bars show the returned ranking and per-route average',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TripAnalyticsChart(data: [
          {
            'route_from': 'Terminal',
            'route_to': 'College',
            'total_trips': 10,
            'completed_trips': 8,
            'cancelled_trips': 2,
          },
          {
            'route_from': 'Market',
            'route_to': 'City Hall',
            'total_trips': 9,
            'completed_trips': 3,
            'cancelled_trips': 6,
          },
        ]),
      ),
    ));
    expect(find.text('Trips by route'), findsOneWidget);
    expect(find.text('Other requests'), findsNothing);
    expect(
        find.bySemanticsLabel(
            'Average per route. Completed 5.50, Cancelled 4.00.'),
        findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Terminal to College, 10 rides')),
        findsOneWidget);
    await tester.tap(find.byTooltip('Next route'));
    await tester.pump();
    expect(
        find.bySemanticsLabel(
            'Market to City Hall, 9 rides, 3 completed, 6 cancelled'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('dark chart fits the driver scroll layout with large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: const Scaffold(
            body: CustomScrollView(slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: Column(children: [
                    TripAnalyticsChart(peakHours: true, dark: true, data: [
                      {
                        'hour_of_day': 23,
                        'total_requests': 321,
                        'completed_trips': 256
                      },
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        );
      }),
    ));
    expect(find.text('256 completed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero counts show the empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: TripAnalyticsChart(data: [
      {'route_from': 'Terminal', 'route_to': 'College', 'total_trips': 0},
    ]))));
    expect(find.text('No completed or cancelled rides yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-analytics-plot')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
