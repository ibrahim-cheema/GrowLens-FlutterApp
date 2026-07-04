import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to persist pending uploads and drafts
class DraftsService {
  static const String _draftsKey = 'pending_uploads';
  static const String _createdAtKey = '_created_at';

  /// Save a pending upload
  static Future<void> savePendingUpload(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = getPendingUploadsSync(prefs);

      data[_createdAtKey] = DateTime.now().toIso8601String();
      drafts[id] = data;

      await prefs.setString(_draftsKey, jsonEncode(drafts));
      debugPrint('Draft saved: $id');
    } catch (e) {
      debugPrint('Failed to save draft: $e');
    }
  }

  /// Get all pending uploads
  static Future<Map<String, dynamic>> getPendingUploads() async {
    final prefs = await SharedPreferences.getInstance();
    return getPendingUploadsSync(prefs);
  }

  /// Sync variant (no await needed)
  static Map<String, dynamic> getPendingUploadsSync(SharedPreferences prefs) {
    try {
      final json = prefs.getString(_draftsKey) ?? '{}';
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (e) {
      debugPrint('Failed to load drafts: $e');
      return {};
    }
  }

  /// Remove a pending upload (after successful sync)
  static Future<void> removePendingUpload(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = getPendingUploadsSync(prefs);

      drafts.remove(id);
      await prefs.setString(_draftsKey, jsonEncode(drafts));
      debugPrint('Draft removed: $id');
    } catch (e) {
      debugPrint('Failed to remove draft: $e');
    }
  }

  /// Clear all pending uploads
  static Future<void> clearAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftsKey);
      debugPrint('All drafts cleared');
    } catch (e) {
      debugPrint('Failed to clear drafts: $e');
    }
  }

  /// Check if there are pending uploads
  static Future<bool> hasPendingUploads() async {
    final drafts = await getPendingUploads();
    return drafts.isNotEmpty;
  }

  /// Get creation time of a draft
  static DateTime? getDraftTime(Map<String, dynamic> draft) {
    try {
      final timeStr = draft[_createdAtKey] as String?;
      if (timeStr == null) return null;
      return DateTime.parse(timeStr);
    } catch (_) {
      return null;
    }
  }
}
