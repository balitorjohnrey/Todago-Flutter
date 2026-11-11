import 'package:flutter/material.dart';
import 'app_theme.dart';

class DriverPerformanceCard extends StatelessWidget {
  final List<Map<String, dynamic>>? drivers;
  const DriverPerformanceCard({super.key, required this.drivers});

  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EDF2))),
        child: DefaultTextStyle(
          style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
              .copyWith(color: AppColors.backgroundDark, fontSize: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.star_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Top Rated Drivers',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16))),
            ]),
            const SizedBox(height: 6),
            const Text('Average passenger rating and completed trips',
                style: TextStyle(color: AppColors.textHint, fontSize: 11)),
            const SizedBox(height: 12),
            if (drivers == null)
              const Text(
                  'Unable to load driver performance. Refresh to try again.')
            else if (drivers!.isEmpty)
              const Text('No driver performance records yet.')
            else
              ...drivers!.asMap().entries.map((entry) {
                final driver = entry.value;
                final rating = _number(driver['avg_rating']);
                final count = _number(driver['rating_count']).toInt();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('${entry.key + 1}.',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  driver['driver_name']?.toString() ?? 'Driver',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          const SizedBox(width: 8),
                          Text(
                              count == 0
                                  ? 'Unrated'
                                  : '${rating.toStringAsFixed(2)} / 5',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 5),
                        Wrap(spacing: 12, runSpacing: 4, children: [
                          Text(
                              '${_number(driver['total_trips']).toInt()} completed trips'),
                          Text('$count ratings'),
                          if (driver['toda_body_number'] != null)
                            Text('Body ${driver['toda_body_number']}'),
                        ]),
                        if (driver['association_name'] != null) ...[
                          const SizedBox(height: 4),
                          Text(driver['association_name'].toString(),
                              style:
                                  const TextStyle(color: AppColors.textHint)),
                        ],
                      ]),
                );
              }),
          ]),
        ),
      );
}
