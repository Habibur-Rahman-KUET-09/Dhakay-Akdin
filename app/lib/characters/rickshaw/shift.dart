import 'dart:math';

import '../../economy/balance.dart';
import 'driver.dart';
import 'road_map.dart';

/// One stretch of driving on a map, with a destination to reach: the part
/// of Rahim Chacha's day that week 2 needs (§৪.১). Passengers, fares and
/// the clock come on top of this in week 3. No drawing here, so it can be
/// tested.
class RickshawShift {
  RickshawShift(
    this.map, {
    required this.baseSpeed,
    this.floodSpeed = 0.5,
    this.minTrip = 8,
    Random? random,
  }) : driver = Driver(map, speed: baseSpeed),
       _random = random ?? Random() {
    destination = _pick();
    _measure();
  }

  factory RickshawShift.fromBalance(RoadMap map, Balance b, {Random? random}) =>
      RickshawShift(
        map,
        baseSpeed: b.n('rickshaw.speed_tiles_per_s').toDouble(),
        floodSpeed: b.n('rickshaw.waterlog_speed').toDouble(),
        random: random,
      );

  final RoadMap map;
  final Driver driver;
  final double baseSpeed;

  /// Speed factor on a waterlogged tile.
  final double floodSpeed;

  /// The shortest legal trip, in tiles, to a new destination.
  final int minTrip;
  final Random _random;

  late Point<int> destination;
  int delivered = 0;

  /// Tiles left on the shortest legal way, from the last tile entered.
  int? remaining;

  bool get onFlood =>
      map.at(driver.cell).kind == TileKind.flood ||
      (driver.moving && map.at(driver.next).kind == TileKind.flood);

  List<DriveEvent> swipe(Dir d) => driver.swipe(d);

  List<DriveEvent> update(double dt) {
    driver.speed = baseSpeed * (onFlood ? floodSpeed : 1);
    final events = driver.update(dt);
    if (!events.contains(DriveEvent.enteredTile)) return events;
    if (driver.cell == destination) {
      delivered++;
      destination = _pick();
      events.add(DriveEvent.arrived);
    }
    _measure();
    return events;
  }

  void _measure() => remaining = map.distance(driver.cell, destination);

  /// A random dry road tile at least [minTrip] legal tiles away; the
  /// farthest one if the map is too small for that.
  Point<int> _pick() {
    final dist = map.distancesFrom(driver.cell)
      ..removeWhere(
        (p, _) => switch (map.at(p).kind) {
          TileKind.road || TileKind.teaStall || TileKind.signal => false,
          _ => true,
        },
      );
    final far = [
      for (final e in dist.entries)
        if (e.value >= minTrip) e.key,
    ];
    if (far.isNotEmpty) return far[_random.nextInt(far.length)];
    if (dist.isEmpty) throw StateError('${map.id}: no dry road to drive to');
    return dist.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
