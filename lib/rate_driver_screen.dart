import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'trip_service.dart';
import 'passenger_home_screen.dart';

class RateDriverScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final double driverRating; // current avg before this rating
  final String todaBodyNumber;
  final String plateNo;
  final String destination;
  final double fare;

  const RateDriverScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverRating,
    required this.todaBodyNumber,
    required this.plateNo,
    required this.destination,
    required this.fare,
  });

  @override
  State<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends State<RateDriverScreen> {
  int _selectedStars = 0;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  // ── Tag options by star tier ──────────────────────────────────────────────
  static const Map<int, List<String>> _tagsByRating = {
    5: [
      'Safe Driver',
      'Very Friendly',
      'On Time',
      'Clean Vehicle',
      'Great Route',
      'Professional',
      'Would Ride Again'
    ],
    4: [
      'Good Driver',
      'Friendly',
      'Mostly On Time',
      'Clean Vehicle',
      'Good Route',
      'Comfortable'
    ],
    3: ['Average', 'Okay Driver', 'Acceptable', 'Could Be Better'],
    2: [
      'Late Arrival',
      'Reckless Driving',
      'Unfriendly',
      'Dirty Vehicle',
      'Wrong Route'
    ],
    1: [
      'Very Late',
      'Dangerous Driving',
      'Rude',
      'Scam Attempt',
      'Wrong Destination'
    ],
  };

  List<String> get _currentTags =>
      _tagsByRating[_selectedStars] ?? _tagsByRating[5]!;

  String get _ratingLabel {
    switch (_selectedStars) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent!';
      default:
        return 'Tap to rate';
    }
  }

  Color get _ratingColor {
    switch (_selectedStars) {
      case 1:
        return AppColors.error;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return AppColors.primary;
      case 5:
        return AppColors.success;
      default:
        return AppColors.textHint;
    }
  }

  String get _driverInitials => widget.driverName
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedStars == 0 || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final result = await TripService.submitRating(
      tripId: widget.tripId,
      rating: _selectedStars,
      comment:
          _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      tags: _selectedTags.toList(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      setState(() => _submitted = true);
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      _goHome();
    } else {
      // Already rated or server error — still let them go home
      final msg = result['message']?.toString() ?? 'Something went wrong.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor:
            msg.contains('already') ? AppColors.primary : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      if (msg.contains('already')) _goHome();
    }
  }

  void _skip() => _goHome();

  void _goHome() {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _submitted ? _buildSuccessView() : _buildRatingView(),
    );
  }

  // ── Success animation ─────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 56),
            ).animate().scale(
                begin: const Offset(0.4, 0.4),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              'Thanks for your feedback!',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              'It helps improve the TodaGo experience.',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _selectedStars,
                (i) =>
                    Icon(Icons.star_rounded, color: AppColors.primary, size: 32)
                        .animate(delay: Duration(milliseconds: 100 * i))
                        .scale(
                            begin: const Offset(0, 0),
                            end: const Offset(1, 1),
                            duration: 300.ms,
                            curve: Curves.bounceOut),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main rating view ──────────────────────────────────────────────────────
  Widget _buildRatingView() {
    return Column(
      children: [
        // ── Dark header ─────────────────────────────────────────────────────
        Container(
          color: AppColors.backgroundDark,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(children: [
                // Top row
                Row(children: [
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white38),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),

                // Driver avatar
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _driverInitials,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).scale(
                    begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                const SizedBox(height: 12),

                Text(
                  'Rate your ride with',
                  style:
                      GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
                ),
                Text(
                  widget.driverName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),

                // Trip summary chip
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _infoChip(Icons.flag_rounded, widget.destination),
                  const SizedBox(width: 8),
                  _infoChip(Icons.payments_rounded,
                      '₱${widget.fare.toStringAsFixed(0)}'),
                  if (widget.plateNo.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _infoChip(Icons.directions_car_rounded, widget.plateNo),
                  ],
                ]),
              ]),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.15, end: 0),

        // ── Scrollable body ──────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Star selector ──────────────────────────────────────────
                Center(
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        final filled = star <= _selectedStars;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedStars = star;
                              _selectedTags.clear(); // reset tags on re-rate
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: filled ? 48 : 42,
                              color: filled
                                  ? AppColors.primary
                                  : const Color(0xFFDDDDDD),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _ratingLabel,
                        key: ValueKey(_selectedStars),
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _ratingColor,
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Quick tags (shown once a star is selected) ─────────────
                if (_selectedStars > 0) ...[
                  Text(
                    'What stood out?',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.backgroundDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _currentTags.map((tag) {
                      final sel = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            sel
                                ? _selectedTags.remove(tag)
                                : _selectedTags.add(tag);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.backgroundDark
                                : const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  sel ? AppColors.primary : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (sel) ...[
                              const Icon(Icons.check_rounded,
                                  color: AppColors.primary, size: 13),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              tag,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : AppColors.backgroundDark,
                              ),
                            ),
                          ]),
                        ),
                      );
                    }).toList(),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 20),

                  // ── Optional comment ───────────────────────────────────────
                  Text(
                    'Add a comment (optional)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.backgroundDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.backgroundDark),
                    decoration: InputDecoration(
                      hintText: 'Tell us more about your experience...',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textHint),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 2),
                      ),
                      counterStyle: GoogleFonts.poppins(
                          fontSize: 10, color: AppColors.textHint),
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                ],

                const SizedBox(height: 28),

                // ── Submit button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        (_selectedStars == 0 || _isSubmitting) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedStars > 0
                          ? AppColors.backgroundDark
                          : const Color(0xFFF0F2F5),
                      disabledBackgroundColor: const Color(0xFFF0F2F5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.send_rounded,
                                color: _selectedStars > 0
                                    ? AppColors.primary
                                    : AppColors.textHint,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Submit Rating',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedStars > 0
                                      ? Colors.white
                                      : AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Skip link ──────────────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip for now',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      );
}
