import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'finding_driver_screen.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});
  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  int _selected = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _onlineDrivers = [];
  bool _driversLoaded = false;

  final List<Map<String, dynamic>> _services = [
    {
      'id': 'solo', 'name': 'Solo', 'subtitle': 'Ride alone, enjoy privacy',
      'icon': Icons.person_rounded, 'passengers': '1 passenger',
      'price': 25.0, 'priceLabel': '₱25–40', 'eta': '3–4 min', 'premium': false,
    },
    {
      'id': 'shared', 'name': 'Shared', 'subtitle': 'Share the ride, save money',
      'icon': Icons.people_rounded, 'passengers': 'Up to 3 passengers',
      'price': 15.0, 'priceLabel': '₱15–25', 'eta': '8–12 min', 'premium': false,
    },
    {
      'id': 'express', 'name': 'Toda-Express', 'subtitle': 'Priority pickup, fastest route',
      'icon': Icons.bolt_rounded, 'passengers': '1–2 passengers',
      'price': 90.0, 'priceLabel': '₱90–100', 'eta': '1–3 min', 'premium': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadOnlineDrivers();
  }

  Future<void> _loadOnlineDrivers() async {
    final drivers = await TripService.fetchOnlineDrivers();
    if (mounted) setState(() { _onlineDrivers = drivers; _driversLoaded = true; });
  }

  Future<void> _confirmRide() async {
    if (_onlineDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No drivers available right now. Please try again.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    setState(() => _isLoading = true);

    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => FindingDriverScreen(
        serviceType: _services[_selected]['name'] as String,
        price: _services[_selected]['priceLabel'] as String,
        fareAmount: _services[_selected]['price'] as double,
        onlineDrivers: _onlineDrivers,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppColors.backgroundDark, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Select Service', style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
                Text('Choose your ride type', style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textHint,
                )),
              ]),
              const Spacer(),
              // Online drivers count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _onlineDrivers.isNotEmpty
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _onlineDrivers.isNotEmpty
                        ? Colors.green.withOpacity(0.4)
                        : Colors.orange.withOpacity(0.4),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: _onlineDrivers.isNotEmpty ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _driversLoaded
                        ? '${_onlineDrivers.length} online'
                        : 'Loading...',
                    style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _onlineDrivers.isNotEmpty ? Colors.green : Colors.orange,
                    ),
                  ),
                ]),
              ),
            ]).animate().fadeIn(duration: 400.ms),
          ),

          const SizedBox(height: 20),

          // Service cards
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _services.length,
              itemBuilder: (_, i) {
                final s = _services[i];
                final isSelected = _selected == i;
                return GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : const Color(0xFFE8EDF2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(s['icon'] as IconData,
                            color: AppColors.backgroundDark, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(s['name'] as String, style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.backgroundDark,
                          )),
                          if (s['premium'] == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary, borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('PREMIUM', style: GoogleFonts.poppins(
                                fontSize: 9, fontWeight: FontWeight.w800,
                                color: AppColors.backgroundDark,
                              )),
                            ),
                          ],
                        ]),
                        Text(s['subtitle'] as String, style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isSelected ? Colors.white54 : AppColors.textHint,
                        )),
                        const SizedBox(height: 8),
                        Row(children: [
                          _badge(Icons.person_outline_rounded,
                              s['passengers'] as String, isSelected),
                          const SizedBox(width: 8),
                          _badge(Icons.schedule_rounded,
                              'Arrives ${s['eta']}', isSelected, green: true),
                        ]),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(s['priceLabel'] as String, style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.primary : AppColors.backgroundDark,
                        )),
                        if (!_driversLoaded)
                          const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2,
                                color: AppColors.primary),
                          )
                        else
                          Text('${_onlineDrivers.length} available',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: _onlineDrivers.isNotEmpty
                                    ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w600,
                              )),
                      ]),
                    ]),
                  ),
                ).animate().fadeIn(
                    delay: Duration(milliseconds: 100 + i * 80), duration: 400.ms);
              },
            ),
          ),

          // Bottom
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(children: [
              // No drivers warning
              if (_driversLoaded && _onlineDrivers.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'No drivers online right now. Try again in a few minutes.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange[800]),
                    )),
                    GestureDetector(
                      onTap: _loadOnlineDrivers,
                      child: Text('Retry', style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange,
                      )),
                    ),
                  ]),
                ),

              // Pickup row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Pickup: University Avenue',
                      style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.backgroundDark,
                        fontWeight: FontWeight.w500,
                      ))),
                  Text('Change', style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600,
                  )),
                ]),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmRide,
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
                      : Text('Find a Driver', style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _badge(IconData icon, String label, bool dark, {bool green = false}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12,
            color: green ? Colors.green : dark ? Colors.white54 : AppColors.textHint),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.poppins(
          fontSize: 11,
          color: green ? Colors.green : dark ? Colors.white54 : AppColors.textHint,
          fontWeight: FontWeight.w500,
        )),
      ]);
}