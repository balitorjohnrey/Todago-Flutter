import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'driver_auth_service.dart';
import 'profile_avatar.dart';
import 'profile_photo_service.dart';

class DriverProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialDriver;

  const DriverProfileScreen({super.key, this.initialDriver});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? _driver;
  String? _photoPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _driver = widget.initialDriver;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final results = await Future.wait([
      DriverAuthService.fetchProfile(),
      ProfilePhotoService.getPhotoPath(ProfilePhotoService.driverPhotoKey),
    ]);
    if (!mounted) return;
    setState(() {
      _driver = (results[0] as Map<String, dynamic>?) ?? _driver;
      _photoPath = results[1] as String?;
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final path = await ProfilePhotoService.pickAndSavePhoto(
      ProfilePhotoService.driverPhotoKey,
    );
    if (path == null || !mounted) return;
    setState(() => _photoPath = path);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Profile photo updated',
          style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String get _name => _driver?['driver_name']?.toString() ?? 'Driver';
  String get _initials => _name
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();

  double get _rating => _asDouble(_driver?['avg_rating']);
  int get _totalTrips => _asInt(_driver?['total_trips']);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: _loading && _driver == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(children: [
                  Row(children: [
                    _roundIcon(Icons.arrow_back_ios_new_rounded, () {
                      Navigator.of(context).pop();
                    }),
                    const Spacer(),
                    Text('Driver Profile',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.backgroundDark)),
                    const Spacer(),
                    _roundIcon(Icons.refresh_rounded, _loadProfile),
                  ]),
                  const SizedBox(height: 18),
                  _headerCard(),
                  const SizedBox(height: 14),
                  Row(children: [
                    _statTile(
                        'Rating',
                        _rating > 0 ? _rating.toStringAsFixed(1) : 'New',
                        Icons.star_rounded),
                    const SizedBox(width: 10),
                    _statTile('Trips', '$_totalTrips', Icons.route_rounded),
                    const SizedBox(width: 10),
                    _statTile('Status', _driver?['status']?.toString() ?? '-',
                        Icons.radio_button_checked_rounded),
                  ]),
                  const SizedBox(height: 14),
                  _ratingsCard(),
                  const SizedBox(height: 14),
                  _detailsCard(),
                  const SizedBox(height: 14),
                  _coachCard(),
                ]),
              ),
      ),
    );
  }

  Widget _headerCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(children: [
          ProfileAvatar(
            initials: _initials,
            imagePath: _photoPath,
            size: 104,
            onTap: _pickPhoto,
          ),
          const SizedBox(height: 14),
          Text(_name,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(_driver?['toda_body_number']?.toString() ?? 'TODA Driver',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                  Icons.verified_rounded,
                  _driver?['is_verified'] == true ? 'Verified' : 'Pending',
                  AppColors.primary),
              _chip(
                  Icons.electric_rickshaw_rounded,
                  _driver?['plate_no']?.toString() ??
                      _driver?['tricycle_plate']?.toString() ??
                      'Vehicle linked',
                  AppColors.success),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: Text('Upload Profile Picture',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.backgroundDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      );

  Widget _ratingsCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ratings',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark)),
          const SizedBox(height: 4),
          Text('Based on passenger feedback after completed trips',
              style:
                  GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 14),
          ...List.generate(5, (index) {
            final stars = 5 - index;
            final value = _rating <= 0
                ? 0.0
                : ((_rating - (stars - 1)).clamp(0.0, 1.0) *
                    (stars == 5 ? 0.95 : 0.55));
            return _ratingBar(stars, value);
          }),
        ]),
      );

  Widget _detailsCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Profile Details',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.backgroundDark)),
          const SizedBox(height: 12),
          _detailTile(Icons.phone_rounded, 'Phone',
              _driver?['phone']?.toString() ?? '-'),
          _detailTile(Icons.email_rounded, 'Email',
              _driver?['email']?.toString() ?? '-'),
          _detailTile(Icons.badge_rounded, 'License',
              _driver?['license_no']?.toString() ?? '-'),
          _detailTile(Icons.confirmation_number_rounded, 'Body Number',
              _driver?['toda_body_number']?.toString() ?? '-'),
          _detailTile(
              Icons.local_taxi_rounded,
              'Plate Number',
              _driver?['plate_no']?.toString() ??
                  _driver?['tricycle_plate']?.toString() ??
                  '-'),
          _detailTile(Icons.palette_rounded, 'Vehicle Color',
              _driver?['vehicle_color']?.toString() ?? '-'),
        ]),
      );

  Widget _coachCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_graph_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Driver Growth',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark)),
          ]),
          const SizedBox(height: 12),
          _growthItem('Keep pickup ETA accurate', 'Improves acceptance trust'),
          _growthItem('Confirm passenger name', 'Reduces wrong-pickup risk'),
          _growthItem('Ask for rating politely', 'Helps build profile quality'),
        ]),
      );

  Widget _roundIcon(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(icon, color: AppColors.backgroundDark, size: 18),
        ),
      );

  Widget _statTile(String label, String value, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: _cardDecoration(),
          child: Column(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundDark)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint)),
          ]),
        ),
      );

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _ratingBar(int stars, double value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
            width: 42,
            child: Text('$stars star',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textHint)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 8,
                color: AppColors.primary,
                backgroundColor: const Color(0xFFE8EDF2),
              ),
            ),
          ),
        ]),
      );

  Widget _detailTile(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.backgroundDark, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint)),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.backgroundDark)),
              ],
            ),
          ),
        ]),
      );

  Widget _growthItem(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.backgroundDark)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
        ]),
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF1F4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      );

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
