import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_auth_service.dart';
import 'app_theme.dart';
import 'splash_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        AdminAuthService.fetchStats(),
        AdminAuthService.fetchIndependentDrivers(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = (results[0] as Map<String, dynamic>?) ?? {};
        _drivers = (results[1] as List<Map<String, dynamic>>?) ??
            <Map<String, dynamic>>[];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to load admin dashboard.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setApproval(Map<String, dynamic> driver, bool approve) async {
    final driverId = driver['driver_id']?.toString();
    if (driverId == null || driverId.isEmpty) return;
    final result = await AdminAuthService.updateDriverVerification(
      driverId: driverId,
      isVerified: approve,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        result.message ?? (approve ? 'Driver approved.' : 'Approval revoked.'),
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      backgroundColor: result.success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
    if (result.success) await _load();
  }

  Future<void> _logout() async {
    await AdminAuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  bool _isVerified(Map<String, dynamic> driver) =>
      driver['is_verified'] == true ||
      driver['is_verified']?.toString() == 'true';

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(children: [
        Container(
          color: AppColors.backgroundDark,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded,
                            color: AppColors.backgroundDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Admin Dashboard',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            )),
                      ),
                      IconButton(
                        onPressed: _isLoading ? null : _load,
                        icon: const Icon(Icons.refresh_rounded,
                            color: Colors.white),
                      ),
                      IconButton(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.white),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _statTile(
                        'Pending',
                        _asInt(_stats['pending_independent_drivers'])
                            .toString(),
                        AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      _statTile(
                        'Approved',
                        _asInt(_stats['approved_independent_drivers'])
                            .toString(),
                        AppColors.success,
                      ),
                      const SizedBox(width: 10),
                      _statTile(
                        'Operator Queue',
                        _asInt(_stats['pending_associated_drivers']).toString(),
                        Colors.blue,
                      ),
                    ]),
                  ]),
            ),
          ),
        ).animate().fadeIn(duration: 350.ms),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!,
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint)),
      );
    }
    if (_drivers.isEmpty) {
      return Center(
        child: Text('No independent driver applications',
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _drivers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _driverCard(_drivers[i], i),
      ),
    );
  }

  Widget _driverCard(Map<String, dynamic> driver, int index) {
    final verified = _isVerified(driver);
    final color = verified ? AppColors.success : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(driver['driver_name']?.toString() ?? 'Driver',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
          ),
          _pill(verified ? 'Approved' : 'Pending', color),
        ]),
        const SizedBox(height: 10),
        _meta('License', driver['license_no']),
        _meta('Vehicle',
            '${driver['toda_body_number'] ?? '-'} / ${driver['plate_no'] ?? '-'}'),
        _meta('Phone', driver['phone']),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: verified
              ? OutlinedButton.icon(
                  onPressed: () => _setApproval(driver, false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Revoke Approval'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () => _setApproval(driver, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve Driver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundDark,
                    foregroundColor: Colors.white,
                  ),
                ),
        ),
      ]),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 25 * index),
          duration: 250.ms,
        );
  }

  Widget _statTile(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style:
                    GoogleFonts.poppins(fontSize: 10, color: Colors.white60)),
            Text(value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                )),
          ]),
        ),
      );

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            )),
      );

  Widget _meta(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(
            width: 68,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textHint)),
          ),
          Expanded(
            child: Text(value?.toString() ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.backgroundDark,
                )),
          ),
        ]),
      );
}
