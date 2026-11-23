import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'catalog/parser.dart';
import 'catalog/show_channel.dart';
import 'services/download_manager.dart';
import 'services/playback_history_manager.dart';
import 'ui/downloads_screen.dart';
import 'ui/player_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _downloadManager.addListener(_onDownloadUpdate);
    _downloadManager.init();
    _historyManager.addListener(_onDownloadUpdate);
    _historyManager.init();
    _loadCatalog();
  }

  void _onDownloadUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _downloadManager.removeListener(_onDownloadUpdate);
    _historyManager.removeListener(_onDownloadUpdate);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    if (widget.initialEpisodes != null && widget.initialEpisodes!.isNotEmpty) {
      setState(() {
        allEpisodes = widget.initialEpisodes!;
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
            .map((e) => CatalogEpisode.fromJson(e as Map<String, dynamic>))
            .toList();
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

    final fallback = currentChannel.fallbackEpisodes.isNotEmpty
        ? currentChannel.fallbackEpisodes
        : ShowChannels.defaultChannel.fallbackEpisodes;
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
        final parsed = CatalogParser.parseList(res.body, defaultShowName: currentChannel.name);
        if (parsed.isNotEmpty && mounted) {
          final existingUrls = allEpisodes.map((e) => e.url).toSet();
          final newEps = parsed.where((p) => !existingUrls.contains(p.url)).toList();
          setState(() {
            if (newEps.isNotEmpty) {
              allEpisodes = [...newEps, ...allEpisodes];
            } else {
              allEpisodes = parsed;
            }
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
        allEpisodes = cached;
      } else if (newChannel.fallbackEpisodes.isNotEmpty) {
        allEpisodes = newChannel.fallbackEpisodes;
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
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
        final parsed = CatalogParser.parseList(res.body, defaultShowName: currentChannel.name);
        if (parsed.isNotEmpty && mounted) {
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

      const pageSize = 10;
      final startIndex = (currentPage - 1) * pageSize;
      if (startIndex >= matched.length) {
        return matched.isEmpty ? [] : matched.take(pageSize).toList();
      }
      return matched.skip(startIndex).take(pageSize).toList();
    }

    return _pageCache[currentPage] ?? (currentPage == 1 ? allEpisodes : []);
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
                child: Row(
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
                    const SizedBox(width: 6),

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
                            Text(
                              currentChannel.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 1),
                            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 15),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Downloads Folder Button
                    TvFocusableButton(
                      onPressed: _openDownloads,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(
                          color: (activeCount > 0 || downloadedCount > 0)
                              ? const Color(0xFFE50914).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (activeCount > 0 || downloadedCount > 0) ? const Color(0xFFE50914) : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (activeCount > 0) ...[
                              const SizedBox(
                                width: 11,
                                height: 11,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFE50914),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '下載中 ($activeCount)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFE50914),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else ...[
                              Icon(
                                Icons.folder_special,
                                size: 14,
                                color: downloadedCount > 0 ? const Color(0xFFE50914) : Colors.white70,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                downloadedCount > 0 ? '下載庫 ($downloadedCount)' : '下載庫',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: downloadedCount > 0 ? Colors.white : Colors.white70,
                                  fontWeight: downloadedCount > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),

                    // Refresh Button
                    TvFocusableButton(
                      onPressed: () => refreshCatalog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isRefreshing)
                              const SizedBox(
                                width: 11,
                                height: 11,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFE50914),
                                ),
                              )
                            else
                              const Icon(Icons.refresh, size: 13, color: Colors.white70),
                            const SizedBox(width: 3),
                            Text(
                              isRefreshing ? '更新中' : '刷新',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                    const Text(
                      '最新劇集與節目 (Episodes)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${currentDisplayEpisodes.length} 集)',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    const SizedBox(width: 8),
                    if (refreshStatus != null)
                      Expanded(
                        child: Text(
                          refreshStatus!,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF46D369)),
                        ),
                      ),
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

/// Triple-Ring Concentric Circular Progress Download Icon
/// Outer Ring: Part 1
/// Middle Ring: Part 2
/// Inner Ring: Part 3
class TripleCircleDownloadButton extends StatelessWidget {
  final CatalogEpisode episode;
  final DownloadManager downloadManager;
  final VoidCallback onTap;

  const TripleCircleDownloadButton({
    super.key,
    required this.episode,
    required this.downloadManager,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = episode.parts;
    final totalParts = parts.isNotEmpty ? parts.length : 3;

    final progresses = <double>[];
    final isDownloadingList = <bool>[];
    final isDownloadedList = <bool>[];

    for (int i = 0; i < totalParts; i++) {
      if (i < parts.length) {
        final p = parts[i];
        final isDown = downloadManager.isDownloaded(episode.id, p.label);
        final isDl = downloadManager.isDownloading(episode.id, p.label);
        final item = downloadManager.getItem(episode.id, p.label);

        isDownloadedList.add(isDown);
        isDownloadingList.add(isDl);
        progresses.add(isDown ? 1.0 : (isDl && item != null ? item.progress : 0.0));
      } else {
        isDownloadedList.add(false);
        isDownloadingList.add(false);
        progresses.add(0.0);
      }
    }

    final allDownloaded = isDownloadedList.isNotEmpty && isDownloadedList.every((d) => d);
    final anyDownloading = isDownloadingList.any((d) => d);
    final anyDownloaded = isDownloadedList.any((d) => d);

    return Tooltip(
      message: '下載管理 (選擇分段)',
      child: TvFocusableButton(
        onPressed: onTap,
        child: GestureDetector(
          key: Key('episode_download_btn_${episode.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black26,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(38, 38),
                  painter: TripleRingPainter(
                    progresses: progresses,
                    isDownloadingList: isDownloadingList,
                    isDownloadedList: isDownloadedList,
                  ),
                ),
                Icon(
                  allDownloaded
                      ? Icons.download_done
                      : (anyDownloading
                          ? Icons.arrow_downward
                          : (anyDownloaded ? Icons.download_done : Icons.download_outlined)),
                  size: 15,
                  color: allDownloaded
                      ? const Color(0xFF46D369)
                      : (anyDownloading
                          ? const Color(0xFFE50914)
                          : (anyDownloaded ? const Color(0xFF46D369) : Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pie-Segmented Surround Border Painter (3 quadrants/sectors, NO inner border)
/// Outer ring is partitioned into 3 equal 120° pie sectors representing Part 1, Part 2, and Part 3.
class TripleRingPainter extends CustomPainter {
  final List<double> progresses;
  final List<bool> isDownloadingList;
  final List<bool> isDownloadedList;

  TripleRingPainter({
    required this.progresses,
    required this.isDownloadingList,
    required this.isDownloadedList,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Single surround border (NO inner border)
    final radius = (size.width / 2) - 3.0; // e.g. 16.0 for 38x38
    const totalSegments = 3;
    const gap = 0.16; // ~9 degrees separation gap between pie quadrants
    final segmentSpan = (2 * math.pi) / totalSegments;
    final arcSweep = segmentSpan - gap;

    for (int i = 0; i < totalSegments; i++) {
      final startAngle = -math.pi / 2 + (i * segmentSpan) + (gap / 2);
      final isDown = i < isDownloadedList.length && isDownloadedList[i];
      final isDl = i < isDownloadingList.length && isDownloadingList[i];
      final progress = (i < progresses.length ? progresses[i] : 0.0).clamp(0.0, 1.0);

      // 1. Background track for this pie quadrant
      final trackPaint = Paint()
        ..color = isDown
            ? const Color(0xFF46D369).withValues(alpha: 0.25)
            : (isDl ? const Color(0xFFE50914).withValues(alpha: 0.2) : Colors.white24)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcSweep,
        false,
        trackPaint,
      );

      // 2. Downloaded / Downloading fill
      if (isDown) {
        // Complete quadrant in vibrant green
        final donePaint = Paint()
          ..color = const Color(0xFF46D369)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.8;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          arcSweep,
          false,
          donePaint,
        );
      } else if (isDl) {
        // Animated progress arc in Netflix red
        final dlPaint = Paint()
          ..color = const Color(0xFFE50914)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.0;

        final fillSweep = progress > 0 ? arcSweep * progress : arcSweep * 0.4;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          fillSweep,
          false,
          dlPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant TripleRingPainter oldDelegate) => true;
}

/// Download Part Selection Modal Sheet (Popover)
void _showDownloadSelectionSheet(
  BuildContext context,
  CatalogEpisode episode,
  DownloadManager downloadManager,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final parts = episode.parts;
          final downloadedCount = parts.where((p) => downloadManager.isDownloaded(episode.id, p.label)).length;
          final allDone = parts.isNotEmpty && downloadedCount == parts.length;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Title & Download Summary
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.download_for_offline, color: Color(0xFFE50914), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '下載分段管理',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              allDone
                                  ? '已下載全部分段 (${parts.length}/${parts.length}) • 可離線觀看'
                                  : '已下載 $downloadedCount/${parts.length} 個分段 • 點擊選擇分段下載',
                              style: TextStyle(
                                fontSize: 12,
                                color: allDone ? const Color(0xFF46D369) : Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),

                  // One-tap Batch Download All Parts Button
                  if (!allDone) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE50914),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.download_for_offline, size: 18),
                        label: Text(
                          '一鍵下載全集 (剩餘 ${parts.length - downloadedCount} 個未下載分段)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          downloadManager.startBatchDownload(episode);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已開始批量下載「${episode.title}」所有分段'),
                              backgroundColor: const Color(0xFFE50914),
                              action: SnackBarAction(
                                label: '查看進度',
                                textColor: Colors.white,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // List of Parts with Downloaded vs Not-Downloaded Standoff
                  for (int i = 0; i < parts.length; i++) ...[
                    Builder(
                      builder: (partContext) {
                        final p = parts[i];
                        final isDown = downloadManager.isDownloaded(episode.id, p.label);
                        final isDl = downloadManager.isDownloading(episode.id, p.label);
                        final item = downloadManager.getItem(episode.id, p.label);
                        final sizeStr = item != null && item.downloadedBytes > 0
                            ? downloadManager.formatBytes(item.downloadedBytes)
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDown
                                ? const Color(0xFF13381B)
                                : (isDl ? const Color(0xFF331111) : const Color(0xFF262626)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDown
                                  ? const Color(0xFF46D369)
                                  : (isDl ? const Color(0xFFE50914) : Colors.white12),
                              width: isDown ? 1.4 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Part Label & Status Badge
                              Row(
                                children: [
                                  // Part Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDown ? const Color(0xFF46D369) : const Color(0xFFE50914),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      p.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Status Badge
                                  if (isDown)
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, size: 14, color: Color(0xFF46D369)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '已下載完成 ${sizeStr.isNotEmpty ? "($sizeStr)" : ""}',
                                          style: const TextStyle(
                                            color: Color(0xFF46D369),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (isDl)
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE50914)),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '下載中 ${item != null ? item.progressPercentage : ""}',
                                          style: const TextStyle(
                                            color: Color(0xFFE50914),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    const Text(
                                      '未下載 (支援離線播放)',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),

                                  const Spacer(),

                                  // Action for Already Downloaded: Play or Delete
                                  if (isDown) ...[
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      icon: const Icon(Icons.play_circle_fill, color: Color(0xFF46D369), size: 26),
                                      tooltip: '播放本機離線檔案',
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        final localFile = downloadManager.getLocalFile(episode.id, p.label);
                                        if (localFile != null) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => NativePlayerScreen(
                                                episode: episode,
                                                initialPartIndex: i,
                                                localFile: localFile,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                                      tooltip: '刪除下載檔案',
                                      onPressed: () {
                                        downloadManager.deleteDownload(episode.id, p.label);
                                        setSheetState(() {});
                                      },
                                    ),
                                  ],
                                ],
                              ),

                              // Row 2: Single Full 1080p Download Option (No 快速版)
                              if (!isDown && !isDl) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE50914),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    icon: const Icon(Icons.download, size: 16),
                                    label: const Text('下載全集 (1080p FHD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      downloadManager.startDownload(episode, p);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('已開始下載 ${episode.title} - ${p.label}'),
                                          backgroundColor: const Color(0xFFE50914),
                                          action: SnackBarAction(
                                            label: '查看進度',
                                            textColor: Colors.white,
                                            onPressed: () => Navigator.of(context).push(
                                              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Bottom Link to Downloads Screen
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.folder_special, size: 16, color: Colors.white70),
                      label: const Text('前往下載資料夾 (Downloads)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// High-Density List View Episode Item (No preview image, no avatar, clean metadata)
class YouTubeEpisodeCard extends StatelessWidget {
  final CatalogEpisode episode;
  final VoidCallback onPlayTapped;
  final Function(int) onPartTapped;

  const YouTubeEpisodeCard({
    super.key,
    required this.episode,
    required this.onPlayTapped,
    required this.onPartTapped,
  });

  @override
  Widget build(BuildContext context) {
    final location = CatalogParser.extractLocation(episode.title);
    final downloadManager = DownloadManager();
    final historyManager = PlaybackHistoryManager();
    final downloadedParts = episode.parts.where((p) => downloadManager.isDownloaded(episode.id, p.label)).length;
    final isAnyDownloading = episode.parts.any((p) => downloadManager.isDownloading(episode.id, p.label));
    final hasAnyDownloaded = downloadedParts > 0;
    final allDownloaded = episode.parts.isNotEmpty && downloadedParts == episode.parts.length;
    final isEpDone = historyManager.isEpisodeCompleted(episode.id, episode.parts.length);
    final epProgress = historyManager.getEpisodeProgress(episode.id, episode.parts.length);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Play Indicator + Title & Clean Metadata + Download Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Play Icon
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPlayTapped,
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(top: 2, right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Color(0xFFE50914),
                      size: 20,
                    ),
                  ),
                ),

                // Title and Clean Subtitle (No Avatar, No xx% Match, No x分段)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPlayTapped,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              episode.date,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (location.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '📍 $location',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFE50914),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Text(
                                '1080p FHD',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isEpDone) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF46D369).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFF46D369).withValues(alpha: 0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 10, color: Color(0xFF46D369)),
                                    SizedBox(width: 2),
                                    Text(
                                      '已看完',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF46D369),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (downloadedParts > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF46D369).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFF46D369).withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, size: 10, color: Color(0xFF46D369)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '已載 $downloadedParts/${episode.parts.length}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF46D369),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Triple-Ring Concentric Circular Progress Download Button (Part 1, Part 2, Part 3)
                TripleCircleDownloadButton(
                  episode: episode,
                  downloadManager: downloadManager,
                  onTap: () => _showDownloadSelectionSheet(context, episode, downloadManager),
                ),
              ],
            ),

            // Bottom: Chapter / Part Quick Selectors (Part 1, Part 2, Part 3)
            if (episode.parts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(episode.parts.length, (idx) {
                  final p = episode.parts[idx];
                  final isPartDown = downloadManager.isDownloaded(episode.id, p.label);
                  final isPartDownloading = downloadManager.isDownloading(episode.id, p.label);
                  final item = downloadManager.getItem(episode.id, p.label);
                  final partRec = historyManager.getRecord(episode.id, p.label);
                  final isPartWatched = partRec != null && partRec.isCompleted;
                  final inProgressWatched = partRec != null && !partRec.isCompleted && partRec.progress > 0.05;

                  String chipLabel = p.label;
                  if (isPartDown) {
                    chipLabel = '${p.label} (已下載)';
                  } else if (isPartDownloading && item != null) {
                    chipLabel = '${p.label} ${(item.progress * 100).toInt()}%';
                  } else if (isPartWatched) {
                    chipLabel = '${p.label} ✓';
                  } else if (inProgressWatched) {
                    chipLabel = '${p.label} (${(partRec.progress * 100).toInt()}%)';
                  }

                  return GestureDetector(
                    onLongPress: () => _showDownloadSelectionSheet(context, episode, downloadManager),
                    child: TvFocusableButton(
                      onPressed: () => onPartTapped(idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isPartDown
                              ? const Color(0xFF13381B)
                              : (isPartDownloading
                                  ? const Color(0xFF331111)
                                  : (isPartWatched ? const Color(0xFF1F2E22) : const Color(0xFF262626))),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPartDown
                                ? const Color(0xFF46D369)
                                : (isPartDownloading
                                    ? const Color(0xFFE50914)
                                    : (isPartWatched ? const Color(0xFF46D369).withValues(alpha: 0.6) : Colors.white12)),
                            width: isPartDown ? 1.4 : 1.0,
                          ),
                          boxShadow: isPartDown
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF46D369).withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPartDownloading)
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFE50914)),
                              )
                            else
                              Icon(
                                isPartDown ? Icons.check_circle : (isPartWatched ? Icons.check : Icons.play_arrow),
                                size: 12,
                                color: isPartDown
                                    ? const Color(0xFF46D369)
                                    : (isPartWatched ? const Color(0xFF46D369) : const Color(0xFFE50914)),
                              ),
                            const SizedBox(width: 4),
                            Text(
                              chipLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPartDown ? const Color(0xFF46D369) : (isPartWatched ? const Color(0xFF46D369) : Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],

            // Watch History Overall Progress Bar (YouTube/Netflix style)
            if (epProgress > 0.02) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: epProgress,
                  minHeight: 2.5,
                  color: const Color(0xFFE50914),
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// D-Pad focusable widget with glowing TV highlight
class TvFocusableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool autofocus;

  const TvFocusableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  State<TvFocusableButton> createState() => _TvFocusableButtonState();
}

class _TvFocusableButtonState extends State<TvFocusableButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.8),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          transform: _isFocused ? Matrix4.diagonal3Values(1.05, 1.05, 1.0) : Matrix4.identity(),
          child: widget.child,
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
