import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RoutePhotoImage extends StatelessWidget {
  const RoutePhotoImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
    this.thumbnail = true,
  });
  final RoutePhotoDM photo;
  final BoxFit fit;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) => Image.file(
    File(photo.path),
    fit: fit,
    width: double.infinity,
    height: double.infinity,
    cacheWidth: thumbnail ? 384 : null,
    semanticLabel: 'Route photo',
    errorBuilder: (context, error, stack) => const ColoredBox(
      color: AppTheme.surface,
      child: Center(
        child: Tooltip(
          message: 'Photo file unavailable',
          child: Icon(Icons.broken_image_outlined, color: AppTheme.muted),
        ),
      ),
    ),
  );
}
