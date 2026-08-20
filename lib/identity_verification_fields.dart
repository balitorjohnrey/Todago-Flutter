import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'app_theme.dart';

class IdentityVerificationData {
  final String? validIdType;
  final String? validIdNumber;
  final String? validIdImageUrl;
  final String? faceImageUrl;

  const IdentityVerificationData({
    this.validIdType,
    this.validIdNumber,
    this.validIdImageUrl,
    this.faceImageUrl,
  });
}

class IdentityVerificationFields extends StatefulWidget {
  const IdentityVerificationFields({
    super.key,
    required this.onChanged,
    this.dark = false,
  });

  final ValueChanged<IdentityVerificationData> onChanged;
  final bool dark;

  @override
  State<IdentityVerificationFields> createState() =>
      _IdentityVerificationFieldsState();
}

class _IdentityVerificationFieldsState
    extends State<IdentityVerificationFields> {
  static const _maxDataUrlLength = 650000;

  final _picker = ImagePicker();
  final _idNumberCtrl = TextEditingController();
  String? _validIdType;
  String? _validIdImageUrl;
  String? _faceImageUrl;
  String? _imageError;

  final List<Map<String, String>> _idTypes = const [
    {'value': 'philippine_national_id', 'label': 'Philippine National ID'},
    {'value': 'drivers_license', 'label': "Driver's License"},
    {'value': 'passport', 'label': 'Passport'},
    {'value': 'umid', 'label': 'UMID'},
    {'value': 'voters_id', 'label': "Voter's ID"},
    {'value': 'sss_id', 'label': 'SSS ID'},
    {'value': 'prc_id', 'label': 'PRC ID'},
    {'value': 'student_id', 'label': 'Student ID'},
  ];

  @override
  void initState() {
    super.initState();
    _idNumberCtrl.addListener(_emit);
  }

  @override
  void dispose() {
    _idNumberCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(IdentityVerificationData(
      validIdType: _validIdType,
      validIdNumber: _idNumberCtrl.text.trim(),
      validIdImageUrl: _validIdImageUrl,
      faceImageUrl: _faceImageUrl,
    ));
  }

  Future<String?> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 55,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final mimeType = _mimeTypeFor(file.name);
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    if (dataUrl.length > _maxDataUrlLength) {
      setState(() {
        _imageError = 'Image is too large. Retake with clearer framing.';
      });
      return null;
    }
    setState(() => _imageError = null);
    return dataUrl;
  }

  String _mimeTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _setIdImage(
    FormFieldState<String> field,
    ImageSource source,
  ) async {
    final dataUrl = await _pickImage(source);
    if (dataUrl == null) return;
    setState(() => _validIdImageUrl = dataUrl);
    field.didChange(dataUrl);
    _emit();
  }

  Future<void> _setFaceImage(
    FormFieldState<String> field,
    ImageSource source,
  ) async {
    final dataUrl = await _pickImage(source);
    if (dataUrl == null) return;
    setState(() => _faceImageUrl = dataUrl);
    field.didChange(dataUrl);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = widget.dark ? AppColors.textPrimary : Colors.grey[700];
    final helperColor = widget.dark ? AppColors.textSecondary : Colors.grey[500];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Identity Verification',
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: labelColor,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Valid ID and face verification are required.',
        style: GoogleFonts.poppins(fontSize: 12, color: helperColor),
      ),
      const SizedBox(height: 16),
      _label('Valid ID Type', required: true),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: _validIdType,
        isExpanded: true,
        dropdownColor: widget.dark ? AppColors.backgroundDark : Colors.white,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.badge_outlined,
              color: widget.dark ? AppColors.textHint : Colors.grey[400],
              size: 20),
          filled: true,
          fillColor: widget.dark ? AppColors.surface : Colors.grey[50],
        ),
        style: GoogleFonts.poppins(
          color: widget.dark ? AppColors.textPrimary : Colors.grey[800],
          fontSize: 14,
        ),
        items: _idTypes
            .map((type) => DropdownMenuItem(
                  value: type['value'],
                  child: Text(type['label']!),
                ))
            .toList(),
        onChanged: (value) {
          setState(() => _validIdType = value);
          _emit();
        },
        validator: (value) =>
            value == null ? 'Select your valid ID type' : null,
      ),
      const SizedBox(height: 14),
      _label('Valid ID Number', required: true),
      const SizedBox(height: 6),
      TextFormField(
        controller: _idNumberCtrl,
        textInputAction: TextInputAction.next,
        style: GoogleFonts.poppins(
          color: widget.dark ? AppColors.textPrimary : Colors.grey[800],
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'ID number',
          prefixIcon: Icon(Icons.numbers_rounded,
              color: widget.dark ? AppColors.textHint : Colors.grey[400],
              size: 20),
          filled: true,
          fillColor: widget.dark ? AppColors.surface : Colors.grey[50],
        ),
        validator: (value) {
          final number = value?.trim() ?? '';
          if (number.length < 3) return 'Enter the ID number';
          return null;
        },
      ),
      const SizedBox(height: 14),
      _captureField(
        label: 'Valid ID Photo',
        value: _validIdImageUrl,
        validatorMessage: 'Upload your valid ID photo',
        icon: Icons.document_scanner_outlined,
        actions: (field) => [
          _captureButton(
            label: 'Camera',
            icon: Icons.photo_camera_outlined,
            onTap: () => _setIdImage(field, ImageSource.camera),
          ),
          const SizedBox(width: 8),
          _captureButton(
            label: 'Upload',
            icon: Icons.upload_file_rounded,
            onTap: () => _setIdImage(field, ImageSource.gallery),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _captureField(
        label: 'Face Verification Photo',
        value: _faceImageUrl,
        validatorMessage: 'Capture your face verification photo',
        icon: Icons.face_retouching_natural_rounded,
        actions: (field) => [
          _captureButton(
            label: 'Capture',
            icon: Icons.photo_camera_front_outlined,
            onTap: () => _setFaceImage(field, ImageSource.camera),
          ),
          const SizedBox(width: 8),
          _captureButton(
            label: 'Upload',
            icon: Icons.upload_file_rounded,
            onTap: () => _setFaceImage(field, ImageSource.gallery),
          ),
        ],
      ),
      if (_imageError != null) ...[
        const SizedBox(height: 10),
        Text(
          _imageError!,
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
        ),
      ],
    ]);
  }

  Widget _captureField({
    required String label,
    required String? value,
    required String validatorMessage,
    required IconData icon,
    required List<Widget> Function(FormFieldState<String> field) actions,
  }) =>
      FormField<String>(
        initialValue: value,
        validator: (fieldValue) =>
            fieldValue == null || fieldValue.isEmpty ? validatorMessage : null,
        builder: (field) {
          final hasImage = field.value != null && field.value!.isNotEmpty;
          final borderColor = field.hasError
              ? AppColors.error
              : hasImage
                  ? AppColors.success
                  : (widget.dark ? AppColors.inputBorder : Colors.grey[200]!);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label(label, required: true),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.dark ? AppColors.surface : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(children: [
                Icon(
                  hasImage ? Icons.check_circle_rounded : icon,
                  color: hasImage ? AppColors.success : AppColors.textHint,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasImage ? 'Image added' : 'No image selected',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: hasImage
                          ? AppColors.success
                          : (widget.dark
                              ? AppColors.textSecondary
                              : Colors.grey[600]),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...actions(field),
              ]),
            ),
            if (field.hasError) ...[
              const SizedBox(height: 6),
              Text(
                field.errorText!,
                style:
                    GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
              ),
            ],
          ]);
        },
      );

  Widget _captureButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withOpacity(0.45)),
          textStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _label(String text, {bool required = false}) => Row(children: [
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: widget.dark ? AppColors.textSecondary : Colors.grey[700],
          ),
        ),
        if (required)
          Text(
            ' *',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
      ]);
}
