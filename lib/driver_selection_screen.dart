import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'passenger_waiting_screen.dart';

class DriverSelectionScreen extends StatefulWidget {
  final String serviceType;
  final String price;
  final double fareAmount;
  final List<Map<String, dynamic>> onlineDrivers;

  const DriverSelectionScreen({
    super.key,
    required this.serviceType,
    required this.price,
    required this.fareAmount,
    required this.onlineDrivers,
  });

  @override
  State<DriverSelectionScreen> createState() => _DriverSelectionScreenState();
}

class _DriverSelectionScreenState extends State<DriverSelectionScreen> {
  int _selected = 0;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> get _selectedDriver => widget.onlineDrivers[_selected];

  String _normalizeServiceType(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[-\s]'), '');
    if (s.contains('express')) return 'express';
    if (s.contains('shared')) return 'shared';
    return 'solo';
  }

  Future<void> _confirmDriver() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await TripService.requestRide(
      driverId: _selectedDriver['driver_id'] as String,
      pickupLocation: 'University Avenue',
      destination: 'Davao del Norte State College',
      serviceType: _normalizeServiceType(widget.serviceType),
      fare: widget.fareAmount,
      paymentMethod: 'cash',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final trip = result['trip'] as Map<String, dynamic>? ?? {};
      // Navigate to waiting screen — shows live tracking once driver accepts
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => PassengerWaitingScreen(
          tripId: trip['trip_id']?.toString() ?? '',
          driverName: _selectedDriver['driver_name']?.toString() ?? 'Driver',
          driverRating: (_selectedDriver['avg_rating'] ?? 0.0).toDouble(),
          todaBodyNumber: _selectedDriver['toda_body_number']?.toString() ?? '',
          plateNo: _selectedDriver['plate_no']?.toString() ?? '',
          etaMinutes: (_selectedDriver['eta_minutes'] ?? 5).toInt(),
          distanceKm: (_selectedDriver['distance_km'] ?? 1.0).toDouble(),
          fare: widget.fareAmount,
          serviceType: widget.serviceType,
        ),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ));
    } else {
      setState(() =>
        _errorMessage = result['message']?.toString() ?? 'Failed to request ride');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textHint),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.backgroundDark, size: 36),
                ).animate().scale(
                    begin: const Offset(0.6, 0.6), end: const Offset(1, 1),
                    duration: 500.ms, curve: Curves.elasticOut),
                const SizedBox(height: 12),
                Text('${widget.onlineDrivers.length} Driver${widget.onlineDrivers.length != 1 ? "s" : ""} Found!',
                    style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: AppColors.backgroundDark,
                    )).animate().fadeIn(delay: 100.ms),
                Text('Select your preferred driver to continue',
                    style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textHint,
                    )).animate().fadeIn(delay: 150.ms),

                // Error banner
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.error))),
                    ]),
                  ),
                ],
              ]),
            ),

            // Driver cards
            SizedBox(
              height: 170,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                itemCount: widget.onlineDrivers.length,
                itemBuilder: (_, i) {
                  final d = widget.onlineDrivers[i];
                  final sel = _selected == i;
                  final name = d['driver_name']?.toString() ?? 'Driver';
                  final initials = name.trim().split(' ')
                      .take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
                  final rating = (d['avg_rating'] ?? 0.0).toDouble();
                  final trips = d['total_trips'] ?? 0;
                  final eta = d['eta_minutes'] ?? 5;
                  final dist = d['distance_km'] ?? 1.0;
                  final assoc = d['association_code']?.toString()
                      ?? d['toda_body_number']?.toString() ?? '';

                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 260, margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: sel ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(sel ? 0.08 : 0.04),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text(initials,
                                style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: AppColors.backgroundDark,
                              )),
                              Text(assoc, style: GoogleFonts.poppins(
                                fontSize: 10, color: AppColors.textHint,
                              )),
                            ],
                          )),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          ...List.generate(5, (si) {
                            if (si < rating.floor()) {
                              return const Icon(Icons.star_rounded,
                                  size: 13, color: AppColors.primary);
                            } else if (si < rating) {
                              return const Icon(Icons.star_half_rounded,
                                  size: 13, color: AppColors.primary);
                            }
                            return const Icon(Icons.star_outline_rounded,
                                size: 13, color: AppColors.primary);
                          }),
                          const SizedBox(width: 4),
                          Text('${rating.toStringAsFixed(1)} ($trips trips)',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: AppColors.textHint)),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          _driverStat('$eta', 'min'),
                          const SizedBox(width: 12),
                          _driverStat('${(dist is double ? dist : (dist as num).toDouble()).toStringAsFixed(1)}', 'km'),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.circle, size: 6, color: Colors.green),
                              const SizedBox(width: 4),
                              Text('Online', style: GoogleFonts.poppins(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: Colors.green,
                              )),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  ).animate().fadeIn(
                      delay: Duration(milliseconds: 200 + i * 80),
                      duration: 400.ms);
                },
              ),
            ),

            // Summary
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(children: [
                _summaryRow('Driver', _selectedDriver['driver_name']?.toString() ?? 'Driver'),
                const SizedBox(height: 6),
                _summaryRow('Service Type', widget.serviceType),
                const SizedBox(height: 6),
                _summaryRow('ETA', '${_selectedDriver['eta_minutes'] ?? 5} min away'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFF0F0F0), height: 1),
                ),
                Row(children: [
                  Text('Estimated Fare', style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.backgroundDark,
                  )),
                  const Spacer(),
                  Text(widget.price, style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: AppColors.backgroundDark,
                  )),
                ]),
              ]),
            ).animate().fadeIn(delay: 400.ms),

            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundDark,
                    disabledBackgroundColor: AppColors.backgroundDark.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text('Confirm Driver & Start Ride',
                          style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                ),
              ),
            ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Text('Fare may vary based on actual distance and traffic',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textHint)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _driverStat(String value, String unit) =>
      Row(crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic, children: [
        Text(value, style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w800,
          color: AppColors.backgroundDark,
        )),
        const SizedBox(width: 2),
        Text(unit, style: GoogleFonts.poppins(
            fontSize: 11, color: AppColors.textHint)),
      ]);

  Widget _summaryRow(String label, String value) =>
      Row(children: [
        Text(label, style: GoogleFonts.poppins(
            fontSize: 13, color: AppColors.textHint)),
        const Spacer(),
        Text(value, style: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.backgroundDark,
        )),
      ]);
}