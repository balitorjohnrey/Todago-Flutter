import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'reservation_notification_service.dart';
import 'trip_service.dart';
import 'live_trip_tracking_screen.dart';
import 'profile_avatar.dart';

class DriverSelectionScreen extends StatefulWidget {
  final String serviceType;
  final String price;
  final double fareAmount;
  final int passengerCount;
  final String passengerFareType;
  final double otherFeeAmount;
  final String? otherFeeLabel;
  final String? bookingNotes;
  final String? pickupItemDescription;
  final String? pickupItemWeight;
  final List<Map<String, dynamic>>? sharedDropoffs;
  final List<Map<String, dynamic>> onlineDrivers;
  final String pickupName;
  final String destinationName;
  final LatLng? pickupLatLng;
  final LatLng? destinationLatLng;
  final DateTime? scheduledAt;

  const DriverSelectionScreen({
    super.key,
    required this.serviceType,
    required this.price,
    required this.fareAmount,
    this.passengerCount = 1,
    this.passengerFareType = 'regular',
    this.otherFeeAmount = 0,
    this.otherFeeLabel,
    this.bookingNotes,
    this.pickupItemDescription,
    this.pickupItemWeight,
    this.sharedDropoffs,
    required this.onlineDrivers,
    this.pickupName = 'Your Location',
    this.destinationName = 'Davao del Norte State College',
    this.pickupLatLng,
    this.destinationLatLng,
    this.scheduledAt,
  });

  @override
  State<DriverSelectionScreen> createState() => _DriverSelectionScreenState();
}

class _DriverSelectionScreenState extends State<DriverSelectionScreen> {
  int _selected = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedPaymentMethod = 'cash';

  static const List<Map<String, dynamic>> _paymentOptions = [
    {
      'value': 'cash',
      'label': 'Cash',
      'subtitle': 'Pay the driver at drop-off',
      'icon': Icons.payments_rounded,
    },
    {
      'value': 'gcash',
      'label': 'GCash',
      'subtitle': 'Pay through PayMongo checkout',
      'icon': Icons.account_balance_wallet_rounded,
    },
    {
      'value': 'maya',
      'label': 'Maya',
      'subtitle': 'Pay through PayMongo checkout',
      'icon': Icons.phone_iphone_rounded,
    },
    {
      'value': 'wallet',
      'label': 'TodaGo Payment',
      'subtitle': 'Keep payment inside TodaGo',
      'icon': Icons.verified_rounded,
    },
  ];

  // Safe numeric parser — all API values may come as Strings
  static double _safeDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double? _tryDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _tryInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  Map<String, dynamic> get _selectedDriver => widget.onlineDrivers[_selected];
  bool get _isScheduled => widget.scheduledAt != null;
  String get _paymentLabel => _paymentOptions.firstWhere(
        (option) => option['value'] == _selectedPaymentMethod,
        orElse: () => _paymentOptions.first,
      )['label'] as String;

  List<Map<String, dynamic>> get _sharedDropoffs =>
      widget.sharedDropoffs ?? const [];

  String _etaText(Map<String, dynamic> driver) {
    final eta = _tryInt(driver['eta_minutes']);
    return eta == null ? 'Locating driver' : '$eta min away';
  }

  String _normalizeServiceType(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[-\s]'), '');
    if (s.contains('pickup') || s.contains('delivery')) return 'pickup';
    if (s.contains('express')) return 'express';
    if (s.contains('shared')) return 'shared';
    return 'solo';
  }

