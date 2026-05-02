import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'service_selection_screen.dart';
import 'live_trip_tracking_screen.dart';
import 'splash_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  int _selectedTab = 0;
  Map<String, dynamic>? _user;
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(7.1907, 125.4553);

  // ── Bookings state ──────────────────────────────────────────────────────
  int _bookingTab = 0;

  final List<Map<String, dynamic>> _upcoming = [
    {
      'trip_id': '',
      'date': 'March 22, 2026',
      'time': '08:00 AM',
      'pickup': 'DNSC',
      'destination': 'Night Market',
      'driver': 'Juan Reyes',
      'type': 'Solo',
      'fare': '₱20',
      'status': 'Confirmed',
      'statusColor': Colors.green,
      // LiveTripTrackingScreen fields
      'driver_rating': 4.8,
      'toda_body_number': 'TODA-01',
      'plate_no': 'ABC 123',
      'eta_minutes': 5,
      'distance_km': 1.2,
    },
    {
      'trip_id': '',
      'date': 'March 23, 2026',
      'time': '08:00 AM',
      'pickup': 'DNSC',
      'destination': 'Panabo Bus Terminal',
      'driver': 'To be assigned',
      'type': 'Solo',
      'fare': '₱20',
      'status': 'Pending',
      'statusColor': AppColors.primary,
      'driver_rating': 0.0,
      'toda_body_number': 'TBA',
      'plate_no': '',
      'eta_minutes': 0,
      'distance_km': 0.0,
    },
  ];

  final List<Map<String, dynamic>> _past = [
    {
      'date': 'March 20, 2026',
      'time': '07:30 AM',
      'pickup': 'Home',
      'destination': 'DNSC',
      'driver': 'Pedro Lopez',
      'type': 'Solo',
      'fare': '₱25',
      'status': 'Completed',
      'statusColor': Colors.grey,
      'rating': 5,
    },
    {
      'date': 'March 18, 2026',
      'time': '05:00 PM',
      'pickup': 'Panabo Market',
      'destination': 'DNSC',
      'driver': 'Maria Santos',
      'type': 'Shared',
      'fare': '₱15',
      'status': 'Completed',
      'statusColor': Colors.grey,
      'rating': 4,
    },
    {
      'date': 'March 15, 2026',
      'time': '08:00 AM',
      'pickup': 'DNSC',
      'destination': 'Panabo Bus Terminal',
      'driver': 'Jose Cruz',
      'type': 'Solo',
      'fare': '₱20',
      'status': 'Cancelled',
      'statusColor': Colors.red,
      'rating': null,
    },
  ];

  // ── Wallet state ────────────────────────────────────────────────────────
  bool _balanceVisible = true;
  int _walletTab = 0;
  final double _balance = 245.50;

  final List<Map<String, dynamic>> _transactions = [
    {
      'type': 'trip',
      'title': 'Solo Ride — Night Market',
      'subtitle': 'Paid to Juan Reyes',
      'date': 'Mar 22, 2026',
      'time': '08:14 AM',
      'amount': -20.00,
      'icon': Icons.electric_rickshaw_rounded,
    },
    {
      'type': 'topup',
      'title': 'GCash Top-up',
      'subtitle': 'via GCash ••••4821',
      'date': 'Mar 21, 2026',
      'time': '10:30 AM',
      'amount': 100.00,
      'icon': Icons.add_circle_rounded,
    },
    {
      'type': 'trip',
      'title': 'Shared Ride — DNSC',
      'subtitle': 'Paid to Maria Santos',
      'date': 'Mar 18, 2026',
      'time': '05:12 PM',
      'amount': -15.00,
      'icon': Icons.electric_rickshaw_rounded,
    },
    {
      'type': 'cashback',
      'title': 'Ride Cashback',
      'subtitle': 'TodaGo Rewards',
      'date': 'Mar 10, 2026',
      'time': '09:01 AM',
      'amount': 5.00,
      'icon': Icons.card_giftcard_rounded,
    },
    {
      'type': 'topup',
      'title': 'Maya Top-up',
      'subtitle': 'via Maya Wallet',
      'date': 'Mar 10, 2026',
      'time': '09:00 AM',
      'amount': 200.00,
      'icon': Icons.add_circle_rounded,
    },
    {
      'type': 'trip',
      'title': 'Toda-Express — Airport',
      'subtitle': 'Paid to Pedro Lopez',
      'date': 'Mar 5, 2026',
      'time': '04:00 AM',
      'amount': -90.00,
      'icon': Icons.electric_rickshaw_rounded,
    },
  ];

  List<Map<String, dynamic>> get _filteredTx {
    if (_walletTab == 1) return _transactions.where((t) => t['type'] == 'topup').toList();
    if (_walletTab == 2) return _transactions.where((t) => t['type'] == 'trip').toList();
    return _transactions;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _loadUser();
    _initLocation();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _initLocation() async {
    final granted = await LocationService.requestPermission(context);
    if (!granted) return;
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_currentLocation, 16);
    }
  }

  String get _firstName {
    final name = _user?['full_name'] ?? 'Rider';
    return name.toString().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _buildHomeTab(),
          _buildBookingsTab(),
          _buildWalletTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HOME TAB
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.todago.app',
            ),
            MarkerLayer(markers: [
              Marker(
                point: _currentLocation,
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 3,
                      )
                    ],
                  ),
                  child: const Icon(Icons.person_pin_rounded,
                      color: AppColors.backgroundDark, size: 22),
                ),
              ),
            ]),
          ],
        ),

        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 12, offset: const Offset(0, 2),
                          )],
                        ),
                        child: Row(children: [
                          const Icon(Icons.bolt_rounded,
                              color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Text('TodaGo', style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: AppColors.backgroundDark,
                          )),
                        ]),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _initLocation,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                            )],
                          ),
                          child: const Icon(Icons.my_location_rounded,
                              color: AppColors.backgroundDark, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(children: [
                      const Icon(Icons.search_rounded,
                          color: AppColors.textHint, size: 22),
                      const SizedBox(width: 10),
                      Text('Where to?', style: GoogleFonts.poppins(
                        fontSize: 15, color: AppColors.textHint,
                      )),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom card
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(
                  color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
                const SizedBox(height: 16),
                Text('Quick Actions', style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
                Text('Choose how you want to ride', style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textHint,
                )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const ServiceSelectionScreen(),
                      transitionDuration: const Duration(milliseconds: 400),
                      transitionsBuilder: (_, anim, __, child) => SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, 1), end: Offset.zero)
                            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                        child: child,
                      ),
                    )),
                    icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                    label: Text('Book Now', style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                    )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.calendar_month_rounded,
                        color: AppColors.backgroundDark, size: 20),
                    label: Text('Schedule Reservation', style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: AppColors.backgroundDark,
                    )),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOOKINGS TAB
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBookingsTab() {
    final list = _bookingTab == 0 ? _upcoming : _past;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Bookings', style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark,
                )),
                Text('Track all your trips', style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textHint,
                )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    _bTabBtn('Upcoming (${_upcoming.length})', 0),
                    _bTabBtn('Past (${_past.length})', 1),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: list.isEmpty
                ? _emptyBookings()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _bookingCard(list[i])
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 80 * i), duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bTabBtn(String label, int idx) {
    final sel = _bookingTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _bookingTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: sel
                ? [BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8, offset: const Offset(0, 2),
                  )]
                : [],
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? AppColors.backgroundDark : AppColors.textHint,
              )),
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final isPast = _bookingTab == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 3),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Date + Status
          Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(b['date'] as String, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.backgroundDark,
            )),
            const Spacer(),
            _statusBadge(b['status'] as String, b['statusColor'] as Color),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time_rounded,
                size: 13, color: AppColors.textHint),
            const SizedBox(width: 5),
            Text(b['time'] as String, style: GoogleFonts.poppins(
              fontSize: 12, color: AppColors.textHint,
            )),
          ]),
          const SizedBox(height: 16),

          // Route
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(width: 10, height: 10,
                  decoration: const BoxDecoration(
                      color: AppColors.backgroundDark, shape: BoxShape.circle)),
              Container(width: 1.5, height: 40, color: const Color(0xFFDDDDDD)),
              Container(width: 10, height: 10,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)),
            ]),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pickup', style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint)),
                Text(b['pickup'] as String, style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.backgroundDark,
                )),
              ]),
              const SizedBox(height: 18),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Destination', style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint)),
                Text(b['destination'] as String, style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.backgroundDark,
                )),
              ]),
            ])),
          ]),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF0F0F0), height: 1),
          const SizedBox(height: 12),

          // Driver + Fare
          Row(children: [
            const Icon(Icons.person_outline_rounded,
                size: 16, color: AppColors.textHint),
            const SizedBox(width: 6),
            Text(b['driver'] as String, style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textHint,
            )),
            const Spacer(),
            Text('${b['type']}  ', style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textHint)),
            Text(b['fare'] as String, style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: AppColors.backgroundDark,
            )),
          ]),

          // Rating for past trips
          if (isPast && b['rating'] != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              ...List.generate(5, (i) => Icon(
                i < (b['rating'] as int)
                    ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 16, color: AppColors.primary,
              )),
              const SizedBox(width: 6),
              Text('You rated this trip', style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textHint,
              )),
            ]),
          ],

          // Buttons for upcoming
          if (!isPast) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEEEEEE)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text('Cancel', style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  // Fixed: pass all required params to LiveTripTrackingScreen
                  onPressed: () => Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => LiveTripTrackingScreen(
                        tripId: b['trip_id']?.toString() ?? '',
                        driverName: b['driver'] as String,
                        driverRating: (b['driver_rating'] as num?)?.toDouble() ?? 4.8,
                        todaBodyNumber: b['toda_body_number']?.toString() ?? 'TODA-01',
                        plateNo: b['plate_no']?.toString() ?? '',
                        etaMinutes: (b['eta_minutes'] as num?)?.toInt() ?? 5,
                        distanceKm: (b['distance_km'] as num?)?.toDouble() ?? 1.2,
                      ),
                      transitionDuration: const Duration(milliseconds: 400),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  child: Text('Track', style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
                  )),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(status, style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w700, color: color,
        )),
      );

  Widget _emptyBookings() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.calendar_today_rounded,
                  size: 32, color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            Text('No ${_bookingTab == 0 ? "upcoming" : "past"} trips',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.backgroundDark)),
            const SizedBox(height: 6),
            Text('Your rides will appear here',
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint)),
          ],
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // WALLET TAB
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildWalletTab() {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Container(
          color: AppColors.backgroundDark,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Wallet', style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white,
                )),
                const SizedBox(height: 24),
                Text('TodaGo Wallet Balance', style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text(
                    _balanceVisible
                        ? '₱${_balance.toStringAsFixed(2)}' : '₱•••••',
                    style: GoogleFonts.poppins(
                      fontSize: 38, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                    child: Icon(
                      _balanceVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white38, size: 20,
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                Row(children: [
                  _walletActionBtn(Icons.add_rounded, 'Top Up',
                      AppColors.primary, AppColors.backgroundDark),
                  const SizedBox(width: 12),
                  _walletActionBtn(Icons.arrow_upward_rounded, 'Cash Out',
                      Colors.white.withOpacity(0.12), Colors.white),
                  const SizedBox(width: 12),
                  _walletActionBtn(Icons.send_rounded, 'Send',
                      Colors.white.withOpacity(0.12), Colors.white),
                ]),
              ]),
            ),
          ),
        ),
      ),

      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(children: [
            _wStat('Total Spent', '₱620', Icons.payments_rounded),
            Container(width: 1, height: 44, color: const Color(0xFFF0F0F0)),
            _wStat('Trips', '31', Icons.electric_rickshaw_rounded),
            Container(width: 1, height: 44, color: const Color(0xFFF0F0F0)),
            _wStat('Saved', '₱48', Icons.card_giftcard_rounded,
                color: AppColors.success),
          ]),
        ),
      ),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Linked Accounts', style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.backgroundDark,
            )),
            const SizedBox(height: 12),
            _linkedAcc('💙', 'GCash', '••••4821', 'Connected', true),
            const SizedBox(height: 10),
            _linkedAcc('💜', 'Maya', 'Not linked', 'Connect', false),
          ]),
        ),
      ),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Transaction History', style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.backgroundDark,
            )),
            const SizedBox(height: 12),
            Row(children: [
              _wFilterTab('All', 0),
              const SizedBox(width: 8),
              _wFilterTab('Top-up', 1),
              const SizedBox(width: 8),
              _wFilterTab('Trips', 2),
            ]),
          ]),
        ),
      ),

      SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _txCard(_filteredTx[i]),
          ),
          childCount: _filteredTx.length,
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 30)),
    ]);
  }

  Widget _walletActionBtn(IconData icon, String label, Color bg, Color fg) =>
      Expanded(
        child: GestureDetector(
          onTap: () => _showTopUpSheet(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: fg,
              )),
            ]),
          ),
        ),
      );

  Widget _wStat(String label, String val, IconData icon,
          {Color color = AppColors.backgroundDark}) =>
      Expanded(
        child: Column(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(val, style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w800, color: color,
          )),
          Text(label, style: GoogleFonts.poppins(
              fontSize: 10, color: AppColors.textHint)),
        ]),
      );

  Widget _linkedAcc(String emoji, String name, String detail, String action,
          bool connected) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.backgroundDark,
            )),
            Text(detail, style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textHint)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(action, style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: connected ? AppColors.success : AppColors.primary,
            )),
          ),
        ]),
      );

  Widget _wFilterTab(String label, int idx) {
    final sel = _walletTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _walletTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.backgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? AppColors.backgroundDark : const Color(0xFFEEEEEE),
          ),
        ),
        child: Text(label, style: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: sel ? Colors.white : AppColors.textHint,
        )),
      ),
    );
  }

  Widget _txCard(Map<String, dynamic> t) {
    final amount = t['amount'] as double;
    final isPos = amount > 0;
    Color iconBg = t['type'] == 'topup'
        ? AppColors.success.withOpacity(0.1)
        : t['type'] == 'cashback'
            ? AppColors.primary.withOpacity(0.1)
            : const Color(0xFFF0F2F5);
    Color iconColor = t['type'] == 'topup'
        ? AppColors.success
        : t['type'] == 'cashback'
            ? AppColors.primary
            : AppColors.backgroundDark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(t['icon'] as IconData, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['title'] as String, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.backgroundDark,
          )),
          Text(t['subtitle'] as String, style: GoogleFonts.poppins(
            fontSize: 11, color: AppColors.textHint,
          )),
          Text('${t['date']} · ${t['time']}', style: GoogleFonts.poppins(
            fontSize: 10, color: AppColors.textHint,
          )),
        ])),
        Text(
          '${isPos ? '+' : ''}₱${amount.abs().toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w800,
            color: isPos ? AppColors.success : AppColors.backgroundDark,
          ),
        ),
      ]),
    );
  }

  void _showTopUpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),
          Text('Top Up Wallet', style: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: AppColors.backgroundDark,
          )),
          const SizedBox(height: 4),
          Text('Select amount and payment method', style: GoogleFonts.poppins(
            fontSize: 13, color: AppColors.textHint,
          )),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [50, 100, 200, 300, 500, 1000]
                .map((amt) => GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('₱$amt', style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.backgroundDark,
                        )),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Text('Pay with', style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.backgroundDark,
          )),
          const SizedBox(height: 12),
          Row(children: [
            _payOpt('💙', 'GCash', true),
            const SizedBox(width: 10),
            _payOpt('💜', 'Maya', false),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Proceed to Top Up', style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
              )),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _payOpt(String emoji, String label, bool sel) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppColors.backgroundDark : const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: sel ? Colors.white : AppColors.backgroundDark,
            )),
          ]),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // PROFILE TAB
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildProfileTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 20),
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(
              color: AppColors.backgroundDark, shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'R',
              style: GoogleFonts.poppins(
                fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primary,
              ),
            )),
          ),
          const SizedBox(height: 14),
          Text(_user?['full_name'] ?? 'Rider', style: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.backgroundDark,
          )),
          Text(_user?['email'] ?? '', style: GoogleFonts.poppins(
            fontSize: 13, color: AppColors.textHint,
          )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Passenger', style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary,
            )),
          ),
          const SizedBox(height: 32),
          _pItem(Icons.phone_rounded, 'Phone', _user?['phone'] ?? '—'),
          _pItem(Icons.email_rounded, 'Email', _user?['email'] ?? '—'),
          _pItem(Icons.star_rounded, 'Total Trips', '31 completed'),
          _pItem(Icons.account_balance_wallet_rounded, 'Wallet Balance', '₱245.50'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: OutlinedButton(
              onPressed: () async {
                await AuthService.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (_) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Logout', style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error,
              )),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pItem(IconData icon, String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.backgroundDark),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textHint)),
            Text(value, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: AppColors.backgroundDark,
            )),
          ]),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAV
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    final tabs = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.calendar_today_rounded, 'label': 'Bookings'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Wallet'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final sel = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tabs[i]['icon'] as IconData,
                          size: 22,
                          color: sel ? AppColors.backgroundDark : Colors.grey[400]),
                      const SizedBox(height: 3),
                      Text(tabs[i]['label'] as String, style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        color: sel ? AppColors.backgroundDark : Colors.grey[400],
                      )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}