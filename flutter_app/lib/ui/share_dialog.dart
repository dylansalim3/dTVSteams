import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../catalog/parser.dart';
import '../catalog/show_channel.dart';
import '../services/share_service.dart';

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
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.share, color: Color(0xFFE50914), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showName.isNotEmpty) ...[
                          Text(
                            '$showEmoji $showName · $partLabel',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFE50914),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          ep.title.isNotEmpty ? ep.title : '分享節目影片',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // QR Code Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: shareUrl,
                  version: QrVersions.auto,
                  size: 180,
                  gapless: true,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '使用手機相機或平板掃描 QR Code 即刻線上開播',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // Copy URL Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16, color: Colors.white54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shareUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: _copied ? const Color(0xFF46D369) : const Color(0xFFE50914),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _copyToClipboard,
                      icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                      label: Text(
                        _copied ? '已複製' : '複製',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _shareLink,
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text(
                        '分享連結',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _shareLocalFile,
                    icon: const Icon(Icons.video_file_outlined, size: 16, color: Color(0xFF46D369)),
                    label: const Text(
                      '傳送本機離線影片檔 (MP4)',
                      style: TextStyle(fontSize: 12),
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
