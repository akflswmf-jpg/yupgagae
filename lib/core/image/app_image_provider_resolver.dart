import 'dart:io';

import 'package:flutter/widgets.dart';

class AppImageProviderResolver {
  const AppImageProviderResolver._();

  static bool isNetworkSource(String source) {
    final normalized = source.trim().toLowerCase();
    return normalized.startsWith('http://') || normalized.startsWith('https://');
  }

  static bool isAssetSource(String source) {
    final normalized = source.trim();
    return normalized.startsWith('assets/');
  }

  static ImageProvider? resolve(
    String source, {
    int? resizeWidth,
  }) {
    final normalized = source.trim();

    if (normalized.isEmpty) {
      return null;
    }

    final ImageProvider provider;

    if (isNetworkSource(normalized)) {
      provider = NetworkImage(normalized);
    } else if (isAssetSource(normalized)) {
      provider = AssetImage(normalized);
    } else {
      provider = FileImage(File(normalized));
    }

    if (resizeWidth == null || resizeWidth <= 0) {
      return provider;
    }

    return ResizeImage(
      provider,
      width: resizeWidth,
    );
  }
}