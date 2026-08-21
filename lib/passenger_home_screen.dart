import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'destination_picker_screen.dart';
import 'map_service.dart';
import 'live_trip_tracking_screen.dart';
import 'rate_driver_screen.dart';
import 'service_selection_screen.dart';
import 'trip_service.dart';
import 'splash_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_avatar.dart';
import 'profile_photo_service.dart';
import 'reservation_notification_service.dart';
import 'report_issue_dialog.dart';
import 'smart_ride_service.dart';
import 'panabo_config.dart';
import 'wallet_service.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});
  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  int _selectedTab = 0;
  Map<String, dynamic>? _user;
  String? _passengerPhotoPath;
  GoogleMapController? _mapController;
  LatLng _currentLocation = PanaboConfig.cityCenter;
  bool _hasLiveLocation = false;
  bool _smartRideLoading = false;
  StreamSubscription<Position>? _locationStream;

  // ── Bookings state ────────────────────────────────────────────────────────
  int _bookingTab = 0;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _livePast = [];
  bool _loadingBookings = false;
  final Map<String, int?> _tripRatings = {};
  Timer? _bookingsTimer;

  // ── Wallet state ──────────────────────────────────────────────────────────
  bool _balanceVisible = true;
  int _walletTab = 0;
  double _walletBalance = 0;
  double _walletTotalSpent = 0;
  double _walletRewards = 0;
  int _walletTrips = 0;
  bool _loadingWallet = false;
  bool _startingTopUp = false;
  Timer? _walletTimer;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, Map<String, dynamic>> _linkedAccounts = {};

  double get _balance => _walletBalance;

  List<Map<String, dynamic>> get _filteredTx {
    if (_walletTab == 1) {
      return _transactions.where((t) => t['type'] == 'topup').toList();
    }
    if (_walletTab == 2) {
      return _transactions.where((t) => t['type'] == 'trip').toList();
    }
    return _transactions;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _loadUser();
    _loadProfilePhoto();
    _initLocation();
    _loadBookings();
    _startBookingsRealtime();
    _loadWallet();
    _startWalletRealtime();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.fetchProfile();
    final serverPhoto = _profilePhotoSource(user);
    if (mounted) {
      setState(() {
        _user = user;
        if (serverPhoto != null) _passengerPhotoPath = serverPhoto;
      });
    }
  }

  Future<void> _loadProfilePhoto() async {
    final path = await ProfilePhotoService.getPhotoPath(
      ProfilePhotoService.passengerPhotoKey,
    );
    if (mounted && _profilePhotoSource(_user) == null) {
      setState(() => _passengerPhotoPath = path);
    }
  }

  Future<void> _initLocation() async {
    final granted = await LocationService.requestPermission(context);
    if (!granted) return;
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentLocation = loc;
        _hasLiveLocation = true;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 16));
    }
    await _locationStream?.cancel();
    _locationStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 8),
    ).listen((position) {
      if (!mounted) return;
      final loc = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = loc;
        _hasLiveLocation = true;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(loc));
    });
  }

  void _startBookingsRealtime() {
    _bookingsTimer?.cancel();
    _bookingsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadBookings(silent: true);
    });
  }

  void _startWalletRealtime() {
    _walletTimer?.cancel();
    _walletTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadWallet(silent: true);
    });
  }

  Future<void> _loadWallet({bool silent = false}) async {
    if (_loadingWallet) return;
    if (!silent && mounted) setState(() => _loadingWallet = true);
    try {
      final wallet = await WalletService.getWallet();
      if (!mounted) return;
      if (wallet == null) {
        setState(() => _loadingWallet = false);
        return;
      }

      final stats = wallet['stats'] as Map<String, dynamic>? ?? {};
      final rawAccounts = wallet['linked_accounts'];
      final accounts = <String, Map<String, dynamic>>{};
      if (rawAccounts is List) {
        for (final account in rawAccounts) {
          if (account is! Map) continue;
          final data = Map<String, dynamic>.from(account);
          final provider = data['provider']?.toString();
          if (provider != null && provider.isNotEmpty) {
            accounts[provider] = data;
          }
        }
      }

      final rawTransactions = wallet['transactions'];
      final transactions = <Map<String, dynamic>>[];
      if (rawTransactions is List) {
        for (final item in rawTransactions) {
          if (item is Map) {
            transactions.add(
                _normalizeWalletTransaction(Map<String, dynamic>.from(item)));
          }
        }
      }

      setState(() {
        _walletBalance = _asDouble(wallet['balance']);
        _walletTotalSpent = _asDouble(stats['total_spent']);
        _walletRewards = _asDouble(stats['rewards']);
        _walletTrips = _asInt(stats['completed_trips']);
        _linkedAccounts = accounts;
        _transactions = transactions;
        _loadingWallet = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingWallet = false);
    }
  }

  Future<void> _loadWalletFromPayload(Map<String, dynamic> wallet) async {
    if (!mounted) return;
    final stats = wallet['stats'] as Map<String, dynamic>? ?? {};
    final rawAccounts = wallet['linked_accounts'];
    final accounts = <String, Map<String, dynamic>>{};
    if (rawAccounts is List) {
      for (final account in rawAccounts) {
        if (account is! Map) continue;
        final data = Map<String, dynamic>.from(account);
        final provider = data['provider']?.toString();
        if (provider != null && provider.isNotEmpty) {
          accounts[provider] = data;
        }
      }
    }

    final rawTransactions = wallet['transactions'];
    final transactions = <Map<String, dynamic>>[];
    if (rawTransactions is List) {
      for (final item in rawTransactions) {
        if (item is Map) {
          transactions.add(
              _normalizeWalletTransaction(Map<String, dynamic>.from(item)));
        }
      }
    }

    setState(() {
      _walletBalance = _asDouble(wallet['balance']);
      _walletTotalSpent = _asDouble(stats['total_spent']);
      _walletRewards = _asDouble(stats['rewards']);
      _walletTrips = _asInt(stats['completed_trips']);
      _linkedAccounts = accounts;
      _transactions = transactions;
      _loadingWallet = false;
    });
  }

  Future<void> _loadBookings({bool silent = false}) async {
    if (_loadingBookings) return;
    if (!silent && mounted) setState(() => _loadingBookings = true);
    try {
      final trips = await TripService.getPassengerBookings();
      if (!mounted) return;
      final upcoming = <Map<String, dynamic>>[];
      final past = <Map<String, dynamic>>[];
      for (final trip in trips) {
        if (_isPastBooking(trip)) {
          past.add(trip);
        } else {
          upcoming.add(trip);
        }
      }
      upcoming.sort((a, b) {
        final ad = _bookingDateTime(a) ?? DateTime.now();
        final bd = _bookingDateTime(b) ?? DateTime.now();
        return ad.compareTo(bd);
      });
      setState(() {
        _upcoming = upcoming;
        _livePast = past;
        _loadingBookings = false;
      });
      await ReservationNotificationService.scheduleForTrips(
        upcoming.where((t) => t['trip_type']?.toString() == 'scheduled'),
        forDriver: false,
      );
      for (final t in past) {
        final id = t['trip_id']?.toString() ?? '';
        if (id.isEmpty || t['status'] != 'completed') continue;
        if (t['rating_score'] != null) {
          final score = t['rating_score'];
          _tripRatings[id] =
              score is int ? score : int.tryParse(score.toString());
        } else if (!_tripRatings.containsKey(id)) {
          setState(() => _tripRatings[id] = null);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  bool _isPastBooking(Map<String, dynamic> trip) {
    final status = trip['status']?.toString().toLowerCase() ?? '';
    return status == 'completed' || status == 'cancelled';
  }

  DateTime? _bookingDateTime(Map<String, dynamic> trip) {
    final raw = trip['scheduled_pickup_at'] ?? trip['request_timestamp'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  Future<void> _refreshTripRating(String tripId) async {
    if (tripId.isEmpty) return;
    final res = await TripService.getTripRating(tripId);
    if (!mounted) return;
    if (res['hasRated'] == true) {
      final score = res['feedback']?['rating_score'];
      setState(() => _tripRatings[tripId] =
          score is int ? score : int.tryParse(score.toString()));
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final tripId = booking['trip_id']?.toString() ?? '';
    if (tripId.isEmpty) return;
    final result = await TripService.cancelPassengerTrip(tripId);
    if (!mounted) return;
    if (result['success'] == true) {
      await ReservationNotificationService.cancelForTrip(
        tripId,
        forDriver: false,
      );
      _showSnack('Booking cancelled.', AppColors.success);
      await _loadBookings();
    } else {
      _showSnack(result['message']?.toString() ?? 'Could not cancel booking.',
          AppColors.error);
    }
  }

  void _openBookingTracking(Map<String, dynamic> booking) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => LiveTripTrackingScreen(
        tripId: booking['trip_id']?.toString() ?? '',
        driverName: booking['driver_name']?.toString() ??
            booking['driver']?.toString() ??
            '',
        driverPhone: booking['driver_phone']?.toString(),
        driverRating: double.tryParse(booking['driver_rating']?.toString() ??
                booking['avg_rating']?.toString() ??
                '') ??
            0.0,
        todaBodyNumber: booking['toda_body_number']?.toString() ?? '',
        plateNo: booking['plate_no']?.toString() ?? '',
        etaMinutes: (booking['eta_minutes'] as num?)?.toInt() ?? 5,
        distanceKm: (booking['distance_km'] as num?)?.toDouble() ?? 1.2,
        destination: booking['destination']?.toString(),
        fare: double.tryParse(booking['fare']?.toString() ?? ''),
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _bookingsTimer?.cancel();
    _walletTimer?.cancel();
    _locationStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  String get _firstName {
    final name = _user?['full_name'] ?? 'Rider';
    return name.toString().split(' ').first;
  }

  String get _profileInitials {
    final name = _user?['full_name']?.toString() ?? 'Rider';
    return name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  int get _completedTripCount =>
      _livePast.where((trip) => trip['status'] == 'completed').length;

  int get _cancelledTripCount =>
      _livePast.where((trip) => trip['status'] == 'cancelled').length;

  Future<void> _pickPassengerPhoto() async {
    final path = await ProfilePhotoService.pickAndSavePhoto(
      ProfilePhotoService.passengerPhotoKey,
    );
    if (path != null && mounted) {
      setState(() => _passengerPhotoPath = path);
      final dataUri = await ProfilePhotoService.fileToDataUri(path);
      final user = dataUri == null
          ? null
          : await AuthService.updateProfilePhoto(dataUri);
      if (!mounted) return;
      final serverPhoto = _profilePhotoSource(user);
      if (user != null) {
        setState(() {
          _user = user;
          if (serverPhoto != null) _passengerPhotoPath = serverPhoto;
        });
        _showSnack('Profile photo updated', AppColors.success);
      } else {
        _showSnack(
            'Photo saved on this device. Online sync failed.', AppColors.error);
      }
    }
  }

  String? _profilePhotoSource(Map<String, dynamic>? data) {
    final value = data?['profile_photo_url']?.toString();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatPeso(double amount, {int decimals = 2}) {
    return '₱${amount.toStringAsFixed(decimals)}';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _formatTxDate(DateTime? date) {
    if (date == null) return 'Pending';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTxTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  IconData _walletTxIcon(String type) {
    switch (type) {
      case 'topup':
        return Icons.add_circle_rounded;
      case 'reward':
      case 'cashback':
        return Icons.card_giftcard_rounded;
      case 'cashout':
        return Icons.arrow_upward_rounded;
      case 'send':
        return Icons.send_rounded;
      default:
        return Icons.electric_rickshaw_rounded;
    }
  }

  Map<String, dynamic> _normalizeWalletTransaction(Map<String, dynamic> raw) {
    final type = raw['type']?.toString() ?? 'trip';
    final status = raw['status']?.toString() ?? 'completed';
    final occurredAt = _parseDate(raw['occurred_at']);
    final subtitle = raw['subtitle']?.toString() ?? '';
    return {
      'type': type,
      'status': status,
      'title': raw['title']?.toString() ?? 'Wallet transaction',
      'subtitle': status == 'pending' && subtitle.isNotEmpty
          ? '$subtitle · Pending'
          : subtitle,
      'date': _formatTxDate(occurredAt),
      'time': _formatTxTime(occurredAt),
      'amount': _asDouble(raw['amount']),
      'icon': _walletTxIcon(type),
    };
  }

  bool _isProviderLinked(String provider) {
    return _linkedAccounts[provider]?['connected'] == true;
  }

  String _linkedAccountDetail(String provider) {
    final account = _linkedAccounts[provider];
    if (account?['connected'] != true) return 'Not linked';
    return account?['masked_number']?.toString() ??
        account?['account_name']?.toString() ??
        'Linked';
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style:
              GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Open FAQ chatbot ──────────────────────────────────────────────────────
  void _openChat() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => AIChatScreen(
        userType: 'passenger',
        userName: _user?['full_name']?.toString() ?? 'Passenger',
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  void _openReportIssue() {
    showReportIssueDialog(
      context: context,
      reporterRole: 'passenger',
    );
  }

  void _openDestinationPicker({String? initialServiceType}) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => DestinationPickerScreen(
        initialServiceType: initialServiceType,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _openSmartRideSheetSafe() async {
    final intent = await showModalBottomSheet<RideIntent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SmartRideSheet(),
    );

    if (!mounted || intent == null) return;
    await _confirmSmartRideIntent(intent);
  }

  Future<void> _confirmSmartRideIntent(RideIntent intent) async {
    final destination = intent.destinationQuery.trim();
    final service = intent.selectedServiceType;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Continue Smart Ride?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pickup: Current location',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
            ),
            Text(
              'Destination: $destination',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
            ),
            Text(
              service == null
                  ? 'Service: Choose next'
                  : 'Service: ${service[0].toUpperCase()}${service.substring(1)}',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textHint),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _startSmartRide(intent);
    }
  }

  Future<void> _startSmartRide(RideIntent intent) async {
    if (_smartRideLoading) return;
    final destinationQuery = intent.destinationQuery.trim();
    if (destinationQuery.isEmpty) {
      _showSnack('Please tell me your destination first.', AppColors.error);
      return;
    }

    setState(() => _smartRideLoading = true);
    try {
      LatLng? pickup = _hasLiveLocation ? _currentLocation : null;
      if (pickup == null) {
        final pos = await LocationService.getCurrentPosition();
        if (pos != null) {
          pickup = LatLng(pos.latitude, pos.longitude);
          if (mounted) {
            setState(() {
              _currentLocation = pickup!;
              _hasLiveLocation = true;
            });
          }
        }
      }

      pickup ??= await MapService.getCurrentLocation()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (!mounted) return;

      if (pickup == null) {
        _showSnack(
            'I could not get your current location yet.', AppColors.error);
        return;
      }

      final suggestions = await MapService.searchPlaces(
        destinationQuery,
        locationBias: pickup,
      );
      if (!mounted) return;

      if (suggestions.isEmpty) {
        _showSnack(
          'I could not find "$destinationQuery". Try a more specific place.',
          AppColors.error,
        );
        return;
      }

      final place = suggestions.first;
      final destination = await MapService.getPlaceLatLng(place.placeId);
      if (!mounted) return;

      if (destination == null) {
        _showSnack(
          'I found the place, but could not get its map location.',
          AppColors.error,
        );
        return;
      }

      var pickupName = 'Your Location';
      try {
        pickupName = await MapService.reverseGeocode(pickup)
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        pickupName = 'Your Location';
      }

      final route = await MapService.fetchRoute(pickup, destination);
      if (!mounted) return;

      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, __, ___) => ServiceSelectionScreen(
          pickupName: pickupName,
          destinationName:
              place.mainText.isNotEmpty ? place.mainText : destinationQuery,
          pickupLatLng: pickup,
          destinationLatLng: destination,
          etaMinutes: route?.etaMinutes,
          distanceKm: route?.distanceKm,
          initialServiceType: intent.selectedServiceType,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ));
    } finally {
      if (mounted) setState(() => _smartRideLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        IndexedStack(
          index: _selectedTab,
          children: [
            _buildHomeTab(),
            _buildBookingsTab(),
            _buildWalletTab(),
            _buildEnhancedProfileTab(),
          ],
        ),

        // ── Floating FAQ chatbot button ─────────────────────────────────
        Positioned(
          bottom: 76, // just above the bottom nav
          right: 16,
          child: GestureDetector(
            onTap: _openChat,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.backgroundDark.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Stack(alignment: Alignment.center, children: [
                const Icon(Icons.question_answer_rounded,
                    color: AppColors.primary, size: 26),
                // Notification dot
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ]),
            ),
          ).animate().fadeIn(delay: 600.ms).scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.elasticOut),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HOME TAB
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    return Stack(children: [
      SizedBox.expand(
        child: GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
            if (_hasLiveLocation) {
              _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLocation, 16));
            }
          },
          initialCameraPosition: CameraPosition(
              target: _currentLocation, zoom: _hasLiveLocation ? 15.0 : 14.5),
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          markers: _hasLiveLocation
              ? {
                  Marker(
                    markerId: const MarkerId('current_location'),
                    position: _currentLocation,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueYellow),
                  ),
                }
              : {},
        ),
      ),

      // Top bar
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(children: [
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 4),
                  Text('TodaGo',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.backgroundDark)),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _initLocation,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.12), blurRadius: 10)
                    ],
                  ),
                  child: const Icon(Icons.my_location_rounded,
                      color: AppColors.backgroundDark, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ),

      // Bottom card
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Quick Actions',
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.backgroundDark)),
                Text('Choose how you want to ride',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textHint)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                        _smartRideLoading ? null : _openSmartRideSheetSafe,
                    icon: _smartRideLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.backgroundDark,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded,
                            color: AppColors.backgroundDark, size: 20),
                    label: Text('Smart Ride',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.backgroundDark)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.55),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _openDestinationPicker(),
                    icon: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 20),
                    label: Text('Book Now',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
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
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openDestinationPicker(initialServiceType: 'pickup'),
                    icon: const Icon(Icons.inventory_2_rounded,
                        color: AppColors.backgroundDark, size: 20),
                    label: Text('Book Pick-up',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.backgroundDark)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _openDestinationPicker(),
                    icon: const Icon(Icons.calendar_month_rounded,
                        color: AppColors.backgroundDark, size: 20),
                    label: Text('Schedule Reservation',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.backgroundDark)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOOKINGS TAB
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBookingsTab() {
    final list = _bookingTab == 0 ? _upcoming : _livePast;
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Bookings',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark)),
            Text('Track all your trips',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textHint)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                _bTabBtn('Upcoming (${_upcoming.length})', 0),
                _bTabBtn('Past', 1),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingBookings && list.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : list.isEmpty
                  ? _emptyBookings()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _bookingCard(list[i])
                            .animate()
                            .fadeIn(
                                delay: Duration(milliseconds: 80 * i),
                                duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _bTabBtn(String label, int idx) {
    final sel = _bookingTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _bookingTab = idx);
          if (idx == 1 && _livePast.isEmpty) _loadBookings();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: sel
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? AppColors.backgroundDark : AppColors.textHint)),
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final isPast = _bookingTab == 1;
    final status = b['status']?.toString().toLowerCase() ?? '';
    final tripId = b['trip_id']?.toString() ?? '';
    final isCompleted = status == 'completed';
    final isScheduled =
        b['trip_type']?.toString() == 'scheduled' || status == 'scheduled';
    final canTrack = ['requested', 'accepted', 'pickup', 'ongoing', 'arrived']
        .contains(status);
    final hasRatingData = _tripRatings.containsKey(tripId);
    final existingRating = _tripRatings[tripId];

    Color statusColor = AppColors.primary;
    if (status == 'completed') statusColor = Colors.green;
    if (status == 'cancelled') statusColor = Colors.red;
    if (status == 'accepted') statusColor = Colors.green;
    if (status == 'arrived') statusColor = AppColors.primary;
    if (status == 'requested') statusColor = Colors.orange;
    if (status == 'scheduled') statusColor = AppColors.primary;
    if (b['statusColor'] is Color) statusColor = b['statusColor'] as Color;

    String displayDate = b['date']?.toString() ?? '';
    String displayTime = b['time']?.toString() ?? '';
    final bookingDate = _bookingDateTime(b);
    if (bookingDate != null) {
      displayDate =
          '${bookingDate.year}-${bookingDate.month.toString().padLeft(2, '0')}-'
          '${bookingDate.day.toString().padLeft(2, '0')}';
      displayTime = '${bookingDate.hour.toString().padLeft(2, '0')}:'
          '${bookingDate.minute.toString().padLeft(2, '0')}';
    }

    String fareDisplay = '—';
    if (b['fare'] != null) {
      final f = double.tryParse(b['fare'].toString());
      fareDisplay =
          f != null ? '₱${f.toStringAsFixed(0)}' : b['fare'].toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(displayDate,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.backgroundDark)),
            const Spacer(),
            _statusBadge(
              _statusLabel(status),
              statusColor,
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time_rounded,
                size: 13, color: AppColors.textHint),
            const SizedBox(width: 5),
            Text(displayTime,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textHint)),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: AppColors.backgroundDark, shape: BoxShape.circle)),
              Container(width: 1.5, height: 40, color: const Color(0xFFDDDDDD)),
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)),
            ]),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pickup',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: AppColors.textHint)),
                        Text(
                          b['pickup_location']?.toString() ??
                              b['pickup']?.toString() ??
                              '—',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.backgroundDark),
                        ),
                      ]),
                  const SizedBox(height: 18),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Destination',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: AppColors.textHint)),
                        Text(b['destination']?.toString() ?? '—',
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.backgroundDark)),
                      ]),
                ])),
          ]),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF0F0F0), height: 1),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.person_outline_rounded,
                size: 16, color: AppColors.textHint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                b['driver_name']?.toString() ?? b['driver']?.toString() ?? '—',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textHint),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(b['service_type']?.toString() ?? b['type']?.toString() ?? '').toUpperCase()}  ',
              style:
                  GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint),
            ),
            Text(fareDisplay,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark)),
          ]),

          // ── Rating ──────────────────────────────────────────────────────
          if (isPast && isCompleted) ...[
            const SizedBox(height: 14),
            if (existingRating != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < existingRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Your rating: $existingRating/5',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.backgroundDark)),
                  const Spacer(),
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 16),
                ]),
              )
            else if (!hasRatingData)
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: tripId.isNotEmpty
                      ? () => Navigator.of(context)
                          .push(PageRouteBuilder(
                            pageBuilder: (_, __, ___) => RateDriverScreen(
                              tripId: tripId,
                              driverName: b['driver_name']?.toString() ??
                                  b['driver']?.toString() ??
                                  'Driver',
                              driverRating: double.tryParse(
                                      b['driver_rating']?.toString() ?? '') ??
                                  0.0,
                              todaBodyNumber:
                                  b['toda_body_number']?.toString() ?? '',
                              plateNo: b['plate_no']?.toString() ?? '',
                              destination:
                                  b['destination']?.toString() ?? 'Destination',
                              fare: double.tryParse(
                                      b['fare']?.toString() ?? '') ??
                                  25.0,
                            ),
                            transitionDuration:
                                const Duration(milliseconds: 400),
                            transitionsBuilder: (_, anim, __, child) =>
                                SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, 1),
                                      end: Offset.zero)
                                  .animate(CurvedAnimation(
                                      parent: anim, curve: Curves.easeOut)),
                              child: child,
                            ),
                          ))
                          .then((_) => _refreshTripRating(tripId))
                      : null,
                  icon: const Icon(Icons.star_rounded,
                      color: AppColors.backgroundDark, size: 18),
                  label: Text('Rate This Trip',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.backgroundDark)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
          ],

          // ── Track / Cancel (upcoming) ───────────────────────────────────
          if (!isPast) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: tripId.isEmpty ? null : () => _cancelBooking(b),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEEEEEE)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error)),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton(
                onPressed: canTrack ? () => _openBookingTracking(b) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.backgroundDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
                child: Text(isScheduled && !canTrack ? 'Reserved' : 'Track',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              )),
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
        child: Text(status,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  String _statusLabel(String status) {
    if (status == 'scheduled') return 'Reserved';
    if (status.isEmpty) return status;
    return status[0].toUpperCase() + status.substring(1);
  }

  Widget _emptyBookings() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.calendar_today_rounded,
                  size: 32, color: AppColors.textHint)),
          const SizedBox(height: 16),
          Text('No ${_bookingTab == 0 ? "upcoming" : "past"} trips',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.backgroundDark)),
          const SizedBox(height: 6),
          Text('Your rides will appear here',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint)),
          if (_bookingTab == 1) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadBookings,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              label: Text('Refresh',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ],
        ]),
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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Wallet',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 24),
                    Text('TodaGo Wallet Balance',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _balanceVisible ? _formatPeso(_balance) : '₱•••••',
                            style: GoogleFonts.poppins(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => setState(
                                () => _balanceVisible = !_balanceVisible),
                            child: Icon(
                              _balanceVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white38,
                              size: 20,
                            ),
                          ),
                        ]),
                    const SizedBox(height: 24),
                    Row(children: [
                      _walletActionBtn(Icons.add_rounded, 'Top Up',
                          AppColors.primary, AppColors.backgroundDark,
                          onTap: _showTopUpSheet),
                      const SizedBox(width: 12),
                      _walletActionBtn(Icons.arrow_upward_rounded, 'Cash Out',
                          Colors.white.withOpacity(0.12), Colors.white,
                          onTap: () => _showSnack(
                              'Cash out requires a live payout provider.',
                              AppColors.error)),
                      const SizedBox(width: 12),
                      _walletActionBtn(Icons.send_rounded, 'Send',
                          Colors.white.withOpacity(0.12), Colors.white,
                          onTap: () => _showSnack(
                              'Send requires a live recipient wallet.',
                              AppColors.error)),
                    ]),
                  ]),
            )),
      )),
      SliverToBoxAdapter(
          child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEEEEEE))),
        child: Row(children: [
          _wStat('Total Spent', _formatPeso(_walletTotalSpent, decimals: 0),
              Icons.payments_rounded),
          Container(width: 1, height: 44, color: const Color(0xFFF0F0F0)),
          _wStat('Trips', '$_walletTrips', Icons.electric_rickshaw_rounded),
          Container(width: 1, height: 44, color: const Color(0xFFF0F0F0)),
          _wStat('Rewards', _formatPeso(_walletRewards, decimals: 0),
              Icons.card_giftcard_rounded,
              color: AppColors.success),
        ]),
      )),
      SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Linked Accounts',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.backgroundDark)),
          const SizedBox(height: 12),
          _linkedAcc(
            '💙',
            'GCash',
            _linkedAccountDetail('gcash'),
            _isProviderLinked('gcash') ? 'Connected' : 'Connect',
            _isProviderLinked('gcash'),
            onTap: () => _isProviderLinked('gcash')
                ? _confirmUnlinkAccount('gcash')
                : _showLinkAccountDialog('gcash'),
          ),
          const SizedBox(height: 10),
          _linkedAcc(
            '💜',
            'Maya',
            _linkedAccountDetail('maya'),
            _isProviderLinked('maya') ? 'Connected' : 'Connect',
            _isProviderLinked('maya'),
            onTap: () => _isProviderLinked('maya')
                ? _confirmUnlinkAccount('maya')
                : _showLinkAccountDialog('maya'),
          ),
        ]),
      )),
      SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Transaction History',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.backgroundDark)),
          const SizedBox(height: 12),
          Row(children: [
            _wFilterTab('All', 0),
            const SizedBox(width: 8),
            _wFilterTab('Top-up', 1),
            const SizedBox(width: 8),
            _wFilterTab('Trips', 2),
          ]),
        ]),
      )),
      if (_loadingWallet && _transactions.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
        )
      else if (_filteredTx.isEmpty)
        SliverToBoxAdapter(child: _emptyWalletTransactions())
      else
        SliverList(
            delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _txCard(_filteredTx[i])),
          childCount: _filteredTx.length,
        )),
      const SliverToBoxAdapter(child: SizedBox(height: 30)),
    ]);
  }

  Widget _walletActionBtn(IconData icon, String label, Color bg, Color fg,
          {required VoidCallback onTap}) =>
      Expanded(
          child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ]),
        ),
      ));

  Widget _wStat(String label, String val, IconData icon,
          {Color color = AppColors.backgroundDark}) =>
      Expanded(
          child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(val,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
      ]));

  Widget _linkedAcc(String emoji, String name, String detail, String action,
          bool connected,
          {required VoidCallback onTap}) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEEEEE))),
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.backgroundDark)),
                    Text(detail,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textHint)),
                  ])),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: connected
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(action,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            connected ? AppColors.success : AppColors.primary)),
              ),
            ]),
          ));

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
              color: sel ? AppColors.backgroundDark : const Color(0xFFEEEEEE)),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AppColors.textHint)),
      ),
    );
  }

  Widget _txCard(Map<String, dynamic> t) {
    final amount = t['amount'] as double;
    final isPos = amount > 0;
    final iconBg = t['type'] == 'topup'
        ? AppColors.success.withOpacity(0.1)
        : t['type'] == 'cashback'
            ? AppColors.primary.withOpacity(0.1)
            : const Color(0xFFF0F2F5);
    final iconColor = t['type'] == 'topup'
        ? AppColors.success
        : t['type'] == 'cashback'
            ? AppColors.primary
            : AppColors.backgroundDark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Row(children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(t['icon'] as IconData, color: iconColor, size: 20)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['title'] as String,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.backgroundDark)),
          Text(t['subtitle'] as String,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
          Text('${t['date']} · ${t['time']}',
              style:
                  GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
        ])),
        Text(
          '${isPos ? '+' : ''}₱${amount.abs().toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isPos ? AppColors.success : AppColors.backgroundDark),
        ),
      ]),
    );
  }

  Widget _emptyWalletTransactions() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Column(children: [
            Icon(Icons.receipt_long_rounded,
                color: AppColors.textHint.withValues(alpha: 0.7), size: 28),
            const SizedBox(height: 8),
            Text('No live transactions yet',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.backgroundDark)),
            const SizedBox(height: 2),
            Text('Completed rides and confirmed top-ups will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textHint)),
          ]),
        ),
      );

  Future<void> _showLinkAccountDialog(String provider) async {
    final accountController =
        TextEditingController(text: _user?['phone']?.toString() ?? '');
    final nameController =
        TextEditingController(text: _user?['full_name']?.toString() ?? '');
    final label = provider == 'maya' ? 'Maya' : 'GCash';

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Link $label',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: accountController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '$label account number',
                labelStyle: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Account name',
                labelStyle: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                final accountNumber = accountController.text.trim();
                if (accountNumber.length < 4) {
                  _showSnack(
                      'Enter a valid $label account number.', AppColors.error);
                  return;
                }
                Navigator.pop(dialogContext);
                final result = await WalletService.linkAccount(
                  provider: provider,
                  accountNumber: accountNumber,
                  accountName: nameController.text,
                );
                if (!mounted) return;
                final wallet = result['wallet'];
                if (result['success'] == true &&
                    wallet is Map<String, dynamic>) {
                  await _loadWalletFromPayload(wallet);
                  _showSnack('$label linked.', AppColors.success);
                } else {
                  _showSnack(
                      result['message']?.toString() ?? 'Could not link $label.',
                      AppColors.error);
                }
              },
              child: Text('Link',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } finally {
      accountController.dispose();
      nameController.dispose();
    }
  }

  Future<void> _confirmUnlinkAccount(String provider) async {
    final label = provider == 'maya' ? 'Maya' : 'GCash';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unlink $label',
            style:
                GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800)),
        content: Text('Remove this linked $label account from your wallet?',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Unlink',
                style: GoogleFonts.poppins(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await WalletService.unlinkAccount(provider);
    if (!mounted) return;
    final wallet = result['wallet'];
    if (result['success'] == true && wallet is Map<String, dynamic>) {
      await _loadWalletFromPayload(wallet);
      _showSnack('$label unlinked.', AppColors.success);
    } else {
      _showSnack(result['message']?.toString() ?? 'Could not unlink $label.',
          AppColors.error);
    }
  }

  void _showTopUpSheet() {
    int selectedAmount = 100;
    String selectedProvider = _isProviderLinked('gcash') ? 'gcash' : 'maya';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final providerLinked = _isProviderLinked(selectedProvider);
          return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('Top Up Wallet',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.backgroundDark)),
                  const SizedBox(height: 4),
                  Text('Select amount and payment method',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textHint)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [50, 100, 200, 300, 500, 1000]
                        .map((amt) => GestureDetector(
                              onTap: () =>
                                  setSheetState(() => selectedAmount = amt),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                    color: selectedAmount == amt
                                        ? AppColors.backgroundDark
                                        : const Color(0xFFF0F2F5),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text('₱$amt',
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: selectedAmount == amt
                                            ? Colors.white
                                            : AppColors.backgroundDark)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('Pay with',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.backgroundDark)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _payOpt('💙', 'GCash', selectedProvider == 'gcash',
                        enabled: _isProviderLinked('gcash'),
                        onTap: () =>
                            setSheetState(() => selectedProvider = 'gcash')),
                    const SizedBox(width: 10),
                    _payOpt('💜', 'Maya', selectedProvider == 'maya',
                        enabled: _isProviderLinked('maya'),
                        onTap: () =>
                            setSheetState(() => selectedProvider = 'maya')),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: providerLinked && !_startingTopUp
                          ? () {
                              Navigator.pop(context);
                              _startTopUp(
                                  selectedProvider, selectedAmount.toDouble());
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.backgroundDark,
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0),
                      child: Text(
                          providerLinked
                              ? 'Proceed to Top Up'
                              : 'Link account first',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: providerLinked
                                  ? Colors.white
                                  : AppColors.textHint)),
                    ),
                  ),
                ]),
          );
        },
      ),
    );
  }

  Future<void> _startTopUp(String provider, double amount) async {
    if (_startingTopUp) return;
    setState(() => _startingTopUp = true);
    final result = await WalletService.createTopUpCheckout(
      provider: provider,
      amount: amount,
    );
    if (!mounted) return;
    setState(() => _startingTopUp = false);

    final wallet = result['wallet'];
    if (wallet is Map<String, dynamic>) {
      await _loadWalletFromPayload(wallet);
    } else {
      await _loadWallet(silent: true);
    }

    final checkoutUrl = result['checkoutUrl']?.toString();
    if (result['success'] == true &&
        checkoutUrl != null &&
        checkoutUrl.isNotEmpty) {
      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        _showSnack('Could not open PayMongo checkout.', AppColors.error);
      }
      return;
    }

    _showSnack(
      result['message']?.toString() ?? 'Could not start top-up.',
      AppColors.error,
    );
  }

  Widget _payOpt(String emoji, String label, bool sel,
          {required bool enabled, required VoidCallback onTap}) =>
      Expanded(
          child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.backgroundDark
                : enabled
                    ? const Color(0xFFF0F2F5)
                    : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? AppColors.primary : Colors.transparent, width: 2),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji,
                style: TextStyle(
                    fontSize: 20, color: enabled ? null : Colors.grey)),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: sel
                        ? Colors.white
                        : enabled
                            ? AppColors.backgroundDark
                            : AppColors.textHint)),
          ]),
        ),
      ));

  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEnhancedProfileTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(children: [
              ProfileAvatar(
                initials: _profileInitials,
                imagePath: _passengerPhotoPath,
                size: 96,
                onTap: _pickPassengerPhoto,
              ),
              const SizedBox(height: 14),
              Text(
                _user?['full_name']?.toString() ?? 'Rider',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _user?['email']?.toString() ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _profileChip(
                    Icons.verified_rounded,
                    'Verified Passenger',
                    AppColors.success,
                  ),
                  _profileChip(
                    Icons.shield_rounded,
                    'Safety Ready',
                    AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _pickPassengerPhoto,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: Text(
                    'Upload Photo',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.backgroundDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _profileStat('Trips', '$_completedTripCount', Icons.route_rounded),
            const SizedBox(width: 10),
            _profileStat(
              'Cancelled',
              '$_cancelledTripCount',
              Icons.cancel_rounded,
            ),
            const SizedBox(width: 10),
            _profileStat(
              'Wallet',
              _formatPeso(_balance, decimals: 0),
              Icons.account_balance_wallet_rounded,
            ),
          ]),
          const SizedBox(height: 20),
          _pItem(
            Icons.phone_rounded,
            'Phone',
            _user?['phone']?.toString() ?? '-',
          ),
          _pItem(
            Icons.email_rounded,
            'Email',
            _user?['email']?.toString() ?? '-',
          ),
          _pItem(Icons.home_rounded, 'Saved Places', 'Home, School, Work'),
          _pItem(Icons.emergency_rounded, 'Emergency Contact', 'Not set'),
          _pItem(Icons.tune_rounded, 'Ride Preferences', 'Cash, solo first'),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _openReportIssue,
              icon: const Icon(Icons.report_problem_rounded, size: 18),
              label: Text(
                'Report an Issue',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _pItem(Icons.card_giftcard_rounded, 'Rewards Tier', 'Starter'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
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
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _profileChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.24)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _profileStat(String label, String value, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint)),
          ]),
        ),
      );

  // PROFILE TAB
  // ══════════════════════════════════════════════════════════════════════════
  Widget buildLegacyProfileTab() {
    return SafeArea(
        child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 20),
        Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: AppColors.backgroundDark, shape: BoxShape.circle),
            child: Center(
                child: Text(
              _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'R',
              style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary),
            ))),
        const SizedBox(height: 14),
        Text(_user?['full_name'] ?? 'Rider',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.backgroundDark)),
        Text(_user?['email'] ?? '',
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text('Passenger',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ),
        const SizedBox(height: 32),
        _pItem(Icons.phone_rounded, 'Phone', _user?['phone'] ?? '—'),
        _pItem(Icons.email_rounded, 'Email', _user?['email'] ?? '—'),
        _pItem(Icons.star_rounded, 'Total Trips', '$_walletTrips completed'),
        _pItem(Icons.account_balance_wallet_rounded, 'Wallet Balance',
            _formatPeso(_balance)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
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
            child: Text('Logout',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error)),
          ),
        ),
      ]),
    ));
  }

  Widget _pItem(IconData icon, String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.backgroundDark),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textHint)),
              Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.backgroundDark)),
            ]),
          ),
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
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
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
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(tabs[i]['icon'] as IconData,
                  size: 22,
                  color: sel ? AppColors.backgroundDark : Colors.grey[400]),
              const SizedBox(height: 3),
              Text(tabs[i]['label'] as String,
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      color:
                          sel ? AppColors.backgroundDark : Colors.grey[400])),
            ]),
          ));
        })),
      )),
    );
  }
}

