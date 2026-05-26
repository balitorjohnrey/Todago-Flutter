import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'app_theme.dart';
import 'service_selection_screen.dart';
import 'map_service.dart';

class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key});
  @override
  State<DestinationPickerScreen> createState() =>
      _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen>
    with SingleTickerProviderStateMixin {
  // ── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  LatLng? _myLocation;
  LatLng? _destination;
  String _pickupName = 'Your Location';
  String _destName = '';
  MapRoute? _route;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // ── Search ────────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isRouting = false;
  bool _showSugg = false;
  bool _loadingLoc = true;
  Timer? _debounce;
  StreamSubscription<LatLng>? _locSub;
  DateTime? _lastRouteRefresh;
  DateTime? _lastReverseGeocode;

  // ── Voice search ──────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isProcessingVoice = false;
  String _voiceText = '';
  late AnimationController _micPulse;

  @override
  void initState() {
    super.initState();
    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _initLocation();
    _initSpeech();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locSub?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapCtrl?.dispose();
    _micPulse.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initLocation() async {
    // Wait for a real GPS fix before saving the passenger pickup point.
    LatLng? realPos;
    try {
      realPos = await MapService.getCurrentLocation()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Timed out or permission denied — keep default coords, no crash
      debugPrint('[Location] GPS timed out or unavailable');
    }

    if (!mounted) return;

    // ── Step 3: Smoothly update to real position if we got one ────────────
    if (realPos != null) {
      await _applyLivePickup(realPos, moveCamera: true, forceRoute: true);
    }

    // ── Step 4: Reverse-geocode in background (non-blocking) ─────────────
    if (realPos == null) {
      setState(() {
        _loadingLoc = false;
        _pickupName = 'Getting live location...';
      });
      _showSnack('Waiting for your live GPS location.');
    }

    _startLocationStream();
  }

  // ── Speech init ───────────────────────────────────────────────────────────
  void _startLocationStream() {
    _locSub?.cancel();
    _locSub = MapService.positionStream().listen(
      (pos) => _applyLivePickup(pos),
      onError: (_) {
        if (mounted) {
          setState(() => _loadingLoc = false);
        }
      },
    );
  }

  Future<void> _applyLivePickup(
    LatLng pos, {
    bool moveCamera = false,
    bool forceRoute = false,
  }) async {
    if (!mounted) return;
    final hadLocation = _myLocation != null;
    setState(() {
      _myLocation = pos;
      _loadingLoc = false;
    });
    _setMyMarker(pos);

    if (moveCamera || !hadLocation) {
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
    }

    final now = DateTime.now();
    if (_lastReverseGeocode == null ||
        now.difference(_lastReverseGeocode!) > const Duration(seconds: 30)) {
      _lastReverseGeocode = now;
      try {
        final address = await MapService.reverseGeocode(pos)
            .timeout(const Duration(seconds: 6));
        if (mounted) {
          setState(() => _pickupName = address);
          _setMyMarker(pos);
        }
      } catch (_) {
        debugPrint('[Location] Reverse geocode timed out');
      }
    }

    await _refreshRouteFromPickup(pos, force: forceRoute);
  }

  Future<void> _refreshRouteFromPickup(
    LatLng pickup, {
    bool force = false,
  }) async {
    final destination = _destination;
    if (destination == null || _isRouting) return;

    final now = DateTime.now();
    if (!force &&
        _lastRouteRefresh != null &&
        now.difference(_lastRouteRefresh!) < const Duration(seconds: 10)) {
      return;
    }
    _lastRouteRefresh = now;

    setState(() => _isRouting = true);
    final route = await MapService.fetchRoute(pickup, destination);
    if (!mounted) return;
    setState(() {
      _route = route;
      _isRouting = false;
    });
    if (route != null) {
      _setPolyline(route.points);
      if (force) _fitBounds(pickup, destination);
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        debugPrint('Speech error: $e');
        if (mounted) {
          setState(() {
            _isListening = false;
            _isProcessingVoice = false;
          });
        }
      },
      // FIX #1: Guard against premature onStatus fires.
      // 'notListening' can fire immediately on some devices when listening
      // first starts, before any audio is captured. Only process when we
      // were actually in the listening state.
      onStatus: (s) {
        debugPrint('Speech status: $s');
        if ((s == 'done' || s == 'notListening') && _isListening) {
          _onSpeechDone();
        }
      },
    );
    if (mounted) setState(() {});
  }

  // ── Markers / polyline ────────────────────────────────────────────────────
  void _setMyMarker(LatLng pos) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('my_location'),
          position: pos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(title: 'You', snippet: _pickupName),
        ),
        ..._markers.where((m) => m.markerId.value != 'my_location'),
      };
    });
  }

  void _setDestMarker(LatLng pos, String name) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('destination'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination', snippet: name),
        ),
        ..._markers.where((m) => m.markerId.value != 'destination'),
      };
    });
  }

  void _setPolyline(List<LatLng> pts) {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: pts,
          color: const Color(0xFF1A73E8),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });
  }

  // ── Text search ───────────────────────────────────────────────────────────
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSugg = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _showSugg = true;
    });
    final results = await MapService.searchPlaces(q, locationBias: _myLocation);
    if (mounted)
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
  }

  // ── Select suggestion ─────────────────────────────────────────────────────
  Future<void> _selectPlace(PlaceSuggestion place) async {
    _searchFocus.unfocus();
    setState(() {
      _showSugg = false;
      _suggestions = [];
      _isRouting = true;
      _searchCtrl.text = place.mainText;
      _destName = place.mainText;
    });
    final coords = await MapService.getPlaceLatLng(place.placeId);
    if (!mounted || coords == null) {
      setState(() => _isRouting = false);
      return;
    }
    setState(() => _destination = coords);
    _setDestMarker(coords, place.mainText);
    if (_myLocation != null) {
      _fitBounds(_myLocation!, coords);
      final route = await MapService.fetchRoute(_myLocation!, coords);
      if (mounted && route != null) {
        setState(() {
          _route = route;
          _isRouting = false;
        });
        _setPolyline(route.points);
      } else {
        setState(() => _isRouting = false);
      }
    } else {
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(coords, 14));
      setState(() => _isRouting = false);
    }
  }

  void _fitBounds(LatLng a, LatLng b) {
    try {
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(a.latitude < b.latitude ? a.latitude : b.latitude,
                a.longitude < b.longitude ? a.longitude : b.longitude),
            northeast: LatLng(a.latitude > b.latitude ? a.latitude : b.latitude,
                a.longitude > b.longitude ? a.longitude : b.longitude),
          ),
          80));
    } catch (_) {}
  }

  // ── VOICE COMMAND ─────────────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      _showSnack('Microphone not available on this device.');
      return;
    }

    // Stop if already listening
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    // FIX #2: Reset voice text and set flag BEFORE calling listen()
    // so the onStatus guard (_isListening check) works correctly.
    setState(() {
      _isListening = true;
      _voiceText = '';
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _voiceText = result.recognizedWords);

        // FIX #3: Some devices never fire onStatus='done'. Using
        // result.finalResult ensures _onSpeechDone always triggers.
        if (result.finalResult && _isListening) {
          _onSpeechDone();
        }
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      cancelOnError: true,
    );
  }

  // FIX #4: Single-fire guard — prevents duplicate voice processing from
  // simultaneous onStatus + result.finalResult triggers.
  void _onSpeechDone() {
    if (!mounted) return;
    if (!_isListening) return; // Already handled — bail out
    setState(() => _isListening = false);

    final text = _voiceText.trim();
    if (text.isNotEmpty) {
      _processVoiceDestination(text);
    } else {
      _showSnack('Nothing heard. Please try again.');
    }
  }

  // ── Voice destination extraction ──────────────────────────────────────────
  Future<void> _processVoiceDestination(String speech) async {
    if (_isProcessingVoice) return;
    setState(() => _isProcessingVoice = true);

    try {
      final destination = _extractDestinationSimple(speech);

      if (destination.isEmpty) {
        _showSnack('Could not understand destination. Try again.');
        setState(() => _isProcessingVoice = false);
        return;
      }

      // Update search bar and trigger search
      _searchCtrl.text = destination;
      setState(() {
        _isProcessingVoice = false;
        _showSugg = true;
        _isSearching = true;
      });

      final results =
          await MapService.searchPlaces(destination, locationBias: _myLocation);
      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _isSearching = false;
          _suggestions = [];
          _showSugg = false;
        });
        _showSnack('No places found for "$destination". Try again.');
        return;
      }

      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
      // Auto-select first result
      await _selectPlace(results.first);
    } catch (e) {
      debugPrint('processVoiceDestination error: $e');
      if (mounted) setState(() => _isProcessingVoice = false);
    }
  }

  // ── Simple keyword extraction fallback ────────────────────────────────────
  String _extractDestinationSimple(String text) {
    final patterns = [
      RegExp(
        r'(?:go to|going to|take me to|navigate to|bring me to|i want to go to|'
        r'head to|drive to|directions to|route to|book a ride to|ride to|'
        r'trip to|find)\s+(.+)',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final dest = _cleanDestination(m.group(1) ?? '');
        if (dest.isNotEmpty) return dest;
      }
    }

    return _cleanDestination(text);
  }

  String _cleanDestination(String value) {
    return value
        .replaceAll(
          RegExp(r'\b(i want|i need|please|can you|could you|book|ride|trip)\b',
              caseSensitive: false),
          '',
        )
        .replaceFirst(RegExp(r'^\s*(to|at|in)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: AppColors.backgroundDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Confirm ───────────────────────────────────────────────────────────────
  void _confirmDestination() {
    if (_destination == null) return;
    if (_myLocation == null) {
      _showSnack('Your live pickup location is still loading.');
      return;
    }
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => ServiceSelectionScreen(
        pickupName: _pickupName,
        destinationName: _destName,
        pickupLatLng: _myLocation,
        destinationLatLng: _destination,
        etaMinutes: _route?.etaMinutes,
        distanceKm: _route?.distanceKm,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  String _estimateFare(double km) =>
      (15 + (km * 5)).round().clamp(15, 300).toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ── Google Map ─────────────────────────────────────────────────────
        // Map shows immediately — no loading gate. GPS updates it in the background.
        Positioned.fill(
          child: GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: _myLocation ?? const LatLng(12.8797, 121.7740),
                  zoom: _myLocation == null ? 5 : 16),
              onMapCreated: (ctrl) {
                _mapCtrl = ctrl;
                if (_myLocation != null) {
                  ctrl.animateCamera(
                      CameraUpdate.newLatLngZoom(_myLocation!, 16));
                  _setMyMarker(_myLocation!);
                }
              },
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onTap: (_) {
                _searchFocus.unfocus();
                setState(() => _showSugg = false);
              }),
        ),

        // ── Top search panel ───────────────────────────────────────────────
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // Back button
                      GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.18),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2))
                                  ]),
                              child: const Icon(Icons.arrow_back_ios_rounded,
                                  color: Colors.black87, size: 18))),
                      const SizedBox(width: 10),

                      // Search bar
                      Expanded(
                          child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3))
                            ]),
                        child: Row(children: [
                          const SizedBox(width: 14),
                          const Icon(Icons.search_rounded,
                              color: Colors.black54, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.black,
                                fontWeight: FontWeight.w500),
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                                hintText: _isListening
                                    ? 'Listening...'
                                    : _isProcessingVoice
                                        ? 'Finding destination...'
                                        : 'Where to go?',
                                hintStyle: GoogleFonts.poppins(
                                    fontSize: 15,
                                    color: _isListening
                                        ? Colors.red.withOpacity(0.7)
                                        : _isProcessingVoice
                                            ? AppColors.primary.withOpacity(0.7)
                                            : Colors.black45),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.zero),
                          )),

                          // Clear button
                          if (_searchCtrl.text.isNotEmpty && !_isListening)
                            GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _suggestions = [];
                                    _showSugg = false;
                                    _destination = null;
                                    _route = null;
                                    _polylines = {};
                                    _markers = _markers
                                        .where((m) =>
                                            m.markerId.value != 'destination')
                                        .toSet();
                                  });
                                },
                                child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(Icons.close_rounded,
                                        color: Colors.black45, size: 18))),

                          // ── Voice mic button ───────────────────────────────────
                          GestureDetector(
                              onTap:
                                  _isProcessingVoice ? null : _toggleListening,
                              child: Container(
                                width: 42,
                                height: 42,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: _isListening
                                      ? Colors.red
                                      : _isProcessingVoice
                                          ? AppColors.primary
                                          : AppColors.backgroundDark,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (_isListening)
                                        AnimatedBuilder(
                                            animation: _micPulse,
                                            builder: (_, __) => Container(
                                                  width: 42 *
                                                      (0.8 +
                                                          0.2 *
                                                              _micPulse.value),
                                                  height: 42 *
                                                      (0.8 +
                                                          0.2 *
                                                              _micPulse.value),
                                                  decoration: BoxDecoration(
                                                      color: Colors.red
                                                          .withOpacity(0.3),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10)),
                                                )),
                                      _isProcessingVoice
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : Icon(
                                              _isListening
                                                  ? Icons.mic_rounded
                                                  : Icons.mic_none_rounded,
                                              color: Colors.white,
                                              size: 22),
                                    ]),
                              )),
                        ]),
                      )),
                    ]),

                    // ── Voice status banner ────────────────────────────────────
                    if (_isListening || _isProcessingVoice)
                      Container(
                        margin: const EdgeInsets.only(top: 8, left: 54),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: _isListening
                                ? Colors.red
                                : AppColors.backgroundDark,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_isListening) ...[
                            const Icon(Icons.mic_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                                _voiceText.isNotEmpty
                                    ? _voiceText
                                    : 'Say your destination...',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ] else ...[
                            const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary)),
                            const SizedBox(width: 8),
                            Text('Finding your destination...',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ]),
                      ).animate().fadeIn(duration: 200.ms),

                    // ── Suggestions list ───────────────────────────────────────
                    if (_showSugg)
                      Container(
                        margin: const EdgeInsets.only(top: 6, left: 54),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4))
                            ]),
                        child: _isSearching && _suggestions.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary))))
                            : _suggestions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text('No results found',
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.black54)))
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _suggestions.length,
                                    separatorBuilder: (_, __) => const Divider(
                                        height: 1, color: Color(0xFFF0F0F0)),
                                    itemBuilder: (_, i) {
                                      final s = _suggestions[i];
                                      return GestureDetector(
                                          onTap: () => _selectPlace(s),
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 12),
                                              child: Row(children: [
                                                Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                        color: AppColors.primary
                                                            .withOpacity(0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(9)),
                                                    child: const Icon(
                                                        Icons
                                                            .location_on_rounded,
                                                        color:
                                                            AppColors.primary,
                                                        size: 18)),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                      Text(s.mainText,
                                                          style: GoogleFonts
                                                              .poppins(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .black87)),
                                                      if (s.secondaryText
                                                          .isNotEmpty)
                                                        Text(s.secondaryText,
                                                            style: GoogleFonts
                                                                .poppins(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .black45),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis),
                                                    ])),
                                                const Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: Colors.black26,
                                                    size: 18),
                                              ])));
                                    }),
                      ).animate().fadeIn(duration: 200.ms),
                  ]),
            ))),

        // ── Voice hint bubble ───────────────────────────────────────────────
        if (!_loadingLoc &&
            _destination == null &&
            !_isListening &&
            !_isProcessingVoice)
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Center(
                child: GestureDetector(
                    onTap: _toggleListening,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 12)
                          ]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.mic_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Tap mic or say your destination',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ))),
          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3, end: 0),

        // ── Routing indicator ──────────────────────────────────────────────
        if (_isRouting)
          Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Center(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8)
                          ]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary)),
                        const SizedBox(width: 10),
                        Text('Getting road route...',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ])))),

        // ── Bottom route card ──────────────────────────────────────────────
        if (_destination != null)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, -4))
                    ]),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 14),

                  // Route A → B card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEEEEEE))),
                    child: Column(children: [
                      Row(children: [
                        Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.backgroundDark,
                                    width: 2))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('FROM',
                                  style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.black45,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w700)),
                              Text(_pickupName,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ])),
                      ]),
                      Padding(
                          padding: const EdgeInsets.only(left: 4.5),
                          child: Column(
                              children: List.generate(
                                  3,
                                  (_) => Container(
                                      width: 1.5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      color: Colors.grey[300])))),
                      Row(children: [
                        Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                                color: AppColors.backgroundDark,
                                borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('TO',
                                  style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.black45,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w700)),
                              Text(_destName,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ])),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Stats row
                  if (_route != null)
                    Row(children: [
                      _statBox(
                          '${_route!.etaMinutes} min',
                          _route!.durationText.isNotEmpty
                              ? _route!.durationText
                              : 'ETA',
                          Icons.schedule_rounded,
                          AppColors.primary),
                      const SizedBox(width: 8),
                      _statBox(
                          '${_route!.distanceKm.toStringAsFixed(1)} km',
                          _route!.distanceText.isNotEmpty
                              ? _route!.distanceText
                              : 'Distance',
                          Icons.route_rounded,
                          Colors.blue),
                      const SizedBox(width: 8),
                      _statBox('~₱${_estimateFare(_route!.distanceKm)}',
                          'Est. Fare', Icons.payments_rounded, Colors.green),
                    ])
                  else if (_isRouting)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary)),
                              const SizedBox(width: 10),
                              Text('Calculating route...',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: Colors.black54)),
                            ])),

                  const SizedBox(height: 12),

                  // Confirm button
                  SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                          onPressed: _isRouting ? null : _confirmDestination,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.backgroundDark,
                              disabledBackgroundColor:
                                  AppColors.backgroundDark.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.electric_rickshaw_rounded,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text('Confirm Destination',
                                    style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ]))),
                ]),
              ).animate().slideY(
                  begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut)),
      ]),
    );
  }

  Widget _statBox(String value, String label, IconData icon, Color color) =>
      Expanded(
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2))),
              child: Column(children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(height: 4),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87)),
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.black45)),
              ])));
}
