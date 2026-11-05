import 'package:flutter/material.dart';

class ReportReviewDecision {
  final String severity;
  final String notes;

  const ReportReviewDecision(this.severity, this.notes);
}

class ReportReviewDialog extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportReviewDialog({super.key, required this.report});

  @override
  State<ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends State<ReportReviewDialog> {
  final _notes = TextEditingController();
  String _severity = 'standard';

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
                      ? 'Passenger booking cooldown'
                      : 'Driver ride suspension',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Choose the duration based on the incident severity.'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(
                        passenger ? 'Standard: 30 minutes' : 'Standard: 1 day'),
                    selected: _severity == 'standard',
                    onSelected: (_) => setState(() => _severity = 'standard'),
                  ),
                  ChoiceChip(
                    label:
                        Text(passenger ? 'Severe: 1 hour' : 'Severe: 2 days'),
                    selected: _severity == 'severe',
                    onSelected: (_) => setState(() => _severity = 'severe'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(passenger
                  ? 'All new ride bookings will be blocked from validation until the cooldown expires automatically.'
                  : 'The driver will be hidden from available drivers and cannot accept new rides until the suspension expires automatically. An already accepted trip can still be finished.'),
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
          onPressed: missingAccount
              ? null
              : () => Navigator.of(context).pop(
                    ReportReviewDecision(_severity, _notes.text.trim()),
                  ),
          child: Text(
              target == null ? 'Validate report' : 'Validate & apply penalty'),
        ),
      ],
    );
  }
}
