import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_auth_service.dart';
import 'app_theme.dart';
import 'fare_settings_service.dart';
import 'panabo_config.dart';
import 'splash_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  bool _isSavingFare = false;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _drivers = [];
  FareSettings _fareSettings = const FareSettings();
  late final TextEditingController _fuelPriceController;

  @override
  void initState() {
    super.initState();
    _fuelPriceController = TextEditingController(
      text: _fareSettings.fuelPricePerLiter.toStringAsFixed(2),
    );
    _load();
  }

  @override
  void dispose() {
    _fuelPriceController.dispose();
    super.dispose();
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
        AdminAuthService.fetchFareSettings(),
      ]);
      if (!mounted) return;
      final fareSettings =
          (results[2] as FareSettings?) ?? const FareSettings();
      setState(() {
        _stats = (results[0] as Map<String, dynamic>?) ?? {};
        _drivers = (results[1] as List<Map<String, dynamic>>?) ??
            <Map<String, dynamic>>[];
        _fareSettings = fareSettings;
        _fuelPriceController.text =
            fareSettings.fuelPricePerLiter.toStringAsFixed(2);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to load admin dashboard.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFareSettings() async {
    final fuelPrice = double.tryParse(_fuelPriceController.text.trim());
    if (fuelPrice == null || fuelPrice < 20) {
      _showSnack('Enter a valid gasoline price.', AppColors.error);
      return;
    }

    setState(() => _isSavingFare = true);
    final result = await AdminAuthService.updateFareSettings(
      fuelPricePerLiter: fuelPrice,
      premiumMultiplier: _fareSettings.premiumMultiplier,
    );
    if (!mounted) return;
    setState(() {
      _isSavingFare = false;
      if (result.success && result.fareSettings != null) {
        _fareSettings = result.fareSettings!;
        _fuelPriceController.text =
            _fareSettings.fuelPricePerLiter.toStringAsFixed(2);
      }
    });
    _showSnack(
      result.message ??
          (result.success
              ? 'Fare settings updated.'
              : 'Unable to update fare.'),
      result.success ? AppColors.success : AppColors.error,
    );
  }

  Future<void> _setApproval(Map<String, dynamic> driver, bool approve) async {
    final driverId = driver['driver_id']?.toString();
    if (driverId == null || driverId.isEmpty) return;
    final result = await AdminAuthService.updateDriverVerification(
      driverId: driverId,
      isVerified: approve,
    );
    if (!mounted) return;
    _showSnack(
      result.message ?? (approve ? 'Driver approved.' : 'Approval revoked.'),
      result.success ? AppColors.success : AppColors.error,
    );
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

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  bool _isVerified(Map<String, dynamic> driver) =>
      driver['is_verified'] == true ||
      driver['is_verified']?.toString() == 'true';

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _fuelRangeLabel(PanaboFareBand band) {
    if (band.maxFuelPrice == null) {
      return 'PHP ${band.minFuelPrice.toStringAsFixed(2)} and up';
    }
    return 'PHP ${band.minFuelPrice.toStringAsFixed(2)} - ${band.maxFuelPrice!.toStringAsFixed(2)}';
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _fareCard(),
          const SizedBox(height: 16),
          Text('Independent Driver Applications',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
          const SizedBox(height: 10),
          if (_drivers.isEmpty)
            _emptyDriversCard()
          else
            ...List.generate(
              _drivers.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _driverCard(_drivers[index], index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fareCard() {
    final band = _fareSettings.band;
    final regular = PanaboFarePolicy.formatPeso(
      PanaboFarePolicy.fareForDistanceKm(
        0,
        fuelPricePerLiter: _fareSettings.fuelPricePerLiter,
      ),
    );
    final discounted = PanaboFarePolicy.formatPeso(
      PanaboFarePolicy.fareForDistanceKm(
        0,
        discounted: true,
        fuelPricePerLiter: _fareSettings.fuelPricePerLiter,
      ),
    );
    final premium = PanaboFarePolicy.formatPeso(
      PanaboFarePolicy.fareForDistanceKm(
        0,
        fuelPricePerLiter: _fareSettings.fuelPricePerLiter,
        premiumMultiplier: _fareSettings.premiumMultiplier,
      ),
    );

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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_gas_station_rounded,
                color: AppColors.backgroundDark, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Fare Regulation',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
          ),
          _pill('ADMIN', AppColors.primary),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _fuelPriceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Gasoline Price / Liter',
                prefixText: 'PHP ',
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.backgroundDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSavingFare ? null : _saveFareSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSavingFare
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Save',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _meta('Fuel Band', _fuelRangeLabel(band)),
        _meta('Regular', regular),
        _meta('Student/Senior/PWD', discounted),
        _meta('Toda-Express', '$premium (+30%)'),
      ]),
    );
  }

  Widget _emptyDriversCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDF2)),
        ),
        child: Text('No independent driver applications',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint)),
      );

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
            width: 132,
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
