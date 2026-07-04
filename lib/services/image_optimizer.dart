import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Image optimization service for compression and caching
class ImageOptimizer {
  /// Compress image before upload
  /// Returns compressed bytes, or null on failure
  static Future<Uint8List?> compressImage(
    XFile imageFile, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 75,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // If already small, return as-is
      if (bytes.lengthInMb < 0.5) {
        return bytes;
      }

      // Decode and resize
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final resized = img.copyResize(
        image,
        width: maxWidth,
        height: maxHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode with compression
      final compressed = img.encodeJpg(resized, quality: quality);
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('Image compression failed: $e');
      return null;
    }
  }

  /// Get file size in MB
  static double getFileSizeMb(Uint8List bytes) {
    return bytes.length / (1024 * 1024);
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

extension on Uint8List {
  double get lengthInMb => length / (1024 * 1024);
}
