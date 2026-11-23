import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'catalog/parser.dart';
import 'catalog/show_channel.dart';
import 'services/download_manager.dart';
import 'services/playback_history_manager.dart';
import 'services/update_manager.dart';
import 'ui/about_update_dialog.dart';
import 'ui/downloads_screen.dart';
import 'ui/episode_card.dart';
import 'ui/player_screen.dart';

export 'ui/episode_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DTVSteamsApp());
}

class DTVSteamsApp extends StatelessWidget {
  const DTVSteamsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dTVSteams',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool autoRefresh;
  final List<CatalogEpisode>? initialEpisodes;
  const HomeScreen({super.key, this.autoRefresh = true, this.initialEpisodes});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ShowChannel currentChannel = ShowChannels.defaultChannel;
  List<CatalogEpisode> allEpisodes = [];
  final Map<String, Map<int, List<CatalogEpisode>>> _channelPageCache = {};
  Map<int, List<CatalogEpisode>> get _pageCache =>
      _channelPageCache.putIfAbsent(currentChannel.id, () => {});

  bool isLoading = true;
  bool isRefreshing = false;
  bool isLoadingPage = false;
  int currentPage = 1;
  String? refreshStatus;
  CatalogEpisode? selectedEpisode;

  // Search state (Category pills removed per user request)
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DownloadManager _downloadManager = DownloadManager();
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();
  final UpdateManager _updateManager = UpdateManager();

  @override
  void initState() {
    super.initState();
    _downloadManager.addListener(_onDownloadUpdate);
    _downloadManager.init();
    _historyManager.addListener(_onDownloadUpdate);
    _historyManager.init();
    _updateManager.addListener(_onDownloadUpdate);
    _updateManager.init();
    _loadCatalog();
    _checkRemoteUpdate();
  }

  Future<void> _checkRemoteUpdate() async {
    // Silent check on startup with 12h cooldown
    final update = await _updateManager.checkForUpdate();
    if (mounted && update != null && update.hasUpdate) {
      if (_updateManager.dismissedVersion != update.latestVersion) {
        AboutUpdateDialog.showUpdatePrompt(context, _updateManager);
      }
    }
  }

  void _onDownloadUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _downloadManager.removeListener(_onDownloadUpdate);
    _historyManager.removeListener(_onDownloadUpdate);
    _updateManager.removeListener(_onDownloadUpdate);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    if (widget.initialEpisodes != null && widget.initialEpisodes!.isNotEmpty) {
      final sortedInitial = List<CatalogEpisode>.from(widget.initialEpisodes!)
        ..sort(CatalogParser.compareDateDescending);
      setState(() {
        allEpisodes = sortedInitial;
        _pageCache[1] = allEpisodes;
        selectedEpisode = allEpisodes.first;
        isLoading = false;
      });
      return;
    }
    try {
      if (currentChannel.id == ShowChannels.defaultChannel.id) {
        final jsonStr = await rootBundle.loadString('assets/catalog.json');
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final eps = (data['episodes'] as List<dynamic>)
            .map((e) {
              final ep = CatalogEpisode.fromJson(e as Map<String, dynamic>);
              return ep.copyWith(
                showId: ep.showId.isNotEmpty ? ep.showId : ShowChannels.defaultChannel.id,
                showName: ep.showName.isNotEmpty ? ep.showName : ShowChannels.defaultChannel.name,
              );
            })
            .toList();
        eps.sort(CatalogParser.compareDateDescending);
        setState(() {
          allEpisodes = eps;
          _pageCache[1] = eps;
          selectedEpisode = eps.isNotEmpty ? eps.first : null;
          isLoading = false;
        });
        if (widget.autoRefresh) {
          _refreshCatalogInBackground();
        }
        return;
      }
    } catch (_) {}

