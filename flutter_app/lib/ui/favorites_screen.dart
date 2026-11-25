import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../catalog/parser.dart';
import '../services/favorites_manager.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Color(0xFFE50914), size: 22),
            const SizedBox(width: 8),
            const Text(
              '我的收藏 (Favorites)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (favorites.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${favorites.length}',
                  style: const TextStyle(
                    color: Color(0xFFE50914),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
              tooltip: '清空所有收藏',
              onPressed: () => FavoritesBody.confirmClearAll(context, _favoritesManager),
            ),
        ],
      ),
      body: const FavoritesBody(),
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE50914), size: 24),
            SizedBox(width: 8),
            Text('清空所有收藏？', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          '確定要清空所有收藏的節目嗎？此操作將移除全部收藏項目。',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
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
            child: const Text('確認清空', style: TextStyle(color: Colors.white)),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE50914).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 40,
                color: Color(0xFFE50914),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '尚未加入任何收藏',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '在首頁或播放器點擊 ❤️ 即可收藏至此，隨時觀看！',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
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
