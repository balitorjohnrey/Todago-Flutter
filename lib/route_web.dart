import 'dart:js_interop';

import 'package:google_maps/google_maps.dart' as maps;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_service.dart';

/// Uses the same Maps JavaScript API already loaded for the Flutter web map.
Future<List<MapRoute>> fetchWebRoutes(LatLng from, LatLng to) async {
  final request = maps.DirectionsRequest()
    ..origin = '${from.latitude},${from.longitude}'.toJS
    ..destination = '${to.latitude},${to.longitude}'.toJS
    ..travelMode = maps.TravelMode.DRIVING
    ..provideRouteAlternatives = true;
  final result = await maps.DirectionsService().route(request);
  final converted = <Map<String, dynamic>>[];
  for (final option in result.routes) {
    if (option.legs.isEmpty) continue;
    final leg = option.legs.first;
    final distance = leg.distance;
    final duration = leg.duration;
    if (distance == null || duration == null) continue;
    converted.add({
      'overview_polyline': {'points': option.overviewPolyline},
      'summary': option.summary,
      'legs': [
        {
          'distance': {'value': distance.value, 'text': distance.text},
          'duration': {'value': duration.value},
        }
      ],
    });
  }
  return MapService.routesFromDirectionsResponse({'routes': converted}, to);
}
