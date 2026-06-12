import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class RideRequestScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  const RideRequestScreen({
    super.key,
    required this.trip,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  int _countdown = 15;
  Timer? _timer;
  double _progress = 1.0;
  bool _isHandling = false; // prevent double-tap

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdown--;
        _progress = _countdown / 15;
      });
      if (_countdown <= 0) {
        t.cancel();
        _handleDecline();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleDecline() async {
    if (_isHandling) return;
    _isHandling = true;
    _timer?.cancel();
    await widget.onDecline(); // calls API only — no navigation here
    if (mounted) Navigator.of(context).pop(false); // return false = declined
  }

  Future<void> _handleAccept() async {
    if (_isHandling) return;
    _isHandling = true;
    _timer?.cancel();
    await widget.onAccept(); // calls API only — no navigation here
    if (mounted) Navigator.of(context).pop(true); // return true = accepted
  }

  double _doubleValue(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  String? _cleanText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  List<Map<String, dynamic>> _sharedDropoffs(dynamic raw) {
    dynamic value = raw;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const [];
      }
    }
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, val) => MapEntry(key.toString(), val)))
        .toList();
  }

  String _dropoffText(Map<String, dynamic> dropoff, int index) {
    final passenger =
        _cleanText(dropoff['passenger_name']) ?? _cleanText(dropoff['label']);
    final location = _cleanText(dropoff['location']);
    if (passenger != null && location != null) {
      return '${index + 1}. $passenger - $location';
    }
    if (location != null) return '${index + 1}. $location';
    return 'Drop-off ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final commuterName =
        widget.trip['commuter_name']?.toString() ?? 'Passenger';
    final pickup = widget.trip['pickup_location']?.toString() ?? 'Pickup';
    final destination = widget.trip['destination']?.toString() ?? 'Destination';
    final dynamic rawFare = widget.trip['fare'];
    final fare = rawFare == null
        ? 25.0
        : rawFare is double
            ? rawFare
            : rawFare is int
                ? rawFare.toDouble()
                : double.tryParse(rawFare.toString()) ?? 25.0;
    final serviceType = widget.trip['service_type']?.toString() ?? 'solo';
    final paymentMethod = widget.trip['payment_method']?.toString() ?? 'cash';
    final isPickupService = serviceType.toLowerCase() == 'pickup';
    final otherFee = _doubleValue(widget.trip['other_fee_amount']);
    final otherFeeLabel =
        _cleanText(widget.trip['other_fee_label']) ?? 'Other Fee';
    final pickupItem = _cleanText(widget.trip['pickup_item_description']);
    final pickupWeight = _cleanText(widget.trip['pickup_item_weight']);
    final bookingNotes = _cleanText(widget.trip['booking_notes']);
    final sharedDropoffs = _sharedDropoffs(widget.trip['shared_dropoffs']);

    final driverEarnings = fare;

    final initials = commuterName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return PopScope(
      canPop: false, // prevent back-swipe from auto-declining silently
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2B3C),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // ── Yellow header ──────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.navigation_rounded,
                            color: AppColors.primary, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                          isPickupService
                              ? 'New Pick-up Request!'
                              : 'New Ride Request!',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.backgroundDark,
                          )),
                      const SizedBox(height: 10),
                      // Countdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                value: _progress,
                                strokeWidth: 2,
                                backgroundColor: Colors.black26,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.backgroundDark),
                              )),
                          const SizedBox(width: 8),
                          Text('Auto-decline in ${_countdown}s',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.backgroundDark,
                              )),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(children: [
                          Text('RIDE TYPE',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white38,
                                letterSpacing: 1.5,
                              )),
                          Text(serviceType.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              )),
                        ]),
                      ),
                    ]),
                  ),

                  // ── Passenger info ──────────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        Row(children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF243548),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                                child: Text(initials,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(commuterName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    )),
                                Text('Passenger',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                    )),
                              ])),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _pill('Verified', Colors.green),
                                const SizedBox(height: 4),
                                _pill(paymentMethod.toUpperCase(),
                                    AppColors.primary),
                              ]),
                        ]),

                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFF243548)),
                        const SizedBox(height: 14),

                        // Route
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle)),
                                Container(
                                    width: 1.5,
                                    height: 36,
                                    color: const Color(0xFF2E4158)),
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(3),
                                    )),
                              ]),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('PICKUP',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 9,
                                                  color: AppColors.textHint,
                                                  letterSpacing: 1)),
                                          Text(pickup,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              )),
                                        ]),
                                    const SizedBox(height: 20),
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('DESTINATION',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 9,
                                                  color: AppColors.textHint,
                                                  letterSpacing: 1)),
                                          Text(destination,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              )),
                                        ]),
                                  ])),
                            ]),

                        const SizedBox(height: 16),

                        if (isPickupService ||
                            pickupItem != null ||
                            pickupWeight != null ||
                            bookingNotes != null) ...[
                          _detailCard(
                            icon: Icons.inventory_2_rounded,
                            title: 'PICK-UP DETAILS',
                            children: [
                              if (pickupItem != null)
                                _detailLine('Item', pickupItem),
                              if (pickupWeight != null)
                                _detailLine('Size / Weight', pickupWeight),
                              if (bookingNotes != null)
                                _detailLine('Driver Note', bookingNotes),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (sharedDropoffs.isNotEmpty) ...[
                          _detailCard(
                            icon: Icons.alt_route_rounded,
                            title: 'SHARED DROP-OFF ORDER',
                            children: [
                              for (var i = 0; i < sharedDropoffs.length; i++)
                                _detailLine(
                                  i == 0 ? 'Stops' : '',
                                  _dropoffText(sharedDropoffs[i], i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Fare breakdown
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2B3C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2E4158)),
                          ),
                          child: Column(children: [
                            Row(children: [
                              const Icon(Icons.receipt_long_rounded,
                                  color: AppColors.primary, size: 14),
                              const SizedBox(width: 6),
                              Text('FARE BREAKDOWN',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textHint,
                                    letterSpacing: 1,
                                  )),
                            ]),
                            const SizedBox(height: 10),
                            _fareRow('Passenger Fare',
                                '₱${fare.toStringAsFixed(2)}', Colors.white),
                            if (otherFee > 0) ...[
                              const SizedBox(height: 6),
                              _fareRow(
                                otherFeeLabel,
                                'PHP ${otherFee.toStringAsFixed(2)}',
                                AppColors.primary,
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child:
                                  Divider(color: Color(0xFF2E4158), height: 1),
                            ),
                            _fareRow(
                                'Your Earnings',
                                '₱${driverEarnings.toStringAsFixed(2)}',
                                AppColors.success,
                                bold: true,
                                large: true),
                          ]),
                        ),

                        const SizedBox(height: 20),

                        // DECLINE + ACCEPT
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _isHandling ? null : _handleDecline,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF243548),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.close_rounded,
                                          color: Colors.white54, size: 18),
                                      const SizedBox(width: 8),
                                      Text('DECLINE',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white54,
                                          )),
                                    ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: _isHandling ? null : _handleAccept,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: _isHandling
                                      ? AppColors.primary.withOpacity(0.7)
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: _isHandling
                                    ? const Center(
                                        child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color:
                                                    AppColors.backgroundDark)))
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                            const Icon(Icons.check_rounded,
                                                color: AppColors.backgroundDark,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Text('ACCEPT',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      AppColors.backgroundDark,
                                                )),
                                          ]),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2B3C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2E4158)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 14),
            const SizedBox(width: 6),
            Text(title,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 1,
                )),
          ]),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _detailLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: label.isEmpty ? 0 : 76,
            child: label.isEmpty
                ? const SizedBox.shrink()
                : Text(label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textHint,
                    )),
          ),
          if (label.isNotEmpty) const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ]),
      );

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            )),
      );

  Widget _fareRow(String label, String value, Color valueColor,
          {bool bold = false, bool large = false}) =>
      Row(children: [
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.poppins(
              fontSize: large ? 16 : 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
            )),
      ]);
}
