import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'operator_login_screen.dart';

class OperatorRegistrationScreen extends StatefulWidget {
  const OperatorRegistrationScreen({super.key});

  @override
  State<OperatorRegistrationScreen> createState() =>
      _OperatorRegistrationScreenState();
}

class _OperatorRegistrationScreenState
    extends State<OperatorRegistrationScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isLoading = false;

  // Step 1 — Association Info
  final _assocNameCtrl = TextEditingController();
  final _assocIdCtrl = TextEditingController();
  final _ltfrbCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();

  // Step 2 — Contact & Account
  final _contactNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  // Step 3 — Fleet Info
  final _totalTricyclesCtrl = TextEditingController();
  final _activeDriversCtrl = TextEditingController();
  final _serviceAreaCtrl = TextEditingController();

  @override
  void dispose() {
    _assocNameCtrl.dispose();
    _assocIdCtrl.dispose();
    _ltfrbCtrl.dispose();
    _regionCtrl.dispose();
    _contactNameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _totalTricyclesCtrl.dispose();
    _activeDriversCtrl.dispose();
    _serviceAreaCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text('Registration submitted! Pending LTFRB verification.',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const OperatorLoginScreen(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.backgroundDark,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _prevStep,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.arrow_back_ios_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Operator Registration',
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                            Text('Step ${_currentStep + 1} of 3',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.white54)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.shield_rounded,
                              color: AppColors.backgroundDark, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(
                          3,
                          (i) => Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: i <= _currentStep
                                        ? AppColors.primary
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              )),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildStep1(), _buildStep2(), _buildStep3()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: TODA Association Info ─────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Association Information',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Your TODA registration details',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 28),
          _lightLabel('TODA Association Name', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _assocNameCtrl,
              hint: 'Davao-Central TODA',
              icon: Icons.groups_rounded),
          const SizedBox(height: 18),
          _lightLabel('Association ID / TODA ID', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _assocIdCtrl,
              hint: 'e.g., DCC-TODA-001',
              icon: Icons.badge_outlined),
          const SizedBox(height: 18),
          _lightLabel('LTFRB Case Number', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _ltfrbCtrl,
              hint: 'LTFRB franchise number',
              icon: Icons.description_outlined),
          const SizedBox(height: 18),
          _lightLabel('Region / City', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _regionCtrl,
              hint: 'Davao City, Davao del Sur',
              icon: Icons.location_on_outlined),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                'Your LTFRB franchise number will be verified before your account is activated.',
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
              )),
            ]),
          ),
          const SizedBox(height: 32),
          _continueBtn(_nextStep),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Step 2: Contact & Account ─────────────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Contact & Account',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Your account login credentials',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 28),
          _lightLabel('Contact Person Name', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _contactNameCtrl,
              hint: 'Full name of authorized officer',
              icon: Icons.person_outline_rounded),
          const SizedBox(height: 18),
          _lightLabel('Operator Email', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _emailCtrl,
              hint: 'operator@toda.ph',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 18),
          _lightLabel('Mobile Number', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _mobileCtrl,
              hint: '+63 912 345 6789',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 18),
          _lightLabel('Password', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _passwordCtrl,
              hint: 'Min. 8 characters',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey[400],
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )),
          const SizedBox(height: 18),
          _lightLabel('Confirm Password', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _confirmCtrl,
              hint: 'Re-enter your password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey[400],
                    size: 20),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              )),
          const SizedBox(height: 32),
          _continueBtn(_nextStep),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Step 3: Fleet Info ────────────────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Fleet Information',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Tell us about your fleet size',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 28),
          _lightLabel('Total Tricycles in Fleet', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _totalTricyclesCtrl,
              hint: 'e.g., 402',
              icon: Icons.directions_car_outlined,
              keyboardType: TextInputType.number),
          const SizedBox(height: 18),
          _lightLabel('Number of Active Drivers'),
          const SizedBox(height: 6),
          _lightField(
              controller: _activeDriversCtrl,
              hint: 'e.g., 315',
              icon: Icons.people_outline_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 18),
          _lightLabel('Primary Service Area', required: true),
          const SizedBox(height: 6),
          _lightField(
              controller: _serviceAreaCtrl,
              hint: 'e.g., Davao City CBD, Panabo City',
              icon: Icons.map_outlined),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LTFRB Compliant',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                      )),
                  Text(
                      'TodaGo only accepts verified, LTFRB-registered operators.',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.green[700])),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text('Submit Registration',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _lightLabel(String text, {bool required = false}) => Row(children: [
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700])),
        if (required)
          Text(' *',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600)),
      ]);

  Widget _lightField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: GoogleFonts.poppins(color: Colors.grey[800], fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.backgroundDark, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );

  Widget _continueBtn(VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.backgroundDark,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 0,
          ),
          child: Text('Continue',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
        ),
      );
}
