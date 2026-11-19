import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:todago/destination_performance_map.dart';
import 'package:todago/ride_trends_card.dart';

class _TestMaps extends MethodChannelGoogleMapsFlutter {
  final _created = <int>{};
  @override
  Future<void> updateGroundOverlays(GroundOverlayUpdates updates,
      {required int mapId}) async {}
  @override
  Widget buildViewWithConfiguration(
      int creationId, PlatformViewCreatedCallback onCreated,
      {required MapWidgetConfiguration widgetConfiguration,
      MapConfiguration mapConfiguration = const MapConfiguration(),
      MapObjects mapObjects = const MapObjects()}) {
    if (_created.add(creationId)) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              MethodChannel('plugins.flutter.io/google_maps_$creationId'),
              (_) async => null);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onCreated(creationId));
    }
    return const SizedBox.expand();
  }
}

Map<String, dynamic> destination(String id, int count, {double? lat = 7.3}) => {
      'destination_id': id,
      'destination': id,
      'destination_lat': lat,
      'destination_lng': 125.68,
      'completed_trips': count,
      'gross_revenue': count * 20,
      'ride_share': 50,
      'avg_trip_minutes': 12.5,
      'last_completed_at': '2026-11-19T01:00:00Z',
    };

Widget page(Widget child) => MaterialApp(
    home: Scaffold(
        body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child))));

void main() {
  setUp(() {
    final previous = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = _TestMaps();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = previous);
  });

  testWidgets(
      'map colors demand, selects information and updates existing markers',
      (tester) async {
    final rows = [
      destination('College', 12),
      destination('Market', 6, lat: 7.31),
      destination('City Hall', 2, lat: 7.32),
      destination('No GPS', 1, lat: null)
    ];
    await tester.pumpWidget(page(DestinationPerformanceMap(data: rows)));
    await tester.pumpAndSettle();
    var map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers, hasLength(3));
    expect(
        map.circles
            .singleWhere((c) => c.circleId.value == 'College')
            .strokeColor,
        const Color(0xFFDC2626));
    expect(
        map.circles
            .singleWhere((c) => c.circleId.value == 'Market')
            .strokeColor,
        const Color(0xFFF59E0B));
    expect(
        map.circles
            .singleWhere((c) => c.circleId.value == 'City Hall')
            .strokeColor,
        const Color(0xFF2563EB));
    expect(
        find.text('21 completed rides · 4 destination areas'), findsOneWidget);
    map.markers.singleWhere((m) => m.markerId.value == 'Market').onTap!();
    await tester.pump();
    expect(find.text('Revenue: PHP 120.00'), findsOneWidget);
    expect(find.text('Average trip: 12.5 min'), findsOneWidget);
    await tester.pumpWidget(page(DestinationPerformanceMap(data: [
      destination('College', 12),
      destination('Market', 15, lat: 7.31)
    ])));
    await tester.pumpAndSettle();
    expect(find.text('15 completed rides · 50% of successful rides'),
        findsOneWidget);
    map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and invalid coordinates never create invented markers',
      (tester) async {
    await tester.pumpWidget(page(const DestinationPerformanceMap(data: [])));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'No successful rides yet.\nCompleted rides will appear here.'),
        findsOneWidget);
    await tester.pumpWidget(page(DestinationPerformanceMap(data: [
      destination('No GPS', 2, lat: null),
      destination('Invalid', 1, lat: 1000)
    ])));
    await tester.pumpAndSettle();
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).markers, isEmpty);
    expect(find.text('No GPS coordinates for these destinations yet.'),
        findsOneWidget);
    expect(
        find.text('3 completed rides · 2 destination areas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map polls after completion and retains data on refresh failure',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(page(DestinationPerformanceCard(
        scope: 'Your TODA',
        load: () async {
          calls++;
          return calls == 3 ? null : [destination('College', calls)];
        })));
    await tester.pumpAndSettle();
    expect(find.text('1 completed ride · 1 destination area'), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('2 completed rides · 1 destination area'), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(find.text('Unable to refresh. Showing the last available data.'),
        findsOneWidget);
    expect(find.text('2 completed rides · 1 destination area'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('period switching uses proper ranges and ignores stale responses',
      (tester) async {
    final delayedDay = Completer<List<Map<String, dynamic>>?>();
    final requests = <String>[];
    await tester.pumpWidget(page(RideTrendsCard(
        scope: 'System-wide',
        load: (period, days) async {
          requests.add('$period:$days');
          if (period == 'day') return delayedDay.future;
          return [
            {
              'hour_of_day': 9,
              'hour_label': '9 AM - 10 AM',
              'period_start': '2026-11-01',
              'period_label': '$period winner',
              'axis_label': 'Nov',
              'completed_trips': 8,
              'cancelled_trips': 3,
              'total_requests': 99
            }
          ];
        })));
    await tester.pumpAndSettle();
    expect(find.text('Other requests'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Day'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Week'));
    await tester.pumpAndSettle();
    expect(find.text('Most completed: week winner · 8 rides'), findsOneWidget);
    delayedDay.complete([
      {'period_label': 'stale day', 'completed_trips': 99}
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('stale day'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Month'));
    await tester.pumpAndSettle();
    expect(requests, ['hour:30', 'day:30', 'week:84', 'month:365']);
    expect(find.text('Most cancelled: month winner · 3 rides'), findsOneWidget);
    expect(find.text('Rides by month'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('analytics controls fit a narrow screen with large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(children: [
                              RideTrendsCard(
                                  scope: 'Your rides',
                                  dark: true,
                                  load: (_, __) async => [
                                        {
                                          'hour_of_day': 9,
                                          'hour_label': '9 AM - 10 AM',
                                          'completed_trips': 3,
                                          'cancelled_trips': 2
                                        }
                                      ]),
                              DestinationPerformanceMap(data: [
                                destination(
                                    'College with a long destination name', 3)
                              ]),
                            ]))))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
