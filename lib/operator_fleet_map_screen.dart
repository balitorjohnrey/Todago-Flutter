import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'operator_auth_service.dart';
import 'panabo_config.dart';

class OperatorFleetMapScreen extends StatefulWidget {
  const OperatorFleetMapScreen({super.key});

  @override
  State<OperatorFleetMapScreen> createState() => _OperatorFleetMapScreenState();
}

class _OperatorFleetMapScreenState extends State<OperatorFleetMapScreen> {
  GoogleMapController? _mapController;
  Timer? _refreshTimer;
  bool _showList = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadFleet();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadFleet(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadFleet({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final drivers = await OperatorAuthService.fetchFleet();
    if (!mounted) return;
    setState(() {
      _drivers = drivers;
      _isLoading = false;
    });
    final positioned = _driversWithLocation;
    if (positioned.isNotEmpty && _mapController != null) {
      final first = positioned.first;
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(
          _asDouble(first['driver_lat']),
          _asDouble(first['driver_lng']),
        ),
        14.5,
      ));
    }
  }

  List<Map<String, dynamic>> get _driversWithLocation => _drivers.where((d) {
        final lat = _asDouble(d['driver_lat'], fallback: double.nan);
        final lng = _asDouble(d['driver_lng'], fallback: double.nan);
        return lat.isFinite && lng.isFinite;
      }).toList();

  int get _activeCount => _drivers
      .where((d) => ['online', 'on_trip'].contains(d['status']?.toString()))
      .length;
  int get _offlineCount =>
      _drivers.where((d) => d['status']?.toString() == 'offline').length;
  int get _pendingCount => _drivers
      .where((d) => d['is_verified'] != true && d['is_verified'] != 'true')
      .length;

  Set<Marker> get _mapMarkers => _driversWithLocation.map((d) {
        final status = d['status']?.toString() ?? 'offline';
        final active = status == 'online' || status == 'on_trip';
        final pending = d['is_verified'] != true && d['is_verified'] != 'true';
        return Marker(
          markerId:
              MarkerId(d['driver_id']?.toString() ?? d.hashCode.toString()),
          position:
              LatLng(_asDouble(d['driver_lat']), _asDouble(d['driver_lng'])),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            pending
                ? BitmapDescriptor.hueOrange
                : active
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: d['driver_name']?.toString() ?? 'Driver',
            snippet:
                '${d['toda_body_number'] ?? '-'} - ${pending ? "Pending" : status}',
          ),
        );
      }).toSet();

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final hasLocations = _driversWithLocation.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: (c) => _mapController = c,
              initialCameraPosition: const CameraPosition(
                target: PanaboConfig.cityCenter,
                zoom: 13.5,
              ),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              markers: _mapMarkers,
            ),
          ),
          if (!hasLocations && !_isLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  alignment: Alignment.center,
                  color: Colors.white.withOpacity(0.55),
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No live driver locations yet',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.backgroundDark,
                    ),
                  ),
                ),
              ),
            ),
          _topBar(),
          _statsBar(),
          if (_isLoading)
            const Positioned(
              top: 150,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_showList) _buildDriverList(),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _showList = !_showList),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                        )
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.list_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_showList ? "Hide" : "Show"} List (${_drivers.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: _roundButton(Icons.arrow_back_ios_rounded),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: _floatingDecoration(20),
                child: Text('Live Fleet Map',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.backgroundDark,
                    )),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isLoading ? null : _loadFleet,
                child: _roundButton(Icons.refresh_rounded),
              ),
            ]).animate().fadeIn(duration: 350.ms),
          ),
        ),
      );

  Widget _statsBar() => Positioned(
        top: 80,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: _floatingDecoration(16),
          child: Row(children: [
            _statDot(AppColors.success, 'Active', _activeCount),
            _divider(),
            _statDot(Colors.grey, 'Offline', _offlineCount),
            _divider(),
            _statDot(AppColors.primary, 'Pending', _pendingCount),
          ]),
        ).animate().fadeIn(delay: 100.ms),
      );

  BoxDecoration _floatingDecoration(double radius) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          )
        ],
      );

  Widget _roundButton(IconData icon) => Container(
        width: 40,
        height: 40,
        decoration: _floatingDecoration(20),
        child: Icon(icon, color: AppColors.backgroundDark, size: 18),
      );

  Widget _divider() => Container(
        width: 1,
        height: 30,
        color: const Color(0xFFEEEEEE),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  Widget _statDot(Color color, String label, int count) => Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint)),
            Text('$count',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
          ]),
        ]),
      );

  Widget _buildDriverList() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _drivers.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF5F5F5)),
            itemBuilder: (_, i) {
              final d = _drivers[i];
              final status = d['status']?.toString() ?? 'offline';
              final active = status == 'online' || status == 'on_trip';
              final hasLocation =
                  _asDouble(d['driver_lat'], fallback: double.nan).isFinite &&
                      _asDouble(d['driver_lng'], fallback: double.nan).isFinite;
              return ListTile(
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.success.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.electric_rickshaw_rounded,
                      size: 18,
                      color: active ? AppColors.success : Colors.grey),
                ),
                title: Text(d['driver_name']?.toString() ?? 'Driver',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.backgroundDark,
                    )),
                subtitle: Text(
                  '${d['toda_body_number'] ?? '-'} - ${hasLocation ? "Live location" : "No location"}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
                trailing: Text(status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: active ? AppColors.success : Colors.grey,
                    )),
              );
            },
          ),
        ),
      );
}