  Future<void> _confirmDriver() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = _isScheduled
        ? await TripService.scheduleRide(
            driverId: _selectedDriver['driver_id'] as String,
            pickupLocation: widget.pickupName,
            destination: widget.destinationName,
            serviceType: _normalizeServiceType(widget.serviceType),
            fare: widget.fareAmount,
            passengerCount: widget.passengerCount,
            passengerFareType: widget.passengerFareType,
            otherFeeAmount: widget.otherFeeAmount,
            otherFeeLabel: widget.otherFeeLabel,
            bookingNotes: widget.bookingNotes,
            pickupItemDescription: widget.pickupItemDescription,
            pickupItemWeight: widget.pickupItemWeight,
            sharedDropoffs: widget.sharedDropoffs,
            paymentMethod: _selectedPaymentMethod,
            scheduledAt: widget.scheduledAt!,
            pickupLatLng: widget.pickupLatLng,
            destinationLatLng: widget.destinationLatLng,
          )
        : await TripService.requestRide(
            driverId: _selectedDriver['driver_id'] as String,
            pickupLocation: widget.pickupName,
            destination: widget.destinationName,
            serviceType: _normalizeServiceType(widget.serviceType),
            fare: widget.fareAmount,
            passengerCount: widget.passengerCount,
            passengerFareType: widget.passengerFareType,
            otherFeeAmount: widget.otherFeeAmount,
            otherFeeLabel: widget.otherFeeLabel,
            bookingNotes: widget.bookingNotes,
            pickupItemDescription: widget.pickupItemDescription,
            pickupItemWeight: widget.pickupItemWeight,
            sharedDropoffs: widget.sharedDropoffs,
            paymentMethod: _selectedPaymentMethod,
            pickupLatLng: widget.pickupLatLng,
            destinationLatLng: widget.destinationLatLng,
          );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final trip = result['trip'] as Map<String, dynamic>? ?? {};
      if (_isScheduled) {
        await ReservationNotificationService.scheduleReservationReminders(
          trip,
          forDriver: false,
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('Reservation Scheduled',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
            content: Text(
              'Your TodaGo reservation is saved in Bookings. We will remind you 1 hour, 30 minutes, and 5 minutes before pickup.',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      // Navigate to waiting screen — shows live tracking once driver accepts
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => LiveTripTrackingScreen(
          tripId: trip['trip_id']?.toString() ?? '',
          driverName: _selectedDriver['driver_name']?.toString() ?? 'Driver',
          driverPhone: _selectedDriver['phone']?.toString(),
          driverRating: _safeDouble(_selectedDriver['avg_rating'], 0.0),
          todaBodyNumber: _selectedDriver['toda_body_number']?.toString() ?? '',
          plateNo: _selectedDriver['plate_no']?.toString() ?? '',
          etaMinutes: _tryInt(_selectedDriver['eta_minutes']),
          distanceKm: _tryDouble(_selectedDriver['distance_km']),
          destination: widget.destinationName,
          fare: widget.fareAmount,
          destinationLatLng: widget.destinationLatLng,
        ),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ));
    } else {
      setState(() => _errorMessage =
          result['message']?.toString() ?? 'Failed to request ride');
    }
  }

