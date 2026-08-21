import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class PersonaVerificationNotice extends StatelessWidget {
  final bool dark;

  const PersonaVerificationNotice({
    super.key,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = dark
        ? AppColors.surface.withOpacity(0.65)
        : AppColors.primary.withOpacity(0.08);
    final border =
        dark ? AppColors.inputBorder : AppColors.primary.withOpacity(0.25);
    final titleColor = dark ? AppColors.textPrimary : AppColors.backgroundDark;
    final bodyColor = dark ? AppColors.textSecondary : Colors.grey[700];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valid ID identity check',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Valid ID and face verification open securely after signup.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.35,
                    color: bodyColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
