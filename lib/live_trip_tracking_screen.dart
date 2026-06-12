import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'contact_service.dart';
import 'trip_service.dart';
import 'passenger_home_screen.dart';
import 'rate_driver_screen.dart';
import 'map_service.dart';
import 'report_issue_dialog.dart';

class LiveTripTrackingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final double driverRating;
  final String todaBodyNumber;
  final String plateNo;
  final String? driverPhone;
  final int? etaMinutes;
  final double? distanceKm;
  final String? destination;
  final double? fare;

  /// Destination coordinates passed from DestinationPickerScreen → ServiceSelectionScreen
  /// → PassengerWaitingScreen → here. Used to draw the route once the driver
  /// arrives at the pickup location and the trip phase switches to "riding".
  final LatLng? destinationLatLng;

  const LiveTripTrackingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverRating,
    required this.todaBodyNumber,
    required this.plateNo,
    this.driverPhone,
    required this.etaMinutes,
    required this.distanceKm,
    this.destination,
    this.fare,
    this.destinationLatLng, // ← NEW
  });

  @override
  State<LiveTripTrackingScreen> createState() => _LiveTripTrackingScreenState();
}

class _LiveTripTrackingScreenState extends State<LiveTripTrackingScreen> {
  GoogleMapController? _mapCtrl;
  LatLng? _myLocation;
  LatLng? _driverPos;
  LatLng? _destPoint; // ← NEW: destination coords for riding phase
  MapRoute? _route;
  String _tripStatus = 'accepted';
  bool _isFetchingRoute = false;

  // ── Phase ─────────────────────────────────────────────────────────────────
  // 'approaching' : driver navigating to the passenger pickup point
  //                 polyline = driver → passenger
  // 'riding'      : passenger is in the vehicle, heading to destination
  //                 polyline = current location → destination
  String _phase = 'approaching'; // ← NEW

  String _destination = '';
  String? _driverPhone;
  double _fare = 0;
  Map<String, dynamic>? _latestTrip;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Timer? _pollTimer;
  Timer? _routeRefreshTimer;
  StreamSubscription<LatLng>? _locSub;

  int? get _liveEta => _route?.etaMinutes ?? widget.etaMinutes;
  double? get _liveDist => _route?.distanceKm ?? widget.distanceKm;
  String get _liveEtaText => _liveEta == null ? 'Locating' : '$_liveEta min';
  String get _liveDistText =>
      _liveDist == null ? 'GPS pending' : '${_liveDist!.toStringAsFixed(1)} km';

  @override
  void initState() {
    super.initState();
    _destination = widget.destination ?? '';
    _driverPhone = widget.driverPhone;
    _fare = widget.fare ?? 0;
    _destPoint = widget.destinationLatLng; // store destination coords early
    _init();
  }

