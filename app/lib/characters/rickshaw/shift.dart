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
    _pick();
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

  /// The real place being driven to, when the map has places.
  Place? place;
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
      _pick();
      events.add(DriveEvent.arrived);
    }
    _measure();
    return events;
  }

  void _measure() => remaining = map.distance(driver.cell, destination);

  /// A real place at least [minTrip] legal tiles away, other than the last
  /// one; on a map without places, a dry road tile. The farthest one if
  /// the map is too small for that.
  void _pick() {
    final dist = map.distancesFrom(driver.cell);
    if (map.places.isNotEmpty) {
      final options = [
        for (final p in map.places)
          if (p != place && dist.containsKey(p.at)) p,
      ];
      if (options.isEmpty) throw StateError('${map.id}: no place to drive to');
      final far = options.where((p) => dist[p.at]! >= minTrip).toList();
      place = far.isNotEmpty
          ? far[_random.nextInt(far.length)]
          : options.reduce((a, b) => dist[a.at]! >= dist[b.at]! ? a : b);
      destination = place!.at;
      return;
    }
    dist.removeWhere(
      (p, _) => switch (map.at(p).kind) {
        TileKind.road ||
        TileKind.mainRoad ||
        TileKind.teaStall ||
        TileKind.signal => false,
        _ => true,
      },
    );
    if (dist.isEmpty) throw StateError('${map.id}: no dry road to drive to');
    final far = [
      for (final e in dist.entries)
        if (e.value >= minTrip) e.key,
    ];
    destination = far.isNotEmpty
        ? far[_random.nextInt(far.length)]
        : dist.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
