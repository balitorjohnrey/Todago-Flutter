import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'register_screen.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await AuthService.login(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => RoleSelectionScreen(
            successMessage: result.message ?? 'Login successful! Welcome back 👋',
          ),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildBackButton(),
                  const Spacer(),
                  _buildMiniLogo(),
                ],
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 40),
              Text(
                'Welcome\nBack 👋',
                style: GoogleFonts.poppins(
                  fontSize: 34, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, height: 1.15, letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideX(begin: -0.2, end: 0),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue your ride',
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
              ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_errorMessage != null)
                      _buildErrorBanner(_errorMessage!)
                          .animate().fadeIn(duration: 300.ms).shakeX(duration: 400.ms),
                    _buildField(
                      controller: _emailCtrl, label: 'Email Address',
                      hint: 'you@example.com', icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email is required';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Enter a valid email';
                        return null;
                      },
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _passwordCtrl, label: 'Password',
                      hint: '••••••••', icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.textHint, size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        return null;
                      },
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: Text('Forgot Password?',
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                      ),
                    ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.backgroundDark))
                            : Text('Sign In',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.backgroundDark)),
                      ),
                    ).animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(begin: 0.3, end: 0),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
                  ),
                  const Expanded(child: Divider(color: AppColors.divider)),
                ],
              ).animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 24),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                    children: [
                      const TextSpan(text: "Don't have an account? "),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const RegisterScreen(),
                            transitionDuration: const Duration(milliseconds: 400),
                            transitionsBuilder: (_, anim, __, child) => SlideTransition(
                              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                              child: child,
                            ),
                          )),
                          child: Text('Sign Up',
                            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 700.ms),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() => GestureDetector(
    onTap: () => Navigator.of(context).pop(),
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18),
    ),
  );

  Widget _buildMiniLogo() => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.bolt_rounded, color: AppColors.backgroundDark, size: 22),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String label, required String hint, required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false, Widget? suffixIcon,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller, keyboardType: keyboardType, obscureText: obscureText,
    style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 15),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
      suffixIcon: suffixIcon,
    ),
    validator: validator,
  );

  Widget _buildErrorBanner(String message) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.error))),
      ],
    ),
  );
}