import 'package:flutter/material.dart';

class ReportReviewDecision {
  final String? duration;
  final String notes;

  const ReportReviewDecision(this.duration, this.notes);
}

class ReportReviewDialog extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportReviewDialog({super.key, required this.report});

  @override
  State<ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends State<ReportReviewDialog> {
  static const _durations = {
    '1h': '1 hour',
    '3h': '3 hours',
    '5h': '5 hours',
    '12h': '12 hours',
    '24h': '24 hours',
    '1w': '1 week',
    'permanent': 'Permanent',
  };

  final _notes = TextEditingController();
  String? _duration;

  String? get _target {
    final reporter = widget.report['reporter_role'];
    final subject = widget.report['subject_role'];
    if (reporter == 'driver' && ['passenger', 'commuter'].contains(subject)) {
      return 'passenger';
    }
    if (['passenger', 'commuter'].contains(reporter) && subject == 'driver') {
      return 'driver';
    }
    return null;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final missingAccount = target != null &&
        (widget.report['subject_id']?.toString().isEmpty ?? true);
    final passenger = target == 'passenger';
    final canValidate =
        target == null || (!missingAccount && _duration != null);
    return AlertDialog(
      title: const Text('Validate report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.report['title']?.toString() ?? 'Reported incident'),
            if (widget.report['subject_name'] != null) ...[
              const SizedBox(height: 8),
              Text('Reported account: ${widget.report['subject_name']}'),
            ],
            const SizedBox(height: 12),
            Text(
                widget.report['details']?.toString() ?? 'No details provided.'),
            if (target != null) ...[
              const SizedBox(height: 20),
              Text(
                  passenger
                      ? 'Passenger booking restriction'
                      : 'Driver ride suspension',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Choose a duration.'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final duration in _durations.entries)
                    ChoiceChip(
                      label: Text(duration.value),
                      selected: _duration == duration.key,
                      onSelected: missingAccount
                          ? null
                          : (selected) => setState(
                              () => _duration = selected ? duration.key : null),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(passenger
                  ? 'The passenger will be blocked from booking new rides.'
                  : 'The driver will be hidden from available drivers and blocked from accepting new rides. They can still finish a trip they already accepted.'),
              if (_duration != null) ...[
                const SizedBox(height: 8),
                Text(_duration == 'permanent'
                    ? 'This restriction has no expiry.'
                    : 'This restriction expires automatically.'),
              ],
              if (missingAccount) ...[
                const SizedBox(height: 12),
                const Text(
                    'No account is linked. A report from the trip screen is needed to apply this penalty.'),
              ],
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                  'This report has no linked passenger or driver penalty. Validation will record the admin decision.'),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLength: 800,
              minLines: 2,
              maxLines: 4,
              decoration:
                  const InputDecoration(labelText: 'Admin notes (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: canValidate
              ? () => Navigator.of(context).pop(
                    ReportReviewDecision(_duration, _notes.text.trim()),
                  )
              : null,
          child: Text(
              target == null ? 'Validate report' : 'Validate & apply penalty'),
        ),
      ],
    );
  }
}
