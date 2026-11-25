import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../catalog/parser.dart';
import '../services/favorites_manager.dart';
import 'app_tokens.dart';
import 'episode_card.dart';
import 'player_screen.dart';
import 'share_dialog.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesManager _favoritesManager = FavoritesManager();

  @override
  void initState() {
    super.initState();
    _favoritesManager.addListener(_onFavoritesUpdate);
    _favoritesManager.init();
  }

  @override
  void dispose() {
    _favoritesManager.removeListener(_onFavoritesUpdate);
    super.dispose();
  }

  void _onFavoritesUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favoritesManager.favoriteEpisodes;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.normalOverlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
        backgroundColor: AppColors.surfaceOverlay,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.borderSubtle, height: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: AppColors.accent, size: 22),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              '我的收藏 (Favorites)',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (favorites.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${favorites.length}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondary),
              tooltip: '清空所有收藏',
              onPressed: () => FavoritesBody.confirmClearAll(context, _favoritesManager),
            ),
        ],
      ),
      body: const SafeArea(
        top: false,
        child: FavoritesBody(),
      ),
    ),
    );
  }
}

/// Reusable favorites list body embedded in [FavoritesScreen] and [DownloadsScreen].
class FavoritesBody extends StatefulWidget {
  const FavoritesBody({super.key});

  static void confirmClearAll(BuildContext context, FavoritesManager manager) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 24),
            SizedBox(width: AppSpacing.sm),
            Text('清空所有收藏？', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: const Text(
          '確定要清空所有收藏的節目嗎？此操作將移除全部收藏項目。',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceInteractive,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              manager.clearAll();
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已清空所有收藏'),
                  duration: Duration(milliseconds: 1500),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('清空收藏'),
          ),
        ],
      ),
    );
  }

  @override
  State<FavoritesBody> createState() => _FavoritesBodyState();
}

class _FavoritesBodyState extends State<FavoritesBody> {
  final FavoritesManager _favoritesManager = FavoritesManager();

  @override
  void initState() {
    super.initState();
    _favoritesManager.addListener(_onFavoritesUpdate);
    _favoritesManager.init();
  }

  @override
  void dispose() {
    _favoritesManager.removeListener(_onFavoritesUpdate);
    super.dispose();
  }

  void _onFavoritesUpdate() {
    if (mounted) setState(() {});
  }

  void _playEpisode(CatalogEpisode ep, int partIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NativePlayerScreen(
          episode: ep,
          initialPartIndex: partIndex,
          playlist: _favoritesManager.favoriteEpisodes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favoritesManager.favoriteEpisodes;
    if (favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Icon(
                  Icons.favorite_border,
                  size: 36,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '尚未加入任何收藏',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '在首頁或播放器點擊收藏按鈕，即可集中整理喜愛的集數！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: const Text('瀏覽節目清單', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final ep = favorites[index];
        return YouTubeEpisodeCard(
          key: ValueKey('fav_${ep.id}'),
          episode: ep,
          onPlayTapped: () => _playEpisode(ep, 0),
          onPartTapped: (partIdx) => _playEpisode(ep, partIdx),
          onShareTapped: () => showShareDialog(context, ep),
        );
      },
    );
  }
}
