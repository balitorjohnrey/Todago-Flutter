import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_theme.dart';
import 'fare_settings_service.dart';
import 'finding_driver_screen.dart';
import 'live_map_screen.dart';
import 'map_service.dart';
import 'panabo_config.dart';
import 'trip_service.dart';

class ServiceSelectionScreen extends StatefulWidget {
  final String pickupName;
  final String destinationName;
  final LatLng? pickupLatLng;
  final LatLng? destinationLatLng;
  final int? etaMinutes;
  final double? distanceKm;
  final String? initialServiceType;

  const ServiceSelectionScreen({
    super.key,
    this.pickupName = 'Your Location',
    this.destinationName = 'Destination',
    this.pickupLatLng,
    this.destinationLatLng,
    this.etaMinutes,
    this.distanceKm,
    this.initialServiceType,
  });

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  int _selected = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _onlineDrivers = [];
  bool _driversLoaded = false;
  bool _isScheduled = false;
  DateTime? _scheduledAt;
  FareSettings _fareSettings = const FareSettings();
  bool _fareSettingsLoaded = false;
  String _passengerFareType = 'regular';
  int _sharedPassengerCount = 2;
  late final TextEditingController _sharedPassengerController;
  late final TextEditingController _otherFeeController;
  late final TextEditingController _pickupItemController;
  late final TextEditingController _pickupWeightController;
  late final TextEditingController _driverNoteController;
  double _otherFeeAmount = 0;
  String? _otherFeeLabel;
  List<String> _dropoffNames = [];
  List<LatLng?> _dropoffPoints = [];

  final List<Map<String, dynamic>> _services = [
    {
      'id': 'solo',
      'name': 'Solo',
      'subtitle': 'Ride alone, enjoy privacy',
      'icon': Icons.person_rounded,
      'passengers': '1 passenger',
      'price': 0.0,
      'priceLabel': 'PHP 0',
      'priceSubLabel': 'Regular rate',
      'eta': '3 min',
      'premium': false,
    },
    {
      'id': 'shared',
      'name': 'Shared',
      'subtitle': 'Share the ride, save money',
      'icon': Icons.people_rounded,
      'passengers': '2-6 passengers',
      'price': 0.0,
      'priceLabel': 'PHP 0',
      'priceSubLabel': 'PHP 0 each',
      'eta': '3 min',
      'premium': false,
    },
    {
      'id': 'express',
      'name': 'Toda-Express',
      'subtitle': 'Priority pickup, fastest route',
      'icon': Icons.bolt_rounded,
      'passengers': '1 passenger',
      'price': 0.0,
      'priceLabel': 'PHP 0',
      'priceSubLabel': '+30% premium',
      'eta': '3 min',
      'premium': true,
    },
    {
      'id': 'pickup',
      'name': 'Pick-up',
      'subtitle': 'Send the driver to pick up an item',
      'icon': Icons.inventory_2_rounded,
      'passengers': 'Items only',
      'price': 0.0,
      'priceLabel': 'PHP 0',
      'priceSubLabel': 'Heavy items can add fees',
      'eta': '3 min',
      'premium': false,
    },
  ];

  String get _selectedServiceId => _services[_selected]['id'] as String;

  bool get _discountedPassenger => _passengerFareType != 'regular';

  String get _passengerFareLabel {
    switch (_passengerFareType) {
      case 'student':
        return 'Student';
      case 'senior':
        return 'Senior';
      case 'pwd':
        return 'PWD';
      default:
        return 'Regular';
    }
  }

  @override
  void initState() {
    super.initState();
    _sharedPassengerController =
        TextEditingController(text: _sharedPassengerCount.toString());
    _otherFeeController = TextEditingController();
    _pickupItemController = TextEditingController();
    _pickupWeightController = TextEditingController();
    _driverNoteController = TextEditingController();
    _syncSharedDropoffs();
    _applyInitialServiceType();
    _applyOfficialFares();
    _loadFareSettings();
    _loadOnlineDrivers();
  }

  @override
  void dispose() {
    _sharedPassengerController.dispose();
    _otherFeeController.dispose();
    _pickupItemController.dispose();
    _pickupWeightController.dispose();
    _driverNoteController.dispose();
    super.dispose();
  }

