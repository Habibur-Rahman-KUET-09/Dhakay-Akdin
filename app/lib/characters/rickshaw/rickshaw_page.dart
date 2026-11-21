import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../economy/balance.dart';
import '../../l10n/gen/app_localizations.dart';
import 'rickshaw_game.dart';
import 'road_map.dart';
import 'shift.dart';

/// Turns a finger's movement into a map direction once it has gone far
/// enough, or null. The map is north-up, so a swipe up is always north.
Dir? swipeDirection(Offset moved, {double threshold = 24}) {
  if (moved.distance < threshold) return null;
  if (moved.dx.abs() > moved.dy.abs()) return moved.dx > 0 ? Dir.e : Dir.w;
  return moved.dy > 0 ? Dir.s : Dir.n;
}

/// Rahim Chacha on the map, week 2: drive to one destination after another.
class RickshawPage extends StatefulWidget {
  const RickshawPage({super.key, required this.map, required this.balance});

  final RoadMap map;
  final Balance balance;

  static Future<void> open(BuildContext context, Balance balance) async {
    final map = RoadMap.fromJson(
      await rootBundle.loadString('assets/content/maps/mirpur.json'),
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RickshawPage(map: map, balance: balance),
      ),
    );
  }

  @override
  State<RickshawPage> createState() => _RickshawPageState();
}

class _RickshawPageState extends State<RickshawPage> {
  late final game = RickshawGame(
    RickshawShift.fromBalance(widget.map, widget.balance),
  );
  Offset _moved = Offset.zero;
  bool _used = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('rickshaw-swipe'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  _moved = Offset.zero;
                  _used = false;
                },
                onPanUpdate: (u) {
                  if (_used) return;
                  _moved += u.delta;
                  final d = swipeDirection(_moved);
                  if (d != null) {
                    _used = true;
                    game.swipe(d);
                  }
                },
                child: GameWidget(game: game),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: game.hud,
              builder: (context, h, _) => _Hud(hud: h, l: l),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.hud, required this.l});

  final RickshawHud hud;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final notice = switch (hud.notice) {
      RickshawNotice.wrongWay => (l.rickshawWrongWay, Palette.vermilion),
      RickshawNotice.waiting => (l.rickshawWhichWay, Palette.sky),
      RickshawNotice.arrived => (l.rickshawArrived, Palette.parrot),
      null => null,
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          child: Row(
            children: [
              const BackButton(),
              Expanded(
                child: _Chip(
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: hud.arrowStep * pi / 18,
                        child: const Icon(
                          Icons.navigation,
                          color: Palette.vermilion,
                          key: ValueKey('rickshaw-arrow'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hud.remaining == null
                              ? l.rickshawNoRoute
                              : l.rickshawToGo(hud.remaining!),
                          style: t.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                child: Text(
                  l.rickshawTrips(hud.delivered),
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: notice == null
              ? _Chip(child: Text(l.rickshawHint, textAlign: TextAlign.center))
              : _Chip(
                  colour: notice.$2,
                  child: Text(
                    notice.$1,
                    textAlign: TextAlign.center,
                    style: t.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child, this.colour});

  final Widget child;
  final Color? colour;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colour ?? Palette.cream.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.outline, width: 2),
      ),
      child: child,
    ),
  );
}
