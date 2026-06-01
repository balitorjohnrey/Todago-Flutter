import 'dart:convert';
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
    final photoProvider = _imageProviderFor(path);
    final hasPhoto = photoProvider != null;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        image: photoProvider != null
            ? DecorationImage(image: photoProvider, fit: BoxFit.cover)
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

  ImageProvider? _imageProviderFor(String? source) {
    if (source == null || source.isEmpty) return null;
    if (source.startsWith('data:image/')) {
      final comma = source.indexOf(',');
      if (comma == -1) return null;
      try {
        return MemoryImage(base64Decode(source.substring(comma + 1)));
      } catch (_) {
        return null;
      }
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return NetworkImage(source);
    }
    final file = File(source);
    return file.existsSync() ? FileImage(file) : null;
  }
}
