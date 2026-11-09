import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'report_issue_dialog.dart';
import 'trip_service.dart';

class RatePassengerScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final double? earnings;

  const RatePassengerScreen({super.key, required this.trip, this.earnings});

  @override
  State<RatePassengerScreen> createState() => _RatePassengerScreenState();
}

class _RatePassengerScreenState extends State<RatePassengerScreen> {
  final _comment = TextEditingController();
  int _stars = 0;
  bool _loading = true;
  bool _saving = false;
  bool _submitted = false;
  bool _ratingLoaded = false;
  String? _error;

  String get _tripId => widget.trip['trip_id'].toString();
  String get _name => widget.trip['commuter_name']?.toString() ?? 'Passenger';

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  Future<void> _loadRating() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await TripService.getTripRating(_tripId, forDriver: true);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _ratingLoaded = true;
        _submitted = result['hasRated'] == true;
        _stars = int.tryParse(
                result['feedback']?['rating_score']?.toString() ?? '') ??
            0;
        _comment.text = result['feedback']?['comments']?.toString() ?? '';
      } else {
        _error = result['message']?.toString() ?? 'Unable to load your rating.';
      }
    });
  }

  Future<void> _submit() async {
    if (_saving || _stars == 0 || _submitted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await TripService.submitRating(
      tripId: _tripId,
      rating: _stars,
      comment: _comment.text,
      forDriver: true,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _submitted = result['success'] == true;
      if (!_submitted) {
        _error = result['message']?.toString() ?? 'Unable to submit rating.';
      }
    });
    if (!_submitted && (_error?.contains('already') ?? false)) {
      await _loadRating();
    }
  }

  void _report() => showReportIssueDialog(
        context: context,
        reporterRole: 'driver',
        initialType: 'passenger_issue',
        tripId: _tripId,
        subjectRole: 'passenger',
        subjectId: widget.trip['commuter_id']?.toString(),
        subjectName: _name,
      );

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canRate = !_loading && _ratingLoaded && !_submitted && !_saving;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Trip Completed')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 64),
              const SizedBox(height: 16),
              Text('Payment collected',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(widget.trip['destination']?.toString() ?? 'Destination',
                  textAlign: TextAlign.center),
              if (widget.earnings != null) ...[
                const SizedBox(height: 12),
                Text('Your earnings: ₱${widget.earnings!.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
              const SizedBox(height: 28),
              Text('Rate Passenger',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  children: List.generate(
                      5,
                      (i) => IconButton(
                            tooltip: '${i + 1} star${i == 0 ? '' : 's'}',
                            onPressed: canRate
                                ? () => setState(() => _stars = i + 1)
                                : null,
                            iconSize: 40,
                            color: AppColors.primary,
                            disabledColor: AppColors.primary,
                            icon: Icon(i < _stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded),
                          )),
                ),
                if (_submitted)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Thanks for your feedback!',
                        textAlign: TextAlign.center),
                  )
                else ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _comment,
                    enabled: !_saving && _ratingLoaded,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                        labelText: 'Comment (optional)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: canRate && _stars > 0 ? _submit : null,
                    child: Text(_saving ? 'Submitting...' : 'Submit Rating'),
                  ),
                ],
              ],
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppColors.error)),
                TextButton(
                    onPressed: _ratingLoaded ? _submit : _loadRating,
                    child: const Text('Retry')),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _report,
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Report Passenger'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(_submitted ? 'Done' : 'Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
