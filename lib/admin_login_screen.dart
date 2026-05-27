import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'app_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _secretCtrl = TextEditingController();
  bool _obscureSecret = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_secretCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Admin secret is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AdminAuthService.login(secret: _secretCtrl.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      setState(() => _errorMessage = result.message);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AdminDashboardScreen(),
        transitionDuration: const Duration(milliseconds: 450),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const Spacer(),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: AppColors.backgroundDark, size: 22),
              ),
            ]).animate().fadeIn(duration: 350.ms),
            const SizedBox(height: 44),
            Text('Admin Access',
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                )).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            Text('Approve independent driver applications',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.error)),
                  ),
                ]),
              ).animate().fadeIn(duration: 250.ms).shakeX(duration: 350.ms),
            TextField(
              controller: _secretCtrl,
              obscureText: _obscureSecret,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Admin Secret',
                hintText: 'Enter admin secret',
                prefixIcon: const Icon(Icons.key_rounded,
                    color: AppColors.textHint, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureSecret
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureSecret = !_obscureSecret),
                ),
              ),
              onSubmitted: (_) => _login(),
            ).animate().fadeIn(delay: 180.ms),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _login,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: AppColors.backgroundDark,
                        ),
                      )
                    : const Icon(Icons.lock_open_rounded),
                label:
                    Text(_isLoading ? 'Checking...' : 'Open Admin Dashboard'),
              ),
            ).animate().fadeIn(delay: 260.ms),
          ]),
        ),
      ),
    );
  }
}
