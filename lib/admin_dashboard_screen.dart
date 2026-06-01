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
  List<Map<String, dynamic>> _routePerformance = [];
  List<Map<String, dynamic>> _peakHours = [];
  FareSettings _fareSettings = const FareSettings();

  late final TextEditingController _fuelPriceController;
  late final TextEditingController _premiumPercentController;
  List<TextEditingController> _regularFareControllers = [];
  List<TextEditingController> _discountFareControllers = [];

  @override
  void initState() {
    super.initState();
    _fuelPriceController = TextEditingController();
    _premiumPercentController = TextEditingController();
    _syncFareControllers(_fareSettings, disposeExisting: false);
    _load();
  }

  @override
  void dispose() {
    _fuelPriceController.dispose();
    _premiumPercentController.dispose();
    for (final controller in _regularFareControllers) {
      controller.dispose();
    }
    for (final controller in _discountFareControllers) {
      controller.dispose();
    }
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
        AdminAuthService.fetchRoutePerformance(),
        AdminAuthService.fetchPeakHours(),
      ]);
      if (!mounted) return;
      final fareSettings =
          (results[2] as FareSettings?) ?? const FareSettings();
      setState(() {
        _stats = (results[0] as Map<String, dynamic>?) ?? {};
        _drivers = (results[1] as List<Map<String, dynamic>>?) ??
            <Map<String, dynamic>>[];
        _fareSettings = fareSettings;
        _routePerformance = (results[3] as List<Map<String, dynamic>>?) ??
            <Map<String, dynamic>>[];
        _peakHours = (results[4] as List<Map<String, dynamic>>?) ??
            <Map<String, dynamic>>[];
        _syncFareControllers(fareSettings);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to load admin dashboard.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncFareControllers(
    FareSettings settings, {
    bool disposeExisting = true,
  }) {
    if (disposeExisting) {
      for (final controller in _regularFareControllers) {
        controller.dispose();
      }
      for (final controller in _discountFareControllers) {
        controller.dispose();
      }
    }
    _fuelPriceController.text = settings.fuelPricePerLiter.toStringAsFixed(2);
    _premiumPercentController.text =
        ((settings.premiumMultiplier - 1) * 100).toStringAsFixed(0);
    _regularFareControllers = settings.fareBands
        .map((band) => TextEditingController(
              text: _numberText(band.regularFare),
            ))
        .toList();
    _discountFareControllers = settings.fareBands
        .map((band) => TextEditingController(
              text: _numberText(band.discountedFare),
            ))
        .toList();
  }

  Future<void> _saveFareSettings() async {
    final fuelPrice = double.tryParse(_fuelPriceController.text.trim());
    final premiumPercent =
        double.tryParse(_premiumPercentController.text.trim());
    if (fuelPrice == null || fuelPrice < 0) {
      _showSnack('Enter a valid gasoline price.', AppColors.error);
      return;
    }
    if (premiumPercent == null || premiumPercent < 0 || premiumPercent > 200) {
      _showSnack('Enter a premium increase from 0 to 200%.', AppColors.error);
      return;
    }

    final fareBands = <Map<String, dynamic>>[];
    for (var i = 0; i < _fareSettings.fareBands.length; i++) {
      final source = _fareSettings.fareBands[i];
      final regularFare =
          double.tryParse(_regularFareControllers[i].text.trim());
      final discountFare =
          double.tryParse(_discountFareControllers[i].text.trim());
      if (regularFare == null || discountFare == null) {
        _showSnack('Complete every fare band before saving.', AppColors.error);
        return;
      }
      fareBands.add({
        'minFuelPrice': source.minFuelPrice,
        'maxFuelPrice': source.maxFuelPrice,
        'regularFare': regularFare,
        'discountedFare': discountFare,
      });
    }

    setState(() => _isSavingFare = true);
    final result = await AdminAuthService.updateFareSettings(
      fuelPricePerLiter: fuelPrice,
      premiumMultiplier: 1 + (premiumPercent / 100),
      fareBands: fareBands,
    );
    if (!mounted) return;
    setState(() {
      _isSavingFare = false;
      if (result.success && result.fareSettings != null) {
        _fareSettings = result.fareSettings!;
        _syncFareControllers(_fareSettings);
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

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(dynamic value) {
    final amount = _asDouble(value);
    return 'PHP ${amount.toStringAsFixed(0)}';
  }

  String _durationLabel(dynamic value) {
    final minutes = _asDouble(value);
    if (minutes <= 0) return '-';
    if (minutes < 60) {
      final decimals = minutes < 10 && minutes % 1 != 0 ? 1 : 0;
      return '${minutes.toStringAsFixed(decimals)} min';
    }
    final hours = minutes ~/ 60;
    final mins = (minutes % 60).round();
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  String _distanceLabel(dynamic value) {
    final distance = _asDouble(value);
    if (distance <= 0) return '-';
    return '${distance.toStringAsFixed(1)} km';
  }

  String _speedLabel(dynamic value) {
    final speed = _asDouble(value);
    if (speed <= 0) return '-';
    return '${speed.toStringAsFixed(1)} km/h';
  }

  String _numberText(double value) {
    if ((value - value.round()).abs() < 0.001) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _fareCard(),
          const SizedBox(height: 16),
          _peakHoursCard(),
          const SizedBox(height: 16),
          _routePerformanceCard(),
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

  Widget _peakHoursCard() {
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
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time_filled_rounded,
                color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Peak Hour Analysis',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  )),
              Text('System-wide busiest request hours',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textHint,
                  )),
            ]),
          ),
          _pill('30 DAYS', Colors.orange),
        ]),
        const SizedBox(height: 12),
        if (_peakHours.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No peak hour data yet',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textHint,
                )),
          )
        else
          ...List.generate(
            _peakHours.length,
            (index) => _peakHourRow(_peakHours[index], index),
          ),
      ]),
    );
  }

  Widget _peakHourRow(Map<String, dynamic> hour, int index) {
    final label = hour['hour_label']?.toString() ?? 'Hour';
    final completion = _asDouble(hour['completion_rate']);
    return Container(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 12, bottom: 12),
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : const Border(top: BorderSide(color: Color(0xFFF0F2F5))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
          ),
          _pill('#${index + 1}', Colors.orange),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _routeMetric(Icons.local_taxi_rounded, 'Requests',
                '${_asInt(hour['total_requests'])}'),
            _routeMetric(Icons.verified_rounded, 'Completed',
                '${_asInt(hour['completed_trips'])}'),
            _routeMetric(Icons.cancel_rounded, 'Cancelled',
                '${_asInt(hour['cancelled_trips'])}'),
            _routeMetric(Icons.percent_rounded, 'Completion',
                '${completion.toStringAsFixed(0)}%'),
            _routeMetric(Icons.payments_rounded, 'Revenue',
                _money(hour['gross_revenue'])),
          ],
        ),
      ]),
    );
  }

  Widget _routePerformanceCard() {
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
              color: Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.alt_route_rounded,
                color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Route Performance Analysis',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  )),
              Text('System-wide completed and cancelled trips',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textHint,
                  )),
            ]),
          ),
          _pill('30 DAYS', Colors.blue),
        ]),
        const SizedBox(height: 12),
        if (_routePerformance.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No route performance data yet',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textHint,
                )),
          )
        else
          ...List.generate(
            _routePerformance.length,
            (index) => _routePerformanceRow(_routePerformance[index], index),
          ),
      ]),
    );
  }

  Widget _routePerformanceRow(Map<String, dynamic> route, int index) {
    final from = route['route_from']?.toString() ?? 'Pickup';
    final to = route['route_to']?.toString() ?? 'Destination';
    final completion = _asDouble(route['completion_rate']);
    final healthColor = completion >= 85
        ? AppColors.success
        : completion >= 65
            ? Colors.orange
            : AppColors.error;
    final healthLabel = completion >= 85
        ? 'Strong'
        : completion >= 65
            ? 'Watch'
            : 'Low';

    return Container(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 12, bottom: 12),
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : const Border(top: BorderSide(color: Color(0xFFF0F2F5))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text('$from to $to',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
          ),
          const SizedBox(width: 8),
          _pill(healthLabel, healthColor),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _routeMetric(Icons.route_rounded, 'Trips',
                '${_asInt(route['completed_trips'])}/${_asInt(route['total_trips'])}'),
            _routeMetric(Icons.verified_rounded, 'Completion',
                '${completion.toStringAsFixed(0)}%'),
            _routeMetric(Icons.cancel_rounded, 'Cancelled',
                '${_asInt(route['cancelled_trips'])}'),
            _routeMetric(Icons.timer_rounded, 'Avg Time',
                _durationLabel(route['avg_trip_minutes'])),
            _routeMetric(Icons.speed_rounded, 'Avg Speed',
                _speedLabel(route['avg_speed_kmh'])),
            _routeMetric(Icons.straighten_rounded, 'Distance',
                _distanceLabel(route['avg_distance_km'])),
            _routeMetric(Icons.payments_rounded, 'Revenue',
                _money(route['gross_revenue'])),
          ],
        ),
      ]),
    );
  }

  Widget _routeMetric(IconData icon, String label, String value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: AppColors.textHint),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
        Text(value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.backgroundDark,
            )),
      ]),
    ]);
  }

  Widget _fareCard() {
    final band = _fareSettings.band;
    final regular = PanaboFarePolicy.formatPeso(
      _fareSettings.fareForDistanceKm(0),
    );
    final discounted = PanaboFarePolicy.formatPeso(
      _fareSettings.fareForDistanceKm(0, discounted: true),
    );
    final premium = PanaboFarePolicy.formatPeso(
      _fareSettings.fareForDistanceKm(
        0,
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
              color: AppColors.primary.withValues(alpha: 0.18),
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
        _fareSettingFields(),
        const SizedBox(height: 12),
        _meta('Active Fuel Band', _fuelRangeLabel(band)),
        _meta('Regular Fare', regular),
        _meta('Student/Senior/PWD', discounted),
        _meta('Toda-Express', '$premium (+${_premiumPercentLabel()}%)'),
        const Divider(height: 24, color: Color(0xFFE8EDF2)),
        Text('Fuel Band Rates',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.backgroundDark,
            )),
        const SizedBox(height: 8),
        ...List.generate(
          _fareSettings.fareBands.length,
          (index) => _fareBandRow(index),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSavingFare ? null : _saveFareSettings,
            icon: _isSavingFare
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text('Save Fare Table',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.backgroundDark,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fareSettingFields() {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 420;
      final fields = [
        _numberField(
          controller: _fuelPriceController,
          label: 'Gasoline Price / Liter',
          suffix: 'PHP',
        ),
        _numberField(
          controller: _premiumPercentController,
          label: 'Toda-Express Increase',
          suffix: '%',
        ),
      ];
      if (compact) {
        return Column(children: [
          fields[0],
          const SizedBox(height: 10),
          fields[1],
        ]);
      }
      return Row(children: [
        Expanded(child: fields[0]),
        const SizedBox(width: 10),
        Expanded(child: fields[1]),
      ]);
    });
  }

  Widget _fareBandRow(int index) {
    final band = _fareSettings.fareBands[index];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F5))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_fuelRangeLabel(band),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.backgroundDark,
            )),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _numberField(
              controller: _regularFareControllers[index],
              label: 'Regular',
              suffix: 'PHP',
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _numberField(
              controller: _discountFareControllers[index],
              label: 'Student/Senior/PWD',
              suffix: 'PHP',
              compact: true,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    bool compact = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: compact,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 10 : 14,
        ),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      style: GoogleFonts.poppins(
        fontSize: compact ? 13 : 14,
        fontWeight: FontWeight.w700,
        color: AppColors.backgroundDark,
      ),
    );
  }

  String _premiumPercentLabel() {
    final percent = (_fareSettings.premiumMultiplier * 100) - 100;
    return percent.toStringAsFixed(percent.roundToDouble() == percent ? 0 : 1);
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
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
          color: color.withValues(alpha: 0.12),
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
