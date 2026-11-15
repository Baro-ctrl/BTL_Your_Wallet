import 'dart:io';

import 'package:flutter/material.dart';

import '../services/moment_image_service.dart';

class MomentImage extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;

  const MomentImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageErrorBuilder(
      BuildContext context,
      Object exception,
      StackTrace? stack,
    ) {
      return const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey),
      );
    }

    if (MomentImageService.isRemoteUrl(imagePath)) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: imageErrorBuilder,
      );
    }

    return Image.file(
      File(imagePath),
      fit: fit,
      errorBuilder: imageErrorBuilder,
    );
  }
}