  // ── Initialise map, location, timers ─────────────────────────────────────
  Future<void> _init() async {
    final loc = await MapService.getCurrentLocation();
    if (!mounted) return;
    if (loc != null) {
      setState(() => _myLocation = loc);
      _updatePassengerMarker(loc);
    }

    // Initial: driver approaching → show driver + passenger markers, route driver→passenger
    await _pollTrip();

    // ── Live passenger position stream ────────────────────────────────────
    _locSub = MapService.positionStream().listen((pos) async {
      if (!mounted) return;
      setState(() => _myLocation = pos);

      if (_phase == 'approaching') {
        _updatePassengerMarker(pos);
        if (_driverPos != null && !_isFetchingRoute) {
          await _fetchAndDrawRoute(_driverPos!, pos);
        }
      } else {
        // Riding phase: update current-location marker, route to destination
        _updateCurrentLocationMarker(pos);
        if (_destPoint != null && !_isFetchingRoute) {
          await _fetchAndDrawRoute(pos, _destPoint!);
        }
      }
    });

    if (widget.tripId.isNotEmpty) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted) return;
        await _pollTrip();
      });
    }

    // ── Periodic route refresh every 10 s ────────────────────────────────
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      if (_phase == 'approaching') {
        if (_driverPos == null || _myLocation == null) return;
        await _fetchAndDrawRoute(_driverPos!, _myLocation!);
      } else {
        if (_myLocation == null || _destPoint == null) return;
        await _fetchAndDrawRoute(_myLocation!, _destPoint!);
      }
    });
  }

  // ── Poll trip status & driver position ───────────────────────────────────
  Future<void> _pollTrip() async {
    try {
      final trip = await TripService.getActiveTrip();
      if (!mounted) return;
      if (trip == null) {
        _pollTimer?.cancel();
        _checkIfCompleted();
        return;
      }
      _latestTrip = trip;

      // Update text fields from server
      if (trip['destination'] != null &&
          trip['destination'].toString().isNotEmpty) {
        _destination = trip['destination'].toString();
      }
      if (trip['fare'] != null) {
        _fare = double.tryParse(trip['fare'].toString()) ?? _fare;
      }
      if (trip['driver_phone'] != null) {
        _driverPhone = trip['driver_phone'].toString();
      }

      // ── Grab destination coords from trip data if not yet set ─────────
      // The backend includes destination_lat / destination_lng in the trip
      // response (same fields used by ActiveTripDriverScreen).
      if (_destPoint == null) {
        final dLat = double.tryParse(trip['destination_lat']?.toString() ?? '');
        final dLng = double.tryParse(trip['destination_lng']?.toString() ?? '');
        if (dLat != null && dLng != null) {
          setState(() => _destPoint = LatLng(dLat, dLng));
        }
      }

      final status = trip['status']?.toString() ?? '';

      // ── Phase switch: 'pickup' = driver confirmed arrival at passenger ─
      // Switch to riding phase immediately so the map shows
      // current location → destination.
      if ((status == 'pickup' || status == 'ongoing') &&
          _phase == 'approaching') {
        setState(() => _tripStatus = status);
        _switchToRidingPhase();
        return; // skip driver-marker update; we no longer need it
      }

      if (status != _tripStatus) {
        setState(() => _tripStatus = status);
        if (status == 'completed') {
          _pollTimer?.cancel();
          _navigateToRating();
          return;
        }
        if (status == 'cancelled') {
          _pollTimer?.cancel();
          _showCancelled();
          return;
        }
      }

      // ── Update driver marker only in approaching phase ────────────────
      if (_phase == 'approaching') {
        final driverLat = double.tryParse(trip['driver_lat']?.toString() ?? '');
        final driverLng = double.tryParse(trip['driver_lng']?.toString() ?? '');
        if (driverLat != null && driverLng != null) {
          final newDriverPos = LatLng(driverLat, driverLng);
          setState(() => _driverPos = newDriverPos);
          final passengerPos = _myLocation;
          if (passengerPos != null) {
            _updateApproachingMarkers(passengerPos, newDriverPos);
            if (!_isFetchingRoute) {
              await _fetchAndDrawRoute(newDriverPos, passengerPos);
            }
          } else {
            _updateDriverMarker(newDriverPos);
          }
        }
      }
    } catch (_) {}
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

  // ── Phase switch: approaching → riding ───────────────────────────────────
  void _switchToRidingPhase() {
    if (_phase == 'riding') return;
    setState(() => _phase = 'riding');

    final myPos = _myLocation;
    final dest = _destPoint;

    if (myPos != null && dest != null) {
      // Show current location + destination markers; route = myPos → dest
      _updateRidingMarkers(myPos, dest);
      _fetchAndDrawRoute(myPos, dest);
      _fitBounds(myPos, dest);
    } else if (myPos != null) {
      // No destination coords available yet — clear driver marker & polyline
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('current'),
            position: myPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow),
            infoWindow: const InfoWindow(title: 'You'),
          ),
        };
        _polylines = {};
      });
    }
  }

  // ── Marker helpers ────────────────────────────────────────────────────────

  // Approaching phase
  void _updateApproachingMarkers(LatLng passenger, LatLng driver) {
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
          infoWindow: InfoWindow(title: widget.driverName, snippet: 'Driver'),
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
          infoWindow: InfoWindow(title: widget.driverName, snippet: 'Driver'),
        ),
      };
    });
  }

  // Riding phase
  void _updateRidingMarkers(LatLng current, LatLng dest) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('current'),
          position: current,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: 'You'),
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

  void _updateCurrentLocationMarker(LatLng pos) {
    setState(() {
      _markers = {
        ..._markers.where((m) =>
            m.markerId.value != 'current' && m.markerId.value != 'passenger'),
        Marker(
          markerId: const MarkerId('current'),
          position: pos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: 'You'),
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

  // ── Navigation after trip completed ──────────────────────────────────────
  void _navigateToRating() {
    _stopTimers();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => RateDriverScreen(
        tripId: widget.tripId,
        driverName: widget.driverName,
        driverRating: widget.driverRating,
        todaBodyNumber: widget.todaBodyNumber,
        plateNo: widget.plateNo,
        destination:
            _destination.isNotEmpty ? _destination : 'Your Destination',
        fare: _fare > 0 ? _fare : 25.0,
      ),
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  Future<void> _checkIfCompleted() async {
    try {
      final history = await TripService.getCommuterHistory();
      if (!mounted) return;
      if (history.isNotEmpty && history.first['status'] == 'completed') {
        _navigateToRating();
        return;
      }
    } catch (_) {}
    _showCancelled();
  }

  void _showCancelled() => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Trip Cancelled',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: Text('The driver cancelled. Please book again.',
                style: GoogleFonts.poppins(fontSize: 14)),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _goHome();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text('Back to Home',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ));

  void _goHome() => Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PassengerHomeScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (_) => false);

  Future<void> _cancelTrip(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('Cancel Trip?',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: Text('Are you sure?',
                  style: GoogleFonts.poppins(fontSize: 14)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('No',
                        style: GoogleFonts.poppins(color: AppColors.textHint))),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: Text('Yes, Cancel',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w600))),
              ],
            ));
    if (confirm != true) return;
    _stopTimers();
    if (widget.tripId.isNotEmpty) {
      await TripService.cancelPassengerTrip(widget.tripId);
    }
    if (!mounted) return;
    _goHome();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _locSub?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Status label & colour change based on phase ───────────────────────────
  String get _statusLabel {
    if (_phase == 'riding') {
      switch (_tripStatus) {
        case 'completed':
          return 'Trip Completed! 🎉';
        default:
          return 'Heading to destination! 🚗';
      }
    }
    switch (_tripStatus) {
      case 'requested':
        return 'Waiting for driver to accept...';
      case 'accepted':
        return 'Driver is on the way!';
      case 'pickup':
        return 'Driver arrived at pickup!';
      case 'ongoing':
        return 'Enjoy your ride!';
      default:
        return 'Connecting...';
    }
  }

  Color get _statusColor {
    if (_phase == 'riding') return Colors.green;
    switch (_tripStatus) {
      case 'requested':
        return Colors.orange;
      case 'accepted':
        return AppColors.primary;
      case 'pickup':
        return Colors.blue;
      case 'ongoing':
        return AppColors.success;
      default:
        return AppColors.textHint;
    }
  }

  String get _initials => widget.driverName
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();

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
                    if (_phase == 'approaching' &&
                        _driverPos != null &&
                        _myLocation != null) {
                      _fitBounds(_driverPos!, _myLocation!);
                    } else if (_phase == 'riding' &&
                        _destPoint != null &&
                        _myLocation != null) {
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

        // ── Top status bar ─────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(children: [
                // Status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor.withOpacity(0.4), width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: _statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(_statusLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _statusColor)),
                  ]),
                ),
                const SizedBox(height: 8),

                // ETA / Distance card
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(children: [
                    _etaItem(
                      _phase == 'riding' ? 'To Destination' : 'ETA',
                      _liveEtaText,
                      Icons.schedule_rounded,
                    ),
                    const SizedBox(width: 24),
                    _etaItem(
                      'Distance',
                      _liveDistText,
                      Icons.straighten_rounded,
                    ),
                    const Spacer(),
                    // Re-centre button
                    GestureDetector(
                      onTap: () {
                        if (_phase == 'approaching' &&
                            _driverPos != null &&
                            _myLocation != null) {
                          _fitBounds(_driverPos!, _myLocation!);
                        } else if (_phase == 'riding' &&
                            _destPoint != null &&
                            _myLocation != null) {
                          _fitBounds(_myLocation!, _destPoint!);
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.my_location_rounded,
                            size: 18, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Cancel button (hide during riding phase)
                    if (_phase == 'approaching')
                      GestureDetector(
                        onTap: () => _cancelTrip(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.red, size: 20),
                        ),
                      ),
                  ]),
                ),

                // ── Destination label (riding phase only) ─────────────────
                if (_phase == 'riding' && _destination.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(children: [
                      const Icon(Icons.flag_rounded,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 8),
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
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: -0.2, end: 0),
              ]),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0),
          ),
        ),

        // ── Bottom sheet ───────────────────────────────────────────────────
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
              // drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Driver info row
              Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(_initials,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
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
                              fontWeight: FontWeight.w700,
                              color: AppColors.backgroundDark)),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 3),
                        Text(widget.driverRating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.backgroundDark,
                                fontWeight: FontWeight.w600)),
                        if (widget.todaBodyNumber.isNotEmpty)
                          Text(' · ${widget.todaBodyNumber}',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: AppColors.textHint)),
                      ]),
                      if (widget.plateNo.isNotEmpty)
                        Text('Plate: ${widget.plateNo}',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                ),
                Row(children: [
                  _actionBtn(Icons.phone_rounded, Colors.green,
                      () => _contactDriver(call: true)),
                  const SizedBox(width: 10),
                  _actionBtn(Icons.chat_bubble_rounded, AppColors.primary,
                      () => _contactDriver(call: false)),
                ]),
              ]),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: _reportDriverIssue,
                  icon: const Icon(Icons.report_problem_rounded, size: 18),
                  label: Text('Report an Issue',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Context hint — changes based on phase
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _phase == 'riding'
                      ? Colors.green.withOpacity(0.06)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _phase == 'riding'
                        ? Colors.green.withOpacity(0.25)
                        : const Color(0xFFEEEEEE),
                  ),
                ),
                child: Row(children: [
                  Icon(
                    _phase == 'riding'
                        ? Icons.electric_rickshaw_rounded
                        : Icons.navigation_rounded,
                    color:
                        _phase == 'riding' ? Colors.green : AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _phase == 'riding'
                        ? 'You are on the way to your destination'
                        : 'Your driver is heading to you',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.backgroundDark),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // Cancel button (approaching phase only)
              if (_phase == 'approaching')
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _cancelTrip(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Cancel Trip',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint)),
                  ),
                ),
            ]),
          ).animate().slideY(
              begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut),
        ),
      ]),
    );
  }

  Widget _etaItem(String label, String value, IconData icon) => Row(children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark)),
        ]),
      ]);

  Future<void> _contactDriver({required bool call}) async {
    final ok = call
        ? await ContactService.call(_driverPhone)
        : await ContactService.message(
            _driverPhone,
            body: 'Hi, this is your TodaGo passenger.',
          );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Driver phone number is not available.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _reportDriverIssue() {
    final trip = _latestTrip;
    showReportIssueDialog(
      context: context,
      reporterRole: 'passenger',
      initialType: 'wrong_driver_vehicle',
      tripId: widget.tripId,
      subjectRole: 'driver',
      subjectId: trip?['driver_id']?.toString(),
      subjectName: widget.driverName,
      metadata: {
        'plate_no': widget.plateNo,
        'toda_body_number': widget.todaBodyNumber,
        'trip_status': _tripStatus,
      },
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      );
}
