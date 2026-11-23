import 'parser.dart';

class ShowChannel {
  final String id;
  final String name;
  final String englishName;
  final String categorySlug;
  final String iconEmoji;
  final String tagline;
  final List<CatalogEpisode> fallbackEpisodes;

  const ShowChannel({
    required this.id,
    required this.name,
    required this.englishName,
    required this.categorySlug,
    required this.iconEmoji,
    required this.tagline,
    this.fallbackEpisodes = const [],
  });

  String get categoryUrl =>
      'https://srgoideas.com/category/variety-show/${Uri.encodeComponent(categorySlug)}/';

  String pageUrl(int page) => page == 1
      ? categoryUrl
      : 'https://srgoideas.com/category/variety-show/${Uri.encodeComponent(categorySlug)}/page/$page/';
}

class ShowChannels {
  static final ShowChannel mrPlayer = ShowChannel(
    id: 'mr_player',
    name: '綜藝玩很大',
    englishName: 'Mr. Player',
    categorySlug: '綜藝玩很大',
    iconEmoji: '🔥',
    tagline: '憲哥領軍・黃黑兩隊命運對決',
    fallbackEpisodes: [
      CatalogEpisode(
        id: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-08-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/',
        title: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        date: '2026-11-08',
        url: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-08-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/',
        overview: '玩很大全員前進台北展開精采冒險！黃隊與黑隊宿命對決，爆笑遊戲與緊張刺激的命運金球爭奪戰！',
        match: 99,
        rating: '13+',
        duration: '1小時 48分',
        category: 'trending',
        tags: ['台北', '綜藝', '戶外競技', '爆笑舒壓'],
        top10: 1,
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-08-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-08-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/2/'),
          CatalogPart(label: 'Part 3', url: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-08-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/3/'),
        ],
      ),
      CatalogEpisode(
        id: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-10-31-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/',
        title: '綜藝玩很大 2026-10-31 台北 搗蛋鬼到你家',
        date: '2026-10-31',
        url: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-10-31-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/',
        overview: '黃隊與黑隊宿命對決，萬聖節特別企劃！搗蛋鬼現身引爆全員大混亂！',
        match: 97,
        rating: '13+',
        duration: '1小時 45分',
        category: 'comedy',
        tags: ['台北', '萬聖節', '爆笑舒壓'],
        top10: 2,
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-10-31-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-10-31-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/2/'),
          CatalogPart(label: 'Part 3', url: 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-10-31-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/3/'),
        ],
      ),
    ],
  );

