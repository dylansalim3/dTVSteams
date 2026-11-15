import 'package:html/parser.dart' as html_parser;

class CatalogEpisode {
  final String id;
  final String title;
  final String date;
  final String url;
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
    return CatalogEpisode(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      date: json['date'] as String? ?? '',
      url: json['url'] as String? ?? '',
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

  /// Native Dart port of parseList from catalog-core
  static List<CatalogEpisode> parseList(String html) {
    final document = html_parser.parse(html);
    final anchors = document.querySelectorAll('ul.lcp_catlist a');
    final out = <CatalogEpisode>[];

    for (final a in anchors) {
      final title = (a.text).trim();
      final url = a.attributes['href']?.trim() ?? '';
      if (title.isEmpty || url.isEmpty) continue;

      final match = _dateRegex.firstMatch(title);
      final date = match != null ? match.group(0)! : '';
      out.add(CatalogEpisode(id: url, title: title, date: date, url: url));
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

  /// Native Dart port of parseStreamUrl from catalog-core
  static String? parseStreamUrl(String html) {
    final document = html_parser.parse(html);
    final source = document.querySelector('#playerdiv video source') ??
        document.querySelector('video source');
    if (source != null) {
      final src = source.attributes['src']?.trim() ?? '';
      if (src.isNotEmpty) return src;
    }
    final regexMatch = RegExp(r"""<source[^>]+src=['"]([^'"]+)['"]""", caseSensitive: false)
        .firstMatch(html);
    return regexMatch?.group(1);
  }

  static String _resolveUrl(String href, String base) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    final uri = Uri.parse(base);
    return uri.resolve(href).toString();
  }
}
