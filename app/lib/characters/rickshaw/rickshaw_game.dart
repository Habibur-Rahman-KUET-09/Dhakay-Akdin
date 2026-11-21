import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme.dart';
import 'driver.dart';
import 'road_map.dart';
import 'shift.dart';

/// Size of a map tile in world units (logical pixels at zoom 1).
const double tile = 48;

/// About this many tiles fit across the screen.
const double tilesAcross = 9;

/// A short message over the map.
enum RickshawNotice { wrongWay, waiting, arrived }

/// What the Flutter overlay shows; a record, so the notifier only fires
/// when something on screen changes.
typedef RickshawHud = ({
  int? remaining,
  int delivered,
  int arrowStep,
  RickshawNotice? notice,
});

/// The rickshaw on the map (§৪.১): placeholder shapes for now (§১০).
class RickshawGame extends FlameGame {
  RickshawGame(this.shift, {this.lang = 'bn'});

  final RickshawShift shift;

  /// Language of the place names drawn on the map.
  final String lang;

  /// Direction to the destination in 10° steps, clockwise from north.
  final hud = ValueNotifier<RickshawHud>((
    remaining: null,
    delivered: 0,
    arrowStep: 0,
    notice: null,
  ));

  late final RickshawComponent _rickshaw;
  late final DestinationComponent _destination;
  RickshawNotice? _notice;
  double _noticeLeft = 0;

  RoadMap get map => shift.map;

  @override
  Color backgroundColor() => Palette.cream;

  @override
  Future<void> onLoad() async {
    world.add(MapComponent(map, lang: lang));
    _destination = DestinationComponent()
      ..position = _centre(shift.destination);
    world.add(_destination);
    _rickshaw = RickshawComponent(shift.driver);
    world.add(_rickshaw);
    camera.viewfinder.anchor = Anchor.center;
    _rickshaw.update(0);
    _aim();
    _publish();
  }

  /// Keeps the rickshaw in view without showing anything beyond the map;
  /// a map narrower than the screen is centred.
  void _aim() {
    final zoom = (size.x / (tilesAcross * tile)).clamp(0.4, 3.0);
    camera.viewfinder.zoom = zoom;
    double clampTo(double v, double view, double world) =>
        view >= world ? world / 2 : v.clamp(view / 2, world - view / 2);
    camera.viewfinder.position = Vector2(
      clampTo(_rickshaw.x, size.x / zoom, map.width * tile),
      clampTo(_rickshaw.y, size.y / zoom, map.height * tile),
    );
  }

  void swipe(Dir d) {
    final e = shift.swipe(d);
    if (e.contains(DriveEvent.wrongWay)) _say(RickshawNotice.wrongWay);
    if (_notice == RickshawNotice.waiting && shift.driver.moving) {
      _say(null);
    }
    _publish();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final e = shift.update(dt);
    if (e.contains(DriveEvent.arrived)) {
      _destination.position = _centre(shift.destination);
      _say(RickshawNotice.arrived);
    }
    if (e.contains(DriveEvent.wrongWay)) _say(RickshawNotice.wrongWay);
    if (e.contains(DriveEvent.waitingAtJunction)) {
      _say(RickshawNotice.waiting, seconds: double.infinity);
    }
    if (_notice != null && (_noticeLeft -= dt) <= 0) _notice = null;
    _aim();
    _publish();
  }

  void _say(RickshawNotice? n, {double seconds = 2}) {
    _notice = n;
    _noticeLeft = seconds;
  }

  void _publish() {
    final p = shift.driver.position;
    final dx = shift.destination.x - p.x;
    final dy = shift.destination.y - p.y;
    // atan2(dx, -dy): 0 at north, growing clockwise.
    final step = ((atan2(dx, -dy) * 180 / pi) / 10).round() % 36;
    final next = (
      remaining: shift.remaining,
      delivered: shift.delivered,
      arrowStep: step,
      notice: _notice,
    );
    if (next == hud.value || next == _pending) return;
    // The game updates while Flutter draws a frame, when widgets may not be
    // rebuilt: hand the overlay the change once the frame is done.
    final schedule = _pending == null;
    _pending = next;
    if (schedule) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final p = _pending;
        _pending = null;
        if (p != null && isAttached) hud.value = p;
      });
    }
  }

  RickshawHud? _pending;

  static Vector2 _centre(Point<int> p) =>
      Vector2((p.x + 0.5) * tile, (p.y + 0.5) * tile);
}

