import 'dart:math';

import 'road_map.dart';

/// What happened during one update, for the game to react to.
enum DriveEvent {
  enteredTile,
  wrongWay,
  waitingAtJunction,
  uTurn,

  /// Reached the destination; raised by RickshawShift, not the driver.
  arrived,
}

/// The rickshaw's movement on a [RoadMap], without any drawing, so the
/// rules can be tested (§৪.১): it follows the road by itself; a swipe picks
/// the direction to take at the next turning where that is possible; a
/// swipe back turns it round at once. At a junction where it cannot go
/// straight and has no direction waiting, it stops and waits for a swipe.
class Driver {
  Driver(this.map, {required this.speed, Point<int>? start, Dir? heading})
    : cell = start ?? map.home,
      heading = heading ?? _firstExit(map, start ?? map.home);

  final RoadMap map;

  /// Tiles per second.
  double speed;

  /// The tile the rickshaw has last entered, and where it is heading.
  Point<int> cell;
  Dir heading;

  /// 0 at [cell], 1 at the next tile.
  double progress = 0;
  bool moving = true;

  /// The direction the player asked for, used at the next turning that
  /// allows it.
  Dir? queued;

  static Dir _firstExit(RoadMap m, Point<int> p) {
    final legal = [
      for (final d in Dir.values)
        if (m.move(p, d) == Move.ok) d,
    ];
    if (legal.isEmpty) throw StateError('${m.id}: no road leaves $p');
    return legal.first;
  }

  /// Where to draw the rickshaw, in tiles.
  ({double x, double y}) get position =>
      (x: cell.x + heading.dx * progress, y: cell.y + heading.dy * progress);

  Point<int> get next => heading.step(cell);

  /// A swipe. Back means turn round now; any other direction waits for the
  /// next turning, and gets a stopped rickshaw going if it can.
  List<DriveEvent> swipe(Dir d) {
    if (d == heading.opposite) {
      if (moving && progress > 0) {
        cell = next;
        progress = 1 - progress;
      }
      heading = d;
      queued = null;
      final m = map.move(cell, heading);
      moving = m != Move.blocked;
      return [DriveEvent.uTurn, if (m == Move.wrongWay) DriveEvent.wrongWay];
    }
    queued = d;
    if (!moving) return _choose();
    return const [];
  }

  List<DriveEvent> update(double dt) {
    if (!moving) return const [];
    final events = <DriveEvent>[];
    progress += speed * dt;
    while (moving && progress >= 1) {
      progress -= 1;
      cell = next;
      events.add(DriveEvent.enteredTile);
      events.addAll(_choose());
      if (!moving) progress = 0;
    }
    return events;
  }

  /// At [cell]: take the waiting direction if the road allows it, else go
  /// straight, else follow a bend with a single way on, else wait.
  List<DriveEvent> _choose() {
    final q = queued;
    if (q != null && q != heading.opposite) {
      final m = map.move(cell, q);
      if (m != Move.blocked) {
        heading = q;
        queued = null;
        moving = true;
        return m == Move.wrongWay ? [DriveEvent.wrongWay] : const [];
      }
    }
    if (map.move(cell, heading) == Move.ok) {
      moving = true;
      return const [];
    }
    final ways = [
      for (final d in Dir.values)
        if (d != heading.opposite && map.move(cell, d) == Move.ok) d,
    ];
    if (ways.length == 1) {
      heading = ways.single;
      moving = true;
      return const [];
    }
    moving = false;
    return [DriveEvent.waitingAtJunction];
  }
}