  void _applyInitialServiceType() {
    final requested = widget.initialServiceType?.toLowerCase();
    if (requested == null || requested.isEmpty) return;

    final index = _services.indexWhere((service) {
      final id = service['id']?.toString().toLowerCase();
      final name = service['name']?.toString().toLowerCase() ?? '';
      return id == requested || name.contains(requested);
    });

    if (index != -1) _selected = index;
  }

  Future<void> _loadFareSettings() async {
    final settings = await FareSettingsService.fetchSettings();
    if (!mounted) return;
    setState(() {
      _fareSettings = settings;
      _fareSettingsLoaded = true;
      _applyOfficialFares();
    });
  }

  void _applyOfficialFares() {
    final distanceKm = widget.distanceKm ?? 0;
    final eta = widget.etaMinutes ??
        PanaboFarePolicy.etaMinutesForDistanceKm(distanceKm);
    final individualFare = _fareSettings.fareForDistanceKm(
      distanceKm,
      discounted: _discountedPassenger,
    );
    final premiumFare = _fareSettings.fareForDistanceKm(
      distanceKm,
      discounted: _discountedPassenger,
      premiumMultiplier: _fareSettings.premiumMultiplier,
    );
    final sharedFare = _fareSettings.fareForDistanceKm(
      distanceKm,
      discounted: _discountedPassenger,
      passengerCount: _sharedPassengerCount,
    );

    for (final service in _services) {
      final id = service['id'] as String;
      service['eta'] = '$eta min';
      if (id == 'shared') {
        final total = sharedFare + _otherFeeAmount;
        service['price'] = total;
        service['priceLabel'] = PanaboFarePolicy.formatPeso(total);
        service['priceSubLabel'] =
            '${PanaboFarePolicy.formatPeso(individualFare)} each';
        service['passengers'] = '$_sharedPassengerCount passengers';
      } else if (id == 'express') {
        final total = premiumFare + _otherFeeAmount;
        service['price'] = total;
        service['priceLabel'] = PanaboFarePolicy.formatPeso(total);
        service['priceSubLabel'] =
            '${(_fareSettings.premiumMultiplier * 100 - 100).toStringAsFixed(0)}% premium';
        service['passengers'] = '1 passenger';
      } else if (id == 'pickup') {
        final total = individualFare + _otherFeeAmount;
        service['price'] = total;
        service['priceLabel'] = PanaboFarePolicy.formatPeso(total);
        service['priceSubLabel'] = _otherFeeAmount > 0
            ? 'Includes ${PanaboFarePolicy.formatPeso(_otherFeeAmount)} item fee'
            : 'Regular pickup rate';
        service['passengers'] = 'Item pick-up';
      } else {
        final total = individualFare + _otherFeeAmount;
        service['price'] = total;
        service['priceLabel'] = PanaboFarePolicy.formatPeso(total);
        service['priceSubLabel'] = '$_passengerFareLabel rate';
        service['passengers'] = '1 passenger';
      }
    }
  }

  Future<void> _loadOnlineDrivers() async {
    final drivers = await TripService.fetchOnlineDrivers(
      pickupLatLng: widget.pickupLatLng,
    );
    if (mounted) {
      setState(() {
        _onlineDrivers = drivers;
        _driversLoaded = true;
      });
    }
  }

