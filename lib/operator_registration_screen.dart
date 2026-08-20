import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'operator_auth_service.dart';
import 'operator_login_screen.dart';
import 'persona_verification_launcher.dart';
import 'persona_verification_notice.dart';

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
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 1 — Association Info
  final _assocNameCtrl = TextEditingController();
  final _assocCodeCtrl = TextEditingController();
  final _ltfrbCtrl     = TextEditingController();
  final _regionCtrl    = TextEditingController();

  // Step 2 — Contact Info
  final _contactNameCtrl = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _mobileCtrl      = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();

  // Step 3 — Fleet Info
  final _totalTricyclesCtrl = TextEditingController();
  final _activeDriversCtrl  = TextEditingController();
  final _serviceAreaCtrl    = TextEditingController();

  @override
  void dispose() {
    _assocNameCtrl.dispose();
    _assocCodeCtrl.dispose();
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

  bool _validateAssociationStep() {
    if (_assocNameCtrl.text.trim().isEmpty ||
        _assocCodeCtrl.text.trim().isEmpty ||
        _ltfrbCtrl.text.trim().isEmpty ||
        _regionCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return false;
    }
    return true;
  }

  bool _validateContactStep() {
    final email = _emailCtrl.text.trim();
    if (_contactNameCtrl.text.trim().split(RegExp(r'\s+')).length < 2) {
      setState(() => _errorMessage = 'Enter the authorized officer full name');
      return false;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _errorMessage = 'Enter a valid operator email');
      return false;
    }
    if (_mobileCtrl.text.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _errorMessage = 'Enter a valid phone number');
      return false;
    }
    if (_passwordCtrl.text.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(_passwordCtrl.text) ||
        !RegExp(r'[a-z]').hasMatch(_passwordCtrl.text) ||
        !RegExp(r'[0-9]').hasMatch(_passwordCtrl.text)) {
      setState(() => _errorMessage =
          'Password must be 8+ characters with uppercase, lowercase, and number');
      return false;
    }
    if (_confirmCtrl.text != _passwordCtrl.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return false;
    }
    return true;
  }

  bool _validateFleetStep() {
    if (_totalTricyclesCtrl.text.trim().isEmpty ||
        _serviceAreaCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (_currentStep == 0 && !_validateAssociationStep()) return;
    if (_currentStep == 1 && !_validateContactStep()) return;
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
        _errorMessage = null;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    if (!_validateAssociationStep() ||
        !_validateContactStep() ||
        !_validateFleetStep()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await OperatorAuthService.register(
      associationName: _assocNameCtrl.text,
      associationCode: _assocCodeCtrl.text,
      ltfrbNumber:     _ltfrbCtrl.text,
      region:          _regionCtrl.text,
      contactName:     _contactNameCtrl.text,
      email:           _emailCtrl.text,
      phone:           _mobileCtrl.text,
      password:        _passwordCtrl.text,
      serviceArea:     _serviceAreaCtrl.text.isNotEmpty
                           ? _serviceAreaCtrl.text
                           : null,
      totalTricycles:  _totalTricyclesCtrl.text.isNotEmpty
                           ? _totalTricyclesCtrl.text
                           : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      await PersonaVerificationLauncher.open(result.personaVerificationUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.message ?? 'Registration submitted!',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ));
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OperatorLoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ));
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        // ── Header ─────────────────────────────────────────────────────────────
        Container(
          color: AppColors.backgroundDark,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    GestureDetector(
                      onTap: _prevStep,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: AppColors.backgroundDark, size: 20),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // Progress bar
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Password notice banner ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            border: Border(
                bottom:
                    BorderSide(color: AppColors.primary.withOpacity(0.2))),
          ),
          child: Row(children: [
            const Icon(Icons.info_rounded, color: AppColors.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Operator accounts use a separate password and identity verification.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
        ),

        // ── Error banner ────────────────────────────────────────────────────────
        if (_errorMessage != null)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppColors.error.withOpacity(0.08),
            child: Row(children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_errorMessage!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.error)),
              ),
            ]),
          ),

        // ── Page content ────────────────────────────────────────────────────────
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(),
              _buildStep2(),
              _buildStep3(),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Step 1: Association Info ──────────────────────────────────────────────
  Widget _buildStep1() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Association Information',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Your TODA registration details',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),

          _lbl('TODA Association Name', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _assocNameCtrl,
            hint: 'Davao-Central TODA',
            icon: Icons.groups_rounded,
          ),
          const SizedBox(height: 18),

          _lbl('Association Code / TODA ID', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _assocCodeCtrl,
            hint: 'e.g., DCC-TODA-001',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 4),
          Text(
            'This is your TODA Association ID used for login',
            style:
                GoogleFonts.poppins(fontSize: 11, color: AppColors.primary),
          ),
          const SizedBox(height: 18),

          _lbl('LTFRB Franchise Number', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _ltfrbCtrl,
            hint: 'LTFRB franchise number',
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 18),

          _lbl('Region / City', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _regionCtrl,
            hint: 'Davao City, Davao del Sur',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your LTFRB franchise number will be verified before your account is activated.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          _continueBtn(_nextStep),
          const SizedBox(height: 24),
        ]),
      );

  // ── Step 2: Contact Info ───────────────────────────────────────────────────
  Widget _buildStep2() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Contact Information',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Authorized officer account details',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),

          _lbl('Contact Person Name', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _contactNameCtrl,
            hint: 'Full name of authorized officer',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 18),

          _lbl('Operator Email', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _emailCtrl,
            hint: 'operator@toda.ph',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 18),

          _lbl('Mobile Number', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _mobileCtrl,
            hint: '+63 912 345 6789',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 18),

          _lbl('Operator Password', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _passwordCtrl,
            hint: 'Min. 8 characters',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 18),

          _lbl('Confirm Password', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _confirmCtrl,
            hint: 'Re-enter your password',
            icon: Icons.lock_person_outlined,
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          const SizedBox(height: 22),

          const PersonaVerificationNotice(),
          const SizedBox(height: 28),
          _continueBtn(_nextStep),
          const SizedBox(height: 24),
        ]),
      );

  // ── Step 3: Fleet Info ────────────────────────────────────────────────────
  Widget _buildStep3() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Fleet Information',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Tell us about your fleet size',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),

          _lbl('Total Tricycles in Fleet', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _totalTricyclesCtrl,
            hint: 'e.g., 402',
            icon: Icons.directions_car_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),

          _lbl('Number of Active Drivers'),
          const SizedBox(height: 6),
          _fld(
            controller: _activeDriversCtrl,
            hint: 'e.g., 315',
            icon: Icons.people_outline_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),

          _lbl('Primary Service Area', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _serviceAreaCtrl,
            hint: 'e.g., Davao City CBD, Panabo City',
            icon: Icons.map_outlined,
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_rounded,
                  color: Colors.green, size: 20),
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
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundDark,
                disabledBackgroundColor:
                    AppColors.backgroundDark.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text('Submit Registration',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      );

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _lbl(String text, {bool required = false}) => Row(children: [
        Text(text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            )),
        if (required)
          Text(' *',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              )),
      ]);

  Widget _fld({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    bool readOnly = false,
    bool obscureText = false,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        obscureText: obscureText,
        style: GoogleFonts.poppins(
          color: readOnly ? Colors.grey[500] : Colors.grey[800],
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline_rounded,
                  color: Colors.grey, size: 16)
              : suffixIcon,
          filled: true,
          fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: readOnly ? Colors.grey[300]! : AppColors.backgroundDark,
              width: 2,
            ),
          ),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28)),
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
