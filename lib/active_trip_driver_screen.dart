import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'contact_service.dart';
import 'trip_service.dart';
import 'driver_dashboard_screen.dart';
import 'map_service.dart';
import 'report_issue_dialog.dart';

class ActiveTripDriverScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const ActiveTripDriverScreen({super.key, required this.trip});

  @override
  State<ActiveTripDriverScreen> createState() => _ActiveTripDriverScreenState();
}

class _ActiveTripDriverScreenState extends State<ActiveTripDriverScreen> {
  late Map<String, dynamic> _trip;
  GoogleMapController? _mapCtrl;
  LatLng? _myLocation;
  LatLng? _destPoint;
  MapRoute? _route;
  bool _isCompleting = false;
  bool _isDroppingPassenger = false;
  bool _isFetchingRoute = false;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  StreamSubscription<LatLng>? _locSub;
  Timer? _routeRefreshTimer;
  Timer? _tripPollTimer;
  DateTime? _lastLocationSync;
  DateTime? _lastRouteFetch;
  LatLng? _lastRouteFrom;
  LatLng? _lastRouteTo;

  // ── Getters ──────────────────────────────────────────────────────────────
  String get _passengerName =>
      _trip['commuter_name']?.toString() ?? 'Passenger';
  String? get _passengerPhone => _trip['commuter_phone']?.toString();
  String get _destination =>
      _currentDropoff?['location']?.toString() ??
      _trip['destination']?.toString() ??
      'Destination';
  String get _passengerInitials => _passengerName
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();
  double get _fare {
    final f = _trip['fare'];
    if (f == null) return 25.0;
    if (f is double) return f;
    if (f is int) return f.toDouble();
    return double.tryParse(f.toString()) ?? 25.0;
  }

  double get _driverEarnings => _fare;

  bool get _isSharedTrip => _trip['service_type']?.toString() == 'shared';

  List<dynamic> get _sharedDropoffs {
    final raw = _trip['shared_dropoffs'];
    return raw is List ? raw : const [];
  }

  Map<String, dynamic>? get _currentDropoff {
    for (final dropoff in _sharedDropoffs) {
      if (dropoff is Map && dropoff['status'] != 'dropped') {
        return Map<String, dynamic>.from(dropoff);
      }
    }
    return null;
  }

  int get _remainingPassengers {
    final value = _trip['remaining_passenger_count'];
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ??
        (_sharedDropoffs.isNotEmpty ? _sharedDropoffs.length : 0);
  }

  bool get _hasPendingSharedDropoffs =>
      _isSharedTrip && _sharedDropoffs.isNotEmpty && _remainingPassengers > 0;