  static final ShowChannel hungerGames = ShowChannel(
    id: 'hunger_games',
    name: '飢餓遊戲',
    englishName: 'The Hunger Games',
    categorySlug: '飢餓遊戲',
    iconEmoji: '⚡',
    tagline: '飢餓指數對決・爭奪充飢美食與獎金',
    fallbackEpisodes: [
      CatalogEpisode(
        id: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/',
        title: '飢餓遊戲 2026-11-22 飢餓指數特別企劃',
        date: '2026-11-22',
        url: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/',
        overview: '飢餓遊戲全員挑戰飢餓指數與高難度關卡！充飢美食與殘酷淘汰賽全面引爆！',
        match: 98,
        rating: '13+',
        duration: '1小時 50分',
        category: 'action',
        tags: ['飢餓遊戲', '競技', '美食爭奪'],
        top10: 1,
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/2/'),
          CatalogPart(label: 'Part 3', url: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/3/'),
        ],
      ),
      CatalogEpisode(
        id: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-15-%e8%aa%aa%e5%a5%bd%e7%9a%84%e6%8f%90%e6%97%a9%e4%b8%8b%e7%8f%ad%e4%b9%8b%e4%b8%bb%e8%ac%80%e9%a8%99%e4%bd%a0%e7%9a%84/',
        title: '飢餓遊戲 2026-11-15 說好的提早下班之主謀騙你的',
        date: '2026-11-15',
        url: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-15-%e8%aa%aa%e5%a5%bd%e7%9a%84%e6%8f%90%e6%97%a9%e4%b8%8b%e7%8f%ad%e4%b9%8b%e4%b8%bb%e8%ac%80%e9%a8%99%e4%bd%a0%e7%9a%84/',
        overview: '主謀精心策劃騙局！全員為了提早下班拼盡全力，真相大白時引發爆笑反彈！',
        match: 96,
        rating: '13+',
        duration: '1小時 48分',
        category: 'comedy',
        tags: ['飢餓遊戲', '搞笑', '鬥智'],
        top10: 2,
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-15-%e8%aa%aa%e5%a5%bd%e7%9a%84%e6%8f%90%e6%97%a9%e4%b8%8b%e7%8f%ad%e4%b9%8b%e4%b8%bb%e8%ac%80%e9%a8%99%e4%bd%a0%e7%9a%84/'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-15-%e8%aa%aa%e5%a5%bd%e7%9a%84%e6%8f%90%e6%97%a9%e4%b8%8b%e7%8f%ad%e4%b9%8b%e4%b8%bb%e8%ac%80%e9%a8%99%e4%bd%a0%e7%9a%84/2/'),
          CatalogPart(label: 'Part 3', url: 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-15-%e8%aa%aa%e5%a5%bd%e7%9a%84%e6%8f%90%e6%97%a9%e4%b8%8b%e7%8f%ad%e4%b9%8b%e4%b8%bb%e8%ac%80%e9%a8%99%e4%bd%a0%e7%9a%84/3/'),
        ],
      ),
    ],
  );

  static final ShowChannel allStars = ShowChannel(
    id: 'all_stars',
    name: '全明星運動會',
    englishName: 'All Star Sports Day',
    categorySlug: '全明星運動會',
    iconEmoji: '🏆',
    tagline: '紅藍巔峰對決・挑戰體育競技極限',
    fallbackEpisodes: [
      CatalogEpisode(
        id: 'https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/',
        title: '全明星運動會 2023-01-08 總冠軍賽殊死戰',
        date: '2023-01-08',
        url: 'https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/',
        overview: '紅藍兩隊頂尖對決！挑戰各項體育極限，爭奪榮譽總冠軍！',
        match: 99,
        rating: '13+',
        duration: '1小時 55分',
        category: 'action',
        tags: ['運動', '熱血', '總決賽'],
        top10: 1,
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/2/'),
          CatalogPart(label: 'Part 3', url: 'https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/3/'),
        ],
      ),
    ],
  );

  static final ShowChannel superEnt = ShowChannel(
    id: 'super_ent',
    name: '小明星大跟班',
    englishName: 'Super Ent.',
    categorySlug: '小明星大跟班',
    iconEmoji: '⭐',
    tagline: '憲哥與Sandy・麻辣爆笑娛樂話題',
    fallbackEpisodes: [
      CatalogEpisode(
        id: 'https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/',
        title: '小明星大跟班 2026-11-20 演藝圈真心話大冒險',
        date: '2026-11-20',
        url: 'https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/',
        overview: '憲哥與Sandy父女聯手主持！麻辣話題與演藝圈八卦獨家大揭密！',
        match: 95,
        rating: '13+',
        duration: '45分',
        category: 'comedy',
        tags: ['小明星大跟班', '訪談', '爆笑'],
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/2/'),
        ],
      ),
    ],
  );

  static final ShowChannel hotShop = ShowChannel(
    id: 'hot_shop',
    name: '11點熱吵店',
    englishName: '11 O\'Clock Hot Shop',
    categorySlug: '11點熱吵店',
    iconEmoji: '🌶️',
    tagline: '沈玉琳與Melody・生活辛辣話題爆笑開講',
    fallbackEpisodes: [
      CatalogEpisode(
        id: 'https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/',
        title: '11點熱吵店 2026-11-19 荒謬日常大吐槽',
        date: '2026-11-19',
        url: 'https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/',
        overview: '沈玉琳與Melody瘋狂開講！熱門辛辣話題、生活爆笑日常大解密！',
        match: 94,
        rating: '13+',
        duration: '45分',
        category: 'comedy',
        tags: ['11點熱吵店', '沈玉琳', '熱吵話題'],
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/2/'),
        ],
      ),
    ],
  );

  static final List<ShowChannel> all = [
    mrPlayer,
    hungerGames,
    allStars,
    superEnt,
    hotShop,
  ];

  static ShowChannel get defaultChannel => mrPlayer;

  static ShowChannel findById(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => defaultChannel);
  }
}
