import 'package:html/parser.dart' as html_parser;

class CatalogEpisode {
  final String id;
  final String title;
  final String date;
  final String url;
  final String showId;
  final String showName;
  final String overview;
  final String backdrop;
  final String poster;
  final int match;
  final String rating;
  final String duration;
  final String category;
  final List<String> tags;
  final int? top10;
  final List<CatalogPart> parts;

  CatalogEpisode({
    required this.id,
    required this.title,
    required this.date,
    required this.url,
    this.showId = '',
    this.showName = '',
    this.overview = '',
    this.backdrop = '',
    this.poster = '',
    this.match = 98,
    this.rating = '13+',
    this.duration = '45分',
    this.category = 'trending',
    this.tags = const ['綜藝', '熱門推薦'],
    this.top10,
    this.parts = const [],
  });

  CatalogEpisode copyWith({
    String? id,
    String? title,
    String? date,
    String? url,
    String? showId,
    String? showName,
    String? overview,
    String? backdrop,
    String? poster,
    int? match,
    String? rating,
    String? duration,
    String? category,
    List<String>? tags,
    int? top10,
    List<CatalogPart>? parts,
  }) {
    return CatalogEpisode(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      url: url ?? this.url,
      showId: showId ?? this.showId,
      showName: showName ?? this.showName,
      overview: overview ?? this.overview,
      backdrop: backdrop ?? this.backdrop,
      poster: poster ?? this.poster,
      match: match ?? this.match,
      rating: rating ?? this.rating,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      top10: top10 ?? this.top10,
      parts: parts ?? this.parts,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'url': url,
        'showId': showId,
        'showName': showName,
        'overview': overview,
        'backdrop': backdrop,
        'poster': poster,
        'match': match,
        'rating': rating,
        'duration': duration,
        'category': category,
        'tags': tags,
        'top10': top10,
        'parts': parts.map((p) => p.toJson()).toList(),
      };

  factory CatalogEpisode.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? 'Untitled';
    final url = json['url'] as String? ?? '';
    final id = json['id'] as String? ?? '';
    var sId = json['showId'] as String? ?? '';
    var sName = json['showName'] as String? ?? '';
    if (sId.isEmpty) {
      sId = CatalogParser.detectShowId('$title $url $id');
    }
    if (sName.isEmpty) {
      sName = CatalogParser.detectShowName('$title $url $id');
    }

    return CatalogEpisode(
      id: id,
      title: title,
      date: json['date'] as String? ?? '',
      url: url,
      showId: sId,
      showName: sName,
      overview: json['overview'] as String? ?? '',
      backdrop: json['backdrop'] as String? ?? '',
      poster: json['poster'] as String? ?? '',
      match: (json['match'] as num?)?.toInt() ?? 95,
      rating: json['rating'] as String? ?? '13+',
      duration: json['duration'] as String? ?? '45分',
      category: json['category'] as String? ?? 'trending',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      top10: (json['top10'] as num?)?.toInt(),
      parts: (json['parts'] as List<dynamic>?)
              ?.map((e) => CatalogPart.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class CatalogPart {
  final String label;
  final String url;
  final String title;
  final String duration;
  final String streamUrl;
  final String fallbackStreamUrl;

  CatalogPart({
    required this.label,
    required this.url,
    this.title = '',
    this.duration = '35分',
    this.streamUrl = '',
    this.fallbackStreamUrl = '',
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'url': url,
        'title': title,
        'duration': duration,
        'streamUrl': streamUrl,
        'fallbackStreamUrl': fallbackStreamUrl,
      };

  factory CatalogPart.fromJson(Map<String, dynamic> json) {
    return CatalogPart(
      label: json['label'] as String? ?? 'Part 1',
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      duration: json['duration'] as String? ?? '35分',
      streamUrl: json['streamUrl'] as String? ?? '',
      fallbackStreamUrl: json['fallbackStreamUrl'] as String? ?? '',
    );
  }
}

class CatalogParser {
  static final RegExp _dateRegex = RegExp(r'\d{4}-\d{2}-\d{2}');
  static final RegExp _flexibleDateRegex = RegExp(r'(\d{4})[-./]?(\d{2})[-./]?(\d{2})');

  static const List<String> _knownLocations = [
    '台北', '新北', '基隆', '桃園', '新竹', '苗栗', '台中', '彰化',
    '南投', '雲林', '嘉義', '台南', '高雄', '屏東', '宜蘭', '花蓮',
    '台東', '澎湖', '金門', '馬祖', '沖繩', '關西', '東京', '北投',
  ];

  /// Parses date string into comparable DateTime, falling back to title regex
  static DateTime? extractDate(String? dateStr, String title) {
    if (dateStr != null && dateStr.isNotEmpty) {
      final normalized = dateStr.replaceAll('.', '-').replaceAll('/', '-').trim();
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) return parsed;
      final m = _flexibleDateRegex.firstMatch(normalized);
      if (m != null) {
        final y = int.tryParse(m.group(1)!);
        final mo = int.tryParse(m.group(2)!);
        final d = int.tryParse(m.group(3)!);
        if (y != null && mo != null && d != null) {
          return DateTime(y, mo, d);
        }
      }
    }
    final m = _flexibleDateRegex.firstMatch(title);
    if (m != null) {
      final y = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final d = int.tryParse(m.group(3)!);
      if (y != null && mo != null && d != null) {
        return DateTime(y, mo, d);
      }
    }
    return null;
  }

  /// Sort comparator ordering episodes strictly descending by date (newest broadcast first)
  static int compareDateDescending(CatalogEpisode a, CatalogEpisode b) {
    final dateA = extractDate(a.date, a.title);
    final dateB = extractDate(b.date, b.title);
    if (dateA != null && dateB != null) {
      final cmp = dateB.compareTo(dateA); // Newest first
      if (cmp != 0) return cmp;
    } else if (dateA != null) {
      return -1; // a has date, b doesn't -> a comes first
    } else if (dateB != null) {
      return 1;
    }
    return b.title.compareTo(a.title);
  }

  /// Extract known location tag from title
  static String extractLocation(String title) {
    for (final loc in _knownLocations) {
      if (title.contains(loc)) return loc;
    }
    return '台灣';
  }

  /// Categorize episode by title content
  static String categorizeTitle(String title) {
    if (title.contains('搶孤') || title.contains('逃殺') || title.contains('奪壘') || title.contains('障礙')) {
      return 'action';
    }
    if (title.contains('搗蛋') || title.contains('罩') || title.contains('兄弟') || title.contains('泥漿') || title.contains('笑')) {
      return 'comedy';
    }
    if (title.contains('十週年') || title.contains('海外') || title.contains('特輯') || title.contains('沖繩')) {
      return 'originals';
    }
    return 'trending';
  }

  /// Helper to detect showId from title, url, or path
  static String detectShowId(String text) {
    var s = text;
    try {
      s = Uri.decodeComponent(text);
    } catch (_) {}
    final lower = s.toLowerCase();
    if (s.contains('綜藝玩很大') || lower.contains('mr_player') || lower.contains('mr-player')) return 'mr_player';
    if (s.contains('飢餓遊戲') || lower.contains('hunger_games') || lower.contains('hunger-games')) return 'hunger_games';
    if (s.contains('全明星運動會') || lower.contains('all_stars') || lower.contains('all-stars')) return 'all_stars';
    if (s.contains('小明星大跟班') || lower.contains('super_ent') || lower.contains('super-ent')) return 'super_ent';
    if (s.contains('11點熱吵店') || lower.contains('hot_shop') || lower.contains('hot-shop')) return 'hot_shop';
    return '';
  }

  /// Helper to detect showName from title, url, or showId
  static String detectShowName(String text) {
    var s = text;
    try {
      s = Uri.decodeComponent(text);
    } catch (_) {}
    final lower = s.toLowerCase();
    if (s.contains('綜藝玩很大') || lower.contains('mr_player')) return '綜藝玩很大';
    if (s.contains('飢餓遊戲') || lower.contains('hunger_games')) return '飢餓遊戲';
    if (s.contains('全明星運動會') || lower.contains('all_stars')) return '全明星運動會';
    if (s.contains('小明星大跟班') || lower.contains('super_ent')) return '小明星大跟班';
    if (s.contains('11點熱吵店') || lower.contains('hot_shop')) return '11點熱吵店';
    return '';
  }

  /// Native Dart port of parseList from catalog-core
  static List<CatalogEpisode> parseList(
    String html, {
    String? showId,
    String? defaultShowName,
  }) {
    final document = html_parser.parse(html);
    // Support WordPress category pages (.entry-title a, article h2 a) as well as legacy/plugin lists (ul.lcp_catlist a)
    final anchors = document.querySelectorAll('.entry-title a, ul.lcp_catlist a, article h2 a');
    final out = <CatalogEpisode>[];
    final seenUrls = <String>{};

    for (var i = 0; i < anchors.length; i++) {
      final a = anchors[i];
      final title = (a.text).trim();
      final url = a.attributes['href']?.trim() ?? '';
      if (title.isEmpty || url.isEmpty) continue;
      if (!seenUrls.add(url)) continue; // avoid duplicates across multi-selectors

      final match = _dateRegex.firstMatch(title);
      final date = match != null ? match.group(0)! : '';
      final location = extractLocation(title);
      final category = categorizeTitle(title);

      final epShowId = (showId != null && showId.isNotEmpty)
          ? showId
          : detectShowId('$title $url');
      final epShowName = (defaultShowName != null && defaultShowName.isNotEmpty)
          ? defaultShowName
          : detectShowName('$title $url $epShowId');

      final baseUrl = url.endsWith('/') ? url : '$url/';
      final defaultParts = [
        CatalogPart(
          label: 'Part 1',
          url: url,
          title: '$title (Part 1)',
          duration: '35分',
        ),
        CatalogPart(
          label: 'Part 2',
          url: '${baseUrl}2/',
          title: '$title (Part 2)',
          duration: '35分',
        ),
        CatalogPart(
          label: 'Part 3',
          url: '${baseUrl}3/',
          title: '$title (Part 3)',
          duration: '35分',
        ),
      ];

      String overview;
      if (title.contains('飢餓遊戲')) {
        overview = '飢餓遊戲全員挑戰飢餓指數與高難度關卡！充飢美食與殘酷淘汰賽全面引爆！';
      } else if (title.contains('全明星運動會')) {
        overview = '紅藍兩隊頂尖對決！挑戰各項體育極限，爭奪榮譽總冠軍！';
      } else if (title.contains('小明星大跟班')) {
        overview = '憲哥與Sandy父女聯手主持！麻辣話題與演藝圈八卦獨家大揭密！';
      } else if (title.contains('11點熱吵店')) {
        overview = '沈玉琳與Melody瘋狂開講！熱門辛辣話題、生活爆笑日常大解密！';
      } else {
        overview = '玩很大全員前進$location展開精采冒險！黃隊與黑隊宿命對決，爆笑遊戲與緊張刺激的命運金球爭奪戰！';
      }

      out.add(CatalogEpisode(
        id: url,
        title: title,
        date: date,
        url: url,
        showId: epShowId,
        showName: epShowName,
        overview: overview,
        match: 99 - (i % 10),
        rating: '13+',
        duration: '1小時 45分',
        category: category,
        tags: [location, epShowName.isNotEmpty ? epShowName : (defaultShowName ?? '台灣綜藝'), '熱門推薦'],
        top10: i < 5 ? (i + 1) : null,
        parts: defaultParts,
      ));
    }
    return out;
  }

  /// Native Dart port of parseParts from catalog-core
  static List<CatalogPart> parseParts(String html, String baseUrl) {
    final document = html_parser.parse(html);
    final items = document.querySelectorAll('ul.contentlist li');
    final out = <CatalogPart>[];

    for (final li in items) {
      final a = li.querySelector('a');
      if (a != null) {
        final label = a.text.trim();
        final rawHref = a.attributes['href']?.trim() ?? '';
        final url = rawHref.isNotEmpty ? _resolveUrl(rawHref, baseUrl) : baseUrl;
        out.add(CatalogPart(label: label, url: url, title: label));
      } else {
        final label = li.text.trim();
        if (label.isNotEmpty) {
          out.add(CatalogPart(label: label, url: baseUrl, title: label));
        }
      }
    }
    return out;
  }

  /// Native Dart port of parseStreamUrl from catalog-core with self-healing entity decoding
  static String? parseStreamUrl(String html) {
    final document = html_parser.parse(html);
    final source = document.querySelector('#playerdiv video source') ??
        document.querySelector('video source');
    if (source != null) {
      final src = source.attributes['src']?.trim() ?? '';
      if (src.isNotEmpty) {
        return src.replaceAll('&amp;', '&');
      }
    }
    final regexMatch = RegExp(r"""<source[^>]+src=['"]([^'"]+)['"]""", caseSensitive: false)
        .firstMatch(html);
    final rawSrc = regexMatch?.group(1);
    return rawSrc?.replaceAll('&amp;', '&');
  }

  static String _resolveUrl(String href, String base) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    final uri = Uri.parse(base);
    return uri.resolve(href).toString();
  }
}
