import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/gen/app_localizations.dart';

/// Week 1 (GDD): Bangla conjuncts must look right both in Flutter widgets
/// and in Flame's game text. The same lines are drawn both ways.
const fontCheckLines = [
  'ক্ষ জ্ঞ ঞ্চ ন্ত্র স্ট্র ত্ত দ্ব্য শ্রী র‍্যা',
  'ওস্তাদ বাঁয়ে প্লাস্টিক!',
  'মামা, যাইবেন? মতিঝিল ৳৬০',
  'উজ্জ্বল সন্ধ্যা, ক্ষুদ্র দোকান',
  'মিরপুর ১০ › ফার্মগেট › শাহবাগ',
];

class FontCheckPage extends StatelessWidget {
  const FontCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.fontCheck), backgroundColor: Palette.cream),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l.fontCheckFlutter, style: t.labelLarge),
          ),
          for (final line in fontCheckLines)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Text(line, style: const TextStyle(fontSize: 20)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l.fontCheckFlame, style: t.labelLarge),
          ),
          Expanded(child: GameWidget(game: FontCheckGame())),
        ],
      ),
    );
  }
}

/// The same lines as Flame text components on a coloured board.
class FontCheckGame extends FlameGame {
  @override
  Color backgroundColor() => Palette.yellow;

  @override
  Future<void> onLoad() async {
    final style = TextPaint(
      style: const TextStyle(
        fontFamily: GameTheme.font,
        fontSize: 20,
        color: Palette.outline,
      ),
    );
    for (final (i, line) in fontCheckLines.indexed) {
      add(
        TextComponent(
          text: line,
          textRenderer: style,
          position: Vector2(16, 12 + i * 34.0),
        ),
      );
    }
  }
}
