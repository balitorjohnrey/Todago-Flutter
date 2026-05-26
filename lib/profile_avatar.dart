import 'dart:io';

import 'package:flutter/material.dart';
import 'app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  final String initials;
  final String? imagePath;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    required this.initials,
    this.imagePath,
    this.size = 80,
    this.backgroundColor = AppColors.backgroundDark,
    this.foregroundColor = AppColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final hasPhoto = path != null && path.isNotEmpty && File(path).existsSync();

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        image: hasPhoto
            ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover)
            : null,
      ),
      child: hasPhoto
          ? null
          : Center(
              child: Text(
                initials.isNotEmpty ? initials : 'TG',
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (onTap != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.backgroundDark,
                  size: size * 0.16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
