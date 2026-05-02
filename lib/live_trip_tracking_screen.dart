import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'passenger_home_screen.dart';

class LiveTripTrackingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final double driverRating;
  final String todaBodyNumber;
  final String plateNo;
  final int etaMinutes;
  final double distanceKm;

  const LiveTripTrackingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverRating,
    required this.todaBodyNumber,
    required this.plateNo,
    required this.etaMinutes,
    required this.distanceKm,
  });

  @override
  State<LiveTripTrackingScreen> createState() => _LiveTripTrackingScreenState();
}

class _LiveTripTrackingScreenState extends State<LiveTripTrackingScreen> {
  final LatLng _pickup      = const LatLng(7.1907, 125.4553);
  final LatLng _driver      = const LatLng(7.1940, 125.4580);
  final LatLng _destination = const LatLng(7.1850, 125.4500);

  String get _initials {
    final parts = widget.driverName.trim().split(' ');
    return parts.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [

        // ── Full screen map ───────────────────────────────────────────────
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(7.1907, 125.4553),
            initialZoom: 14.5,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.todago.app',
            ),
            PolylineLayer(polylines: [
              Polyline(
                points: [_driver, _pickup, _destination],
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ]),
            MarkerLayer(markers: [
              // Driver marker
              Marker(
                point: _driver, width: 40, height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.electric_rickshaw_rounded,
                      color: AppColors.primary, size: 20),
                ),
              ),
              // Pickup
              Marker(
                point: _pickup, width: 36, height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              // Destination
              Marker(
                point: _destination, width: 36, height: 36,
                child: const Icon(Icons.location_on_rounded,
                    color: Colors.red, size: 36),
              ),
            ]),
          ],
        ),

        // ── Top ETA bar ───────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12, offset: const Offset(0, 3),
                  )],
                ),
                child: Row(children: [
                  _etaItem('ETA', '${widget.etaMinutes} min',
                      Icons.schedule_rounded),
                  const SizedBox(width: 24),
                  _etaItem('Distance', '${widget.distanceKm.toStringAsFixed(1)} km',
                      Icons.straighten_rounded),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _cancelTrip(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1), shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.red, size: 20),
                    ),
                  ),
                ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0),
            ),
          ),
        ),

        // ── Bottom driver card ─────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(
                color: Colors.black12, blurRadius: 20, offset: Offset(0, -4),
              )],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 16),

              // Driver info — uses REAL name from backend
              Row(children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(_initials,
                      style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.driverName, style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.backgroundDark,
                  )),
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 3),
                    Text(widget.driverRating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.backgroundDark,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(' · ${widget.todaBodyNumber}',
                        style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textHint,
                        )),
                  ]),
                  if (widget.plateNo.isNotEmpty)
                    Text('Plate: ${widget.plateNo}',
                        style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textHint,
                        )),
                ])),
                Row(children: [
                  _actionBtn(Icons.phone_rounded, Colors.green),
                  const SizedBox(width: 10),
                  _actionBtn(Icons.chat_bubble_rounded, AppColors.primary),
                ]),
              ]),

              const SizedBox(height: 16),

              // Destination
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.navigation_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Heading to', style: GoogleFonts.poppins(
                      fontSize: 10, color: AppColors.textHint,
                    )),
                    Text('Davao del Norte State College, Panabo',
                        style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.backgroundDark,
                        )),
                  ])),
                ]),
              ),

              const SizedBox(height: 14),

              // Cancel button
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton(
                  onPressed: () => _cancelTrip(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Cancel Trip', style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  )),
                ),
              ),
            ]),
          ).animate().slideY(begin: 0.3, end: 0,
              duration: 400.ms, curve: Curves.easeOut),
        ),
      ]),
    );
  }

  Future<void> _cancelTrip(BuildContext context) async {
    if (widget.tripId.isNotEmpty) {
      await TripService.updateTripStatus(widget.tripId, 'cancelled');
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

  Widget _etaItem(String label, String value, IconData icon) =>
      Row(children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(
              fontSize: 10, color: AppColors.textHint)),
          Text(value, style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w800,
            color: AppColors.backgroundDark,
          )),
        ]),
      ]);

  Widget _actionBtn(IconData icon, Color color) =>
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      );
}