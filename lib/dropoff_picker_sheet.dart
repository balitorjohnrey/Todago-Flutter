import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_theme.dart';
import 'map_service.dart';
import 'panabo_config.dart';

class DropoffSelection {
  final String name;
  final LatLng point;

  const DropoffSelection({required this.name, required this.point});
}

ThemeData _pickerTheme() => ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(primary: AppColors.backgroundDark),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
    );

class DropoffPickerSheet extends StatefulWidget {
  final String title;
  final LatLng? locationBias;
  final DropoffSelection? initialSelection;

  const DropoffPickerSheet({
    super.key,
    required this.title,
    this.locationBias,
    this.initialSelection,
  });

  @override
  State<DropoffPickerSheet> createState() => _DropoffPickerSheetState();
}

class _DropoffPickerSheetState extends State<DropoffPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isSelecting = false;
  String? _message;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    ++_requestId;
    setState(() {
      _suggestions = [];
      _isSearching = false;
      _message = null;
    });
    if (value.trim().length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 350), _search);
    }
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.length < 2 || _isSelecting) return;
    final requestId = ++_requestId;
    setState(() {
      _isSearching = true;
      _suggestions = [];
      _message = null;
    });
    try {
      final suggestions = await MapService.searchPlaces(
        query,
        locationBias: widget.locationBias ?? PanaboConfig.cityCenter,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isSearching = false;
        _suggestions = suggestions;
        _message = suggestions.isEmpty
            ? 'No places found. Try another search or pin on the map.'
            : null;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isSearching = false;
        _message = 'Search is unavailable. You can still pin on the map.';
      });
    }
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    if (_isSelecting) return;
    _debounce?.cancel();
    ++_requestId;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSelecting = true;
      _isSearching = false;
      _message = null;
    });
    LatLng? point;
    try {
      point = await MapService.getPlaceLatLng(suggestion.placeId);
    } catch (_) {
      // Keep the picker open so the passenger can choose another location.
    }
    if (!mounted) return;
    if (point == null) {
      setState(() {
        _isSelecting = false;
        _message = 'Could not locate this place. Try another result or pin on '
            'the map.';
      });
      return;
    }
    final fullText = suggestion.fullText.trim();
    final fallback = [suggestion.mainText, suggestion.secondaryText]
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
    Navigator.of(context).pop(DropoffSelection(
      name: fullText.isNotEmpty ? fullText : fallback,
      point: point,
    ));
  }

  Future<void> _pinOnMap() async {
    _debounce?.cancel();
    ++_requestId;
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = false);
    final selected = await Navigator.of(context).push<DropoffSelection>(
      MaterialPageRoute(
        builder: (_) => DropoffMapScreen(
          title: widget.title,
          initialLocation: widget.locationBias,
          initialSelection: widget.initialSelection,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height - media.viewInsets.bottom - media.padding.top;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: availableHeight * 0.9),
          child: Theme(
            data: _pickerTheme(),
            child: Material(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: Text(widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.backgroundDark,
                            )),
                      ),
                      IconButton(
                        tooltip: 'Close drop-off picker',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_isSelecting,
                          textInputAction: TextInputAction.search,
                          onChanged: _onChanged,
                          onSubmitted: (_) => _search(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.backgroundDark,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search drop-off location',
                            filled: true,
                            fillColor: const Color(0xFFF5F6FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox.square(
                        dimension: 48,
                        child: IconButton.filled(
                          tooltip: 'Search drop-offs',
                          onPressed: _isSelecting ? null : _search,
                          icon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isSelecting ? null : _pinOnMap,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Pin on map'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    if (_isSearching || _isSelecting) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (_message != null || _suggestions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          _message ??
                              'Search for a place or pin the drop-off '
                                  'directly on the map.',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textHint),
                        ),
                      ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          enabled: !_isSelecting,
                          onTap: () => _select(suggestion),
                          leading: const Icon(Icons.location_on_rounded,
                              color: AppColors.primary),
                          title: Text(suggestion.mainText,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          subtitle: suggestion.secondaryText.isEmpty
                              ? null
                              : Text(suggestion.secondaryText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DropoffMapScreen extends StatefulWidget {
  final String title;
  final LatLng? initialLocation;
  final DropoffSelection? initialSelection;

  const DropoffMapScreen({
    super.key,
    required this.title,
    this.initialLocation,
    this.initialSelection,
  });

  @override
  State<DropoffMapScreen> createState() => _DropoffMapScreenState();
}

class _DropoffMapScreenState extends State<DropoffMapScreen> {
  GoogleMapController? _mapController;
  late LatLng? _point = widget.initialSelection?.point;
  late String? _name = widget.initialSelection?.name;
  int _requestId = 0;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _selectPoint(LatLng point) async {
    final requestId = ++_requestId;
    final fallback = 'Pinned drop-off (${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)})';
    setState(() {
      _point = point;
      _name = fallback;
    });
    try {
      final address = await MapService.reverseGeocode(point)
          .timeout(const Duration(seconds: 5));
      if (!mounted || requestId != _requestId) return;
      if (address.trim().isNotEmpty && address != 'Your Location') {
        setState(() => _name = address);
      }
    } catch (_) {
      // Coordinates are enough to confirm a pin if address lookup is offline.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _pickerTheme(),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _point ?? widget.initialLocation ?? PanaboConfig.cityCenter,
            zoom: 15.5,
          ),
          onMapCreated: (controller) => _mapController = controller,
          onTap: _selectPoint,
          markers: {
            if (_point != null)
              Marker(
                markerId: const MarkerId('dropoff'),
                position: _point!,
                draggable: true,
                onDragEnd: _selectPoint,
              ),
          },
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_name ?? 'Tap the map to pin this passenger\'s drop-off.'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _point == null
                      ? null
                      : () => Navigator.of(context).pop(DropoffSelection(
                            name: _name!,
                            point: _point!,
                          )),
                  child: const Text('Confirm drop-off'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
