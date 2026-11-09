import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'report_issue_service.dart';
import 'trip_service.dart';

class ReportIssueOption {
  final String type;
  final String label;
  final String title;
  final String hint;
  final IconData icon;
  final String priority;

  const ReportIssueOption({
    required this.type,
    required this.label,
    required this.title,
    required this.hint,
    required this.icon,
    this.priority = 'normal',
  });
}

Future<void> showReportIssueDialog({
  required BuildContext context,
  required String reporterRole,
  String? initialType,
  String? tripId,
  String? subjectRole,
  String? subjectId,
  String? subjectName,
  Map<String, dynamic>? metadata,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportIssueSheet(
      reporterRole: reporterRole,
      initialType: initialType,
      tripId: tripId,
      subjectRole: subjectRole,
      subjectId: subjectId,
      subjectName: subjectName,
      metadata: metadata,
    ),
  );
}

class _ReportIssueSheet extends StatefulWidget {
  final String reporterRole;
  final String? initialType;
  final String? tripId;
  final String? subjectRole;
  final String? subjectId;
  final String? subjectName;
  final Map<String, dynamic>? metadata;

  const _ReportIssueSheet({
    required this.reporterRole,
    this.initialType,
    this.tripId,
    this.subjectRole,
    this.subjectId,
    this.subjectName,
    this.metadata,
  });

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  late String _selectedType;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingTrips = false;
  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic>? _selectedTrip;
  String? _error;

  bool get _participantReporter =>
      ['driver', 'passenger', 'commuter'].contains(widget.reporterRole);
  String? get _tripId => widget.tripId ?? _selectedTrip?['trip_id']?.toString();
  bool get _needsTrip =>
      _participantReporter &&
      (_selectedType != 'other' || widget.subjectRole != null);

