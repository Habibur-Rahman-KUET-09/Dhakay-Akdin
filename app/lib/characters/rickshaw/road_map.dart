import 'dart:collection';
import 'dart:convert';
import 'dart:math';

/// A compass direction on the map. The map never rotates, so a swipe up
/// always means north (docs/DETAILED_DESIGN.md §৪.১).
enum Dir {
  n(0, -1),
  e(1, 0),
  s(0, 1),
  w(-1, 0);

  const Dir(this.dx, this.dy);
  final int dx;
  final int dy;

  Dir get opposite => Dir.values[(index + 2) % 4];

  Point<int> step(Point<int> p) => Point(p.x + dx, p.y + dy);

  /// Radians, clockwise from east, as Flame draws angles.
  double get angle => atan2(dy.toDouble(), dx.toDouble());
}

enum TileKind { block, road, flood, teaStall, signal, home }

class Tile {
  const Tile(this.kind, [this.oneWay]);

  static const block = Tile(TileKind.block);

  final TileKind kind;

  /// For a one-way lane, the only direction of travel; null when two-way.
  final Dir? oneWay;

  bool get isRoad => kind != TileKind.block;
}

/// What happens when the rickshaw moves one tile in a direction.
enum Move { blocked, ok, wrongWay }

/// The road grid of one area, read from `assets/content/maps/<id>.json`.
/// Rows of characters; the legend is in the file.
class RoadMap {
  RoadMap._(this.id, this.width, this.height, this._tiles, this.home);

  factory RoadMap.parse(String id, List<String> rows) {
    final h = rows.length;
    final w = rows.first.length;
    if (rows.any((r) => r.length != w)) {
      throw FormatException('$id: rows have different lengths');
    }
    Point<int>? home;
    final tiles = <Tile>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final ch = rows[y][x];
        tiles.add(switch (ch) {
          '#' => Tile.block,
          '.' => const Tile(TileKind.road),
          'n' => const Tile(TileKind.road, Dir.n),
          'e' => const Tile(TileKind.road, Dir.e),
          's' => const Tile(TileKind.road, Dir.s),
          'w' => const Tile(TileKind.road, Dir.w),
          'W' => const Tile(TileKind.flood),
          'T' => const Tile(TileKind.teaStall),
          'P' => const Tile(TileKind.signal),
          'H' => const Tile(TileKind.home),
          _ => throw FormatException('$id: unknown tile "$ch" at $x,$y'),
        });
        if (ch == 'H') home = Point(x, y);
      }
    }
    if (home == null) throw FormatException('$id: no home tile (H)');
    return RoadMap._(id, w, h, tiles, home);
  }

  factory RoadMap.fromJson(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    return RoadMap.parse(j['id'] as String, (j['rows'] as List).cast<String>());
  }

  final String id;
  final int width;
  final int height;
  final List<Tile> _tiles;

  /// Where the day starts.
  final Point<int> home;

  Tile at(Point<int> p) => p.x < 0 || p.y < 0 || p.x >= width || p.y >= height
      ? Tile.block
      : _tiles[p.y * width + p.x];

  Iterable<Point<int>> get roads sync* {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_tiles[y * width + x].isRoad) yield Point(x, y);
      }
    }
  }

  /// Moving from [p] one tile in [d]: travelling against a one-way lane,
  /// on the tile being left or the one being entered, is wrong way.
  /// Crossing a lane, or turning into or out of it its own way, is fine.
  Move move(Point<int> p, Dir d) {
    final to = at(d.step(p));
    if (!to.isRoad) return Move.blocked;
    if (at(p).oneWay == d.opposite || to.oneWay == d.opposite) {
      return Move.wrongWay;
    }
    return Move.ok;
  }

  /// Directions with a road next to [p], legal or not.
  List<Dir> exits(Point<int> p) => [
    for (final d in Dir.values)
      if (move(p, d) != Move.blocked) d,
  ];

  /// The shortest legal route, tile by tile (start excluded), or null when
  /// [to] cannot be reached without going the wrong way. Fares and expected
  /// times use its length (§৪.১).
  List<Point<int>>? route(Point<int> from, Point<int> to) {
    if (from == to) return const [];
    final prev = <Point<int>, Point<int>>{from: from};
    final queue = Queue<Point<int>>()..add(from);
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      for (final d in Dir.values) {
        if (move(p, d) != Move.ok) continue;
        final q = d.step(p);
        if (prev.containsKey(q)) continue;
        prev[q] = p;
        if (q == to) {
          final path = <Point<int>>[q];
          var c = p;
          while (c != from) {
            path.add(c);
            c = prev[c]!;
          }
          return path.reversed.toList();
        }
        queue.add(q);
      }
    }
    return null;
  }

  int? distance(Point<int> from, Point<int> to) => route(from, to)?.length;

  /// Legal distance from [from] to every road tile it can reach.
  Map<Point<int>, int> distancesFrom(Point<int> from) {
    final dist = <Point<int>, int>{from: 0};
    final queue = Queue<Point<int>>()..add(from);
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      for (final d in Dir.values) {
        if (move(p, d) != Move.ok) continue;
        final q = d.step(p);
        if (dist.containsKey(q)) continue;
        dist[q] = dist[p]! + 1;
        queue.add(q);
      }
    }
    return dist;
  }
}
