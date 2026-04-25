import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'operator_auth_service.dart';
import 'operator_dashboard_screen.dart';
import 'operator_registration_screen.dart';

class OperatorLoginScreen extends StatefulWidget {
  const OperatorLoginScreen({super.key});
  @override
  State<OperatorLoginScreen> createState() => _OperatorLoginScreenState();
}

class _OperatorLoginScreenState extends State<OperatorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _todaIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _todaIdCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // ✅ Real API call — not a fake delay
    final result = await OperatorAuthService.login(
      todaAssociationId: _todaIdCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(result.message ?? 'Login successful!',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OperatorDashboardScreen(),
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
      body: Column(children: [
        // Header
        Container(
          color: AppColors.backgroundDark,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary, borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: AppColors.backgroundDark, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Operator Login', style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white,
                    )),
                    Text('Fleet Management Access', style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.white54,
                    )),
                  ]),
                ]),
              ]),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),

        // Form
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),

              // Error banner
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMessage!, style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.error,
                    ))),
                  ]),
                ).animate().fadeIn(duration: 300.ms).shakeX(duration: 400.ms),

              _label('TODA Association ID', required: true),
              const SizedBox(height: 6),
              _field(controller: _todaIdCtrl, hint: 'Enter your association ID',
                icon: Icons.badge_outlined,
                suffixIcon: const Icon(Icons.info_outline_rounded,
                    color: Colors.grey, size: 18),
                validator: (v) => v == null || v.isEmpty ? 'TODA Association ID is required' : null),
              const SizedBox(height: 4),
              Text('e.g., "Davao-Central TODA #001" or your TODA code',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400])),

              const SizedBox(height: 18),

              _label('Operator Email', required: true),
              const SizedBox(height: 6),
              _field(controller: _emailCtrl, hint: 'operator@toda.ph',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                }),

              const SizedBox(height: 18),

              _label('Password', required: true),
              const SizedBox(height: 6),
              _field(
                controller: _passwordCtrl, hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey[400], size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text('Forgot Password?', style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500,
                  )),
                ),
              ),

              const SizedBox(height: 20),

              // Secure notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.security_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Secure Access', style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.backgroundDark,
                    )),
                    Text(
                      'Operator accounts have elevated privileges. Only authorized TODA personnel may access this portal.',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ])),
                ]),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundDark,
                    disabledBackgroundColor: AppColors.backgroundDark.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text('Login to Dashboard', style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 20),

              // Register link
              GestureDetector(
                onTap: () => Navigator.of(context).pushReplacement(PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const OperatorRegistrationScreen(),
                  transitionDuration: const Duration(milliseconds: 400),
                  transitionsBuilder: (_, anim, __, child) => SlideTransition(
                    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
                )),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Text('Register New Operator Account', style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary,
                    )),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.primary, size: 13),
                  ]),
                ),
              ),

              const SizedBox(height: 20),
              Center(child: Text('Secure operator portal • LTFRB Compliant',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]))),
              const SizedBox(height: 24),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _label(String text, {bool required = false}) => Row(children: [
    Text(text, style: GoogleFonts.poppins(
      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700],
    )),
    if (required) Text(' *', style: GoogleFonts.poppins(
      fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600,
    )),
  ]);

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscure,
    style: GoogleFonts.poppins(color: Colors.grey[800], fontSize: 15),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
      suffixIcon: suffixIcon,
      filled: true, fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.backgroundDark, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    validator: validator,
  );
}