  void _openLiveMap() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => LiveMapScreen(
        initialLocation: widget.pickupLatLng ?? widget.destinationLatLng,
      ),
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  Future<void> _confirmRide() async {
    if (_onlineDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No drivers available right now. Please try again.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    if (_isScheduled) {
      final scheduledAt = _scheduledAt;
      if (scheduledAt == null) {
        _showSnack(
            'Select a pickup time for your reservation.', AppColors.error);
        return;
      }
      if (scheduledAt
          .isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
        _showSnack('Choose a pickup time at least 5 minutes from now.',
            AppColors.error);
        return;
      }
    }

    if (_selectedServiceId == 'pickup' &&
        _pickupItemController.text.trim().isEmpty) {
      _showSnack('Tell the driver what to pick up.', AppColors.error);
      return;
    }

    final sharedDropoffs = _buildSharedDropoffPayload();
    if (_selectedServiceId == 'shared' && sharedDropoffs == null) {
      _showSnack(
          'Pin every shared passenger drop-off location.', AppColors.error);
      return;
    }

    setState(() => _isLoading = true);

    final selectedService = _services[_selected];
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => FindingDriverScreen(
        serviceType: selectedService['name'] as String,
        price: selectedService['priceLabel'] as String,
        fareAmount: selectedService['price'] as double,
        passengerCount:
            selectedService['id'] == 'shared' ? _sharedPassengerCount : 1,
        passengerFareType: _passengerFareType,
        otherFeeAmount: _otherFeeAmount,
        otherFeeLabel: _otherFeeLabel,
        pickupItemDescription: _pickupItemController.text.trim(),
        pickupItemWeight: _pickupWeightController.text.trim(),
        bookingNotes: _driverNoteController.text.trim(),
        sharedDropoffs: sharedDropoffs,
        onlineDrivers: _onlineDrivers,
        pickupName: widget.pickupName,
        destinationName: widget.destinationName,
        pickupLatLng: widget.pickupLatLng,
        destinationLatLng: widget.destinationLatLng,
        scheduledAt: _isScheduled ? _scheduledAt : null,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));

    setState(() => _isLoading = false);
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (selectedTime == null) return;

    final value = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (value.isBefore(now.add(const Duration(minutes: 5)))) {
      _showSnack(
          'Choose a pickup time at least 5 minutes from now.', AppColors.error);
      return;
    }
    setState(() => _scheduledAt = value);
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _setPassengerFareType(String value) {
    setState(() {
      _passengerFareType = value;
      _applyOfficialFares();
    });
  }

  void _setSharedPassengerCount(int value) {
    final next = value.clamp(2, 6).toInt();
    if (_sharedPassengerCount == next &&
        _sharedPassengerController.text == next.toString()) {
      return;
    }
    setState(() {
      _sharedPassengerCount = next;
      _sharedPassengerController.text = next.toString();
      _sharedPassengerController.selection = TextSelection.collapsed(
        offset: _sharedPassengerController.text.length,
      );
      _syncSharedDropoffs();
      _applyOfficialFares();
    });
  }

  void _handleSharedPassengerInput(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    if (parsed < 2 || parsed > 6) {
      _setSharedPassengerCount(parsed);
      return;
    }
    setState(() {
      _sharedPassengerCount = parsed;
      _syncSharedDropoffs();
      _applyOfficialFares();
    });
  }

  void _syncSharedDropoffs() {
    final names = List<String>.from(_dropoffNames);
    final points = List<LatLng?>.from(_dropoffPoints);
    while (names.length < _sharedPassengerCount) {
      names.add('');
      points.add(null);
    }
    if (names.length > _sharedPassengerCount) {
      names.removeRange(_sharedPassengerCount, names.length);
      points.removeRange(_sharedPassengerCount, points.length);
    }
    if (names.isNotEmpty) {
      names[0] = widget.destinationName;
      points[0] = widget.destinationLatLng;
    }
    _dropoffNames = names;
    _dropoffPoints = points;
  }

  void _setOtherFee(String? label, double amount) {
    setState(() {
      _otherFeeLabel = label;
      _otherFeeAmount = amount < 0 ? 0 : amount;
      _otherFeeController.text =
          _otherFeeAmount == 0 ? '' : _otherFeeAmount.toStringAsFixed(0);
      _applyOfficialFares();
    });
  }

  void _setCustomOtherFee(String value) {
    final amount = double.tryParse(value.trim()) ?? 0;
    setState(() {
      _otherFeeAmount = amount < 0 ? 0 : amount;
      _otherFeeLabel = amount > 0 ? 'Custom fee' : null;
      _applyOfficialFares();
    });
  }

  List<Map<String, dynamic>>? _buildSharedDropoffPayload() {
    if (_selectedServiceId != 'shared') return null;
    _syncSharedDropoffs();
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < _sharedPassengerCount; i++) {
      final point = _dropoffPoints[i];
      final name = _dropoffNames[i].trim();
      if (point == null || name.isEmpty) return null;
      items.add({
        'label': i == 0 ? 'Passenger 1 (booker)' : 'Passenger ${i + 1}',
        'location': name,
        'lat': point.latitude,
        'lng': point.longitude,
      });
    }
    return items;
  }

