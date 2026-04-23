import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'driver_login_screen.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Step 1 — Personal Info
  final _fullNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Step 2 — TODA Association
  final _todaBranchCtrl = TextEditingController();

  // Step 3 — Vehicle Details
  final _bodyNumberCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _todaBranchCtrl.dispose();
    _bodyNumberCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
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
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Registration submitted! Pending verification.',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DriverLoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back_ios_rounded,
                                color: AppColors.textPrimary, size: 16),
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
                                  color: AppColors.textPrimary,
                                )),
                            Text('Step ${_currentStep + 1} of 3',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                )),
                          ],
                        ),
                      ],
                    ),
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
                              )),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pages
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
        ],
      ),
    );
  }

  // ── STEP 1: Personal Information ─────────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Personal Information',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Tell us about yourself',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 28),

          _buildLightLabel('Full Name', required: true),
          const SizedBox(height: 6),
          _buildLightField(
            controller: _fullNameCtrl,
            hint: 'Juan Dela Cruz',
            icon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 20),

          _buildLightLabel('Mobile Number', required: true),
          const SizedBox(height: 6),
          _buildLightField(
            controller: _mobileCtrl,
            hint: '+63 912 345 6789',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 20),

          _buildLightLabel('Email Address'),
          const SizedBox(height: 6),
          _buildLightField(
            controller: _emailCtrl,
            hint: 'juan.delacruz@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 20),

          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF1565C0), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Verification Required',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1565C0),
                          )),
                      Text(
                          "We'll send a verification code to your mobile number to confirm your identity.",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF1565C0),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          _buildContinueButton(_nextStep),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── STEP 2: TODA Association ──────────────────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('TODA Association',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Your official TODA registration details',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 28),

          _buildLightLabel('TODA Branch', required: true),
          const SizedBox(height: 6),
          _buildLightField(
            controller: _todaBranchCtrl,
            hint: 'Panabo City TODA',
            icon: Icons.location_on_outlined,
          ),

          const SizedBox(height: 20),

          // Benefits card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFFFFCC02).withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: Color(0xFFFFCC02), size: 20),
                    const SizedBox(width: 8),
                    Text('TODA Certification Benefits',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.backgroundDark,
                        )),
                  ],
                ),
                const SizedBox(height: 10),
                _benefitItem('Priority ride requests from verified passengers'),
                _benefitItem('Access to exclusive TODA-only service areas'),
                _benefitItem(
                    'Lower commission rates (10% vs 15% for non-TODA)'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Document verification
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.upload_file_rounded,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Document Verification',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          )),
                      Text(
                          "You'll need to upload your TODA membership card and franchise documents.",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.orange[700],
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildContinueButton(_nextStep),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── STEP 3: Vehicle Details ───────────────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Vehicle Details',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          Text('Your tricycle registration information',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 28),

          _buildLightLabel('TODA Body Number', required: true),
          const SizedBox(height: 6),
          _buildLightField(
            controller: _bodyNumberCtrl,
            hint: 'Enter your TODA body number',
            icon: Icons.tag_rounded,
            suffixIcon: const Icon(Icons.info_outline_rounded,
                color: Colors.grey, size: 18),
          ),
          const SizedBox(height: 4),
          Text('e.g., "Davao City #402" or "Panabo TODA #115"',
              style:
                  GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),

          const SizedBox(height: 20),

          _buildLightLabel('Plate Number', required: true),
          const SizedBox(height: 6),
          _buildLightField(
            controller: _plateCtrl,
            hint: 'ABC 1234',
            icon: Icons.document_scanner_outlined,
          ),

          const SizedBox(height: 20),

          _buildLightLabel('Vehicle Color', required: true),
          const SizedBox(height: 6),
          _buildLightField(
            controller: _colorCtrl,
            hint: 'Blue and Yellow',
            icon: Icons.color_lens_outlined,
          ),

          const SizedBox(height: 20),

          // Compliance badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Compliance Certified',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          )),
                      Text(
                          'TodaGo is a specialized, compliant local transport service.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green[700],
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Complete Registration button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _completeRegistration,
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
                  : Text('Complete Registration',
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

  Widget _benefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Color(0xFFFFCC02)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Widget _buildLightLabel(String text, {bool required = false}) {
    return Row(
      children: [
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
      ],
    );
  }

  Widget _buildLightField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.backgroundDark, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildContinueButton(VoidCallback onTap) {
    return SizedBox(
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
}
