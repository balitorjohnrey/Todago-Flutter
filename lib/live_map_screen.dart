import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_theme.dart';
import 'map_service.dart';
import 'panabo_config.dart';
import 'map_place.dart';
import 'map_place_taps.dart';
import 'place_details_card.dart';

/// Public map explorer, also available before choosing an account.
class LiveMapScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LiveMapScreen({super.key, this.initialLocation});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final _searchController = TextEditingController();
  GoogleMapController? _mapController;
  Timer? _debounce;
  late LatLng _cameraTarget;
  LatLng? _selectedPoint;
  String _placeName = '';
  String _placeAddress = '';
  MapPlace? _place;
  MapPlaceTaps? _placeTaps;
  bool _detailsUnavailable = false;
  MapRoute? _route;
  LatLng? _routeOrigin;
  bool _routeRequested = false;
  bool _routing = false;
  String? _routeError;
  int _routeRequest = 0;
  List<PlaceSuggestion> _suggestions = [];
  String? _searchMessage;
  bool _searching = false;
  bool _selecting = false;
  bool _locating = false;
  bool _locationEnabled = false;
  bool _trafficEnabled = true;
  MapType _mapType = MapType.normal;
  int _searchRequest = 0;
  int _selectionRequest = 0;

  @override
  void initState() {
    super.initState();
    _cameraTarget = widget.initialLocation ?? PanaboConfig.cityCenter;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _placeTaps?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    ++_searchRequest;
    ++_selectionRequest;
    setState(() {
      _suggestions = [];
      _searchMessage = null;
      _searching = false;
      _selecting = false;
      _selectedPoint = null;
      _place = null;
      _clearRoute();
    });
    if (value.trim().length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 350), _search);
    }
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 2) return;
    final request = ++_searchRequest;
    setState(() {
      _searching = true;
      _searchMessage = null;
      _suggestions = [];
    });
    final results = await MapService.searchPlaces(
      query,
      locationBias: _cameraTarget,
      restrictToPhilippines: false,
    );
    if (!mounted || request != _searchRequest) return;
    setState(() {
      _searching = false;
      _suggestions = results;
      _searchMessage = results.isEmpty
          ? 'No places found. Check your connection or try another search.'
          : null;
    });
  }

  void _dismissSearch() {
    _debounce?.cancel();
    ++_searchRequest;
    FocusScope.of(context).unfocus();
    _suggestions = [];
    _searching = false;
    _searchMessage = null;
  }

  Future<void> _selectPlace(PlaceSuggestion place) async {
    _dismissSearch();
    final request = ++_selectionRequest;
    setState(() {
      _selecting = true;
      _selectedPoint = null;
      _place = null;
      _clearRoute();
    });
    final details = await MapService.getPlaceDetails(place.placeId);
    if (!mounted || request != _selectionRequest) return;
    final point =
        details?.point ?? await MapService.getPlaceLatLng(place.placeId);
    if (!mounted || request != _selectionRequest) return;
    setState(() {
      _selecting = false;
      if (point == null) {
        _searchMessage = 'Could not locate this place. Try another search or '
            'tap the map to drop a pin.';
      } else {
        _selectedPoint = point;
        _placeName = place.mainText;
        _placeAddress = place.secondaryText;
        _searchController.text = place.mainText;
        _place = details ??
            MapPlace(
              placeId:
                  place.placeId.startsWith('coord:') ? null : place.placeId,
              point: point,
              name: place.mainText,
              address: place.secondaryText,
            );
        _detailsUnavailable =
            details == null && !place.placeId.startsWith('coord:');
      }
    });
    if (point != null) await _moveCamera(point);
  }

  Future<void> _selectMapPlace(MapPlace place) async {
    _dismissSearch();
    final request = ++_selectionRequest;
    setState(() {
      _clearRoute();
      _selectedPoint = place.point;
      _place = place;
      _placeName = place.name;
      _placeAddress = place.address;
      _searchController.text = place.name;
      _selecting = true;
      _detailsUnavailable = false;
    });
    final details = await MapService.getPlaceDetails(place.placeId!);
    if (!mounted || request != _selectionRequest) return;
    setState(() {
      _selecting = false;
      _detailsUnavailable = details == null;
      if (details != null) {
        _place = details;
        _selectedPoint = details.point;
        _placeName = details.name;
        _placeAddress = details.address;
      }
    });
    await _moveCamera(_selectedPoint!);
  }

  Future<void> _dropPin(LatLng point) async {
    _dismissSearch();
    final request = ++_selectionRequest;
    setState(() {
      _selecting = false;
      _selectedPoint = point;
      _placeName = 'Dropped pin';
      _placeAddress = '${point.latitude.toStringAsFixed(5)}, '
          '${point.longitude.toStringAsFixed(5)}';
      _searchController.clear();
      _place = null;
      _detailsUnavailable = false;
      _clearRoute();
    });
    final address = await MapService.reverseGeocode(point);
    if (!mounted || request != _selectionRequest) return;
    if (address.isNotEmpty && address != 'Your Location') {
      setState(() => _placeAddress = address);
    }
  }

  Future<void> _moveCamera(LatLng point) async {
    _cameraTarget = point;
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    final point = await MapService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locationEnabled = point != null;
    });
    if (point == null) {
      _showMessage('Your location is unavailable. Enable location services and '
          'allow location access, or keep searching and exploring the map.');
      return;
    }
    await _moveCamera(point);
  }

  void _clearRoute() {
    ++_routeRequest;
    _route = null;
    _routeOrigin = null;
    _routeRequested = false;
    _routing = false;
    _routeError = null;
  }

  Future<void> _openDirections() async {
    final destination = _selectedPoint;
    final placeId = _place?.placeId;
    if (destination == null || _routing) return;
    final request = ++_routeRequest;
    setState(() {
      _routeRequested = true;
      _routing = true;
      _route = null;
      _routeError = null;
    });
    final origin = await MapService.getCurrentLocation();
    if (!mounted || request != _routeRequest) return;
    if (origin == null) {
      setState(() {
        _routing = false;
        _routeError = 'Your location is unavailable. Enable location services '
            'and allow location access, then retry directions.';
      });
      return;
    }
    setState(() {
      _routeOrigin = origin;
      _locationEnabled = true;
    });
    final route = await MapService.fetchRoute(origin, destination,
        destinationPlaceId: placeId, allowEstimate: false);
    if (!mounted || request != _routeRequest) return;
    setState(() {
      _routing = false;
      _route = route;
      _routeError = route == null
          ? 'No road route is available. Check your connection and retry directions.'
          : null;
    });
    if (route != null) await _fitRoute();
  }

  Future<void> _fitRoute() async {
    final route = _route;
    if (route == null || _mapController == null) return;
    final points = [...route.points, _routeOrigin!, _selectedPoint!];
    final south = points.map((p) => p.latitude).reduce(math.min);
    final north = points.map((p) => p.latitude).reduce(math.max);
    final west = points.map((p) => p.longitude).reduce(math.min);
    final east = points.map((p) => p.longitude).reduce(math.max);
    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(south - 0.0001, west - 0.0001),
            northeast: LatLng(north + 0.0001, east + 0.0001)),
        40));
  }

  Widget _searchPanel(double maxHeight) {
    return Material(
      color: AppColors.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _search(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search places or addresses',
            prefixIcon: IconButton(
              tooltip: 'Search places',
              onPressed: _search,
              icon: const Icon(Icons.search),
            ),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        if (_searching || _selecting) const LinearProgressIndicator(),
        if (_searchMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_searchMessage!, style: const TextStyle(fontSize: 13)),
          ),
        if (_suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (_, index) {
                final place = _suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(place.mainText),
                  subtitle: Text(place.secondaryText,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _selectPlace(place),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _placeCard() {
    final place = _place;
    if (place != null) {
      return PlaceDetailsCard(
        place: place,
        loading: _selecting,
        detailsUnavailable: _detailsUnavailable,
        onDirections: _openDirections,
        onClose: _closePlace,
        onRetry: () => _selectMapPlace(place),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Text(_placeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              tooltip: 'Close place',
              onPressed: _closePlace,
              icon: const Icon(Icons.close),
            ),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_placeAddress,
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _openDirections,
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Get Directions'),
            ),
          ),
        ]),
      ),
    );
  }

  void _closePlace() {
    ++_selectionRequest;
    setState(() {
      _selectedPoint = null;
      _place = null;
      _selecting = false;
      _clearRoute();
    });
  }

  Widget _directionsCard() => Card(
        margin: EdgeInsets.zero,
        child: SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.directions, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Directions',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(
                  tooltip: 'Close directions',
                  onPressed: () => setState(_clearRoute),
                  icon: const Icon(Icons.close)),
            ]),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('From: Your location')),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('To: $_placeName',
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 12),
            if (_routing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Finding a road route…'),
            ],
            if (_route != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    '${_route!.distanceText} · ${_route!.durationText} '
                    '(estimated tricycle travel time)',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            if ((_route?.destinationOffsetMeters ?? 0) > 50)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('The road route ends about '
                    '${_route!.destinationOffsetMeters.round()} m from your '
                    'selected destination. Check the entrance and final access.'),
              ),
            if (_routeError != null) ...[
              Text(_routeError!),
              TextButton(
                  onPressed: _openDirections,
                  child: const Text('Retry directions')),
            ],
          ]),
        )),
      );

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore map'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: _trafficEnabled ? 'Hide traffic' : 'Show traffic',
            onPressed: () => setState(() => _trafficEnabled = !_trafficEnabled),
            color: _trafficEnabled ? AppColors.primary : null,
            icon: const Icon(Icons.traffic_outlined),
          ),
          PopupMenuButton<MapType>(
            tooltip: 'Map layers',
            initialValue: _mapType,
            onSelected: (type) => setState(() => _mapType = type),
            icon: const Icon(Icons.layers_outlined),
            itemBuilder: (_) => [
              for (final layer in {
                MapType.normal: 'Standard',
                MapType.hybrid: 'Satellite',
                MapType.terrain: 'Terrain',
              }.entries)
                CheckedPopupMenuItem(
                  value: layer.key,
                  checked: _mapType == layer.key,
                  child: Text(layer.value),
                ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation ?? PanaboConfig.cityCenter,
              zoom: 15.5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _placeTaps = MapPlaceTaps(
                  mapId: controller.mapId,
                  onSelected: (place) {
                    if (mounted) _selectMapPlace(place);
                  });
              unawaited(_placeTaps!.attach());
              // A search can finish while the native map is still loading.
              controller.moveCamera(CameraUpdate.newLatLng(_cameraTarget));
              if (_route != null) unawaited(_fitRoute());
            },
            onCameraMove: (position) => _cameraTarget = position.target,
            onTap: _dropPin,
            onLongPress: _dropPin,
            markers: {
              if (_routeOrigin != null)
                Marker(
                    markerId: const MarkerId('explore-origin'),
                    position: _routeOrigin!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure),
                    infoWindow: const InfoWindow(title: 'Your location')),
              if (_selectedPoint != null)
                Marker(
                  markerId: const MarkerId('explore-place'),
                  position: _selectedPoint!,
                  infoWindow: InfoWindow(title: _placeName),
                ),
            },
            polylines: {
              if (_route != null)
                Polyline(
                    polylineId: const PolylineId('explore-route'),
                    points: _route!.points,
                    color: const Color(0xFF1A73E8),
                    width: 6,
                    jointType: JointType.round),
            },
            padding: EdgeInsets.only(
              top: 80,
              bottom: !keyboardVisible && _selectedPoint != null
                  ? math.min(constraints.maxHeight * 0.48, 380.0) + 24
                  : 24,
            ),
            mapType: _mapType,
            myLocationEnabled: _locationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            trafficEnabled: _trafficEnabled,
            buildingsEnabled: true,
            indoorViewEnabled: true,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _searchPanel(constraints.maxHeight * 0.45),
                const Spacer(),
                if (!keyboardVisible) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton.small(
                      heroTag: 'explore-my-location',
                      tooltip: 'My location',
                      onPressed: _locating ? null : _locateMe,
                      child: _locating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedPoint != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight:
                              math.min(constraints.maxHeight * 0.48, 380.0)),
                      child: _routeRequested ? _directionsCard() : _placeCard(),
                    )
                  else
                    const Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Search for a place or tap the map to drop '
                            'a pin. No account needed.'),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ]);
      }),
    );
  }
}
