import 'dart:convert';

import 'package:flutter/services.dart';

/// All game numbers, from assets/content/balance.json (docs/DETAILED_DESIGN.md
/// §৯.৫). Nothing in the code hard-codes a price, speed or time; playtests
/// change the file, and Remote Config can later replace parts of it.
class Balance {
  Balance(this.raw);

  final Map<String, dynamic> raw;

  static const asset = 'assets/content/balance.json';

  static Future<Balance> load([AssetBundle? bundle]) async => Balance(
    jsonDecode(await (bundle ?? rootBundle).loadString(asset))
        as Map<String, dynamic>,
  );

  /// A number at a dotted path, e.g. `rickshaw.speed_tiles_per_s`.
  num n(String path) {
    final v = at(path);
    if (v is! num) throw StateError('balance.json: $path is not a number');
    return v;
  }

  /// Any value at a dotted path, or null.
  Object? at(String path) {
    Object? o = raw;
    for (final k in path.split('.')) {
      if (o is! Map) return null;
      o = o[k];
    }
    return o;
  }

  late final EconomyRules economy = EconomyRules(
    fundShare: n('economy.fund_share').toDouble(),
    featuredMultiplier: n('economy.featured_multiplier').toInt(),
    xpBase: n('economy.xp_base').toInt(),
    xpPerStar: n('economy.xp_per_rating_star').toInt(),
    xpChapterBonus: n('economy.xp_chapter_bonus').toInt(),
    xpLevelBase: n('economy.xp_level_base').toInt(),
    xpLevelStep: n('economy.xp_level_step').toInt(),
    maxLevel: n('economy.max_level').toInt(),
  );
}

/// The shared economy (§৫): the community fund's cut, today's-character
/// bonus, XP and mohalla levels.
class EconomyRules {
  const EconomyRules({
    required this.fundShare,
    required this.featuredMultiplier,
    required this.xpBase,
    required this.xpPerStar,
    required this.xpChapterBonus,
    required this.xpLevelBase,
    required this.xpLevelStep,
    required this.maxLevel,
  });

  final double fundShare;
  final int featuredMultiplier;
  final int xpBase;
  final int xpPerStar;
  final int xpChapterBonus;
  final int xpLevelBase;
  final int xpLevelStep;
  final int maxLevel;

  /// A day's takings split into what the character keeps and what goes to
  /// the community fund. [earned] already counts today's-character bonus.
  ({int keep, int fund}) split(int earned) {
    if (earned <= 0) return (keep: earned, fund: 0);
    final fund = (earned * fundShare).round();
    return (keep: earned - fund, fund: fund);
  }

  /// XP for one day: a base, more for a better rating, a bonus when a story
  /// chapter opened.
  int dayXp({required double rating, bool chapter = false}) =>
      xpBase +
      (rating.clamp(0, 5) * xpPerStar).round() +
      (chapter ? xpChapterBonus : 0);

  /// XP needed to go from [level] to the next one.
  int toNext(int level) => xpLevelBase + xpLevelStep * level;

  /// The mohalla level and the XP into it, from all XP ever earned.
  ({int level, int into}) levelFor(int totalXp) {
    var level = 1;
    var left = totalXp;
    while (level < maxLevel && left >= toNext(level)) {
      left -= toNext(level);
      level++;
    }
    return (level: level, into: left);
  }
}