  @override
  void initState() {
    super.initState();
    final options = _optionsForRole(widget.reporterRole);
    _selectedType = widget.initialType != null &&
            options.any((option) => option.type == widget.initialType)
        ? widget.initialType!
        : options.first.type;
    if (_participantReporter && widget.tripId == null) _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoadingTrips = true);
    final trips = widget.reporterRole == 'driver'
        ? await TripService.getDriverHistory()
        : await TripService.getCommuterHistory();
    if (!mounted) return;
    setState(() {
      _isLoadingTrips = false;
      _trips = trips
          .where((trip) =>
              (trip['trip_id']?.toString().isNotEmpty ?? false) &&
              (trip[widget.reporterRole == 'driver'
                          ? 'commuter_id'
                          : 'driver_id']
                      ?.toString()
                      .isNotEmpty ??
                  false))
          .toList();
    });
  }

  String _tripLabel(Map<String, dynamic> trip) {
    final name =
        trip[widget.reporterRole == 'driver' ? 'commuter_name' : 'driver_name']
                ?.toString() ??
            (widget.reporterRole == 'driver' ? 'Passenger' : 'Driver');
    final date = DateTime.tryParse(trip['request_timestamp']?.toString() ?? '')
        ?.toLocal();
    final dateLabel = date == null
        ? ''
        : ' · ${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$name$dateLabel · ${trip['destination'] ?? 'Trip'}';
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  List<ReportIssueOption> _optionsForRole(String role) {
    switch (role) {
      case 'driver':
        return const [
          ReportIssueOption(
            type: 'passenger_issue',
            label: 'Report Passenger',
            title: 'Passenger issue',
            hint: 'Describe what happened with this passenger.',
            icon: Icons.person_off_rounded,
          ),
          ReportIssueOption(
            type: 'blacklist_passenger',
            label: 'Cooldown Request',
            title: 'Passenger booking cooldown request',
            hint:
                'Tell admin why this passenger should receive a booking cooldown.',
            icon: Icons.block_rounded,
            priority: 'high',
          ),
          ReportIssueOption(
            type: 'fare_or_item_issue',
            label: 'Fare or Item',
            title: 'Fare or item issue',
            hint:
                'Explain the fare, baggage, pickup item, or other fee concern.',
            icon: Icons.payments_rounded,
          ),
          ReportIssueOption(
            type: 'other',
            label: 'Other',
            title: 'Driver report',
            hint: 'Describe the issue for admin validation.',
            icon: Icons.report_problem_rounded,
          ),
        ];
      case 'operator':
        return const [
          ReportIssueOption(
            type: 'driver_vehicle_mismatch',
            label: 'Vehicle Mismatch',
            title: 'Different driver or vehicle',
            hint: 'Describe which driver or vehicle is involved.',
            icon: Icons.no_crash_rounded,
            priority: 'high',
          ),
          ReportIssueOption(
            type: 'driver_issue',
            label: 'Driver Issue',
            title: 'Driver issue',
            hint: 'Describe the driver concern for admin review.',
            icon: Icons.badge_rounded,
          ),
          ReportIssueOption(
            type: 'system_issue',
            label: 'System Issue',
            title: 'System issue',
            hint: 'Describe the system or dashboard problem.',
            icon: Icons.settings_suggest_rounded,
          ),
          ReportIssueOption(
            type: 'other',
            label: 'Other',
            title: 'Operator report',
            hint: 'Describe the issue for admin validation.',
            icon: Icons.report_problem_rounded,
          ),
        ];
      default:
        return const [
          ReportIssueOption(
            type: 'wrong_driver_vehicle',
            label: 'Different Driver',
            title: 'Different driver using vehicle',
            hint: 'Tell admin who arrived or what looked different.',
            icon: Icons.person_search_rounded,
            priority: 'high',
          ),
          ReportIssueOption(
            type: 'driver_behavior',
            label: 'Driver Behavior',
            title: 'Driver behavior issue',
            hint: 'Describe what happened with the driver.',
            icon: Icons.warning_amber_rounded,
          ),
          ReportIssueOption(
            type: 'fare_or_baggage_fee',
            label: 'Fare or Baggage',
            title: 'Fare or baggage fee issue',
            hint: 'Explain the fare, baggage, or extra fee concern.',
            icon: Icons.luggage_rounded,
          ),
          ReportIssueOption(
            type: 'other',
            label: 'Other',
            title: 'Passenger report',
            hint: 'Describe the issue for admin validation.',
            icon: Icons.report_problem_rounded,
          ),
        ];
    }
  }

  ReportIssueOption get _selectedOption => _optionsForRole(widget.reporterRole)
      .firstWhere((option) => option.type == _selectedType);

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_needsTrip && (_tripId == null || _tripId!.isEmpty)) {
      setState(
          () => _error = 'Select the trip to identify the reported account.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final option = _selectedOption;
    final forDriver = widget.reporterRole == 'driver';
    final result = await ReportIssueService.submitReport(
      reporterRole: widget.reporterRole,
      reportType: option.type,
      title: option.title,
      details: _detailsController.text,
      subjectRole: _selectedTrip == null
          ? widget.subjectRole
          : (forDriver ? 'passenger' : 'driver'),
      subjectId: _selectedTrip == null
          ? widget.subjectId
          : _selectedTrip![forDriver ? 'commuter_id' : 'driver_id']?.toString(),
      subjectName: _selectedTrip == null
          ? widget.subjectName
          : _selectedTrip![forDriver ? 'commuter_name' : 'driver_name']
              ?.toString(),
      tripId: _tripId,
      priority: option.priority,
      metadata: widget.metadata,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(
        result.message,
        style: GoogleFonts.poppins(fontSize: 13),
      ),
      backgroundColor: result.success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final options = _optionsForRole(widget.reporterRole);
    final media = MediaQuery.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.report_problem_rounded,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report an Issue',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.backgroundDark,
                            ),
                          ),
                          Text(
                            'Admin will validate and confirm the report.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  if (_participantReporter && widget.tripId == null) ...[
                    Text('Which trip is this about?',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (_isLoadingTrips)
                      const LinearProgressIndicator()
                    else if (_trips.isEmpty)
                      Row(children: [
                        const Expanded(
                            child: Text(
                                'No trips available. A trip is required to report a passenger or driver.')),
                        TextButton(
                            onPressed: _loadTrips, child: const Text('Retry')),
                      ])
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTrip?['trip_id']?.toString(),
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Select trip',
                            border: OutlineInputBorder()),
                        items: _trips
                            .map((trip) => DropdownMenuItem(
                                  value: trip['trip_id'].toString(),
                                  child: Text(_tripLabel(trip),
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (id) => setState(() {
                                  _selectedTrip = _trips.firstWhere((trip) =>
                                      trip['trip_id'].toString() == id);
                                  _error = null;
                                }),
                      ),
                    const SizedBox(height: 16),
                  ] else if (widget.subjectName?.isNotEmpty ?? false) ...[
                    Text('Reported account: ${widget.subjectName}',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options
                        .map((option) => ChoiceChip(
                              selected: _selectedType == option.type,
                              onSelected: _isSubmitting
                                  ? null
                                  : (_) => setState(
                                      () => _selectedType = option.type),
                              showCheckmark: false,
                              avatar: Icon(option.icon, size: 16),
                              label: Text(option.label),
                              selectedColor: AppColors.backgroundDark,
                              backgroundColor: const Color(0xFFF5F6FA),
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _selectedType == option.type
                                    ? Colors.white
                                    : AppColors.backgroundDark,
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _detailsController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1200,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      hintText: _selectedOption.hint,
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.backgroundDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!,
                        style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting ? 'Sending...' : 'Send to Admin',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.backgroundDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