    final fallback = List<CatalogEpisode>.from(
      currentChannel.fallbackEpisodes.isNotEmpty
          ? currentChannel.fallbackEpisodes
          : ShowChannels.defaultChannel.fallbackEpisodes,
    )..sort(CatalogParser.compareDateDescending);
    setState(() {
      allEpisodes = fallback;
      _pageCache[1] = fallback;
      selectedEpisode = fallback.isNotEmpty ? fallback.first : null;
      isLoading = false;
    });
    if (widget.autoRefresh) {
      _refreshCatalogInBackground();
    }
  }

  Future<void> _refreshCatalogInBackground() async {
    await refreshCatalog(silent: true);
  }

  Future<void> refreshCatalog({bool silent = false}) async {
    if (isRefreshing) return;
    if (!silent) {
      setState(() => isRefreshing = true);
    }
    try {
      final res = await http
          .get(
            Uri.parse(currentChannel.categoryUrl),
            headers: const {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final parsed = CatalogParser.parseList(
          res.body,
          showId: currentChannel.id,
          defaultShowName: currentChannel.name,
        );
        if (parsed.isNotEmpty && mounted) {
          final existingUrls = allEpisodes.map((e) => e.url).toSet();
          final newEps = parsed.where((p) => !existingUrls.contains(p.url)).toList();
          final combined = (newEps.isNotEmpty ? [...newEps, ...allEpisodes] : parsed)
            ..sort(CatalogParser.compareDateDescending);
          setState(() {
            allEpisodes = combined;
            _pageCache[1] = allEpisodes;
            refreshStatus = '${currentChannel.name} 目錄已更新 (${parsed.length} 部最新集數)';
            currentPage = 1;
          });
        }
      }
    } catch (_) {
      // Offline / network failure: keep cached items cleanly
    } finally {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  void _switchChannel(ShowChannel newChannel) {
    if (newChannel.id == currentChannel.id) return;
    setState(() {
      currentChannel = newChannel;
      currentPage = 1;
      searchQuery = '';
      _searchController.clear();

      final cached = _channelPageCache[newChannel.id]?[1];
      if (cached != null && cached.isNotEmpty) {
        allEpisodes = List<CatalogEpisode>.from(cached)..sort(CatalogParser.compareDateDescending);
      } else if (newChannel.fallbackEpisodes.isNotEmpty) {
        allEpisodes = List<CatalogEpisode>.from(newChannel.fallbackEpisodes)..sort(CatalogParser.compareDateDescending);
        _pageCache[1] = allEpisodes;
      } else {
        allEpisodes = [];
      }
      selectedEpisode = allEpisodes.isNotEmpty ? allEpisodes.first : null;
      refreshStatus = '已切換至「${newChannel.name}」';
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }

    if (widget.autoRefresh) {
      refreshCatalog(silent: true);
    }
  }

  void _showChannelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, (bottomInset + 24) / 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.tv, color: Color(0xFFE50914), size: 22),
                      SizedBox(width: 8),
                      Text(
                        '切換節目頻道 (Channels)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '選擇您想觀賞的綜藝節目，各頻道具備獨立集數清單與分頁快取',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Channel List
              ...ShowChannels.all.map((ch) {
                final isSelected = ch.id == currentChannel.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Material(
                    color: isSelected
                        ? const Color(0xFFE50914).withValues(alpha: 0.15)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
                        _switchChannel(ch);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFE50914) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE50914).withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Text(ch.iconEmoji, style: const TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        ch.name,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                          fontSize: 16,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        ch.englishName,
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ch.tagline,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white70 : Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Color(0xFFE50914), size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
    );
  }

  Future<void> goToPage(int page) async {
    if (page < 1 || page == currentPage || isLoadingPage) return;

    if (searchQuery.isNotEmpty) {
      setState(() {
        currentPage = page;
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    if (_pageCache.containsKey(page) && _pageCache[page]!.isNotEmpty) {
      setState(() {
        currentPage = page;
        refreshStatus = '第 $page 頁 (已載入 ${_pageCache[page]!.length} 部集數)';
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    setState(() {
      isLoadingPage = true;
      currentPage = page;
      refreshStatus = '載入第 $page 頁中...';
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    try {
      final url = currentChannel.pageUrl(page);
      final res = await http.get(
        Uri.parse(url),
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final parsed = CatalogParser.parseList(
          res.body,
          showId: currentChannel.id,
          defaultShowName: currentChannel.name,
        );
        if (parsed.isNotEmpty && mounted) {
          parsed.sort(CatalogParser.compareDateDescending);
          _pageCache[page] = parsed;
          setState(() {
            refreshStatus = '第 $page 頁 (載入 ${parsed.length} 部最新集數)';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          refreshStatus = '無法連線至第 $page 頁，已顯示離線快取';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingPage = false;
        });
      }
    }
  }

  Future<void> loadMoreEpisodes() => goToPage(currentPage + 1);

  void _openPlayer(CatalogEpisode ep, int partIndex) {
    int targetPartIndex = partIndex;
    if (partIndex == 0 && ep.parts.length > 1) {
      for (int i = 0; i < ep.parts.length; i++) {
        final rec = _historyManager.getRecord(ep.id, ep.parts[i].label);
        if (rec != null && !rec.isCompleted && rec.positionMs > 5000) {
          targetPartIndex = i;
          break;
        } else if (rec != null && rec.isCompleted && i + 1 < ep.parts.length) {
          targetPartIndex = i + 1;
        }
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NativePlayerScreen(episode: ep, initialPartIndex: targetPartIndex),
      ),
    );
  }

  void _openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DownloadsScreen(),
      ),
    );
  }

  List<CatalogEpisode> get filteredEpisodes {
    if (searchQuery.isEmpty) return allEpisodes;
    final q = searchQuery.toLowerCase();
    return allEpisodes.where((ep) {
      final matchTitle = ep.title.toLowerCase().contains(q);
      final matchDate = ep.date.toLowerCase().contains(q);
      final matchOverview = ep.overview.toLowerCase().contains(q);
      final matchTags = ep.tags.any((t) => t.toLowerCase().contains(q));
      return matchTitle || matchDate || matchOverview || matchTags;
    }).toList();
  }

  List<CatalogEpisode> get displayEpisodes {
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      final allKnown = <String, CatalogEpisode>{};
      for (final eps in _pageCache.values) {
        for (final ep in eps) {
          allKnown[ep.url] = ep;
        }
      }
      for (final ep in allEpisodes) {
        allKnown[ep.url] = ep;
      }
      final matched = allKnown.values.where((ep) {
        final matchTitle = ep.title.toLowerCase().contains(q);
        final matchDate = ep.date.toLowerCase().contains(q);
        final matchOverview = ep.overview.toLowerCase().contains(q);
        final matchTags = ep.tags.any((t) => t.toLowerCase().contains(q));
        return matchTitle || matchDate || matchOverview || matchTags;
      }).toList();

      matched.sort(CatalogParser.compareDateDescending);

      const pageSize = 10;
      final startIndex = (currentPage - 1) * pageSize;
      if (startIndex >= matched.length) {
        return matched.isEmpty ? [] : matched.take(pageSize).toList();
      }
      return matched.skip(startIndex).take(pageSize).toList();
    }

    final paged = _pageCache[currentPage] ?? (currentPage == 1 ? allEpisodes : []);
    final sorted = List<CatalogEpisode>.from(paged)..sort(CatalogParser.compareDateDescending);
    return sorted;
  }

  int get totalPages {
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      final allKnown = <String, CatalogEpisode>{};
      for (final eps in _pageCache.values) {
        for (final ep in eps) {
          allKnown[ep.url] = ep;
        }
      }
      for (final ep in allEpisodes) {
        allKnown[ep.url] = ep;
      }
      final matchCount = allKnown.values.where((ep) {
        final matchTitle = ep.title.toLowerCase().contains(q);
        final matchDate = ep.date.toLowerCase().contains(q);
        final matchOverview = ep.overview.toLowerCase().contains(q);
        final matchTags = ep.tags.any((t) => t.toLowerCase().contains(q));
        return matchTitle || matchDate || matchOverview || matchTags;
      }).length;
      return (matchCount / 10).ceil().clamp(1, 99);
    }
    return (currentPage + 4).clamp(10, 99);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }

    final currentDisplayEpisodes = displayEpisodes;
    final downloadedCount = _downloadManager.completedDownloads.length;
    final activeCount = _downloadManager.activeDownloads.length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Top App Bar with Logo, Download Folder Button, and Refresh
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                child: Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isCompact = screenWidth < 370;

                    return Row(
                      children: [
                        // Brand Logo
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'dTV',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 5),
                          const Text(
                            'STEAMS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                        SizedBox(width: isCompact ? 4 : 6),

                        // Channel Switcher Selector Button
                        TvFocusableButton(
                          onPressed: _showChannelPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE50914).withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(currentChannel.iconEmoji, style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 3),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: isCompact ? 70 : 130),
                                  child: Text(
                                    currentChannel.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 1),
                                const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 15),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),

                        // Action Buttons: Downloads, Refresh, Settings
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Downloads Folder Icon Button
                            TvFocusableButton(
                              onPressed: _openDownloads,
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(28, 28),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                icon: Icon(
                                  Icons.folder_special,
                                  color: (activeCount > 0 || downloadedCount > 0)
                                      ? const Color(0xFFE50914)
                                      : Colors.white70,
                                  size: 20,
                                ),
                                tooltip: '下載庫',
                                onPressed: _openDownloads,
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Refresh Icon Button
                            TvFocusableButton(
                              onPressed: () => refreshCatalog(),
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(28, 28),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                icon: isRefreshing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFE50914),
                                        ),
                                      )
                                    : const Icon(Icons.refresh, color: Colors.white70, size: 20),
                                tooltip: '刷新',
                                onPressed: () => refreshCatalog(),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Settings & Updates Icon Button
                            TvFocusableButton(
                              onPressed: () => AboutUpdateDialog.show(context, _updateManager),
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(28, 28),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                icon: Icon(
                                  _updateManager.updateAvailable
                                      ? Icons.system_update_alt
                                      : Icons.settings_outlined,
                                  color: _updateManager.updateAvailable
                                      ? const Color(0xFFE50914)
                                      : Colors.white70,
                                  size: 20,
                                ),
                                tooltip: '設定與關於',
                                onPressed: () => AboutUpdateDialog.show(context, _updateManager),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Clean Search Bar (Category pills removed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 20, color: Colors.white54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: '搜尋集數、日期 (如 2026-11-08) 或地點 (台北、宜蘭)...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() { searchQuery = val.trim(); currentPage = 1; }),
                        ),
                      ),
                      if (searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() { searchQuery = ''; currentPage = 1; });
                          },
                          child: const Icon(Icons.close, size: 18, color: Colors.white54),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Section Status Strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Flexible(
                      child: Text(
                        '最新劇集與節目 (Episodes)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${currentDisplayEpisodes.length} 集)',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    if (refreshStatus != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          refreshStatus!,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF46D369)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // 1-by-1 Vertical Feed (YouTube Mobile App Style)
            if (isLoadingPage && currentDisplayEpisodes.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE50914)),
                      SizedBox(height: 16),
                      Text('載入最新集數中...', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              )
            else if (currentDisplayEpisodes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      const Text('無符合篩選條件之集數', style: TextStyle(color: Colors.white54)),
                      const Spacer(),
                      GooglePaginationBar(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        isLoading: isLoadingPage,
                        onPageSelected: goToPage,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) {
                    // Google Search Style Numbered Pagination Bar at the end of the vertical feed
                    if (idx == currentDisplayEpisodes.length) {
                      return GooglePaginationBar(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        isLoading: isLoadingPage,
                        onPageSelected: goToPage,
                      );
                    }

                    final ep = currentDisplayEpisodes[idx];
                    return YouTubeEpisodeCard(
                      episode: ep,
                      onPlayTapped: () => _openPlayer(ep, 0),
                      onPartTapped: (partIdx) => _openPlayer(ep, partIdx),
                    );
                  },
                  childCount: currentDisplayEpisodes.length + 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}



/// Full-Width Numbered Pagination Bar
/// [< 上一頁] [1] [2] [3] [4] [5] [下一頁 >]
class GooglePaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final Function(int) onPageSelected;

  const GooglePaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTotal = totalPages < 1 ? 1 : totalPages;
    const windowSize = 5;
    // Sliding 5-page window centered on current page
    int startPage = (currentPage - 2).clamp(1, effectiveTotal > 4 ? effectiveTotal - 4 : 1);
    int endPage = (startPage + windowSize - 1).clamp(1, effectiveTotal);

    final pages = <int>[];
    for (int i = startPage; i <= endPage; i++) {
      pages.add(i);
    }
    if (pages.isEmpty) pages.add(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      child: Row(
        children: [
          // Previous Page Button
          Expanded(
            flex: 3,
            child: TvFocusableButton(
              key: const Key('page_btn_prev'),
              onPressed: (currentPage > 1 && !isLoading)
                  ? () => onPageSelected(currentPage - 1)
                  : () {},
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: currentPage > 1
                      ? const Color(0xFF222222)
                      : const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: currentPage > 1 ? Colors.white24 : Colors.white10,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 11,
                      color: currentPage > 1 ? Colors.white : Colors.white24,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '上一頁',
                      style: TextStyle(
                        fontSize: 12,
                        color: currentPage > 1 ? Colors.white : Colors.white24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Numbered Page Buttons [1] [2] [3] [4] [5]
          for (final p in pages) ...[
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TvFocusableButton(
                  key: Key('page_btn_$p'),
                  onPressed: (p != currentPage && !isLoading)
                      ? () => onPageSelected(p)
                      : () {},
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p == currentPage
                          ? const Color(0xFFE50914)
                          : const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: p == currentPage
                            ? const Color(0xFFE50914)
                            : Colors.white24,
                      ),
                      boxShadow: p == currentPage
                          ? [
                              BoxShadow(
                                color: const Color(0xFFE50914).withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: (isLoading && p == currentPage)
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            '$p',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: p == currentPage
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: p == currentPage ? Colors.white : Colors.white70,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),

          // Next Page Button
          Expanded(
            flex: 3,
            child: TvFocusableButton(
              key: const Key('page_btn_next'),
              onPressed: (currentPage < effectiveTotal && !isLoading)
                  ? () => onPageSelected(currentPage + 1)
                  : () {},
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: currentPage < effectiveTotal
                      ? const Color(0xFF222222)
                      : const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: currentPage < effectiveTotal
                        ? Colors.white24
                        : Colors.white10,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '下一頁',
                      style: TextStyle(
                        fontSize: 12,
                        color: currentPage < effectiveTotal
                            ? Colors.white
                            : Colors.white24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 11,
                      color: currentPage < effectiveTotal
                          ? Colors.white
                          : Colors.white24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
