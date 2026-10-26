import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_place.dart';

/// The app's pinned Maps plugin predates POI callbacks. Forward Android's
/// native POI event without changing the SDK or replacing plugin internals.
class MapPlaceTaps {
  static const channel = MethodChannel('todago/map_places');
  final int mapId;
  final ValueChanged<MapPlace> onSelected;

  MapPlaceTaps({required this.mapId, required this.onSelected});

  Future<void> attach() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'placeTapped') return;
      final data = Map<String, dynamic>.from(call.arguments as Map);
      if (data['mapId'] != mapId) return;
      onSelected(MapPlace(
        placeId: data['placeId'] as String,
        name: data['name'] as String,
        point: LatLng((data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble()),
      ));
    });
    try {
      await channel.invokeMethod<void>('attach', {'mapId': mapId});
    } on PlatformException {
      // Search and dropped pins remain available if the native map is absent.
    } on MissingPluginException {
      // Other platforms and widget tests do not install the Android bridge.
    }
  }

  void dispose() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    channel.setMethodCallHandler(null);
    channel.invokeMethod<void>(
        'detach', {'mapId': mapId}).catchError((Object _) {});
  }
}
