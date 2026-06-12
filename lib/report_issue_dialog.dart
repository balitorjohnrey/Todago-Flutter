import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'report_issue_service.dart';

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

  @override
  void initState() {
    super.initState();
    final options = _optionsForRole(widget.reporterRole);
    _selectedType = widget.initialType != null &&
            options.any((option) => option.type == widget.initialType)
        ? widget.initialType!
        : options.first.type;
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
            label: 'Blacklist Request',
            title: 'Blacklist passenger request',
            hint: 'Tell admin why this passenger should be blacklisted.',
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
    setState(() => _isSubmitting = true);
    final option = _selectedOption;
    final result = await ReportIssueService.submitReport(
      reporterRole: widget.reporterRole,
      reportType: option.type,
      title: option.title,
      details: _detailsController.text,
      subjectRole: widget.subjectRole,
      subjectId: widget.subjectId,
      subjectName: widget.subjectName,
      tripId: widget.tripId,
      priority: option.priority,
      metadata: widget.metadata,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options
                        .map((option) => ChoiceChip(
                              selected: _selectedType == option.type,
                              onSelected: (_) =>
                                  setState(() => _selectedType = option.type),
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
