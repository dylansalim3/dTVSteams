import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'catalog/parser.dart';
import 'catalog/show_channel.dart';
import 'services/download_manager.dart';
import 'services/favorites_manager.dart';
import 'services/playback_history_manager.dart';
import 'services/settings_manager.dart';
import 'services/update_manager.dart';
import 'ui/about_update_dialog.dart';
import 'ui/app_tokens.dart';
import 'ui/downloads_screen.dart';
import 'ui/episode_card.dart';
import 'ui/player_screen.dart';
import 'ui/share_dialog.dart';

export 'ui/episode_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppSystemUi.restoreNormalChrome();
  runApp(const DTVSteamsApp());
}

class DTVSteamsApp extends StatelessWidget {
  const DTVSteamsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsManager();
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        AppColors.setThemeById(settings.themeId);
        return MaterialApp(
          title: 'dTVSteams',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: AppColors.brightness,
            scaffoldBackgroundColor: AppColors.canvas,
            primaryColor: AppColors.accent,
            dividerColor: AppColors.borderSeparator,
            colorScheme: ColorScheme(
              brightness: AppColors.brightness,
              primary: AppColors.accent,
              onPrimary: AppColors.onAccent,
              secondary: AppColors.accent,
              onSecondary: AppColors.onAccent,
              error: AppPrimitives.red500,
              onError: Colors.white,
              surface: AppColors.surfaceSecondary,
              onSurface: AppColors.textPrimary,
            ),
          ),
          home: const HomeScreen(),
        );
      },
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

  // Search & Filter state
  String searchQuery = '';
  String selectedYear = '全部';
  bool isSortAscending = false;
  static const List<String> yearOptions = ['全部', '2026', '2025', '2024', '2023', '2022', '經典懷舊'];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DownloadManager _downloadManager = DownloadManager();
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();
  final UpdateManager _updateManager = UpdateManager();
  final FavoritesManager _favoritesManager = FavoritesManager();

  @override
  void initState() {
    super.initState();
    _downloadManager.addListener(_onDownloadUpdate);
    _downloadManager.init();
    _historyManager.addListener(_onDownloadUpdate);
    _historyManager.init();
    _updateManager.addListener(_onDownloadUpdate);
    _updateManager.init();
    _favoritesManager.addListener(_onDownloadUpdate);
    _favoritesManager.init();
    _loadCatalog();
    _checkRemoteUpdate();
  }

  Future<void> _checkRemoteUpdate() async {
    // Ensure native version and cache are initialized before checking remote updates
    await _updateManager.init();
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
    _favoritesManager.removeListener(_onDownloadUpdate);
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
      useSafeArea: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
            border: Border(
              top: BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          child: SafeArea(
            top: true,
            bottom: true,
            minimum: const EdgeInsets.only(top: AppSpacing.sm),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg + 4,
                AppSpacing.sm,
                AppSpacing.lg + 4,
                (bottomInset + AppSpacing.xl) / 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.borderDefault,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Icon(Icons.tv_rounded, color: AppColors.accent, size: 18),
                            ),
                            const SizedBox(width: AppSpacing.md - 2),
                            Flexible(
                              child: Text(
                                '切換節目頻道 (Channels)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.title3Semibold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                    '選擇您想觀賞的綜藝節目，各頻道具備獨立集數清單與分頁快取',
                    style: AppType.bodyRegular.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Channel List
                  ...ShowChannels.all.map((ch) {
                    final isSelected = ch.id == currentChannel.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Material(
                        color: isSelected ? AppColors.accentSoft : AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(AppRadius.control + 2),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.control + 2),
                          onTap: () {
                            Navigator.pop(ctx);
                            _switchChannel(ch);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.control + 2),
                              border: Border.all(
                                color: isSelected ? AppColors.accent : AppColors.borderSubtle,
                                width: isSelected ? 1.5 : 1,
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
                                        ? AppColors.accent.withValues(alpha: 0.22)
                                        : AppColors.surfacePrimary,
                                    borderRadius: BorderRadius.circular(AppRadius.control),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accent.withValues(alpha: 0.45)
                                          : AppColors.borderSubtle,
                                    ),
                                  ),
                                  child: Text(ch.iconEmoji, style: const TextStyle(fontSize: 18)),
                                ),
                                const SizedBox(width: AppSpacing.md + 2),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              ch.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppType.headlineMedium.copyWith(
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Flexible(
                                            child: Text(
                                              ch.englishName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppType.caption1Regular.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ch.tagline,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.caption1Regular.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
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
        builder: (_) => NativePlayerScreen(
          episode: ep,
          initialPartIndex: targetPartIndex,
          playlist: displayEpisodes,
        ),
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

  bool _matchesYear(CatalogEpisode ep, String year) {
    if (year == '全部') return true;
    if (year == '經典懷舊') {
      final date = ep.date.trim();
      if (date.length >= 4) {
        final y = int.tryParse(date.substring(0, 4));
        if (y != null && y <= 2021) return true;
      }
      final match = RegExp(r'(20\d\d)').firstMatch(ep.title);
      if (match != null) {
        final y = int.tryParse(match.group(1)!);
        if (y != null && y <= 2021) return true;
      }
      return false;
    }
    return ep.date.startsWith(year) || ep.title.contains(year);
  }

  int _compareEpisodes(CatalogEpisode a, CatalogEpisode b) {
    final res = CatalogParser.compareDateDescending(a, b);
    return isSortAscending ? -res : res;
  }

  List<CatalogEpisode> get filteredEpisodes {
    if (searchQuery.isEmpty && selectedYear == '全部') return allEpisodes;
    final q = searchQuery.toLowerCase();
    return allEpisodes.where((ep) {
      final matchSearch = searchQuery.isEmpty ||
          ep.title.toLowerCase().contains(q) ||
          ep.date.toLowerCase().contains(q) ||
          ep.overview.toLowerCase().contains(q) ||
          ep.tags.any((t) => t.toLowerCase().contains(q));
      final matchYear = _matchesYear(ep, selectedYear);
      return matchSearch && matchYear;
    }).toList();
  }

  List<CatalogEpisode> get displayEpisodes {
    final isFiltering = searchQuery.isNotEmpty || selectedYear != '全部';

    if (isFiltering) {
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
        final matchSearch = searchQuery.isEmpty ||
            ep.title.toLowerCase().contains(q) ||
            ep.date.toLowerCase().contains(q) ||
            ep.overview.toLowerCase().contains(q) ||
            ep.tags.any((t) => t.toLowerCase().contains(q));
        final matchYear = _matchesYear(ep, selectedYear);
        return matchSearch && matchYear;
      }).toList();

      matched.sort(_compareEpisodes);

      const pageSize = 10;
      final startIndex = (currentPage - 1) * pageSize;
      if (startIndex >= matched.length) {
        return matched.isEmpty ? [] : matched.take(pageSize).toList();
      }
      return matched.skip(startIndex).take(pageSize).toList();
    }

    final paged = _pageCache[currentPage] ?? (currentPage == 1 ? allEpisodes : []);
    final sorted = List<CatalogEpisode>.from(paged)..sort(_compareEpisodes);
    return sorted;
  }

  int get totalPages {
    final isFiltering = searchQuery.isNotEmpty || selectedYear != '全部';
    if (isFiltering) {
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
        final matchSearch = searchQuery.isEmpty ||
            ep.title.toLowerCase().contains(q) ||
            ep.date.toLowerCase().contains(q) ||
            ep.overview.toLowerCase().contains(q) ||
            ep.tags.any((t) => t.toLowerCase().contains(q));
        final matchYear = _matchesYear(ep, selectedYear);
        return matchSearch && matchYear;
      }).length;
      return (matchCount / 10).ceil().clamp(1, 99);
    }
    return (currentPage + 4).clamp(10, 99);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    final currentDisplayEpisodes = displayEpisodes;
    final downloadedCount = _downloadManager.completedDownloads.length;
    final activeCount = _downloadManager.activeDownloads.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.normalOverlayStyle,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Top App Bar (BoardUI dark secondary surface + hairline bottom separator)
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isCompact = screenWidth < 370;
                  final isMedium = screenWidth < 430;
                  final btnPadding = isCompact
                      ? const EdgeInsets.all(2)
                      : (isMedium ? const EdgeInsets.all(4) : const EdgeInsets.all(6));
                  final btnConstraints = BoxConstraints(
                    minWidth: isCompact ? 32 : (isMedium ? 36 : 40),
                    minHeight: isCompact ? 32 : (isMedium ? 36 : 40),
                  );

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      border: Border(
                        bottom: BorderSide(color: AppColors.borderSeparator),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8.0 : (isMedium ? 12.0 : 16.0),
                      vertical: 10.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Section: Brand Logo + Channel Switcher
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(AppRadius.badge),
                                ),
                                child: Text(
                                  'dTV',
                                  style: TextStyle(
                                    color: AppColors.onAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              if (!isCompact) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'STEAMS',
                                  style: AppType.body2Medium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                              SizedBox(width: isCompact ? 6 : 10),

                              // Channel Switcher Selector (BoardUI rounded-2lg control)
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: isCompact ? 96 : (isMedium ? 132 : 165)),
                                  child: TvFocusableButton(
                                    onPressed: _showChannelPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfacePrimary,
                                        borderRadius: BorderRadius.circular(AppRadius.control),
                                        border: Border.all(color: AppColors.borderSubtle),
                                        boxShadow: AppShadows.card,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(currentChannel.iconEmoji, style: const TextStyle(fontSize: 12)),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              currentChannel.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppType.caption1Semibold,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            color: AppColors.textSecondary,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons: Downloads (Library), Refresh, Settings
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TvFocusableButton(
                              onPressed: _openDownloads,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: btnPadding,
                                constraints: btnConstraints,
                                icon: Icon(
                                  Icons.folder_special,
                                  size: 20,
                                  color: (activeCount > 0 || downloadedCount > 0)
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                                tooltip: '下載庫',
                                onPressed: _openDownloads,
                              ),
                            ),
                            TvFocusableButton(
                              onPressed: () => refreshCatalog(),
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: btnPadding,
                                constraints: btnConstraints,
                                icon: isRefreshing
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.accent,
                                        ),
                                      )
                                    : Icon(Icons.refresh, size: 20, color: AppColors.textSecondary),
                                tooltip: '刷新',
                                onPressed: () => refreshCatalog(),
                              ),
                            ),
                            TvFocusableButton(
                              onPressed: () => AboutUpdateDialog.show(context, _updateManager),
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: btnPadding,
                                constraints: btnConstraints,
                                icon: Icon(
                                  _updateManager.updateAvailable
                                      ? Icons.system_update_alt
                                      : Icons.settings_outlined,
                                  size: 20,
                                  color: _updateManager.updateAvailable
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                                tooltip: '設定與關於',
                                onPressed: () => AboutUpdateDialog.show(context, _updateManager),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

            // BoardUI SearchField (10px radius-2lg + hairline border)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: AppColors.borderDefault.withValues(alpha: 0.7)),
                    boxShadow: AppShadows.card,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 19, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: AppType.bodyRegular.copyWith(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '搜尋集數、日期 (如 2026-11-08) 或地點 (台北、宜蘭)...',
                            hintStyle: AppType.body2Medium.copyWith(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() {
                            searchQuery = val.trim();
                            currentPage = 1;
                          }),
                        ),
                      ),
                      if (searchQuery.isNotEmpty)
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              searchQuery = '';
                              currentPage = 1;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfacePrimary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Year Filter Chips & Sort Order Switcher (BoardUI Chip & Secondary Button styling)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs + 2, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: yearOptions.map((year) {
                            final isSelected = selectedYear == year;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: FilterChip(
                                label: Text(
                                  year,
                                  style: (isSelected ? AppType.caption1Semibold : AppType.caption1Medium).copyWith(
                                    fontFeatures: AppType.tabular,
                                    color: isSelected ? AppColors.onAccent : AppColors.textSecondary,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.accent,
                                backgroundColor: AppColors.surfaceSecondary,
                                checkmarkColor: AppColors.onAccent,
                                showCheckmark: false,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.badge),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.accent : AppColors.borderSubtle,
                                  ),
                                ),
                                onSelected: (val) {
                                  setState(() {
                                    selectedYear = year;
                                    currentPage = 1;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      onTap: () {
                        setState(() {
                          isSortAscending = !isSortAscending;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSortAscending ? AppColors.accent : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(AppRadius.control),
                          border: Border.all(
                            color: isSortAscending ? AppColors.accent : AppColors.borderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 14,
                              color: isSortAscending ? AppColors.onAccent : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSortAscending ? '舊到新' : '新到舊',
                              style: AppType.caption1Semibold.copyWith(
                                color: isSortAscending ? AppColors.onAccent : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

            // Section Status Strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '最新劇集與節目 (Episodes)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.title3Semibold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePrimary,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        '(${currentDisplayEpisodes.length} 集)',
                        style: AppType.caption1Semibold.copyWith(
                          color: AppColors.textSecondary,
                          fontFeatures: AppType.tabular,
                        ),
                      ),
                    ),
                    if (refreshStatus != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          refreshStatus!,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: AppType.caption2Medium.copyWith(color: AppColors.success),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

            // 1-by-1 Vertical Feed
            if (isLoadingPage && currentDisplayEpisodes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.accent),
                      const SizedBox(height: AppSpacing.lg),
                      Text('載入最新集數中...', style: AppType.bodyRegular),
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
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.xl,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(AppRadius.modal),
                          border: Border.all(color: AppColors.borderSeparator),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.surfacePrimary,
                                borderRadius: BorderRadius.circular(AppRadius.control),
                              ),
                              child: Icon(
                                Icons.movie_filter_outlined,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text('無符合篩選條件之集數', style: AppType.bodyMedium),
                            if (searchQuery.isNotEmpty || selectedYear != '全部') ...[
                              const SizedBox(height: AppSpacing.md),
                              OutlinedButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    searchQuery = '';
                                    selectedYear = '全部';
                                    currentPage = 1;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: BorderSide(color: AppColors.borderDefault),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.control),
                                  ),
                                ),
                                child: Text('重設篩選條件', style: AppType.body2Medium),
                              ),
                            ],
                          ],
                        ),
                      ),
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
                      onShareTapped: () => showShareDialog(context, ep),
                    );
                  },
                  childCount: currentDisplayEpisodes.length + 1,
                ),
              ),
          ],
        ),
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
                  color: currentPage > 1 ? AppColors.surfaceSecondary : AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: currentPage > 1 ? AppColors.borderDefault : AppColors.borderSeparator,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 11,
                      color: currentPage > 1 ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '上一頁',
                      style: AppType.caption1Semibold.copyWith(
                        color: currentPage > 1 ? AppColors.textPrimary : AppColors.textTertiary,
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
                      color: p == currentPage ? AppColors.accent : AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: p == currentPage ? AppColors.accent : AppColors.borderSubtle,
                      ),
                    ),
                    child: (isLoading && p == currentPage)
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          )
                        : Text(
                            '$p',
                            style: AppType.bodyMedium.copyWith(
                              fontFeatures: AppType.tabular,
                              fontWeight: p == currentPage ? FontWeight.w700 : FontWeight.w500,
                              color: p == currentPage ? AppColors.onAccent : AppColors.textSecondary,
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
                      ? AppColors.surfaceSecondary
                      : AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: currentPage < effectiveTotal
                        ? AppColors.borderDefault
                        : AppColors.borderSeparator,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '下一頁',
                      style: AppType.caption1Semibold.copyWith(
                        color: currentPage < effectiveTotal
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 11,
                      color: currentPage < effectiveTotal
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
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
