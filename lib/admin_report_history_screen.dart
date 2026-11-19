import 'package:flutter/material.dart';

import 'admin_auth_service.dart';
import 'app_theme.dart';
import 'monitoring_service.dart';

String _time(Object? raw) {
  final date = DateTime.tryParse('$raw')?.toLocal();
  if (date == null) return 'Unavailable';
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)}';
}

String _status(Object? raw) => switch (raw) {
      'validated' => 'Validated',
      'rejected' => 'Rejected',
      'resolved' => 'Resolved',
      'pending' => 'Pending',
      'reopened' => 'Reopened',
      'penalty_revoked' => 'Penalty undone',
      'legacy_review' => 'Existing review (imported)',
      _ => '$raw',
    };

String _duration(Map<String, dynamic> row) {
  if (row['penalty_permanent'] == true) return 'Permanent';
  final minutes = int.tryParse('${row['penalty_minutes']}');
  if (minutes == null) return 'No penalty';
  if (minutes == 10080) return '1 week';
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    return '$hours hour${hours == 1 ? '' : 's'}';
  }
  return '$minutes minutes';
}

String _penalty(Map<String, dynamic> report) {
  if (report['penalty_revoked_at'] != null) return 'Penalty undone';
  if (report['penalty_active'] == true) {
    return 'Active penalty · ${_duration(report)}';
  }
  if (report['restriction_until'] != null ||
      report['penalty_permanent'] == true) {
    return 'Inactive penalty · ${_duration(report)}';
  }
  return 'No penalty applied';
}

Widget _page(BuildContext context,
        {required String title,
        required Widget body,
        required VoidCallback? refresh}) =>
    Theme(
      data: ThemeData.light(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          textTheme: Theme.of(context).textTheme.apply(
              bodyColor: AppColors.backgroundDark,
              displayColor: AppColors.backgroundDark)),
      child: Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          appBar: AppBar(title: Text(title), actions: [
            IconButton(
                onPressed: refresh,
                tooltip: 'Refresh report history',
                icon: const Icon(Icons.refresh))
          ]),
          body: body),
    );

class AdminReportHistoryScreen extends StatefulWidget {
  const AdminReportHistoryScreen({super.key});
  @override
  State<AdminReportHistoryScreen> createState() =>
      _AdminReportHistoryScreenState();
}

class _AdminReportHistoryScreenState extends State<AdminReportHistoryScreen> {
  List<Map<String, dynamic>> _reports = [];
  String _statusFilter = 'all';
  bool _loading = false, _hasMore = false;
  int _offset = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await MonitoringService.fetchReportHistory(
        status: _statusFilter, offset: append ? _offset : 0);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = 'Unable to load report history. Tap refresh to retry.';
        return;
      }
      final rows = MonitoringService.records(data['reports']);
      _reports = append ? [..._reports, ...rows] : rows;
      _hasMore = data['has_more'] == true;
      _offset = int.tryParse('${data['next_offset']}') ?? 0;
    });
  }

  Future<void> _open(Map<String, dynamic> report) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            AdminReportReviewHistoryScreen(issueId: '${report['issue_id']}')));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => _page(
        context,
        title: 'Report History',
        refresh: _loading ? null : _load,
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                      'Review past decisions and undo a mistaken penalty. Original decisions and reversal reasons stay in the review history.'),
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final filter in const {
                      'all': 'All',
                      'validated': 'Validated',
                      'rejected': 'Rejected',
                      'resolved': 'Resolved',
                      'revoked': 'Penalty undone',
                      'pending': 'Reopened'
                    }.entries)
                      ChoiceChip(
                          label: Text(filter.value),
                          selected: _statusFilter == filter.key,
                          onSelected: _loading
                              ? null
                              : (_) {
                                  setState(() {
                                    _statusFilter = filter.key;
                                    _reports = [];
                                    _hasMore = false;
                                  });
                                  _load();
                                }),
                  ]),
                  const SizedBox(height: 12),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(_error!)),
                  if (!_loading && _error == null && _reports.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No reviewed reports in this category.')),
                  for (final report in _reports)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(spacing: 8, runSpacing: 4, children: [
                                    Text(_status(report['status']),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(_penalty(report)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text('${report['title'] ?? 'Report'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15)),
                                  Text(
                                      'Reported account: ${report['subject_name'] ?? report['subject_id'] ?? 'Not linked'}'),
                                  Text(
                                      'Last review: ${_time(report['last_review_at'])}',
                                      style: const TextStyle(fontSize: 12)),
                                  if (report['details'] != null)
                                    Text('${report['details']}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  TextButton.icon(
                                      onPressed: () => _open(report),
                                      icon: const Icon(Icons.history),
                                      label: const Text('View review history')),
                                ]))),
                  if (_hasMore)
                    OutlinedButton(
                        onPressed: _loading ? null : () => _load(append: true),
                        child: const Text('Load more reports')),
                ])),
      );
}

