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
    expect(requested?.host, 'maps.googleapis.com');
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

  test('OSRM fills missing options and removes a duplicate Google road',
      () async {
    final requests = <Uri>[];
    final routes = await http.runWithClient(
      () => MapService.fetchRoutes(origin, destination),
      () => MockClient((request) async {
        requests.add(request.url);
        if (request.url.host == 'router.project-osrm.org') {
          return http.Response(
              jsonEncode({
                'code': 'Ok',
                'routes': [
                  {
                    'distance': 4210,
                    'geometry': {
                      'coordinates': [
                        [125.68191, 7.29937],
                        [125.678455, 7.302185],
                        [125.675, 7.305],
                        [125.6726, 7.30965],
                        [125.67020, 7.31430],
                      ]
                    },
                  },
                  {
                    'distance': 3600,
                    'geometry': {
                      'coordinates': [
                        [125.68191, 7.29937],
                        [125.678, 7.307],
                        [125.67020, 7.31430],
                      ]
                    },
                  },
                  {
                    'distance': 5300,
                    'geometry': {
                      'coordinates': [
                        [125.68191, 7.29937],
                        [125.671, 7.309],
                        [125.67020, 7.31430],
                      ]
                    },
                  },
                ],
              }),
              200);
        }
        return http.Response(
            jsonEncode({
              'status': 'OK',
              'routes': [route(r'atpk@}fb~Veb@dj@cy@~\', 4200, 'Main Road')],
            }),
            200);
      }),
    );

    expect(requests, hasLength(2));
    expect(requests.last.host, 'router.project-osrm.org');
    expect(requests.last.queryParameters['alternatives'], '3');
    expect(requests.last.queryParameters['geometries'], 'geojson');
    expect(routes, hasLength(3));
    expect(routes.map((option) => option.distanceKm), [3.6, 4.2, 5.3]);
    expect(
        routes.where((option) => option.summary == 'Main Road'), hasLength(1));
  });

  test('OSRM fallback shows only real routes when Google is unavailable',
      () async {
    final routes = await http.runWithClient(
      () => MapService.fetchRoutes(origin, destination),
      () => MockClient((request) async {
        if (request.url.host == 'maps.googleapis.com') {
          return http.Response('{"status":"REQUEST_DENIED"}', 200);
        }
        return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 4200,
                  'geometry': {
                    'coordinates': [
                      [125.68191, 7.29937],
                      [125.675, 7.305],
                      [125.67020, 7.31430],
                    ]
                  },
                },
              ],
            }),
            200);
      }),
    );
    expect(routes, hasLength(1));
    expect(routes.single.points.last, destination);
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
