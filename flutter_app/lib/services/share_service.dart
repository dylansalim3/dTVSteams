import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service providing native file and video sharing via Android Intent.ACTION_SEND
class ShareService {
  static const MethodChannel _channel = MethodChannel('com.dtvsteams.dtvsteams/share');

  /// Shares text/URL using Android native system share sheet
  static Future<bool> shareText(String text, {String? title}) async {
    try {
      if (text.isEmpty) return false;
      final bool? success = await _channel.invokeMethod<bool>('shareText', {
        'text': text,
        'title': title ?? '分享連結',
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ShareService] PlatformException sharing text: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[ShareService] Error sharing text: $e');
      return false;
    }
  }

  /// Shares a single video file using Android native system share sheet
  static Future<bool> shareVideoFile(
    String filePath, {
    String? title,
    String mimeType = 'video/mp4',
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('[ShareService] File does not exist: $filePath');
        return false;
      }
      final bool? success = await _channel.invokeMethod<bool>('shareFile', {
        'filePath': filePath,
        'title': title ?? '分享影片',
        'mimeType': mimeType,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ShareService] PlatformException sharing file: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[ShareService] Error sharing file: $e');
      return false;
    }
  }

  /// Shares multiple video files using Android native system share sheet (ACTION_SEND_MULTIPLE)
  static Future<bool> shareVideoFiles(
    List<String> filePaths, {
    String? title,
    String mimeType = 'video/mp4',
  }) async {
    try {
      final validPaths = filePaths.where((p) => File(p).existsSync()).toList();
      if (validPaths.isEmpty) {
        debugPrint('[ShareService] No valid files found to share');
        return false;
      }
      final bool? success = await _channel.invokeMethod<bool>('shareFiles', {
        'filePaths': validPaths,
        'title': title ?? '分享影片',
        'mimeType': mimeType,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ShareService] PlatformException sharing files: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[ShareService] Error sharing files: $e');
      return false;
    }
  }
}
