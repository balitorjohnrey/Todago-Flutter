import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todago/location_query.dart';
import 'package:todago/map_service.dart';
import 'package:todago/route_display.dart';

void main() {
  const origin = LatLng(7.29937, 125.68191);
  const destination = LatLng(7.31430, 125.67020);

  Map<String, dynamic> route(String points, int meters, String summary) => {
        'overview_polyline': {'points': points},
        'summary': summary,
        'legs': [
          {
            'distance': {'value': meters, 'text': '${meters / 1000} km'},
            'duration': {'value': 600},
          }
        ],
      };

  test('Directions requests alternatives and keeps three distinct roads',
      () async {
    Uri? requested;
    final routes = await http.runWithClient(
      () => MapService.fetchRoutes(origin, destination),
      () => MockClient((request) async {
        requested = request.url;
        return http.Response(
            jsonEncode({
              'status': 'OK',
              'routes': [
                route(r'atpk@}fb~Veb@dj@cy@~\', 4200, 'Main Road'),
                route(r'atpk@}fb~Vun@lWsl@vo@', 3600, 'Second Road'),
                route(r'atpk@}fb~Ve{@dcAc`@~C', 5300, 'Third Road'),
                route(r'atpk@}fb~Veb@dj@cy@~\', 4200, 'Duplicate Road'),
              ],
            }),
            200);
      }),
    );

    expect(requested?.queryParameters['alternatives'], 'true');
    expect(routes, hasLength(3));
    expect(routes.map((option) => option.summary),
        ['Second Road', 'Main Road', 'Third Road']);
    expect(routes.first.distanceKm, 3.6);
    expect(routes.first.points.first, origin);
    expect(routes.first.points.last, destination);

    final polylines = RouteDisplay.polylines(routes).toList();
    expect(polylines, hasLength(3));
    expect(
        polylines
            .singleWhere((line) => line.polylineId.value == 'route-0')
            .color,
        RouteDisplay.recommendedColor);
    expect(
        polylines
            .where((line) => line.polylineId.value != 'route-0')
            .every((line) => line.color == RouteDisplay.alternativeColor),
        isTrue);
  });

  test('chat recognizes location requests without swallowing FAQs', () {
    expect(locationQueryFromMessage('How do I get to Gaisano Mall?'),
        'Gaisano Mall');
    expect(
        locationQueryFromMessage('directions to Panabo City'), 'Panabo City');
    expect(locationQueryFromMessage('Can you show me directions to SM Lanang?'),
        'SM Lanang');
    expect(locationQueryFromMessage('How do I book a ride?'), isNull);
    expect(locationQueryFromMessage('Where is my driver?'), isNull);
    expect(looksLikeStandalonePlace('Gaisano Mall'), isTrue);
    expect(looksLikeStandalonePlace('How do fares work?'), isFalse);
  });
}
