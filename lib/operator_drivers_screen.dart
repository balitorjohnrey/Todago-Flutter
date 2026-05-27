import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'operator_auth_service.dart';

class OperatorDriversScreen extends StatefulWidget {
  const OperatorDriversScreen({super.key});
  @override
  State<OperatorDriversScreen> createState() => _OperatorDriversScreenState();
}

class _OperatorDriversScreenState extends State<OperatorDriversScreen> {
  int _filterTab = 0; // 0=All, 1=Pending, 2=Active, 3=Offline
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final drivers = await OperatorAuthService.fetchDrivers();
      if (!mounted) return;
      setState(() => _drivers = drivers);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to load TODA drivers.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setApproval(Map<String, dynamic> driver, bool approve) async {
    final driverId = driver['driver_id']?.toString();
    if (driverId == null || driverId.isEmpty) return;

    final result = await OperatorAuthService.updateDriverVerification(
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

    if (result.success) await _loadDrivers();
  }

  bool _isVerified(Map<String, dynamic> driver) =>
      driver['is_verified'] == true ||
      driver['is_verified']?.toString() == 'true';

  bool _isActive(Map<String, dynamic> driver) {
    final status = driver['status']?.toString().toLowerCase();
    return status == 'online' || status == 'on_trip';
  }

  int get _pendingCount => _drivers.where((d) => !_isVerified(d)).length;
  int get _activeCount =>
      _drivers.where((d) => _isVerified(d) && _isActive(d)).length;
  int get _offlineCount => _drivers.where((d) {
        final status = d['status']?.toString().toLowerCase();
        return _isVerified(d) && (status == null || status == 'offline');
      }).length;

  List<Map<String, dynamic>> get _filtered {
    var list = _drivers;
    if (_filterTab == 1) {
      list = list.where((d) => !_isVerified(d)).toList();
    } else if (_filterTab == 2) {
      list = list.where((d) => _isVerified(d) && _isActive(d)).toList();
    } else if (_filterTab == 3) {
      list = list.where((d) {
        final status = d['status']?.toString().toLowerCase();
        return _isVerified(d) && (status == null || status == 'offline');
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((d) {
        final haystack = [
          d['driver_name'],
          d['toda_body_number'],
          d['plate_no'],
          d['license_no'],
          d['phone'],
        ].whereType<Object>().map((v) => v.toString().toLowerCase()).join(' ');
        return haystack.contains(query);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(children: [
        _buildHeader(),
        _buildFilters(),
        Expanded(child: _buildBody()),
        _buildFooter(),
      ]),
    );
  }

  Widget _buildHeader() => Container(
        color: AppColors.backgroundDark,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(children: [
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Driver Management',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      )),
                ),
                IconButton(
                  onPressed: _isLoading ? null : _loadDrivers,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Refresh',
                ),
              ]),
              const SizedBox(height: 14),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search driver, body number, plate, license...',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.white38),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.white38, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _buildFilters() => Container(
        color: AppColors.backgroundDark,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(children: [
            _filterTab2('All (${_drivers.length})', 0),
            const SizedBox(width: 8),
            _filterTab2('Pending ($_pendingCount)', 1),
            const SizedBox(width: 8),
            _filterTab2('Active ($_activeCount)', 2),
            const SizedBox(width: 8),
            _filterTab2('Offline ($_offlineCount)', 3),
          ]),
        ),
      );

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 34),
            const SizedBox(height: 10),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textHint)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDrivers,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Text('No drivers found',
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDrivers,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _driverRow(_filtered[i], i),
      ),
    );
  }

  Widget _driverRow(Map<String, dynamic> driver, int index) {
    final verified = _isVerified(driver);
    final active = _isActive(driver);
    final statusText = verified
        ? (active ? driver['status']?.toString() ?? 'active' : 'offline')
        : 'pending';
    final statusColor = verified
        ? (active ? AppColors.success : Colors.grey)
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(driver['driver_name']?.toString() ?? 'Driver',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.backgroundDark,
                )),
            const SizedBox(height: 4),
            Text(
              '${driver['toda_body_number'] ?? '-'} - ${driver['plate_no'] ?? '-'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint),
            ),
            const SizedBox(height: 4),
            Text(
              'License ${driver['license_no'] ?? '-'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _statusPill(statusText, statusColor),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: verified
                ? OutlinedButton(
                    onPressed: () => _setApproval(driver, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text('Revoke',
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _setApproval(driver, true),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text('Approve',
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      elevation: 0,
                    ),
                  ),
          ),
        ]),
      ])
          .animate()
          .fadeIn(delay: Duration(milliseconds: 25 * index), duration: 250.ms),
    );
  }

  Widget _statusPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            )),
      );

  Widget _buildFooter() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(children: [
          Text('Showing ${_filtered.length} drivers',
              style:
                  GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          _footerBadge('$_pendingCount Pending', AppColors.primary),
          const SizedBox(width: 8),
          _footerBadge('$_activeCount Active', AppColors.success),
        ]),
      );

  Widget _filterTab2(String label, int idx) {
    final sel = _filterTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _filterTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: sel ? AppColors.backgroundDark : Colors.white60,
            )),
      ),
    );
  }

  Widget _footerBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            )),
      );
}
