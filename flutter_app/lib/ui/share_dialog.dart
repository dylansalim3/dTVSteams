import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../catalog/parser.dart';
import '../catalog/show_channel.dart';
import '../services/share_service.dart';
import 'app_tokens.dart';

/// Unified Share Dialog displaying QR Code, Copy URL, System Share, and optional offline video file transfer.
class ShareDialog extends StatefulWidget {
  final CatalogEpisode episode;
  final int partIndex;
  final String? localFilePath;

  const ShareDialog({
    super.key,
    required this.episode,
    this.partIndex = 0,
    this.localFilePath,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  String get shareUrl {
    final ep = widget.episode;
    final partNum = widget.partIndex + 1;
    final epId = Uri.encodeComponent(ep.id);
    if (partNum > 1) {
      return 'https://dtvsteams.pages.dev/?ep=$epId&part=$partNum';
    }
    return 'https://dtvsteams.pages.dev/?ep=$epId';
  }

  String get partLabel {
    if (widget.partIndex < widget.episode.parts.length) {
      return widget.episode.parts[widget.partIndex].label;
    }
    return 'Part ${widget.partIndex + 1}';
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: shareUrl));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已複製分享連結到剪貼簿'),
        duration: Duration(seconds: 2),
      ),
    );
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _shareLink() {
    final ep = widget.episode;
    final shareTitle = '【${ep.title}】($partLabel)';
    ShareService.shareText('$shareTitle\n$shareUrl', title: shareTitle);
  }

  void _shareLocalFile() {
    if (widget.localFilePath != null && File(widget.localFilePath!).existsSync()) {
      Navigator.of(context).pop();
      final shareTitle = '${widget.episode.title} - $partLabel';
      ShareService.shareVideoFile(widget.localFilePath!, title: shareTitle);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本機影片檔案不存在或已被移動')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final showId = ep.showId.isNotEmpty
        ? ep.showId
        : CatalogParser.detectShowId('${ep.title} ${ep.id}');
    final showName = ep.showName.isNotEmpty
        ? ep.showName
        : ShowChannels.getShowName(showId);
    final showEmoji = ShowChannels.getEmoji(showId);
    final hasLocalFile = widget.localFilePath != null && File(widget.localFilePath!).existsSync();

    return Dialog(
      backgroundColor: AppColors.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.modal),
        side: BorderSide(color: AppColors.borderSeparator, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg + 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                    ),
                    child: Icon(Icons.share, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showName.isNotEmpty) ...[
                          Text(
                            '$showEmoji $showName · $partLabel',
                            style: AppType.caption1Semibold.copyWith(color: AppColors.accent),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          ep.title.isNotEmpty ? ep.title : '分享節目影片',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.headlineMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                    style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: AppColors.borderSeparator, height: 1),
              const SizedBox(height: AppSpacing.lg),

              // QR Code Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.dropdown,
                ),
                child: QrImageView(
                  data: shareUrl,
                  version: QrVersions.auto,
                  size: 180,
                  gapless: true,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: AppSpacing.md - 2),
              Text(
                '使用手機相機或平板掃描 QR Code 即刻線上開播',
                textAlign: TextAlign.center,
                style: AppType.caption2Medium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Copy URL Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 2, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: AppColors.borderSeparator),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        shareUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption1Regular.copyWith(
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: _copied ? AppColors.success : AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _copyToClipboard,
                      icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                      label: Text(
                        _copied ? '已複製' : '複製',
                        style: AppType.caption1Semibold.copyWith(
                          color: _copied ? AppColors.success : AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.control),
                        ),
                      ),
                      onPressed: _shareLink,
                      icon: const Icon(Icons.share, size: 16),
                      label: Text(
                        '分享連結',
                        style: AppType.body2Medium.copyWith(color: AppColors.onAccent),
                      ),
                    ),
                  ),
                ],
              ),

              // Optional Local Video File Transfer Button
              if (hasLocalFile) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.borderDefault),
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                    ),
                    onPressed: _shareLocalFile,
                    icon: Icon(Icons.video_file_outlined, size: 16, color: AppColors.success),
                    label: Text(
                      '傳送本機離線影片檔 (MP4)',
                      style: AppType.caption1Medium.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to display the Share Dialog
void showShareDialog(
  BuildContext context,
  CatalogEpisode episode, {
  int partIndex = 0,
  String? localFilePath,
}) {
  showDialog(
    context: context,
    builder: (ctx) => ShareDialog(
      episode: episode,
      partIndex: partIndex,
      localFilePath: localFilePath,
    ),
  );
}
