import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'live_trip_tracking_screen.dart';
import 'passenger_home_screen.dart';
import 'map_service.dart';

class PassengerWaitingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final double driverRating;
  final String todaBodyNumber;
  final String plateNo;
  final int etaMinutes;
  final double distanceKm;
  final double fare;
  final String serviceType;

  /// Passed from DestinationPickerScreen → ServiceSelectionScreen so that
  /// LiveTripTrackingScreen can switch its polyline from driver→passenger
  /// to current_location→destination once the driver confirms pickup arrival.
  final LatLng? destinationLatLng; // ← NEW
  final String? destinationName; // ← NEW (display name)

  const PassengerWaitingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverRating,
    required this.todaBodyNumber,
    required this.plateNo,
    required this.etaMinutes,
    required this.distanceKm,
    required this.fare,
    required this.serviceType,
    this.destinationLatLng, // ← NEW
    this.destinationName, // ← NEW
  });

  @override
  State<PassengerWaitingScreen> createState() => _PassengerWaitingScreenState();
}

class _PassengerWaitingScreenState extends State<PassengerWaitingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  GoogleMapController? _mapCtrl;
  LatLng? _myLocation;
  LatLng? _driverPos;
  MapRoute? _route;
  bool _isFetchingRoute = false;
  bool _isNavigating = false;
  bool _isCancelling = false;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Timer? _pollTimer;
  Timer? _routeRefreshTimer;
  Timer? _dotsTimer;
  Timer? _waitTimer;
  StreamSubscription<LatLng>? _locSub;

  int _dotsCount = 1;
  int _waitSeconds = 0;

  int get _liveEta => _route?.etaMinutes ?? widget.etaMinutes;
  double get _liveDist => _route?.distanceKm ?? widget.distanceKm;

  String get _initials => widget.driverName
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();
  String get _waitTime => _waitSeconds < 60
      ? '${_waitSeconds}s'
      : '${_waitSeconds ~/ 60}m ${_waitSeconds % 60}s';

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _dotsCount = (_dotsCount % 3) + 1);
    });
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _waitSeconds++);
    });
    _init();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
    Future.delayed(const Duration(seconds: 1), _checkStatus);
  }

  // ── Initialization ────────────────────────────────────────────────────────
  Future<void> _init() async {
    final loc = await MapService.getCurrentLocation();
    if (!mounted) return;

    if (loc != null) {
      setState(() => _myLocation = loc);
      _updatePassengerMarker(loc);
    }

    await _checkStatus();

    _locSub = MapService.positionStream().listen((pos) async {
      if (!mounted) return;
      setState(() => _myLocation = pos);
      _updatePassengerMarker(pos);
      if (_driverPos != null && !_isFetchingRoute) {
        await _fetchAndDrawRoute(_driverPos!, pos);
      }
    });

    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || _driverPos == null || _myLocation == null) return;
      await _fetchAndDrawRoute(_driverPos!, _myLocation!);
    });
  }

  // ── Route helper ──────────────────────────────────────────────────────────
  Future<void> _fetchAndDrawRoute(LatLng from, LatLng to) async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;
    try {
      final route = await MapService.fetchRoute(from, to);
      if (mounted && route != null) {
        setState(() => _route = route);
        _updatePolyline(route.points);
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  void _updateMarkers(LatLng passenger, LatLng driver) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('passenger'),
          position: passenger,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: 'You'),
        ),
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow:
              InfoWindow(title: widget.driverName, snippet: 'Coming to you'),
        ),
      };
    });
  }

  void _updatePassengerMarker(LatLng pos) {
    setState(() {
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'passenger'),
        Marker(
          markerId: const MarkerId('passenger'),
          position: pos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      };
    });
  }

  void _updateDriverMarker(LatLng pos) {
    setState(() {
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'driver'),
        Marker(
          markerId: const MarkerId('driver'),
          position: pos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow:
              InfoWindow(title: widget.driverName, snippet: 'Coming to you'),
        ),
      };
    });
  }

  void _updatePolyline(List<LatLng> pts) {
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

  void _fitBounds(LatLng a, LatLng b) {
    final bounds = LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ── Status polling ────────────────────────────────────────────────────────
  Future<void> _checkStatus() async {
    if (_isNavigating || !mounted) return;
    try {
      final trip = await TripService.getActiveTrip();
      if (!mounted || _isNavigating) return;
      if (trip != null) {
        final status = trip['status']?.toString() ?? '';

        // Update driver marker from server coords
        final driverLat = double.tryParse(trip['driver_lat']?.toString() ?? '');
        final driverLng = double.tryParse(trip['driver_lng']?.toString() ?? '');
        if (driverLat != null && driverLng != null) {
          final newDriverPos = LatLng(driverLat, driverLng);
          setState(() => _driverPos = newDriverPos);
          final passengerPos = _myLocation;
          if (passengerPos != null) {
            _updateMarkers(passengerPos, newDriverPos);
            if (!_isFetchingRoute) {
              await _fetchAndDrawRoute(newDriverPos, passengerPos);
            }
          } else {
            _updateDriverMarker(newDriverPos);
          }
        }

        if (status == 'accepted' || status == 'pickup' || status == 'ongoing') {
          _isNavigating = true;
          _stopTimers();

          // ── Resolve destination coords ─────────────────────────────────
          // Prefer the coords passed from DestinationPickerScreen.
          // Fall back to whatever the trip response provides.
          LatLng? destLatLng = widget.destinationLatLng;
          if (destLatLng == null) {
            final dLat =
                double.tryParse(trip['destination_lat']?.toString() ?? '');
            final dLng =
                double.tryParse(trip['destination_lng']?.toString() ?? '');
            if (dLat != null && dLng != null) {
              destLatLng = LatLng(dLat, dLng);
            }
          }

          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => LiveTripTrackingScreen(
                tripId: trip['trip_id']?.toString() ?? widget.tripId,
                driverName:
                    trip['driver_name']?.toString() ?? widget.driverName,
                driverPhone: trip['driver_phone']?.toString(),
                driverRating: widget.driverRating,
                todaBodyNumber: trip['toda_body_number']?.toString() ??
                    widget.todaBodyNumber,
                plateNo: trip['plate_no']?.toString() ?? widget.plateNo,
                etaMinutes: _liveEta,
                distanceKm: _liveDist,
                // ── Pass destination through so LiveTripTrackingScreen ──
                // can switch the polyline when the driver confirms pickup.
                destinationLatLng: destLatLng, // ← NEW
                destination: widget.destinationName ?? // ← NEW
                    trip['destination']?.toString(),
              ),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        } else if (status == 'cancelled') {
          _isNavigating = true;
          _stopTimers();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Driver declined. Please try again.',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
            (_) => false,
          );
        }
      }
    } catch (_) {}
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _dotsTimer?.cancel();
    _waitTimer?.cancel();
    _locSub?.cancel();
  }

  Future<void> _cancelRide() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    _stopTimers();
    if (widget.tripId.isNotEmpty) {
      await TripService.cancelPassengerTrip(widget.tripId);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PassengerHomeScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _stopTimers();
    _pulseCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ── Map ────────────────────────────────────────────────────────────
        Positioned.fill(
          child: _myLocation == null
              ? Container(
                  color: const Color(0xFFE8EFF5),
                  child: const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)))
              : GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _myLocation!, zoom: 15),
                  onMapCreated: (ctrl) {
                    _mapCtrl = ctrl;
                    if (_driverPos != null && _myLocation != null) {
                      _fitBounds(_driverPos!, _myLocation!);
                    }
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
        ),

        // ── Top status bar ─────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(31),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(
                          (102 + (153 * _pulseCtrl.value).round())
                              .clamp(0, 255),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waiting for driver${'.' * _dotsCount}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.backgroundDark,
                        ),
                      ),
                      Text(
                        'Wait time: $_waitTime',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (_driverPos != null && _myLocation != null) {
                        _fitBounds(_driverPos!, _myLocation!);
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          size: 16, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_liveEta min',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),

        // ── Bottom card ────────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4))
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Driver row
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(_initials,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        )),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.driverName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.backgroundDark,
                          )),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 3),
                        Text(widget.driverRating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.backgroundDark,
                                fontWeight: FontWeight.w600)),
                      ]),
                      if (widget.todaBodyNumber.isNotEmpty)
                        Text(widget.todaBodyNumber,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textHint)),
                      if (widget.plateNo.isNotEmpty)
                        Text('Plate: ${widget.plateNo}',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withAlpha(77)),
                  ),
                  child: Text('Waiting',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange,
                      )),
                ),
              ]),
              const SizedBox(height: 16),

              // Distance / ETA / Fare
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Row(children: [
                  _info('${_liveDist.toStringAsFixed(1)} km', 'Distance',
                      Icons.route_rounded),
                  _divV(),
                  _info('$_liveEta min', 'ETA', Icons.schedule_rounded),
                  _divV(),
                  _info('₱${widget.fare.toStringAsFixed(0)}', 'Fare',
                      Icons.payments_rounded),
                ]),
              ),
              const SizedBox(height: 12),

              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text('Checking every 4 seconds...',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint)),
              ]),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _isCancelling ? null : _cancelRide,
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Cancel Ride',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          )),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _info(String v, String l, IconData icon) => Expanded(
        child: Column(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(v,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark)),
          Text(l,
              style:
                  GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
        ]),
      );

  Widget _divV() =>
      Container(width: 1, height: 40, color: const Color(0xFFEEEEEE));
}