class _SmartRideSheet extends StatefulWidget {
  const _SmartRideSheet();

  @override
  State<_SmartRideSheet> createState() => _SmartRideSheetState();
}

class _SmartRideSheetState extends State<_SmartRideSheet> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _parsing = false;
  bool _speechReady = false;
  bool _isListening = false;
  String? _error;
  String _lastSpeechText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ready = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _finishListening();
        }
      },
    );
    if (mounted) setState(() => _speechReady = ready);
  }

  Future<void> _toggleListening() async {
    if (_parsing) return;
    if (!_speechReady) {
      setState(() => _error = 'Microphone is not available on this device.');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      _finishListening();
      return;
    }

    setState(() {
      _isListening = true;
      _error = null;
      _lastSpeechText = '';
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _lastSpeechText = result.recognizedWords.trim();
        _controller.text = _lastSpeechText;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        if (result.finalResult) _finishListening();
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      cancelOnError: true,
    );
  }

  void _finishListening() {
    if (!mounted || !_isListening) return;
    setState(() => _isListening = false);
    if (_lastSpeechText.isEmpty && _controller.text.trim().isEmpty) {
      setState(() => _error = 'Nothing heard. Please try again.');
    }
  }

  Future<void> _submit() async {
    final command = _controller.text.trim();
    if (command.isEmpty || _parsing) return;

    setState(() {
      _parsing = true;
      _error = null;
    });

    final intent = await SmartRideService.parseRideIntent(command);
    if (!mounted) return;

    if (intent == null || !intent.canContinueBooking) {
      setState(() {
        _parsing = false;
        _error = intent?.reply.isNotEmpty == true
            ? intent!.reply
            : 'Tell me where you want to go, like "Book me a ride to Gaisano".';
      });
      return;
    }

    Navigator.of(context).pop(intent);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.82;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.backgroundDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Ride',
                              style: GoogleFonts.poppins(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.backgroundDark,
                              ),
                            ),
                            Text(
                              'Tell TodaGo where you want to go',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.backgroundDark,
                              ),
                              decoration: InputDecoration(
                                hintText: _isListening
                                    ? 'Listening...'
                                    : 'Example: Book me a ride to Gaisano from my current location',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _isListening
                                      ? AppColors.error.withOpacity(0.7)
                                      : AppColors.textHint,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  8,
                                  14,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 6, 8, 8),
                            child: GestureDetector(
                              onTap: _toggleListening,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _isListening
                                      ? AppColors.error
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isListening
                                        ? AppColors.error
                                        : const Color(0xFFE0E0E0),
                                  ),
                                ),
                                child: Icon(
                                  _isListening
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  color: _isListening
                                      ? Colors.white
                                      : AppColors.backgroundDark,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(
                        _isListening
                            ? Icons.graphic_eq_rounded
                            : Icons.keyboard_voice_rounded,
                        size: 14,
                        color:
                            _isListening ? AppColors.error : AppColors.textHint,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _isListening
                              ? 'Listening for your ride request'
                              : 'Tap the microphone to speak your request',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _isListening
                                ? AppColors.error
                                : AppColors.textHint,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ]),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _parsing ? null : _submit,
                        icon: _parsing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.directions_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          _parsing ? 'Understanding...' : 'Plan Smart Ride',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.backgroundDark,
                          disabledBackgroundColor:
                              AppColors.backgroundDark.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
