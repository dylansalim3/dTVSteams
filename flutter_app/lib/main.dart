import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'catalog/parser.dart';
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
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          surface: Color(0xFF1F1F1F),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CatalogEpisode> episodes = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String? refreshStatus;
  CatalogEpisode? selectedEpisode;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/catalog.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final eps = (data['episodes'] as List<dynamic>)
          .map((e) => CatalogEpisode.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        episodes = eps;
        selectedEpisode = eps.isNotEmpty ? eps.first : null;
        isLoading = false;
      });
      // Background auto-refresh on entry
      _refreshCatalogInBackground();
    } catch (_) {
      final fallback = [
        CatalogEpisode(
          id: 'demo-1',
          title: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
          date: '2026-11-08',
          url: 'https://srgoideas.com/demo-1',
          overview: '黃隊與黑隊前進嘉義阿里山與市區展開命運奪壘戰！全新懲罰機制引爆全員危機感。',
          backdrop: 'https://image.tmdb.org/t/p/original/mDeUmPe4MF35him3nvMeeb2GYv.jpg',
          poster: 'https://image.tmdb.org/t/p/w500/8b8R8l88Qje9dn9OE8PY05Wxl1X.jpg',
          match: 99,
          rating: '13+',
          duration: '1小時 48分',
          category: 'trending',
          tags: ['綜藝', '戶外競技', '爆笑舒壓'],
          top10: 1,
          parts: [
            CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/demo-1', streamUrl: ''),
            CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/demo-1/2/', streamUrl: ''),
            CatalogPart(label: 'Part 3', url: 'https://srgoideas.com/demo-1/3/', streamUrl: ''),
          ],
        ),
      ];
      setState(() {
        episodes = fallback;
        selectedEpisode = fallback.first;
        isLoading = false;
      });
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
            Uri.parse('https://srgoideas.com/category/%E7%B6%9C%E8%97%9D%E7%8E%A9%E5%BE%88%E5%A4%A7/'),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final parsed = CatalogParser.parseList(res.body);
        if (parsed.isNotEmpty && mounted) {
          final existingUrls = episodes.map((e) => e.url).toSet();
          final newEps = parsed.where((p) => !existingUrls.contains(p.url)).toList();
          setState(() {
            if (newEps.isNotEmpty) {
              episodes = [...newEps, ...episodes];
            }
            refreshStatus = '目錄已更新 (Catalog updated)';
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

  void _openPlayer(CatalogEpisode ep, int partIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NativePlayerScreen(episode: ep, initialPartIndex: partIndex),
      ),
    );
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

    final isTv = MediaQuery.of(context).size.width > 900;
    final current = selectedEpisode ?? episodes.first;

    return Scaffold(
      body: Stack(
        children: [
          // Background Backdrop (TV / Wide)
          if (isTv && current.backdrop.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.35,
                child: Image.network(
                  current.backdrop,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: Colors.black),
                ),
              ),
            ),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Top App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'dTV',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'STEAMS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const Spacer(),
                        TvFocusableButton(
                          onPressed: () => refreshCatalog(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFE50914),
                                    ),
                                  )
                                else
                                  const Icon(Icons.refresh, size: 14, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  isRefreshing ? '更新中...' : '刷新目錄',
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            isTv ? '📺 Native Android TV' : '📱 Native Android Mobile',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Hero Billboard
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (current.top10 != null)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                color: const Color(0xFFE50914),
                                child: Text(
                                  'TOP ${current.top10}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '#1 in Trending Today',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        Text(
                          current.title,
                          style: TextStyle(
                            fontSize: isTv ? 32 : 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${current.match}% Match',
                              style: const TextStyle(
                                color: Color(0xFF46D369),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white38),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                current.rating,
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              current.duration,
                              style: const TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isTv ? 650 : double.infinity),
                          child: Text(
                            current.overview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons (Play / Parts)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            TvFocusableButton(
                              autofocus: true,
                              onPressed: () => _openPlayer(current, 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow, color: Colors.black, size: 22),
                                    SizedBox(width: 6),
                                    Text(
                                      'Play Now',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (current.parts.length > 1)
                              ...List.generate(current.parts.length, (idx) {
                                return TvFocusableButton(
                                  onPressed: () => _openPlayer(current, idx),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      current.parts[idx].label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Row Title
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Text(
                      'Episodes & Series',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Episode Horizontal / Vertical Cards
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: isTv ? 240 : 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: episodes.length,
                      itemBuilder: (context, idx) {
                        final ep = episodes[idx];
                        final isSelected = ep.id == current.id;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: TvFocusableButton(
                            onPressed: () {
                              setState(() => selectedEpisode = ep);
                            },
                            child: Container(
                              width: isTv ? 280 : 200,
                              decoration: BoxDecoration(
                                color: const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFE50914) : Colors.white12,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ep.backdrop.isNotEmpty
                                        ? Image.network(
                                            ep.backdrop,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Container(
                                              color: const Color(0xFF333333),
                                              child: const Center(
                                                child: Icon(Icons.tv, color: Colors.white38),
                                              ),
                                            ),
                                          )
                                        : Container(color: const Color(0xFF333333)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ep.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ep.date,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white54,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${ep.parts.length} Parts',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFE50914),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
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
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
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