  Future<void> _pickSharedDropoff(int index) async {
    final selected = await showModalBottomSheet<_DropoffSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DropoffPickerSheet(
        title: 'Passenger ${index + 1} Drop-off',
        locationBias: widget.destinationLatLng ?? widget.pickupLatLng,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _syncSharedDropoffs();
      _dropoffNames[index] = selected.name;
      _dropoffPoints[index] = selected.point;
    });
  }

  String _formatSchedule(DateTime? value) {
    if (value == null) return 'Select pickup time';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day}/${value.year}  $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _fareControls().animate().fadeIn(duration: 350.ms),
                const SizedBox(height: 14),
                ...List.generate(_services.length, (i) {
                  return _serviceCard(i).animate().fadeIn(
                        delay: Duration(milliseconds: 100 + i * 80),
                        duration: 400.ms,
                      );
                }),
              ],
            ),
          ),
          _bottomConfirmSection(),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.backgroundDark, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Select Service',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  )),
              Text('Choose your ride type',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textHint,
                  )),
            ]),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'View Live Map',
            child: Semantics(
              label: 'View Live Map',
              button: true,
              child: GestureDetector(
                onTap: _openLiveMap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8EDF2)),
                  ),
                  child: const Icon(Icons.map_rounded,
                      color: AppColors.backgroundDark, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _onlineDrivers.isNotEmpty
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _onlineDrivers.isNotEmpty
                    ? Colors.green.withValues(alpha: 0.4)
                    : Colors.orange.withValues(alpha: 0.4),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color:
                      _onlineDrivers.isNotEmpty ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _driversLoaded
                    ? '${_onlineDrivers.length} online'
                    : 'Loading...',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      _onlineDrivers.isNotEmpty ? Colors.green : Colors.orange,
                ),
              ),
            ]),
          ),
        ]),
      ).animate().fadeIn(duration: 400.ms);

  Widget _fareControls() {
    final fuel = _fareSettings.fuelPricePerLiter.toStringAsFixed(2);
    final regular = PanaboFarePolicy.formatPeso(
      _fareSettings.fareForDistanceKm(
        0,
      ),
    );
    final discounted = PanaboFarePolicy.formatPeso(
      _fareSettings.fareForDistanceKm(
        0,
        discounted: true,
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Fare Type',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
          ),
          Text(
            _fareSettingsLoaded ? 'Fuel PHP $fuel/L' : 'Loading fare rate',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _fareTypeChip('regular', 'Regular'),
            _fareTypeChip('student', 'Student'),
            _fareTypeChip('senior', 'Senior'),
            _fareTypeChip('pwd', 'PWD'),
          ],
        ),
        const SizedBox(height: 10),
        Row(children: [
          _smallRateBadge('Regular', regular),
          const SizedBox(width: 8),
          _smallRateBadge('Discount', discounted),
        ]),
        const SizedBox(height: 12),
        _otherFeeControls(),
        if (_selectedServiceId == 'pickup') ...[
          const SizedBox(height: 12),
          _pickupItemControls(),
        ],
        if (_selectedServiceId == 'shared') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text('Shared Passengers',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  )),
            ),
            SizedBox(
              width: 116,
              height: 42,
              child: TextField(
                controller: _sharedPassengerController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _handleSharedPassengerInput,
                decoration: InputDecoration(
                  suffixText: 'pax',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _sharedDropoffControls(),
        ],
      ]),
    );
  }

  Widget _otherFeeControls() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Other Fee',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.backgroundDark,
          )),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _feeChip('None', null, 0),
        _feeChip('Baggage', 'Baggage', 10),
        _feeChip('Heavy item', 'Heavy item', 20),
        SizedBox(
          width: 128,
          height: 38,
          child: TextField(
            controller: _otherFeeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: _setCustomOtherFee,
            decoration: InputDecoration(
              hintText: 'Custom',
              suffixText: 'PHP',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _feeChip(String label, String? feeLabel, double amount) {
    final selected = (_otherFeeLabel == feeLabel) &&
        ((_otherFeeAmount - amount).abs() < 0.01);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _setOtherFee(feeLabel, amount),
      showCheckmark: false,
      selectedColor: AppColors.backgroundDark,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppColors.backgroundDark : const Color(0xFFE8EDF2),
      ),
      labelStyle: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : AppColors.backgroundDark,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _pickupItemControls() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Pick-up Details',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.backgroundDark,
          )),
      const SizedBox(height: 8),
      TextField(
        controller: _pickupItemController,
        decoration: _fieldDecoration('What should the driver pick up?'),
        style: GoogleFonts.poppins(fontSize: 13),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _pickupWeightController,
        decoration: _fieldDecoration('Heavy item / size note'),
        style: GoogleFonts.poppins(fontSize: 13),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _driverNoteController,
        minLines: 2,
        maxLines: 3,
        decoration: _fieldDecoration('Guide note for the driver'),
        style: GoogleFonts.poppins(fontSize: 13),
      ),
    ]);
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      );

  Widget _sharedDropoffControls() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.alt_route_rounded, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Shared Drop-off Order',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark,
              )),
        ),
      ]),
      const SizedBox(height: 4),
      Text(
        'Passenger 1 uses your main destination. Pin each additional passenger stop before booking.',
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: AppColors.textHint,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 10),
      ...List.generate(_sharedPassengerCount, (index) {
        final pinned = index < _dropoffNames.length &&
            _dropoffNames[index].trim().isNotEmpty &&
            index < _dropoffPoints.length &&
            _dropoffPoints[index] != null;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8EDF2)),
          ),
          child: Row(children: [
            Icon(
              pinned
                  ? Icons.location_on_rounded
                  : Icons.add_location_alt_rounded,
              size: 18,
              color: pinned ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      index == 0
                          ? 'Passenger 1 (booker)'
                          : 'Passenger ${index + 1}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                    Text(
                      pinned ? _dropoffNames[index] : 'Pin drop-off',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.backgroundDark,
                      ),
                    ),
                  ]),
            ),
            TextButton(
              onPressed: index == 0 ? null : () => _pickSharedDropoff(index),
              child: Text(
                index == 0 ? 'Main' : (pinned ? 'Change' : 'Pin'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        );
      }),
    ]);
  }

  Widget _fareTypeChip(String value, String label) {
    final selected = _passengerFareType == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _setPassengerFareType(value),
      showCheckmark: false,
      selectedColor: AppColors.backgroundDark,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppColors.backgroundDark : const Color(0xFFE8EDF2),
      ),
      labelStyle: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : AppColors.backgroundDark,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _smallRateBadge(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8EDF2)),
          ),
          child: Row(children: [
            Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.textHint,
                )),
            const Spacer(),
            Text(value,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
          ]),
        ),
      );

  Widget _serviceCard(int index) {
    final service = _services[index];
    final isSelected = _selected == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selected = index;
        _applyOfficialFares();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : const Color(0xFFE8EDF2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(service['icon'] as IconData,
                color: AppColors.backgroundDark, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(service['name'] as String,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppColors.backgroundDark,
                      )),
                ),
                if (service['premium'] == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('PREMIUM',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.backgroundDark,
                        )),
                  ),
                ],
              ]),
              Text(service['subtitle'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isSelected ? Colors.white54 : AppColors.textHint,
                  )),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _badge(Icons.person_outline_rounded,
                    service['passengers'] as String, isSelected),
                _badge(Icons.schedule_rounded, 'Arrives ${service['eta']}',
                    isSelected,
                    green: true),
              ]),
            ],
          )),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(service['priceLabel'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color:
                      isSelected ? AppColors.primary : AppColors.backgroundDark,
                )),
            Text(service['priceSubLabel'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: isSelected ? Colors.white54 : AppColors.textHint,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 2),
            if (!_driversLoaded)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            else
              Text('${_onlineDrivers.length} available',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: _onlineDrivers.isNotEmpty
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w600,
                  )),
          ]),
        ]),
      ),
    );
  }

  Widget _bottomConfirmSection() => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Column(children: [
          if (_driversLoaded && _onlineDrivers.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_rounded,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  'No drivers online right now. Try again in a few minutes.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.orange[800]),
                )),
                GestureDetector(
                  onTap: _loadOnlineDrivers,
                  child: Text('Retry',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange,
                      )),
                ),
              ]),
            ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              _scheduleModeButton('Ride Now', Icons.bolt_rounded, false),
              _scheduleModeButton(
                  'Schedule', Icons.event_available_rounded, true),
            ]),
          ),
          if (_isScheduled) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickSchedule,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Row(children: [
                  const Icon(Icons.notifications_active_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formatSchedule(_scheduledAt),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.backgroundDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text('Change',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      )),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                'To: ${widget.destinationName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.w500,
                ),
              )),
              Text('Change',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  )),
            ]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundDark,
                disabledBackgroundColor:
                    AppColors.backgroundDark.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text(_isScheduled ? 'Reserve Ride' : 'Find a Driver',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
        ]),
      );

  Widget _badge(IconData icon, String label, bool dark, {bool green = false}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 12,
            color: green
                ? Colors.green
                : dark
                    ? Colors.white54
                    : AppColors.textHint),
        const SizedBox(width: 3),
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: green
                  ? Colors.green
                  : dark
                      ? Colors.white54
                      : AppColors.textHint,
              fontWeight: FontWeight.w500,
            )),
      ]);

  Widget _scheduleModeButton(String label, IconData icon, bool scheduled) {
    final selected = _isScheduled == scheduled;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isScheduled = scheduled;
            if (scheduled && _scheduledAt == null) {
              _scheduledAt = DateTime.now().add(const Duration(hours: 1));
            }
          });
          if (scheduled) _pickSchedule();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 16,
                color:
                    selected ? AppColors.backgroundDark : AppColors.textHint),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected ? AppColors.backgroundDark : AppColors.textHint,
                )),
          ]),
        ),
      ),
    );
  }
}

