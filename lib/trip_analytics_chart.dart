import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

typedef _TripBucket = ({String label, int completed, int cancelled, int other});

enum _TripStatus {
  completed('Completed', Color(0xFF007BC2), Color(0xFF66C5FF)),
  cancelled('Cancelled', Color(0xFFCF443D), Color(0xFFFF8078)),
  other('Other requests', Color(0xFFB77500), AppColors.primary);

  const _TripStatus(this.label, this.lightColor, this.darkColor);

  final String label;
  final Color lightColor;
  final Color darkColor;

  Color color(bool dark) => dark ? darkColor : lightColor;

  int count(_TripBucket bucket) => switch (this) {
        completed => bucket.completed,
        cancelled => bucket.cancelled,
        other => bucket.other,
      };
}

int _total(_TripBucket bucket) =>
    bucket.completed + bucket.cancelled + bucket.other;

int _count(Object? value) {
  final number = num.tryParse(value?.toString() ?? '');
  return number != null && number.isFinite ? math.max(0, number.toInt()) : 0;
}

String _clockLabel(int hour) {
  final clockHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$clockHour ${hour < 12 ? 'AM' : 'PM'}';
}

final _hourStart = RegExp(r'^(1[0-2]|[1-9])\s*([AP]M)\b', caseSensitive: false);

int? _hourOfDay(Map<String, dynamic> row) {
  final hour = int.tryParse('${row['hour_of_day']}');
  if (hour != null && hour >= 0 && hour < 24) return hour;
  final match = _hourStart.firstMatch('${row['hour_label']}');
  if (match == null) return null;
  return int.parse(match[1]!) % 12 + (match[2]!.toUpperCase() == 'PM' ? 12 : 0);
}

_TripBucket _bucket(Map<String, dynamic> row, String label, String totalKey) {
  final completed = _count(row['completed_trips']);
  final cancelled = _count(row['cancelled_trips']);
  return (
    label: label,
    completed: completed,
    cancelled: cancelled,
    other: math.max(0, _count(row[totalKey]) - completed - cancelled),
  );
}

List<_TripBucket> _hourBuckets(List<Map<String, dynamic>> rows) {
  // The API returns only hours with requests, even when all 24 are requested.
  final byHour = <int, Map<String, dynamic>>{};
  for (final row in rows) {
    final hour = _hourOfDay(row);
    if (hour != null) byHour[hour] = row;
  }
  return List.generate(24, (hour) {
    final label = '${_clockLabel(hour)} – ${_clockLabel((hour + 1) % 24)}';
    return _bucket(byHour[hour] ?? const {}, label, 'total_requests');
  });
}

int _gridStep(int maximum) {
  final roughStep = math.max(1, maximum / 4);
  final unit = math.pow(10, (math.log(roughStep) / math.ln10).floor()).toInt();
  return [unit, unit * 2, (unit * 2.5).ceil(), unit * 5, unit * 10]
      .firstWhere((step) => step >= roughStep);
}

class TripAnalyticsChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final bool peakHours;
  final bool dark;

  const TripAnalyticsChart({
    super.key,
    required this.data,
    this.peakHours = false,
    this.dark = false,
  });

  @override
  State<TripAnalyticsChart> createState() => _TripAnalyticsChartState();
}

class _TripAnalyticsChartState extends State<TripAnalyticsChart> {
  String? _selectedLabel;