/// The whole map, drawn once into a picture.
class MapComponent extends PositionComponent {
  MapComponent(this.map, {this.lang = 'bn'})
    : super(size: Vector2(map.width * tile, map.height * tile));

  final RoadMap map;
  final String lang;
  late final Picture _picture;

  static final _asphalt = Paint()..color = const Color(0xFF8A8F96);
  static final _main = Paint()..color = const Color(0xFF5A5F68);
  static final _dash = Paint()
    ..color = const Color(0xFFF6D365)
    ..strokeWidth = 3;
  static final _grass = Paint()..color = const Color(0xFF7CC47F);
  static final _lane = Paint()..color = const Color(0xFFA7ACB2);
  static final _water = Paint()..color = const Color(0xFF6FB4E8);
  static final _ground = Paint()..color = const Color(0xFFE9DCC0);
  static final _mark = Paint()
    ..color = const Color(0xCCFFFFFF)
    ..strokeWidth = 2;
  static final _outline = Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static const _roofs = [
    Color(0xFFF2B5C9),
    Color(0xFFB9E0CB),
    Color(0xFFFFE08A),
    Color(0xFFB7D6F2),
    Color(0xFFF7C1A8),
  ];

  @override
  Future<void> onLoad() async {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(size.toRect(), _ground);
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        _tile(c, Point(x, y));
      }
    }
    for (final p in map.places) {
      _sign(c, p);
    }
    _picture = rec.endRecording();
  }

  void _tile(Canvas c, Point<int> p) {
    final r = Rect.fromLTWH(p.x * tile, p.y * tile, tile, tile);
    final t = map.at(p);
    if (t.kind == TileKind.island) {
      c.drawRect(r, _main);
      c.drawCircle(r.center, tile * 0.42, _grass);
      c.drawCircle(r.center, tile * 0.42, _outline);
      return;
    }
    if (!t.isRoad) {
      // A building wherever a road runs alongside; open ground elsewhere.
      final nextToRoad = Dir.values.any((d) => map.at(d.step(p)).isRoad);
      if (nextToRoad) {
        final roof = Paint()
          ..color = _roofs[(p.x * 7 + p.y * 13) % _roofs.length];
        final b = RRect.fromRectAndRadius(
          r.deflate(4),
          const Radius.circular(6),
        );
        c.drawRRect(b, roof);
        c.drawRRect(b, _outline);
      }
      return;
    }
    if (t.kind == TileKind.mainRoad) {
      c.drawRect(r, _main);
      final ew = map.at(Dir.e.step(p)).isRoad && map.at(Dir.w.step(p)).isRoad;
      final ns = map.at(Dir.n.step(p)).isRoad && map.at(Dir.s.step(p)).isRoad;
      if (ew != ns) {
        final a = ew
            ? Offset(r.left + 12, r.center.dy)
            : Offset(r.center.dx, r.top + 12);
        final b = ew
            ? Offset(r.right - 12, r.center.dy)
            : Offset(r.center.dx, r.bottom - 12);
        c.drawLine(a, b, _dash);
      }
    } else {
      // A lane is narrower than its tile, joined to the roads beside it.
      final paint = t.oneWay != null ? _lane : _asphalt;
      const inset = 7.0;
      c.drawRect(r.deflate(inset), paint);
      for (final d in Dir.values) {
        if (!map.at(d.step(p)).isRoad) continue;
        c.drawRect(
          Rect.fromCenter(
            center: r.center + Offset(d.dx * tile / 4, d.dy * tile / 4),
            width: d.dx != 0 ? tile / 2 : tile - 2 * inset,
            height: d.dy != 0 ? tile / 2 : tile - 2 * inset,
          ),
          paint,
        );
      }
    }
    if (t.oneWay case final d?) _arrow(c, r.center, d);
    switch (t.kind) {
      case TileKind.flood:
        c.drawRRect(
          RRect.fromRectAndRadius(r.deflate(3), const Radius.circular(14)),
          _water,
        );
      case TileKind.teaStall:
        _marker(c, r, Palette.parrot, 'চা');
      case TileKind.signal:
        c.drawCircle(
          r.center.translate(0, -8),
          6,
          Paint()..color = Palette.vermilion,
        );
        c.drawCircle(
          r.center.translate(0, 8),
          6,
          Paint()..color = Palette.parrot,
        );
      case TileKind.home:
        _marker(c, r, Palette.magenta, 'বাড়ি');
      case TileKind.road ||
          TileKind.mainRoad ||
          TileKind.block ||
          TileKind.island:
        break;
    }
  }

  /// A place's name on a small sign above its tile.
  void _sign(Canvas c, Place p) {
    final tp = TextPainter(
      text: TextSpan(
        text: p.name(lang),
        style: const TextStyle(
          fontFamily: 'HindSiliguri',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Palette.outline,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: tile * 4);
    final centre = Offset((p.at.x + 0.5) * tile, p.at.y * tile - 4);
    final box = Rect.fromCenter(
      center: centre.translate(0, -tp.height / 2),
      width: tp.width + 12,
      height: tp.height + 4,
    );
    final rr = RRect.fromRectAndRadius(box, const Radius.circular(6));
    c.drawRRect(rr, Paint()..color = const Color(0xEEFFF6E5));
    c.drawRRect(rr, _outline);
    tp.paint(c, box.topLeft + const Offset(6, 2));
  }

  /// A one-way lane's direction, drawn as a path: the font has no arrows.
  static void _arrow(Canvas c, Offset o, Dir d) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(d.angle);
    final path = Path()
      ..moveTo(12, 0)
      ..lineTo(0, -8)
      ..lineTo(0, -3)
      ..lineTo(-12, -3)
      ..lineTo(-12, 3)
      ..lineTo(0, 3)
      ..lineTo(0, 8)
      ..close();
    c.drawPath(path, _mark);
    c.restore();
  }

  static void _marker(Canvas c, Rect r, Color colour, String label) {
    final b = RRect.fromRectAndRadius(r.deflate(5), const Radius.circular(8));
    c.drawRRect(b, Paint()..color = colour);
    c.drawRRect(b, _outline);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'HindSiliguri',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: r.width);
    tp.paint(c, r.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void render(Canvas canvas) => canvas.drawPicture(_picture);
}

/// Rahim Chacha's rickshaw: a hood, a seat and three wheels.
class RickshawComponent extends PositionComponent {
  RickshawComponent(this.driver)
    : super(size: Vector2(30, 22), anchor: Anchor.center, priority: 2);

  final Driver driver;

  static final _body = Paint()..color = Palette.magenta;
  static final _hood = Paint()..color = Palette.yellow;
  static final _wheel = Paint()..color = Palette.outline;
  static final _outline = Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) {
    final p = driver.position;
    position.setValues((p.x + 0.5) * tile, (p.y + 0.5) * tile);
    // Turn smoothly towards the heading.
    final target = driver.heading.angle;
    var diff = (target - angle + pi) % (2 * pi) - pi;
    if (diff < -pi) diff += 2 * pi;
    angle += diff * min(1, dt * 14);
  }

  @override
  void render(Canvas canvas) {
    final c = canvas;
    // Drawn facing east (+x); the component's angle turns it.
    c.drawCircle(const Offset(27, 11), 4, _wheel);
    c.drawCircle(const Offset(6, 2), 4, _wheel);
    c.drawCircle(const Offset(6, 20), 4, _wheel);
    final body = RRect.fromLTRBR(2, 4, 26, 18, const Radius.circular(5));
    c.drawRRect(body, _body);
    c.drawRRect(body, _outline);
    final hood = RRect.fromLTRBR(3, 5, 13, 17, const Radius.circular(5));
    c.drawRRect(hood, _hood);
    c.drawRRect(hood, _outline);
  }
}

/// Where the passenger is going: a pulsing pin.
class DestinationComponent extends PositionComponent {
  DestinationComponent()
    : super(size: Vector2.all(tile), anchor: Anchor.center, priority: 1);

  double _t = 0;
  static final _ring = Paint()
    ..color = Palette.vermilion
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _dot = Paint()..color = Palette.vermilion;

  @override
  void update(double dt) => _t = (_t + dt) % 1.2;

  @override
  void render(Canvas canvas) {
    final c = canvas;
    final o = Offset(tile / 2, tile / 2);
    final k = _t / 1.2;
    _ring.color = Palette.vermilion.withValues(alpha: 1 - k);
    c.drawCircle(o, 8 + 14 * k, _ring);
    c.drawCircle(o, 8, _dot);
  }
}