  Future<void> _choosePaymentMethod() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Payment Method',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ..._paymentOptions.map((option) {
                final value = option['value'] as String;
                final selected = value == _selectedPaymentMethod;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(value),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withOpacity(0.14)
                            : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : const Color(0xFFEEEEEE),
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          option['icon'] as IconData,
                          color: selected
                              ? AppColors.backgroundDark
                              : AppColors.textHint,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option['label'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.backgroundDark,
                                ),
                              ),
                              Text(
                                option['subtitle'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary),
                      ]),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (choice != null && mounted) {
      setState(() => _selectedPaymentMethod = choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textHint),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.backgroundDark, size: 36),
                ).animate().scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1),
                    duration: 500.ms,
                    curve: Curves.elasticOut),
                const SizedBox(height: 12),
                Text(
                    '${widget.onlineDrivers.length} Driver${widget.onlineDrivers.length != 1 ? "s" : ""} Found!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.backgroundDark,
                    )).animate().fadeIn(delay: 100.ms),
                Text(
                    _isScheduled
                        ? 'Select a driver for your reservation'
                        : 'Select your preferred driver to continue',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textHint,
                    )).animate().fadeIn(delay: 150.ms),

                // Error banner
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_errorMessage!,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: AppColors.error))),
                    ]),
                  ),
                ],
              ]),
            ),

            // Driver cards
            SizedBox(
              height: 170,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                itemCount: widget.onlineDrivers.length,
                itemBuilder: (_, i) {
                  final d = widget.onlineDrivers[i];
                  final sel = _selected == i;
                  final name = d['driver_name']?.toString() ?? 'Driver';
                  final initials = name
                      .trim()
                      .split(' ')
                      .take(2)
                      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
                      .join();
                  final rating = _safeDouble(d['avg_rating'], 0.0);
                  final trips = _safeInt(d['total_trips'], 0);
                  final eta = _tryInt(d['eta_minutes']);
                  final dist = _tryDouble(d['distance_km']);
                  final assoc = d['association_code']?.toString() ??
                      d['toda_body_number']?.toString() ??
                      '';
                  final photoSource = d['profile_photo_url']?.toString();

                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 260,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: sel ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(sel ? 0.08 : 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              ProfileAvatar(
                                initials: initials,
                                imagePath: photoSource,
                                size: 44,
                                backgroundColor: AppColors.backgroundDark,
                                foregroundColor: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.backgroundDark,
                                      )),
                                  Text(assoc,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: AppColors.textHint,
                                      )),
                                ],
                              )),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              ...List.generate(5, (si) {
                                if (si < rating.floor()) {
                                  return const Icon(Icons.star_rounded,
                                      size: 13, color: AppColors.primary);
                                } else if (si < rating) {
                                  return const Icon(Icons.star_half_rounded,
                                      size: 13, color: AppColors.primary);
                                }
                                return const Icon(Icons.star_outline_rounded,
                                    size: 13, color: AppColors.primary);
                              }),
                              const SizedBox(width: 4),
                              Text(
                                  '${rating.toStringAsFixed(1)} ($trips trips)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 10, color: AppColors.textHint)),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Text(eta == null ? 'Locating' : '$eta min',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.backgroundDark,
                                  )),
                              Text('  ·  ',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: AppColors.textHint)),
                              Flexible(
                                  child: Text(
                                dist == null
                                    ? 'GPS pending'
                                    : '${dist.toStringAsFixed(1)} km',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.backgroundDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              )),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.circle,
                                          size: 6, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text('Online',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green,
                                          )),
                                    ]),
                              ),
                            ]),
                          ]),
                    ),
                  ).animate().fadeIn(
                      delay: Duration(milliseconds: 200 + i * 80),
                      duration: 400.ms);
                },
              ),
            ),

            // Summary
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(children: [
                _summaryRow('Driver',
                    _selectedDriver['driver_name']?.toString() ?? 'Driver'),
                const SizedBox(height: 6),
                _summaryRow('Service Type', widget.serviceType),
                const SizedBox(height: 6),
                _summaryRow('Passengers', widget.passengerCount.toString()),
                const SizedBox(height: 6),
                _summaryRow(
                    'Fare Type', _formatFareType(widget.passengerFareType)),
                if (_sharedDropoffs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _summaryRow(
                    'Shared Stops',
                    '${_sharedDropoffs.length} drop-off${_sharedDropoffs.length == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(_sharedDropoffs.length, (index) {
                    final stop = _sharedDropoffs[index];
                    final location =
                        stop['location']?.toString() ?? 'Drop-off ${index + 1}';
                    final label =
                        stop['label']?.toString() ?? 'Passenger ${index + 1}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _summaryRow(
                        index == 0 ? 'Stop Order' : '',
                        '${index + 1}. $label - $location',
                      ),
                    );
                  }),
                ],
                if (widget.otherFeeAmount > 0) ...[
                  const SizedBox(height: 6),
                  _summaryRow(
                    'Other Fee',
                    '${widget.otherFeeLabel ?? 'Extra'} PHP ${widget.otherFeeAmount.toStringAsFixed(0)}',
                  ),
                ],
                if ((widget.pickupItemDescription ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _summaryRow('Pickup Item', widget.pickupItemDescription!),
                ],
                if ((widget.bookingNotes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _summaryRow('Driver Note', widget.bookingNotes!),
                ],
                if (_isScheduled) ...[
                  const SizedBox(height: 6),
                  _summaryRow(
                      'Pickup Time', _formatSchedule(widget.scheduledAt)),
                ],
                const SizedBox(height: 6),
                _summaryRow('Payment Method', _paymentLabel),
                const SizedBox(height: 6),
                _summaryRow('ETA', _etaText(_selectedDriver)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFF0F0F0), height: 1),
                ),
                Row(children: [
                  Text('Estimated Fare',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.backgroundDark,
                      )),
                  const Spacer(),
                  Text(widget.price,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.backgroundDark,
                      )),
                ]),
              ]),
            ).animate().fadeIn(delay: 400.ms),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _choosePaymentMethod,
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: Text(
                    'Payment Method: $_paymentLabel',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.backgroundDark,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 425.ms),

            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundDark,
                    disabledBackgroundColor:
                        AppColors.backgroundDark.withOpacity(0.5),
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
                      : Text(
                          _isScheduled
                              ? 'Confirm Reservation'
                              : 'Confirm Driver & Start Ride',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                ),
              ),
            ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Text('Fare follows the Panabo tricycle rate table',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textHint)),
            ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Row(children: [
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.backgroundDark,
            ),
          ),
        ),
      ]);

  String _formatSchedule(DateTime? value) {
    if (value == null) return '-';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day}/${value.year} $hour:$minute $ampm';
  }

  String _formatFareType(String value) {
    switch (value.toLowerCase()) {
      case 'student':
        return 'Student';
      case 'senior':
        return 'Senior Citizen';
      case 'pwd':
        return 'PWD';
      default:
        return 'Regular';
    }
  }
}