  @override
  Widget build(BuildContext context) {
    final hourly = widget.peakHours;
    final dark = widget.dark;
    final buckets = hourly
        ? _hourBuckets(widget.data)
        : [
            for (final row in widget.data)
              _bucket(
                  row,
                  '${row['route_from'] ?? 'Pickup'} to '
                      '${row['route_to'] ?? 'Destination'}',
                  'total_trips'),
          ];
    final textColor = dark ? Colors.white : AppColors.backgroundDark;
    final hintColor = dark ? const Color(0xFFBDC9DD) : const Color(0xFF526879);
    final hintStyle = DefaultTextStyle.of(context)
        .style
        .copyWith(color: hintColor, fontSize: 11);
    if (!buckets.any((bucket) => _total(bucket) > 0)) {
      return Text('No ${hourly ? 'request' : 'trip'} data to chart yet',
          style: hintStyle);
    }

    final series = [
      _TripStatus.completed,
      _TripStatus.cancelled,
      if (buckets.any((bucket) => bucket.other > 0)) _TripStatus.other,
    ];
    final averages = [
      for (final status in series)
        buckets.fold(0, (sum, bucket) => sum + status.count(bucket)) /
            buckets.length,
    ];
    final largestCount = series.fold(0, (largest, status) {
      return buckets.fold(
          largest, (max, bucket) => math.max(max, status.count(bucket)));
    });
    final step = _gridStep(largestCount);
    final tickCount = math.max(2, (largestCount / step).ceil());
    final formatCount = MaterialLocalizations.of(context).formatDecimal;
    final ticks = List.generate(tickCount + 1, (i) => formatCount(i * step));

    var selectedIndex =
        buckets.indexWhere((bucket) => bucket.label == _selectedLabel);
    if (selectedIndex == -1 && hourly) {
      final busiest = buckets.reduce((a, b) => _total(a) >= _total(b) ? a : b);
      selectedIndex = buckets.indexOf(busiest);
    }
    selectedIndex = math.max(0, selectedIndex);
    final selected = buckets[selectedIndex];
    final unit = hourly ? 'hour' : 'route';
    final total = _total(selected);
    final totalUnit = hourly ? 'request' : 'trip';
    final selectedTotal =
        '${formatCount(total)} $totalUnit${total == 1 ? '' : 's'}';
    final selectedCounts = [
      for (final status in series)
        '${formatCount(status.count(selected))} '
            '${status == _TripStatus.other && selected.other == 1 ? 'other request' : status.label.toLowerCase()}',
    ];
    final averageLabel = [
      for (var i = 0; i < series.length; i++)
        '${series[i].label} ${averages[i].toStringAsFixed(2)}',
    ].join(', ');

    void select(int index) {
      final label = buckets[index].label;
      if (label != (_selectedLabel ?? selected.label)) {
        setState(() => _selectedLabel = label);
      }
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final fontHeight = textScaler.scale(hintStyle.fontSize!);
    final plotHeight = MediaQuery.sizeOf(context).width >= 600 ? 190.0 : 144.0;
    final height = plotHeight + fontHeight * 2.6 + 8;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(hourly ? 'Requests by hour' : 'Trips by route',
          style: TextStyle(
              color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 6, children: [
        for (final status in series)
          _seriesLabel(status.label, status.color(dark), hintStyle),
      ]),
      const SizedBox(height: 10),
      SizedBox(
          height: height,
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final tickWidth = TextPainter.computeWidth(
              text: TextSpan(text: ticks.last, style: hintStyle),
              textDirection: TextDirection.ltr,
              textScaler: textScaler,
            );
            final averageWidth =
                math.min(width * 0.25, (width * 0.18).clamp(36.0, 76.0));
            final plotLeft =
                math.min(averageWidth + tickWidth + 18, width * 0.62);
            final plot = Rect.fromLTWH(
              plotLeft,
              fontHeight,
              math.max(0, width - plotLeft - 2),
              plotHeight,
            );

            void selectAt(double x) {
              if (plot.isEmpty) return;
              select((x / plot.width * buckets.length)
                  .floor()
                  .clamp(0, buckets.length - 1));
            }

            return Semantics(
              label: 'Average per $unit. $averageLabel.',
              child: Stack(fit: StackFit.expand, children: [
                CustomPaint(
                  painter: _TripChartPainter(
                    plot: plot,
                    averageWidth: averageWidth,
                    buckets: buckets,
                    series: series,
                    averages: averages,
                    ticks: ticks,
                    maximum: tickCount * step,
                    selectedIndex: selectedIndex,
                    hourly: hourly,
                    dark: dark,
                    axisStyle: hintStyle,
                    textScaler: textScaler,
                  ),
                ),
                Positioned(
                  left: plot.left,
                  right: width - plot.right,
                  top: plot.top,
                  bottom: 0,
                  child: MouseRegion(
                    onHover: (event) => selectAt(event.localPosition.dx),
                    child: GestureDetector(
                      key: const ValueKey('trip-analytics-plot'),
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTapUp: (event) => selectAt(event.localPosition.dx),
                      onHorizontalDragStart: (event) =>
                          selectAt(event.localPosition.dx),
                      onHorizontalDragUpdate: (event) =>
                          selectAt(event.localPosition.dx),
                    ),
                  ),
                ),
              ]),
            );
          })),
      Text(hourly ? 'Philippine time' : 'Routes ranked by completed trips',
          style: hintStyle),
      const SizedBox(height: 10),
      DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1D1D34) : const Color(0xFFF2F6FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 4, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label:
                      '${selected.label}, $selectedTotal, ${selectedCounts.join(', ')}',
                  excludeSemantics: true,
                  child: Text.rich(TextSpan(
                    style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    text: selected.label,
                    children: [
                      TextSpan(
                          text: ' · $selectedTotal',
                          style:
                              hintStyle.copyWith(fontWeight: FontWeight.w400))
                    ],
                  )),
                ),
              ),
              if (buckets.length > 1)
                for (final direction in [-1, 1])
                  IconButton(
                    icon: Icon(direction < 0
                        ? Icons.chevron_left
                        : Icons.chevron_right),
                    iconSize: 18,
                    color: textColor,
                    disabledColor: hintColor.withValues(alpha: 0.45),
                    tooltip: '${direction < 0 ? 'Previous' : 'Next'} $unit',
                    onPressed: selectedIndex + direction >= 0 &&
                            selectedIndex + direction < buckets.length
                        ? () => select(selectedIndex + direction)
                        : null,
                  ),
            ]),
            ExcludeSemantics(
              child: Wrap(spacing: 12, runSpacing: 6, children: [
                for (var i = 0; i < series.length; i++)
                  _seriesLabel(
                      selectedCounts[i], series[i].color(dark), hintStyle),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _seriesLabel(String label, Color color, TextStyle style) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 8),
          ),
          const SizedBox(width: 5),
          Flexible(child: Text(label, style: style)),
        ],
      );
}

