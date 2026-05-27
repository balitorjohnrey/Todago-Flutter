import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'driver_auth_service.dart';
import 'driver_dashboard_screen.dart';
import 'driver_registration_screen.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});
  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _associationCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _withAssociation = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _associationCtrl.dispose();
    _licenseCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final association = _associationCtrl.text.trim();
    final licenseNo = _licenseCtrl.text.trim();
    final password = _passwordCtrl.text;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // ✅ Real API call — not a fake delay
    final result = await DriverAuthService.login(
      driverType: _withAssociation ? 'associated' : 'independent',
      licenseNo: licenseNo,
      todaAssociation: _withAssociation ? association : null,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(result.message ?? 'Login successful!',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DriverDashboardScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
        (_) => false,
      );
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          width: double.infinity,
          color: AppColors.backgroundDark,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
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
                    const SizedBox(height: 20),
                    Text('Driver Login',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        )),
                    Text('Welcome back, partner!',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white54,
                        )),
                  ]),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),

        // Form
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),

              // Error banner
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isApprovalMessage(_errorMessage!)
                        ? AppColors.primary.withOpacity(0.12)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isApprovalMessage(_errorMessage!)
                          ? AppColors.primary.withOpacity(0.35)
                          : AppColors.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      _isApprovalMessage(_errorMessage!)
                          ? Icons.pending_actions_rounded
                          : Icons.error_outline,
                      color: _isApprovalMessage(_errorMessage!)
                          ? AppColors.primary
                          : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_errorMessage!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _isApprovalMessage(_errorMessage!)
                                  ? AppColors.backgroundDark
                                  : AppColors.error,
                            ))),
                  ]),
                ).animate().fadeIn(duration: 300.ms),

              Row(children: [
                Expanded(
                  child: _driverTypeCard(
                    title: 'No Association',
                    icon: Icons.badge_outlined,
                    selected: !_withAssociation,
                    onTap: () => setState(() {
                      _withAssociation = false;
                      _associationCtrl.clear();
                      _errorMessage = null;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _driverTypeCard(
                    title: 'With Association',
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
                _label('TODA Association Name or Code', required: true),
                const SizedBox(height: 6),
                _field(
                  controller: _associationCtrl,
                  hint: 'Panabo City TODA or association code',
                  icon: Icons.location_on_outlined,
                  suffixIcon: const Icon(Icons.info_outline_rounded,
                      color: Colors.grey, size: 18),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'TODA Association Name or Code is required'
                      : null,
                ),
                const SizedBox(height: 18),
              ],

              _label('License Number', required: true),
              const SizedBox(height: 6),
              _field(
                controller: _licenseCtrl,
                hint: 'N01-23-456789',
                icon: Icons.document_scanner_outlined,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'License number is required'
                    : null,
              ),

              const SizedBox(height: 18),

              _label('Password', required: true),
              const SizedBox(height: 6),
              _field(
                controller: _passwordCtrl,
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey[400],
                      size: 20),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Password is required' : null,
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text('Forgot Password?',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      )),
                ),
              ),

              const SizedBox(height: 24),

              // Secure notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.security_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                    _withAssociation
                        ? 'Your TODA operator must approve your account before you can log in.'
                        : 'TodaGo admin must approve your independent driver account before you can log in.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[700]),
                  )),
                ]),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
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
                              strokeWidth: 2.5, color: Colors.white))
                      : Text('Login',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),

              const SizedBox(height: 20),

              // Register link
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.textHint, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('First time?',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.backgroundDark,
                            )),
                        Text('New drivers must complete registration first.',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textHint)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  const DriverRegistrationScreen(),
                              transitionDuration:
                                  const Duration(milliseconds: 400),
                              transitionsBuilder: (_, anim, __, child) =>
                                  SlideTransition(
                                position: Tween<Offset>(
                                        begin: const Offset(1, 0),
                                        end: Offset.zero)
                                    .animate(CurvedAnimation(
                                        parent: anim, curve: Curves.easeOut)),
                                child: child,
                              ),
                            ),
                          ),
                          child: Text('Register as Driver',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ])),
                ]),
              ),

              const SizedBox(height: 24),
              Center(
                  child: Text(
                      'By logging in, you agree to our Terms of Service',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey[400]))),
              const SizedBox(height: 24),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _driverTypeCard({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          child: Row(children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textHint,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  )),
            ),
          ]),
        ),
      );

  Widget _label(String text, {bool required = false}) => Row(children: [
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

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        obscureText: obscure,
        textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
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
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      );

  bool _isApprovalMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('pending') ||
        lower.contains('approval') ||
        lower.contains('approve') ||
        lower.contains('verified');
  }
}
