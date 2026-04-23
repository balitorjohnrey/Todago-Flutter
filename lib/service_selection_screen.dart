import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'finding_driver_screen.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  int _selected = 0;

  final List<Map<String, dynamic>> _services = [
    {
      'id': 'solo',
      'name': 'Solo',
      'subtitle': 'Ride alone, enjoy privacy',
      'icon': Icons.person_rounded,
      'passengers': '1 passenger',
      'price': '₱40–60',
      'eta': '3–4 min',
      'premium': false,
      'color': AppColors.backgroundDark,
    },
    {
      'id': 'shared',
      'name': 'Shared',
      'subtitle': 'Share the ride, save money',
      'icon': Icons.people_rounded,
      'passengers': 'Up to 3 passengers',
      'price': '₱20–35',
      'eta': '8–12 min',
      'premium': false,
      'color': AppColors.backgroundDark,
    },
    {
      'id': 'express',
      'name': 'Toda-Express',
      'subtitle': 'Priority pickup, fastest route',
      'icon': Icons.bolt_rounded,
      'passengers': '1–2 passengers',
      'price': '₱90–100',
      'eta': '3–5 min',
      'premium': true,
      'color': AppColors.primary,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: AppColors.backgroundDark, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Service',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.backgroundDark,
                          )),
                      Text('Choose your ride type',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textHint,
                          )),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // Service cards
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: List.generate(_services.length, (i) {
                    final s = _services[i];
                    final isSelected = _selected == i;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.backgroundDark
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Icon
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFFE8EDF2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(s['icon'] as IconData,
                                  color: isSelected
                                      ? AppColors.backgroundDark
                                      : AppColors.backgroundDark,
                                  size: 26),
                            ),

                            const SizedBox(width: 16),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(s['name'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.backgroundDark,
                                          )),
                                      if (s['premium'] == true) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text('PREMIUM',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.backgroundDark,
                                              )),
                                        ),
                                      ]
                                    ],
                                  ),
                                  Text(s['subtitle'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: isSelected
                                            ? Colors.white54
                                            : AppColors.textHint,
                                      )),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _infoBadge(
                                          Icons.person_outline_rounded,
                                          s['passengers'] as String,
                                          isSelected),
                                      const SizedBox(width: 8),
                                      _infoBadge(Icons.schedule_rounded,
                                          'Arrives ${s['eta']}', isSelected,
                                          green: true),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Price
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(s['price'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.backgroundDark,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 100 + i * 80),
                            duration: 400.ms,
                          )
                          .slideX(begin: 0.1, end: 0),
                    );
                  }),
                ),
              ),
            ),

            // Pickup row + Continue
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Pickup in: University Avenue',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.backgroundDark,
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                        Text('Change',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => FindingDriverScreen(
                            serviceType: _services[_selected]['name'] as String,
                            price: _services[_selected]['price'] as String,
                          ),
                          transitionDuration: const Duration(milliseconds: 400),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.backgroundDark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text('Confirm Ride',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label, bool dark,
      {bool green = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 12,
            color: green
                ? Colors.green
                : dark
                    ? Colors.white54
                    : AppColors.textHint),
        const SizedBox(width: 3),
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: green
                  ? Colors.green
                  : dark
                      ? Colors.white54
                      : AppColors.textHint,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }
}