class _TripChartPainter extends CustomPainter {
  const _TripChartPainter({
    required this.plot,
    required this.averageWidth,
    required this.buckets,
    required this.series,
    required this.averages,
    required this.ticks,
    required this.maximum,
    required this.selectedIndex,
    required this.hourly,
    required this.dark,
    required this.axisStyle,
    required this.textScaler,
  });

  final Rect plot;
  final double averageWidth;
  final List<_TripBucket> buckets;
  final List<_TripStatus> series;
  final List<double> averages;
  final List<String> ticks;
  final int maximum;
  final int selectedIndex;
  final bool hourly;
  final bool dark;
  final TextStyle axisStyle;
  final TextScaler textScaler;

  double _x(int index) =>
      plot.left + (index + 0.5) * plot.width / buckets.length;
  double _y(num count) => plot.bottom - plot.height * (count / maximum);

  @override
  void paint(Canvas canvas, Size size) {
    if (plot.isEmpty) return;

    final grid = Paint()
      ..color = dark ? const Color(0xFF40445E) : const Color(0xFFE1E8EE);
    final baseline = Paint()
      ..color = dark ? const Color(0xFF66708B) : const Color(0xFFB6C5D1);
    canvas.drawLine(
        Offset(0, plot.bottom), Offset(averageWidth, plot.bottom), baseline);
    for (var i = 0; i < ticks.length; i++) {
      final y = plot.bottom - i * plot.height / (ticks.length - 1);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y),
          i == 0 ? baseline : grid);
      _label(canvas, ticks[i], Offset(plot.left - 8, y),
          rightAligned: true,
          maxWidth: math.max(0, plot.left - averageWidth - 9));
    }
    final labelTop = plot.bottom + 7;
    _label(canvas, 'Average', Offset(averageWidth / 2, labelTop),
        topAligned: true, maxWidth: math.max(0, plot.left - 6));

    final highlight = Paint()
      ..color = dark ? const Color(0xFF333B59) : const Color(0xFFEAF3FB);
    final selectedX = _x(selectedIndex);
    if (hourly) {
      canvas.drawLine(Offset(selectedX, plot.top),
          Offset(selectedX, plot.bottom), baseline);
      _drawLines(canvas);
    } else {
      final halfBucket = plot.width / buckets.length / 2;
      final selectedArea = Rect.fromLTRB(selectedX - halfBucket, plot.top,
          selectedX + halfBucket, plot.bottom - 1);
      canvas.drawRRect(
          RRect.fromRectAndRadius(selectedArea, const Radius.circular(4)),
          highlight);
      for (var i = 0; i < buckets.length; i++) {
        _drawBars(canvas, _x(i), halfBucket * 2 - 6,
            [for (final status in series) status.count(buckets[i])]);
      }
    }

    _drawBars(canvas, averageWidth / 2, averageWidth - 8, averages);
    final labelScale =
        textScaler.scale(axisStyle.fontSize!) / axisStyle.fontSize!;
    final routeLabelStep =
        math.max(1, (26 * labelScale * buckets.length / plot.width).ceil());
    final labels = hourly
        ? switch (plot.width / labelScale) {
            >= 310 => [0, 4, 8, 12, 16, 20, 23],
            >= 190 => [0, 6, 12, 18],
            >= 125 => [0, 8, 16],
            _ => [0, 12],
          }
        : [for (var i = 0; i < buckets.length; i += routeLabelStep) i];
    for (final i in labels) {
      _label(canvas, hourly ? _clockLabel(i) : '#${i + 1}',
          Offset(_x(i), labelTop),
          topAligned: true,
          maxWidth: plot.width / labels.length,
          minX: plot.left,
          maxX: size.width);
    }
  }

  void _drawLines(Canvas canvas) {
    for (final status in series) {
      final color = status.color(dark);
      final path = Path()..moveTo(_x(0), _y(status.count(buckets.first)));
      for (var i = 1; i < buckets.length; i++) {
        path.lineTo(_x(i), _y(status.count(buckets[i])));
      }
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      if (status == _TripStatus.completed) {
        canvas.drawPath(path, paint);
      } else {
        final dash = status == _TripStatus.cancelled ? 5.0 : 2.0;
        for (final metric in path.computeMetrics()) {
          for (var start = 0.0; start < metric.length; start += dash + 4) {
            canvas.drawPath(
                metric.extractPath(
                    start, math.min(start + dash, metric.length)),
                paint);
          }
        }
      }
    }
    for (final status in series) {
      final count = status.count(buckets[selectedIndex]);
      if (count == 0) continue;
      final center = Offset(_x(selectedIndex), _y(count));
      final radius = 4.8 - status.index * 1.2;
      canvas.drawCircle(center, radius + 1,
          Paint()..color = dark ? AppColors.backgroundDark : Colors.white);
      canvas.drawCircle(center, radius, Paint()..color = status.color(dark));
    }
  }

  void _drawBars(
      Canvas canvas, double center, double availableWidth, List<num> counts) {
    final groupWidth = math.min(availableWidth, counts.length * 14.0);
    if (groupWidth <= 0) return;
    final slot = groupWidth / counts.length;
    final gap = math.min(1.5, slot / 4);
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] == 0) continue;
      final x = center - groupWidth / 2 + i * slot;
      final bar =
          Rect.fromLTRB(x + gap, _y(counts[i]), x + slot - gap, plot.bottom);
      canvas.drawRRect(
          RRect.fromRectAndCorners(bar,
              topLeft: const Radius.circular(2),
              topRight: const Radius.circular(2)),
          Paint()..color = series[i].color(dark));
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset position, {
    bool rightAligned = false,
    bool topAligned = false,
    double minX = 0,
    double maxX = double.infinity,
    double maxWidth = double.infinity,
  }) {
    final label = TextPainter(
      text: TextSpan(text: text, style: axisStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final x = position.dx - label.width * (rightAligned ? 1 : 0.5);
    label.paint(
        canvas,
        Offset(x.clamp(minX, math.max(minX, maxX - label.width)),
            position.dy - (topAligned ? 0 : label.height / 2)));
    label.dispose();
  }

  @override
  bool shouldRepaint(_TripChartPainter oldDelegate) =>
      plot != oldDelegate.plot ||
      averageWidth != oldDelegate.averageWidth ||
      selectedIndex != oldDelegate.selectedIndex ||
      hourly != oldDelegate.hourly ||
      dark != oldDelegate.dark ||
      axisStyle != oldDelegate.axisStyle ||
      textScaler != oldDelegate.textScaler ||
      !listEquals(ticks, oldDelegate.ticks) ||
      !listEquals(buckets, oldDelegate.buckets);
}
