import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

class _TripBar {
  final String label;
  final int completed;
  final int cancelled;
  final int other;

  int get total => completed + cancelled + other;

  _TripBar(Map<String, dynamic> data, {required bool peakHours})
      : label = peakHours
            ? (data['hour_label']?.toString() ?? 'Hour')
            : '${data['route_from'] ?? 'Pickup'} → '
                '${data['route_to'] ?? 'Destination'}',
        completed = _count(data['completed_trips']),
        cancelled = _count(data['cancelled_trips']),
        other = math.max(
          0,
          _count(data[peakHours ? 'total_requests' : 'total_trips']) -
              _count(data['completed_trips']) -
              _count(data['cancelled_trips']),
        );

  static int _count(dynamic value) =>
      math.max(0, num.tryParse(value?.toString() ?? '')?.toInt() ?? 0);
}

/// Stacked counts share one zero-based scale so bar lengths are comparable.
class TripAnalyticsChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool peakHours;
  final bool dark;

  const TripAnalyticsChart({
    super.key,
    required this.data,
    this.peakHours = false,
    this.dark = false,
  });

  static const _completedColor = Color(0xFF278752);
  static const _cancelledColor = Color(0xFFCF4A46);
  static const _otherColor = Color(0xFF307CC0);

  @override
  Widget build(BuildContext context) {
    final bars =
        data.map((row) => _TripBar(row, peakHours: peakHours)).toList();
    final maximum = bars.fold<int>(0, (max, bar) => math.max(max, bar.total));
    final textColor = dark ? Colors.white : AppColors.backgroundDark;
    final hintColor = dark ? Colors.white70 : const Color(0xFF607681);
    if (maximum == 0) {
      return Text('No ${peakHours ? 'request' : 'trip'} data to chart yet',
          style: TextStyle(fontSize: 12, color: hintColor));
    }
    final hasOther = bars.any((bar) => bar.other > 0);

    Widget legend(String label, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, color: hintColor)),
          ],
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(peakHours ? 'Requests by hour' : 'Trips by route',
          style: TextStyle(
              color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 6, children: [
        legend('Completed', _completedColor),
        legend('Cancelled', _cancelledColor),
        if (hasOther) legend('Other requests', _otherColor),
      ]),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.only(right: 38),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('0', style: TextStyle(fontSize: 10, color: hintColor)),
          Text('$maximum ${peakHours ? 'requests' : 'trips'}',
              style: TextStyle(fontSize: 10, color: hintColor)),
        ]),
      ),
      for (var i = 0; i < bars.length; i++) ...[
        const SizedBox(height: 8),
        Semantics(
          label: '${bars[i].label}: ${bars[i].total} total, '
              '${bars[i].completed} completed, ${bars[i].cancelled} cancelled'
              '${hasOther ? ', ${bars[i].other} other requests' : ''}',
          excludeSemantics: true,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bars[i].label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: textColor)),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 18,
                    child: Row(children: [
                      if (bars[i].completed > 0)
                        Expanded(
                            flex: bars[i].completed,
                            child: Container(color: _completedColor)),
                      if (bars[i].cancelled > 0)
                        Expanded(
                            flex: bars[i].cancelled,
                            child: Container(color: _cancelledColor)),
                      if (bars[i].other > 0)
                        Expanded(
                            flex: bars[i].other,
                            child: Container(color: _otherColor)),
                      if (bars[i].total < maximum)
                        Expanded(
                            flex: maximum - bars[i].total,
                            child: Container(
                                color: dark
                                    ? Colors.white10
                                    : const Color(0xFFEDF1F5))),
                    ]),
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text('${bars[i].total}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
              ),
            ]),
          ]),
        ),
      ],
    ]);
  }
}
