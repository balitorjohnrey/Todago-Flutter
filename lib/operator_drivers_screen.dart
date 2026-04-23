import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class OperatorDriversScreen extends StatefulWidget {
  const OperatorDriversScreen({super.key});
  @override
  State<OperatorDriversScreen> createState() => _OperatorDriversScreenState();
}

class _OperatorDriversScreenState extends State<OperatorDriversScreen> {
  int _filterTab = 0; // 0=All, 1=Active, 2=Offline, 3=New
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _drivers = List.generate(12, (i) => {
    'toda': 'Davao #${(i + 1).toString().padLeft(3, '0')}',
    'name': 'Driver ${i + 1}',
    'rating': (3.5 + (i % 5) * 0.3).clamp(3.5, 5.0),
    'trips': [506, 82, 205, 411, 61, 548, 320, 164, 291, 68, 402, 130][i],
    'acceptance': [88, 83, 79, 99, 70, 34, 91, 91, 83, 79, 85, 72][i],
    'status': i % 3 == 2 ? 'offline' : 'active',
    'isNew': i >= 10,
  });

  List<Map<String, dynamic>> get _filtered {
    var list = _drivers;
    if (_filterTab == 1) list = list.where((d) => d['status'] == 'active').toList();
    if (_filterTab == 2) list = list.where((d) => d['status'] == 'offline').toList();
    if (_filterTab == 3) list = list.where((d) => d['isNew'] == true).toList();
    if (_searchQuery.isNotEmpty) {
      list = list.where((d) =>
        (d['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (d['toda'] as String).toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    return list;
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
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
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Driver Management', style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                  )),
                ]),
                const SizedBox(height: 14),
                // Search
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
                      hintText: 'Search TODA number or name...',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.white38),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Filter tabs ──────────────────────────────────────────────────────
        Container(
          color: AppColors.backgroundDark,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(children: [
              _filterTab2('All (${_drivers.length})', 0),
              const SizedBox(width: 8),
              _filterTab2('Active (${_drivers.where((d) => d['status'] == 'active').length})', 1),
              const SizedBox(width: 8),
              _filterTab2('Offline (${_drivers.where((d) => d['status'] == 'offline').length})', 2),
              const SizedBox(width: 8),
              _filterTab2('New', 3),
            ]),
          ),
        ),

        // ── Column headers ────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            SizedBox(width: 80, child: Text('TODA', style: _headerStyle())),
            SizedBox(width: 80, child: Text('DRIVER', style: _headerStyle())),
            SizedBox(width: 60, child: Text('RATING', style: _headerStyle())),
            SizedBox(width: 55, child: Text('TRIPS', style: _headerStyle())),
            Expanded(child: Text('%', style: _headerStyle())),
          ]),
        ),

        // ── Driver list ───────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final d = _filtered[i];
              final isActive = d['status'] == 'active';
              return Container(
                color: i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(children: [
                  // TODA badge
                  SizedBox(
                    width: 80,
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(d['toda'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textHint,
                          ))),
                    ]),
                  ),
                  // Name
                  SizedBox(
                    width: 80,
                    child: Text(d['name'] as String, style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.backgroundDark,
                    )),
                  ),
                  // Rating
                  SizedBox(
                    width: 60,
                    child: Row(children: [
                      const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text((d['rating'] as double).toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.backgroundDark,
                          )),
                    ]),
                  ),
                  // Trips
                  SizedBox(
                    width: 55,
                    child: Text('${d['trips']}', style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.backgroundDark,
                    )),
                  ),
                  // Acceptance %
                  Expanded(
                    child: Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (d['acceptance'] as int) / 100,
                            backgroundColor: const Color(0xFFEEEEEE),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              (d['acceptance'] as int) >= 80
                                  ? Colors.green
                                  : (d['acceptance'] as int) >= 60
                                      ? AppColors.primary
                                      : AppColors.error,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${d['acceptance']}%', style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: (d['acceptance'] as int) >= 80
                            ? Colors.green : AppColors.textHint,
                      )),
                    ]),
                  ),
                ]).animate().fadeIn(delay: Duration(milliseconds: 30 * i), duration: 300.ms),
              );
            },
          ),
        ),

        // ── Footer ────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(children: [
            Text('Showing ${_filtered.length} drivers',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
            const Spacer(),
            _footerBadge('${_drivers.where((d) => d['status'] == 'active').length} Active', Colors.green),
            const SizedBox(width: 8),
            _footerBadge('${_drivers.where((d) => d['status'] == 'offline').length} Offline', Colors.grey),
          ]),
        ),
      ]),
    );
  }

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
        child: Text(label, style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: sel ? AppColors.backgroundDark : Colors.white60,
        )),
      ),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.poppins(
    fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.5,
  );

  Widget _footerBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label, style: GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w700, color: color,
    )),
  );
}