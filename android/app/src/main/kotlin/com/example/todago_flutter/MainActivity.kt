package com.example.todago_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.maps.MapView

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "todago/map_places")
        channel.setMethodCallHandler { call, result ->
            val mapId = call.argument<Int>("mapId")
            if (mapId == null) {
                result.error("INVALID_MAP", "A map ID is required", null)
                return@setMethodCallHandler
            }
            val mapView = flutterEngine.platformViewsController.getPlatformViewById(mapId) as? MapView
            when (call.method) {
                "attach" -> {
                    if (mapView == null) {
                        result.error("MAP_UNAVAILABLE", "The map is not ready", null)
                    } else {
                        mapView.getMapAsync { map ->
                            map.setOnPoiClickListener { place ->
                                channel.invokeMethod("placeTapped", mapOf(
                                    "mapId" to mapId,
                                    "placeId" to place.placeId,
                                    "name" to place.name,
                                    "latitude" to place.latLng.latitude,
                                    "longitude" to place.latLng.longitude
                                ))
                            }
                            result.success(null)
                        }
                    }
                }
                "detach" -> {
                    mapView?.getMapAsync { it.setOnPoiClickListener(null) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
