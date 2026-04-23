import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class OperatorFleetMapScreen extends StatefulWidget {
  const OperatorFleetMapScreen({super.key});
  @override
  State<OperatorFleetMapScreen> createState() => _OperatorFleetMapScreenState();
}

class _OperatorFleetMapScreenState extends State<OperatorFleetMapScreen> {
  bool _showList = false;

  // Simulated driver positions around Davao/Panabo area
  final List<Map<String, dynamic>> _drivers = [
    {'lat': 7.1907, 'lng': 125.4553, 'status': 'active', 'id': 'TODA #001', 'name': 'Juan Reyes'},
    {'lat': 7.1940, 'lng': 125.4580, 'status': 'active', 'id': 'TODA #002', 'name': 'Maria Cruz'},
    {'lat': 7.1880, 'lng': 125.4510, 'status': 'active', 'id': 'TODA #003', 'name': 'Pedro Lopez'},
    {'lat': 7.1960, 'lng': 125.4490, 'status': 'offline', 'id': 'TODA #004', 'name': 'Jose Santos'},
    {'lat': 7.1850, 'lng': 125.4600, 'status': 'active', 'id': 'TODA #005', 'name': 'Ana Gomez'},
    {'lat': 7.1920, 'lng': 125.4530, 'status': 'offline', 'id': 'TODA #006', 'name': 'Carlo Ramos'},
    {'lat': 7.1870, 'lng': 125.4570, 'status': 'active', 'id': 'TODA #007', 'name': 'Lena Torres'},
    {'lat': 7.1930, 'lng': 125.4620, 'status': 'active', 'id': 'TODA #008', 'name': 'Ben Villanueva'},
    {'lat': 7.1900, 'lng': 125.4480, 'status': 'active', 'id': 'TODA #009', 'name': 'Rose Dela Cruz'},
    {'lat': 7.1950, 'lng': 125.4550, 'status': 'offline', 'id': 'TODA #010', 'name': 'Mark Fernandez'},
  ];

  int get _activeCount => _drivers.where((d) => d['status'] == 'active').length;
  int get _offlineCount => _drivers.where((d) => d['status'] == 'offline').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(7.1907, 125.4553),
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.todago.app',
              ),
              MarkerLayer(
                markers: _drivers.map((d) => Marker(
                  point: LatLng(d['lat'] as double, d['lng'] as double),
                  width: 32, height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: d['status'] == 'active'
                          ? AppColors.primary
                          : Colors.grey[400],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(
                        color: (d['status'] == 'active'
                            ? AppColors.primary : Colors.grey).withOpacity(0.4),
                        blurRadius: 6,
                      )],
                    ),
                    child: Icon(
                      Icons.electric_rickshaw_rounded,
                      size: 14,
                      color: d['status'] == 'active'
                          ? AppColors.backgroundDark : Colors.white,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.12), blurRadius: 10,
                        )],
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: AppColors.backgroundDark, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 10,
                      )],
                    ),
                    child: Text('Live Fleet Map', style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.backgroundDark,
                    )),
                  ),
                  const Spacer(),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.12), blurRadius: 10,
                      )],
                    ),
                    child: const Icon(Icons.filter_list_rounded,
                        color: AppColors.backgroundDark, size: 20),
                  ),
                ]).animate().fadeIn(duration: 400.ms),
              ),
            ),
          ),

          // ── Stats bar ─────────────────────────────────────────────────────
          Positioned(
            top: 80, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 3),
                )],
              ),
              child: Row(children: [
                _statDot(AppColors.primary, 'Active', _activeCount),
                const SizedBox(width: 4),
                Container(width: 1, height: 30, color: const Color(0xFFEEEEEE)),
                const SizedBox(width: 4),
                _statDot(Colors.grey, 'Offline', _offlineCount),
              ]),
            ).animate().fadeIn(delay: 100.ms),
          ),

          // ── Bottom show list button ───────────────────────────────────────
          Positioned(
            bottom: 24, left: 0, right: 0,
            child: Column(
              children: [
                if (_showList) _buildDriverList(),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _showList = !_showList),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.2), blurRadius: 12,
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.list_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('${_showList ? "Hide" : "Show"} List (${_drivers.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                          )),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDot(Color color, String label, int count) => Expanded(
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
        Text('$count', style: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.backgroundDark,
        )),
      ]),
    ]),
  );

  Widget _buildDriverList() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    constraints: const BoxConstraints(maxHeight: 250),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4),
      )],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _drivers.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF5F5F5)),
        itemBuilder: (_, i) {
          final d = _drivers[i];
          final isActive = d['status'] == 'active';
          return ListTile(
            dense: true,
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.electric_rickshaw_rounded,
                size: 18, color: isActive ? AppColors.primary : Colors.grey),
            ),
            title: Text(d['name'] as String, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.backgroundDark,
            )),
            subtitle: Text(d['id'] as String, style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.textHint,
            )),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(isActive ? 'Active' : 'Offline',
                  style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: isActive ? Colors.green : Colors.grey,
                  )),
            ),
          );
        },
      ),
    ),
  );
}