class AdminReportReviewHistoryScreen extends StatefulWidget {
  final String issueId;
  const AdminReportReviewHistoryScreen({super.key, required this.issueId});
  @override
  State<AdminReportReviewHistoryScreen> createState() =>
      _AdminReportReviewHistoryScreenState();
}

class _AdminReportReviewHistoryScreenState
    extends State<AdminReportReviewHistoryScreen> {
  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _history = [];
  bool _loading = false, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await MonitoringService.fetchReportReviews(widget.issueId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null || data['report'] is! Map) {
        _error = 'Unable to load the report. Tap refresh to retry.';
        return;
      }
      _report = Map<String, dynamic>.from(data['report'] as Map);
      _history = MonitoringService.records(data['history']);
    });
  }

  Future<void> _change({required bool undo}) async {
    final reason = await showDialog<String>(
        context: context,
        builder: (_) => _ReasonDialog(
              title: undo ? 'Undo penalty' : 'Reopen report',
              details: undo
                  ? 'Remove the penalty from this report for ${_report?['subject_name'] ?? 'the reported account'}? The original decision stays in history. Other active penalties still apply.'
                  : 'Return this rejected report to the pending review queue? The earlier rejection stays in history so a new review can be recorded.',
            ));
    if (!mounted || reason == null) return;
    setState(() => _saving = true);
    final result = undo
        ? await AdminAuthService.undoReportPenalty(
            issueId: widget.issueId, reason: reason)
        : await AdminAuthService.updateReportStatus(
            issueId: widget.issueId, status: 'pending', adminNotes: reason);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Report updated.')));
    if (result.success) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return _page(
      context,
      title: 'Report review history',
      refresh: _loading || _saving ? null : _load,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_loading || _saving) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_error!)),
        if (report != null) ...[
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${report['title'] ?? 'Report'}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text('Status: ${_status(report['status'])}'),
                        Text(
                            'Reporter: ${report['reporter_name'] ?? report['reporter_role'] ?? 'Unknown'}'),
                        Text(
                            'Reported account: ${report['subject_name'] ?? report['subject_id'] ?? 'Not linked'}'),
                        if (report['trip_id'] != null)
                          SelectableText('Trip: ${report['trip_id']}'),
                        Text('Submitted: ${_time(report['created_at'])}'),
                        const SizedBox(height: 10),
                        Text('${report['details'] ?? 'No further details.'}'),
                        if (report['admin_notes'] != null)
                          Text('Admin notes: ${report['admin_notes']}'),
                        const Divider(height: 24),
                        Text(_penalty(report),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        if (report['penalty_revoked_at'] != null) ...[
                          Text(
                              'Undone: ${_time(report['penalty_revoked_at'])}'),
                          Text('Reason: ${report['penalty_revoke_reason']}'),
                        ] else if (report['penalty_active'] == true &&
                            report['penalty_permanent'] != true)
                          Text(
                              'Expires: ${_time(report['restriction_until'])}'),
                        const SizedBox(height: 12),
                        if ((report['restriction_until'] != null ||
                                report['penalty_permanent'] == true) &&
                            report['penalty_revoked_at'] == null)
                          FilledButton.icon(
                              onPressed: _saving || _loading
                                  ? null
                                  : () => _change(undo: true),
                              icon: const Icon(Icons.undo),
                              label: const Text('Undo penalty')),
                        if (report['status'] == 'rejected')
                          OutlinedButton.icon(
                              onPressed: _saving || _loading
                                  ? null
                                  : () => _change(undo: false),
                              icon: const Icon(Icons.replay),
                              label: const Text('Reopen report')),
                      ]))),
          const SizedBox(height: 16),
          const Text('Review history',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            const Text(
                'No detailed review events were recorded for this report.'),
          for (final event in _history)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_status(event['action']),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          Text(_time(event['created_at']),
                              style: const TextStyle(fontSize: 12)),
                          Text(
                              'Admin account: ${event['admin_id'] ?? 'Not recorded for this earlier review'}',
                              style: const TextStyle(fontSize: 12)),
                          Text(
                              '${event['previous_status'] == null ? '' : '${_status(event['previous_status'])} → '}${_status(event['status'])}'),
                          if (event['penalty_minutes'] != null ||
                              event['penalty_permanent'] == true)
                            Text('Original penalty: ${_duration(event)}'),
                          if (event['notes'] != null)
                            Text('Notes: ${event['notes']}'),
                        ]))),
        ],
      ]),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  final String title, details;
  const _ReasonDialog({required this.title, required this.details});
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.details),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _reason,
                          maxLength: 800,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              labelText: 'Reason (required)',
                              border: OutlineInputBorder()),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter a reason.'
                                  : null),
                    ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.of(context).pop(_reason.text.trim());
                }
              },
              child: Text(widget.title))
        ],
      );
}