  LatLng? _currentDestinationPoint() {
    final dropoff = _currentDropoff;
    final dropLat = double.tryParse(dropoff?['lat']?.toString() ?? '');
    final dropLng = double.tryParse(dropoff?['lng']?.toString() ?? '');
    if (dropLat != null && dropLng != null) {
      return LatLng(dropLat, dropLng);
    }

    final destLat = double.tryParse(_trip['destination_lat']?.toString() ?? '');
    final destLng = double.tryParse(_trip['destination_lng']?.toString() ?? '');
    if (destLat != null && destLng != null) {
      return LatLng(destLat, destLng);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _trip = Map<String, dynamic>.from(widget.trip);
    _init();
  }

  // ── Initialization ────────────────────────────────────────────────────────
  Future<void> _init() async {
    final loc = await MapService.getCurrentLocation();
    if (!mounted) return;

    if (loc == null) {
      final destPos = _currentDestinationPoint();
      if (destPos != null) {
        setState(() => _destPoint = destPos);
      }
      _startLocationStream();
      _routeRefreshTimer =
          Timer.periodic(const Duration(seconds: 30), (_) async {
        if (!mounted || _myLocation == null || _destPoint == null) return;
        await _fetchAndDrawRoute(_myLocation!, _destPoint!);
      });
      if ((_trip['trip_id']?.toString() ?? '').isNotEmpty) {
        _tripPollTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => _pollTripStatus(),
        );
      }
      return;
    }
    final myPos = loc;

    // Resolve destination coords from trip data
    final destPos = _currentDestinationPoint();

    setState(() {
      _myLocation = myPos;
      _destPoint = destPos;
    });

    _syncDriverLocation(myPos, force: true);
    if (destPos != null) {
      _updateMarkers(myPos, destPos);
      await _fetchAndDrawRoute(myPos, destPos, force: true);
      _fitBounds(myPos, destPos);
    } else {
      _updateDriverMarker(myPos);
    }

    // ── Live driver position stream ───────────────────────────────────────
    _startLocationStream();

    // ── Periodic route refresh as backup ─────────────────────────────────
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted || _myLocation == null || _destPoint == null) return;
      await _fetchAndDrawRoute(_myLocation!, _destPoint!);
    });

    if ((_trip['trip_id']?.toString() ?? '').isNotEmpty) {
      _tripPollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pollTripStatus(),
      );
    }
  }

  // ── Route helper ──────────────────────────────────────────────────────────
  void _startLocationStream() {
    _locSub?.cancel();
    _locSub = MapService.positionStream().listen((pos) async {
      if (!mounted) return;
      setState(() => _myLocation = pos);
      _updateDriverMarker(pos);
      _syncDriverLocation(pos);

      if (_destPoint != null && !_isFetchingRoute) {
        await _fetchAndDrawRoute(pos, _destPoint!);
      }
    });
  }

  void _syncDriverLocation(LatLng pos, {bool force = false}) {
    final tripId = _trip['trip_id']?.toString() ?? '';
    if (tripId.isEmpty) return;
    final now = DateTime.now();
    if (!force &&
        _lastLocationSync != null &&
        now.difference(_lastLocationSync!) < const Duration(seconds: 5)) {
      return;
    }
    _lastLocationSync = now;
    TripService.updateDriverLocation(tripId, pos);
  }

  Future<void> _fetchAndDrawRoute(
    LatLng from,
    LatLng to, {
    bool force = false,
  }) async {
    if (_isFetchingRoute) return;
    if (!force && !_shouldRefreshRoute(from, to)) return;

    _isFetchingRoute = true;
    try {
      final route = await MapService.fetchRoute(from, to);
      if (mounted && route != null) {
        _lastRouteFetch = DateTime.now();
        _lastRouteFrom = from;
        _lastRouteTo = to;
        setState(() => _route = route);
        _updatePolyline(route.points);
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  bool _shouldRefreshRoute(LatLng from, LatLng to) {
    final lastFetch = _lastRouteFetch;
    final lastFrom = _lastRouteFrom;
    final lastTo = _lastRouteTo;
    if (lastFetch == null || lastFrom == null || lastTo == null) return true;

    final elapsed = DateTime.now().difference(lastFetch);
    final movedMeters = _approxDistanceMeters(lastFrom, from);
    final destChangedMeters = _approxDistanceMeters(lastTo, to);

    if (destChangedMeters > 25) return true;
    if (movedMeters >= 60) return true;
    return elapsed >= const Duration(seconds: 30);
  }

  double _approxDistanceMeters(LatLng a, LatLng b) {
    const metersPerDegreeLat = 111320.0;
    final latMeters = (a.latitude - b.latitude).abs() * metersPerDegreeLat;
    final lngMeters =
        (a.longitude - b.longitude).abs() * metersPerDegreeLat * 0.99;
    return latMeters + lngMeters;
  }

  void _updateMarkers(LatLng driver, LatLng dest) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'You (Driver)'),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: dest,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination', snippet: _destination),
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
          infoWindow: const InfoWindow(title: 'You (Driver)'),
        ),
      };
    });
  }

  // ── Blue road-following polyline (same as destination_picker) ─────────────
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

  @override
  void dispose() {
    _locSub?.cancel();
    _routeRefreshTimer?.cancel();
    _tripPollTimer?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _pollTripStatus() async {
    final tripId = _trip['trip_id']?.toString() ?? '';
    if (tripId.isEmpty || !mounted) return;
    final trip = await TripService.getTripById(tripId, forDriver: true);
    if (!mounted || trip == null) return;
    setState(() {
      _trip = Map<String, dynamic>.from(trip);
      _destPoint = _currentDestinationPoint();
    });
    if (trip['status']?.toString() == 'cancelled') {
      _showPassengerCancelled();
    }
  }

  Future<void> _showPassengerCancelled() async {
    _locSub?.cancel();
    _routeRefreshTimer?.cancel();
    _tripPollTimer?.cancel();
    await TripService.updateDriverStatus('online', location: _myLocation);
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Trip Cancelled',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('The passenger cancelled this trip.',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.backgroundDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Back to Dashboard',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
      (_) => false,
    );
  }

  Future<void> _dropPassenger() async {
    if (_isDroppingPassenger) return;
    final tripId = _trip['trip_id']?.toString() ?? '';
    if (tripId.isEmpty) return;

    setState(() => _isDroppingPassenger = true);
    final result = await TripService.markSharedPassengerDropped(tripId);
    if (!mounted) return;
    setState(() => _isDroppingPassenger = false);

    if (result['success'] == true) {
      final updatedTrip = result['trip'];
      if (updatedTrip is Map<String, dynamic>) {
        setState(() {
          _trip = Map<String, dynamic>.from(updatedTrip);
          _destPoint = _currentDestinationPoint();
          _route = null;
          _polylines = {};
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Passenger dropped.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      if (_myLocation != null && _destPoint != null) {
        _updateMarkers(_myLocation!, _destPoint!);
        await _fetchAndDrawRoute(_myLocation!, _destPoint!, force: true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Could not mark dropoff.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _reportPassenger({String? initialType}) {
    showReportIssueDialog(
      context: context,
      reporterRole: 'driver',
      initialType: initialType ?? 'passenger_issue',
      tripId: _trip['trip_id']?.toString(),
      subjectRole: 'passenger',
      subjectId: _trip['commuter_id']?.toString(),
      subjectName: _passengerName,
      metadata: {
        'service_type': _trip['service_type']?.toString(),
        'destination': _destination,
      },
    );
  }

  Future<void> _completeTrip() async {
    if (_hasPendingSharedDropoffs) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Drop the remaining $_remainingPassengers passenger${_remainingPassengers == 1 ? '' : 's'} first.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _isCompleting = true);
    final tripId = _trip['trip_id']?.toString() ?? '';
    Map<String, dynamic> result = {'success': false};
    if (tripId.isNotEmpty) {
      result = await TripService.updateTripStatus(tripId, 'completed');
    }
    if (!mounted) return;
    setState(() => _isCompleting = false);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Could not complete trip.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final earnings = result['earnings'];
    double parseFare(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    final actualEarnings = earnings != null
        ? parseFare(earnings['your_earnings'], _driverEarnings)
        : _driverEarnings;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'Trip Completed! 🎉',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Thank you for the ride, $_passengerName!',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              _earningsRow('Passenger Fare', '₱${_fare.toStringAsFixed(2)}',
                  Colors.black),
              const Divider(height: 16),
              _earningsRow('Your Earnings',
                  '₱${actualEarnings.toStringAsFixed(2)}', Colors.green,
                  bold: true, large: true),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const DriverDashboardScreen(),
                    transitionDuration: const Duration(milliseconds: 500),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
                  (_) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.backgroundDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0),
              child: Text(
                'Back to Dashboard',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _earningsRow(String label, String value, Color valueColor,
          {bool bold = false, bool large = false}) =>
      Row(children: [
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: large ? 18 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor)),
      ]);

  @override
  Widget build(BuildContext context) {
    // Always reflect live _route data for ETA/distance
    final eta = _route?.etaMinutes ?? 10;
    final dist = _route?.distanceKm ?? 2.0;

    return Scaffold(
      body: Stack(children: [
        // ── Map ────────────────────────────────────────────────────────────
        Positioned.fill(
          child: _myLocation == null
              ? Container(
                  color: const Color(0xFFE8EFF5),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ))
              : GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _myLocation!, zoom: 15),
                  onMapCreated: (ctrl) {
                    _mapCtrl = ctrl;
                    if (_myLocation != null && _destPoint != null) {
                      _fitBounds(_myLocation!, _destPoint!);
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

        // ── Top card ───────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: Colors.green, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TRIP IN PROGRESS',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      // Live distance + time from _route
                      Row(children: [
                        _navStat('${dist.toStringAsFixed(1)} km', 'Distance'),
                        const SizedBox(width: 24),
                        _navStat('$eta min', 'Time Left'),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            if (_myLocation != null && _destPoint != null) {
                              _fitBounds(_myLocation!, _destPoint!);
                            }
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.my_location_rounded,
                                size: 18, color: Colors.black54),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.flag_rounded,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _destination,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.backgroundDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Passenger row
                Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _passengerInitials,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.backgroundDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _passengerName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.backgroundDark,
                            ),
                          ),
                          Row(children: [
                            const Icon(Icons.verified_rounded,
                                color: Colors.green, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'Verified Passenger',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: AppColors.textHint),
                            ),
                          ]),
                        ]),
                  ),
                ]),
                const SizedBox(height: 14),

                // Call / Message buttons
                Row(children: [
                  Expanded(
                      child: _actionBtn(Icons.phone_rounded, 'Call',
                          Colors.green, () => _contactPassenger(call: true))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _actionBtn(
                          Icons.chat_bubble_rounded,
                          'Message',
                          AppColors.primary,
                          () => _contactPassenger(call: false))),
                ]),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(
                    child: _actionBtn(
                      Icons.report_problem_rounded,
                      'Report',
                      AppColors.error,
                      () => _reportPassenger(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionBtn(
                      Icons.block_rounded,
                      'Blacklist',
                      AppColors.error,
                      () => _reportPassenger(
                        initialType: 'blacklist_passenger',
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // Stats row — live from _route
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _tripStat('$eta min', 'Time Left',
                            Icons.schedule_rounded, AppColors.primary),
                        _divV(),
                        _tripStat('${dist.toStringAsFixed(1)} km', 'Distance',
                            Icons.route_rounded, Colors.blue),
                        _divV(),
                        _tripStat('₱${_driverEarnings.toStringAsFixed(0)}',
                            'Earnings', Icons.payments_rounded, Colors.green),
                      ]),
                ),
                const SizedBox(height: 16),

                if (_hasPendingSharedDropoffs) ...[
                  GestureDetector(
                    onTap: _isDroppingPassenger ? null : _dropPassenger,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _isDroppingPassenger
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.backgroundDark,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person_remove_rounded,
                                  color: AppColors.backgroundDark,
                                  size: 22,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Drop Passenger',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.backgroundDark,
                                ),
                              ),
                              Text(
                                '$_remainingPassengers remaining in this shared ride',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color:
                                      AppColors.backgroundDark.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Complete Trip button
                GestureDetector(
                  onTap: _isCompleting ? null : _completeTrip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isCompleting
                          ? Colors.green.withOpacity(0.7)
                          : Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10)),
                        child: _isCompleting
                            ? const Center(
                                child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              ))
                            : const Icon(Icons.check_rounded,
                                color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Complete Trip',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Tap when passenger reaches destination',
                                style: GoogleFonts.poppins(
                                    fontSize: 10, color: Colors.white70),
                              ),
                            ]),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ).animate().slideY(
              begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut),
        ),
      ]),
    );
  }

  Widget _navStat(String v, String l) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v,
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.backgroundDark)),
        Text(l,
            style:
                GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
      ]);

  Widget _actionBtn(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );

  Future<void> _contactPassenger({required bool call}) async {
    final ok = call
        ? await ContactService.call(_passengerPhone)
        : await ContactService.message(
            _passengerPhone,
            body: 'Hi, this is your TodaGo driver.',
          );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Passenger phone number is not available.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _tripStat(String v, String l, IconData icon, Color color) => Expanded(
        child: Column(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(v,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark)),
          Text(l,
              style:
                  GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
        ]),
      );

  Widget _divV() =>
      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));
}
