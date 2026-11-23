import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service interfacing with native Android storage features, permissions, and directory picker.
class StorageService {
  static const MethodChannel _channel = MethodChannel('com.dtvsteams.dtvsteams/storage');

  /// Check if the app has permission to write to public/external storage.
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('hasStoragePermission');
      return res ?? false;
    } catch (e) {
      debugPrint('[StorageService] hasStoragePermission error: $e');
      return true;
    }
  }

  /// Request storage permissions or launch manage all files permission settings on Android 11+.
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('requestStoragePermission');
      return res ?? false;
    } catch (e) {
      debugPrint('[StorageService] requestStoragePermission error: $e');
      return false;
    }
  }

  /// Query standard public storage locations on Android (Downloads, Movies, external app dir).
  static Future<Map<String, String>> getPublicStorageLocations() async {
    if (!Platform.isAndroid) return {};
    try {
      final res = await _channel.invokeMapMethod<String, String>('getPublicStorageLocations');
      return res ?? {};
    } catch (e) {
      debugPrint('[StorageService] getPublicStorageLocations error: $e');
      return {};
    }
  }

  /// Launch native Android directory picker (ACTION_OPEN_DOCUMENT_TREE).
  /// Resolves the tree URI into an absolute filesystem path.
  static Future<String?> pickDirectory() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<String>('pickDirectory');
      return res;
    } catch (e) {
      debugPrint('[StorageService] pickDirectory error: $e');
      return null;
    }
  }
}
