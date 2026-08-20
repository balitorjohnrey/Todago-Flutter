import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'panabo_config.dart';

class LiveMapScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LiveMapScreen({
    super.key,
    this.initialLocation,
  });

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.initialLocation ?? PanaboConfig.cityCenter;

    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: target,
          zoom: 15.5,
        ),
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: true,
        trafficEnabled: true,
        buildingsEnabled: true,
        indoorViewEnabled: true,
        rotateGesturesEnabled: true,
        scrollGesturesEnabled: true,
        tiltGesturesEnabled: true,
        zoomGesturesEnabled: true,
      ),
    );
  }
}