class _DropoffSelection {
  final String name;
  final LatLng point;

  const _DropoffSelection({
    required this.name,
    required this.point,
  });
}

class _DropoffPickerSheet extends StatefulWidget {
  final String title;
  final LatLng? locationBias;

  const _DropoffPickerSheet({
    required this.title,
    this.locationBias,
  });

  @override
  State<_DropoffPickerSheet> createState() => _DropoffPickerSheetState();
}

class _DropoffPickerSheetState extends State<_DropoffPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 2 || _isSearching) return;
    setState(() => _isSearching = true);
    final suggestions = await MapService.searchPlaces(
      query,
      locationBias: widget.locationBias ?? PanaboConfig.cityCenter,
    );
    if (!mounted) return;
    setState(() {
      _suggestions = suggestions;
      _isSearching = false;
    });
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    setState(() => _isSearching = true);
    final point = await MapService.getPlaceLatLng(suggestion.placeId);
    if (!mounted) return;
    setState(() => _isSearching = false);
    if (point == null) return;
    final fullText = suggestion.fullText.trim();
    final fallbackText = [
      suggestion.mainText.trim(),
      suggestion.secondaryText.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    Navigator.of(context).pop(
      _DropoffSelection(
        name: fullText.isNotEmpty ? fullText : fallbackText,
        point: point,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: Text(widget.title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.backgroundDark,
                        )),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Search drop-off location',
                        filled: true,
                        fillColor: const Color(0xFFF5F6FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.backgroundDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: media.size.height * 0.38,
                  ),
                  child: _suggestions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text('Search and choose a pinned location.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textHint,
                              )),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              onTap: () => _select(suggestion),
                              leading: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                suggestion.mainText,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: suggestion.secondaryText.isEmpty
                                  ? null
                                  : Text(
                                      suggestion.secondaryText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(fontSize: 11),
                                    ),
                            );
                          },
                        ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
