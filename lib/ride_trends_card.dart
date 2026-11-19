import 'dart:async';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'trip_analytics_chart.dart';

typedef RideTrendsLoader = Future<List<Map<String, dynamic>>?> Function(
    String period, int days);

/// Shared across admin, operator and driver analytics, with the caller's scope.
class RideTrendsCard extends StatefulWidget {
  final RideTrendsLoader load;
  final bool dark;
  final String scope;

  const RideTrendsCard(
      {super.key, required this.load, this.dark = false, required this.scope});

  @override
  State<RideTrendsCard> createState() => _RideTrendsCardState();
}

class _RideTrendsCardState extends State<RideTrendsCard> {
  String _period = 'hour';
  List<Map<String, dynamic>>? _data;
  bool _loading = true;
  bool _failed = false;
  int _request = 0;
  Timer? _timer;

  int get _days => switch (_period) { 'week' => 84, 'month' => 365, _ => 30 };
  String get _range => switch (_period) {
        'week' => 'Last 12 calendar weeks',
        'month' => 'Last 12 calendar months',
        _ => 'Last 30 days',
      };

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_loading) _reload();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ++_request;
    setState(() => _loading = true);
    List<Map<String, dynamic>>? data;
    try {
      data = await widget.load(_period, _days);
    } catch (_) {/* Retry in UI. */}
    if (!mounted || request != _request) return;
    setState(() {
      _loading = false;
      _failed = data == null;
      if (data != null) _data = data;
    });
  }

  String _peak(String key) {
    final rows = _data ?? [];
    int count(Map<String, dynamic> row) => int.tryParse('${row[key]}') ?? 0;
    var max = 0;
    for (final row in rows) {
      if (count(row) > max) max = count(row);
    }
    if (max == 0) {
      return 'No ${key == 'completed_trips' ? 'completed' : 'cancelled'} rides';
    }
    final winners = rows.where((row) => count(row) == max).toList();
    final label =
        winners.first[_period == 'hour' ? 'hour_label' : 'period_label'];
    return '$label · $max ride${max == 1 ? '' : 's'}${winners.length > 1 ? ' (${winners.length} tied)' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.dark ? Colors.white : AppColors.backgroundDark;
    final hint =
        widget.dark ? const Color(0xFFBDC9DD) : const Color(0xFF526879);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.dark ? 0 : 16),
      decoration: BoxDecoration(
        color: widget.dark ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: widget.dark ? null : Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.access_time_filled_rounded,
              color: Colors.orange, size: 22),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Peak Hour Analysis',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 15))),
          IconButton(
              onPressed: _loading ? null : _reload,
              tooltip: 'Refresh ride analysis',
              color: color,
              icon: const Icon(Icons.refresh, size: 20)),
        ]),
        Text('${widget.scope} · Completed and cancelled rides',
            style: TextStyle(color: hint, fontSize: 11)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final period in const {
            'hour': 'Hour',
            'day': 'Day',
            'week': 'Week',
            'month': 'Month'
          }.entries)
            ChoiceChip(
                label: Text(period.value),
                selected: _period == period.key,
                selectedColor: const Color(0xFFFFD65A),
                backgroundColor: widget.dark
                    ? const Color(0xFF303048)
                    : const Color(0xFFF2F6FA),
                labelStyle: TextStyle(
                    color: _period == period.key
                        ? AppColors.backgroundDark
                        : color),
                onSelected: (_) {
                  if (_period == period.key) return;
                  setState(() {
                    _period = period.key;
                    _data = null;
                    _failed = false;
                  });
                  _reload();
                }),
        ]),
        const SizedBox(height: 8),
        Text('$_range · Booking date · Philippine time',
            style: TextStyle(color: hint, fontSize: 11)),
        if (_period == 'week' || _period == 'month')
          Text(
              'Current ${_period == 'week' ? 'week' : 'month'} is still in progress.',
              style: TextStyle(color: hint, fontSize: 11)),
        const SizedBox(height: 12),
        if (_loading && _data == null)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator()))
        else if (_failed)
          Text(
              _data == null
                  ? 'Unable to load ride analysis. Tap refresh to retry.'
                  : 'Unable to refresh. Showing the last available data.',
              style: TextStyle(color: hint, fontSize: 12)),
        if (_data != null) ...[
          Text('Most completed: ${_peak('completed_trips')}',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Most cancelled: ${_peak('cancelled_trips')}',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TripAnalyticsChart(
              key: ValueKey(_period),
              data: _data!,
              peakHours: true,
              period: _period,
              dark: widget.dark),
        ],
      ]),
    );
  }
}
