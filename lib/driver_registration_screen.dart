import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'driver_auth_service.dart';
import 'driver_login_screen.dart';
import 'persona_verification_launcher.dart';
import 'persona_verification_notice.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});
  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _withAssociation = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 1 — Personal Info
  final _fullNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // Step 2 — TODA Association
  final _todaBranchCtrl = TextEditingController();

  // Step 3 — Vehicle Details
  final _bodyNumberCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _todaBranchCtrl.dispose();
    _bodyNumberCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    _licenseCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _validateAccountStep() {
    final email = _emailCtrl.text.trim();
    if (_fullNameCtrl.text.trim().split(RegExp(r'\s+')).length < 2) {
      setState(() => _errorMessage = 'Enter your full name');
      return false;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _errorMessage = 'Enter a valid email address');
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

  bool _validateVerificationStep() {
    if (_withAssociation && _todaBranchCtrl.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Enter your TODA Association Name or Code');
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (_currentStep == 0 && !_validateAccountStep()) return;
    if (_currentStep == 1 && !_validateVerificationStep()) return;
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

  Future<void> _completeRegistration() async {
    if (!_validateAccountStep() || !_validateVerificationStep()) return;
    if (_bodyNumberCtrl.text.trim().isEmpty ||
        _plateCtrl.text.trim().isEmpty ||
        _licenseCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await DriverAuthService.register(
      fullName: _fullNameCtrl.text,
      email: _emailCtrl.text,
      phone: _mobileCtrl.text,
      password: _passwordCtrl.text,
      driverType: _withAssociation ? 'associated' : 'independent',
      licenseNo: _licenseCtrl.text,
      todaBodyNumber: _bodyNumberCtrl.text,
      plateNo: _plateCtrl.text,
      vehicleColor: _colorCtrl.text.isNotEmpty ? _colorCtrl.text : null,
      todaAssociation: _withAssociation ? _todaBranchCtrl.text.trim() : null,
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
        pageBuilder: (_, __, ___) => const DriverLoginScreen(),
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
                          Text('Driver Registration',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                          Text('Step ${_currentStep + 1} of 3',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.white54)),
                        ]),
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

        // ── Info banner ─────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            border: Border(
                bottom: BorderSide(color: AppColors.primary.withOpacity(0.2))),
          ),
          child: Row(children: [
            const Icon(Icons.info_rounded, color: AppColors.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Driver accounts use a separate driver password and identity verification.',
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppColors.error.withOpacity(0.08),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
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

  // ── Step 1: Personal Info ──────────────────────────────────────────────────
  Widget _buildStep1() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Driver Account',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Use your driver details and password',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),
          _lbl('Full Name', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _fullNameCtrl,
            hint: 'Juan Dela Cruz',
            icon: Icons.person_outline_rounded,
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
          _lbl('Email Address', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _emailCtrl,
            hint: 'juan.delacruz@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 18),
          _lbl('Driver Password', required: true),
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
          const SizedBox(height: 28),
          _continueBtn(_nextStep),
          const SizedBox(height: 24),
        ]),
      );

  // ── Step 2: TODA Association ────────────────────────────────────────────────
  Widget _buildStep2() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Driver Type & Identity',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Choose how your driver application should be verified',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(
              child: _driverTypeCard(
                title: 'No Association',
                subtitle: 'Admin verifies your license',
                icon: Icons.badge_outlined,
                selected: !_withAssociation,
                onTap: () => setState(() {
                  _withAssociation = false;
                  _todaBranchCtrl.clear();
                  _errorMessage = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _driverTypeCard(
                title: 'With Association',
                subtitle: 'Operator approves your TODA membership',
                icon: Icons.groups_rounded,
                selected: _withAssociation,
                onTap: () => setState(() {
                  _withAssociation = true;
                  _errorMessage = null;
                }),
              ),
            ),
          ]),
          const SizedBox(height: 18),

          if (_withAssociation) ...[
            _lbl('TODA Association Name or Code', required: true),
            const SizedBox(height: 6),
            _fld(
              controller: _todaBranchCtrl,
              hint: 'Panabo City TODA or association code',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 4),
            Text(
              'Your application will appear in the operator Driver Management list.',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 18),
          ],

          const PersonaVerificationNotice(),
          const SizedBox(height: 18),

          // Benefits card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('Registration Options',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.backgroundDark,
                    )),
              ]),
              const SizedBox(height: 10),
              _benefit(
                  'Registered TODA membership is reviewed by its operator'),
              _benefit('Independent drivers are reviewed by TodaGo admin'),
              _benefit('Valid ID and face match are checked securely'),
            ]),
          ),
          const SizedBox(height: 28),
          _continueBtn(_nextStep),
          const SizedBox(height: 24),
        ]),
      );

  // ── Step 3: Vehicle Details ─────────────────────────────────────────────────
  Widget _buildStep3() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Vehicle Details',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Your tricycle registration information',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),

          _lbl('License Number', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _licenseCtrl,
            hint: 'N01-23-456789',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 18),

          _lbl('TODA / Vehicle Body Number', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _bodyNumberCtrl,
            hint: 'Body #123',
            icon: Icons.tag_rounded,
          ),
          const SizedBox(height: 4),
          Text(
            'Use your TODA body number if associated, or your vehicle body number if independent.',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 18),

          _lbl('Plate Number', required: true),
          const SizedBox(height: 6),
          _fld(
            controller: _plateCtrl,
            hint: 'ABC 1234',
            icon: Icons.document_scanner_outlined,
          ),
          const SizedBox(height: 18),

          _lbl('Vehicle Color'),
          const SizedBox(height: 6),
          _fld(
            controller: _colorCtrl,
            hint: 'Blue and Yellow',
            icon: Icons.color_lens_outlined,
          ),
          const SizedBox(height: 20),

          // Approval notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_user_rounded,
                  color: Colors.green, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Verification required',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.green[800],
                          )),
                      Text('You can log in after admin or operator approval.',
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
              onPressed: _isLoading ? null : _completeRegistration,
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
                  : Text('Complete Registration',
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

  Widget _driverTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.14)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey[200]!,
              width: selected ? 2 : 1,
            ),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon,
                size: 24,
                color: selected ? AppColors.primary : AppColors.textHint),
            const SizedBox(height: 10),
            Text(title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
            const SizedBox(height: 4),
            Text(subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[600],
                  height: 1.25,
                )),
          ]),
        ),
      );

  Widget _benefit(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          const Icon(Icons.circle, size: 5, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
          ),
        ]),
      );

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
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
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
