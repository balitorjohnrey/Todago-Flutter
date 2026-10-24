import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'map_service.dart';
import 'panabo_config.dart';

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
    setState(() => _selecting = true);
    final point = await MapService.getPlaceLatLng(place.placeId);
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
      }
    });
    if (point != null) await _moveCamera(point);
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

  Future<void> _openDirections() async {
    final point = _selectedPoint;
    if (point == null) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${point.latitude},${point.longitude}',
      'travelmode': 'driving',
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('Could not open directions. Please try again.');
      }
    } catch (_) {
      if (mounted) _showMessage('Could not open directions. Please try again.');
    }
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
              onPressed: () {
                ++_selectionRequest;
                setState(() => _selectedPoint = null);
              },
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
              label: const Text('Directions'),
            ),
          ),
        ]),
      ),
    );
  }

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
              // A search can finish while the native map is still loading.
              controller.moveCamera(CameraUpdate.newLatLng(_cameraTarget));
            },
            onCameraMove: (position) => _cameraTarget = position.target,
            onTap: _dropPin,
            onLongPress: _dropPin,
            markers: {
              if (_selectedPoint != null)
                Marker(
                  markerId: const MarkerId('explore-place'),
                  position: _selectedPoint!,
                  infoWindow: InfoWindow(title: _placeName),
                ),
            },
            padding: EdgeInsets.only(
              top: 80,
              bottom: !keyboardVisible && _selectedPoint != null ? 210 : 24,
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
                    _placeCard()
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
