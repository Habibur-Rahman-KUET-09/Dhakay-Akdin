import 'dart:io';
import 'dart:math';

import 'package:dhakar_ekdin/characters/rickshaw/driver.dart';
import 'package:dhakar_ekdin/characters/rickshaw/road_map.dart';
import 'package:dhakar_ekdin/characters/rickshaw/shift.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small map: a two-way loop, a one-way lane going east, a dead end.
///   0123456
/// 0 #######
/// 1 #H....#
/// 2 #.##.##
/// 3 #.eee.#
/// 4 #.##..#
/// 5 #######
final small = RoadMap.parse('small', [
  '#######',
  '#H....#',
  '#.##.##',
  '#.eee.#',
  '#.##..#',
  '#######',
]);

Point<int> p(int x, int y) => Point(x, y);

/// Runs the driver until it enters [n] tiles or stops.
List<DriveEvent> drive(Driver d, int n) {
  final all = <DriveEvent>[];
  var entered = 0;
  for (var i = 0; i < 1000 && entered < n && d.moving; i++) {
    final e = d.update(0.1);
    entered += e.where((x) => x == DriveEvent.enteredTile).length;
    all.addAll(e);
  }
  return all;
}

void main() {
  group('map', () {
    test('tiles, home and one-way rules', () {
      expect(small.home, p(1, 1));
      expect(small.at(p(2, 3)).oneWay, Dir.e);
      expect(
        small.move(p(1, 3), Dir.e),
        Move.ok,
        reason: 'into the lane in its direction',
      );
      expect(
        small.move(p(5, 3), Dir.w),
        Move.wrongWay,
        reason: 'into the lane against it',
      );
      expect(
        small.move(p(3, 3), Dir.w),
        Move.wrongWay,
        reason: 'back along the lane',
      );
      expect(small.move(p(1, 1), Dir.n), Move.blocked);
      expect(small.at(p(-1, 0)).isRoad, isFalse);
    });

    test('routes are the shortest legal way and never against a lane', () {
      expect(small.distance(p(1, 3), p(5, 3)), 4, reason: 'through the lane');
      expect(
        small.distance(p(5, 3), p(1, 3)),
        10,
        reason: 'round the loop, not back through the lane',
      );
      expect(small.route(p(1, 1), p(1, 1)), isEmpty);
      expect(small.distance(p(1, 1), p(5, 4)), 7);
      expect(small.move(p(4, 2), Dir.s), Move.ok, reason: 'crossing a lane');
    });

    test('the Mirpur map: every road can reach every other legally', () {
      final mirpur = RoadMap.fromJson(
        File('assets/content/maps/mirpur.json').readAsStringSync(),
      );
      expect((mirpur.width, mirpur.height), (20, 28));
      final roads = mirpur.roads.toList();
      for (final a in [mirpur.home, roads[roads.length ~/ 3], roads.last]) {
        for (final b in roads) {
          expect(mirpur.route(a, b), isNotNull, reason: '$a → $b');
        }
      }
    });
  });

  group('driving', () {
    test('follows the road by itself and stops at a dead end', () {
      final d = Driver(small, speed: 2, heading: Dir.e);
      final e = drive(d, 10);
      expect((d.cell, d.heading, d.moving), (p(5, 1), Dir.e, false));
      expect(e.where((x) => x == DriveEvent.enteredTile), hasLength(4));
      expect(e.last, DriveEvent.waitingAtJunction);
    });

    test('follows a bend with one way on', () {
      final d = Driver(small, speed: 2, start: p(4, 4), heading: Dir.e);
      drive(d, 2);
      expect((d.cell, d.heading), (p(5, 3), Dir.n));
    });

    test('a swipe is used at the next turning that allows it', () {
      final d = Driver(small, speed: 2, heading: Dir.e);
      d.swipe(Dir.s);
      drive(d, 1);
      expect(d.queued, Dir.s, reason: 'no road south at (2,1): kept for later');
      drive(d, 2);
      expect((d.cell, d.heading), (p(4, 1), Dir.s));
      expect(d.queued, isNull);
    });

    test('swiping back turns round at once, mid-tile too', () {
      final d = Driver(small, speed: 2, heading: Dir.e);
      d.update(0.25); // half way from (1,1) to (2,1)
      expect(d.swipe(Dir.w), [DriveEvent.uTurn]);
      expect((d.cell, d.heading), (p(2, 1), Dir.w));
      expect(d.progress, closeTo(0.5, 1e-9));
      expect(d.position.x, closeTo(1.5, 1e-9));
    });

    test('a T-junction without a swipe waits; a swipe gets it going', () {
      final d = Driver(small, speed: 2, start: p(4, 3), heading: Dir.n);
      final e = drive(d, 2);
      expect(d.cell, p(4, 1));
      expect(e.last, DriveEvent.waitingAtJunction, reason: 'east or west?');
      expect(d.moving, isFalse);
      d.swipe(Dir.e);
      expect((d.moving, d.heading), (true, Dir.e));
    });

    test('going the wrong way into a lane is allowed but reported', () {
      final d = Driver(small, speed: 2, start: p(5, 4), heading: Dir.n);
      d.swipe(Dir.w);
      final e = drive(d, 1);
      expect(e, contains(DriveEvent.wrongWay));
      expect((d.cell, d.heading), (p(5, 3), Dir.w));
    });

    test('it never goes the wrong way by itself', () {
      final d = Driver(small, speed: 2, start: p(5, 4), heading: Dir.n);
      final e = drive(d, 1);
      expect(e, isNot(contains(DriveEvent.wrongWay)));
      expect((d.cell, d.moving), (p(5, 3), false), reason: 'west is the lane');
    });
  });

  group('shift', () {
    final mirpur = RoadMap.fromJson(
      File('assets/content/maps/mirpur.json').readAsStringSync(),
    );

    test('destinations are dry roads at least minTrip legal tiles away', () {
      for (var seed = 0; seed < 30; seed++) {
        final s = RickshawShift(mirpur, baseSpeed: 2, random: Random(seed));
        expect(s.map.at(s.destination).kind, isNot(TileKind.flood));
        expect(s.remaining, greaterThanOrEqualTo(8));
        expect(s.remaining, mirpur.distance(mirpur.home, s.destination));
      }
    });

    test('reaching the destination counts it and picks a new one', () {
      final s = RickshawShift(
        small,
        baseSpeed: 2,
        minTrip: 3,
        random: Random(1),
      );
      // Drive the legal route, swiping for each turn a tile ahead, as a
      // player would.
      Dir towards(Point<int> a, Point<int> b) =>
          Dir.values.firstWhere((d) => d.step(a) == b);
      final events = <DriveEvent>[];
      for (var i = 0; i < 400 && s.delivered == 0; i++) {
        final path = s.map.route(s.driver.cell, s.destination)!;
        final first = towards(s.driver.cell, path.first);
        if (first != s.driver.heading) {
          s.swipe(first);
        } else if (path.length > 1) {
          s.swipe(towards(path[0], path[1]));
        }
        events.addAll(s.update(0.05));
      }
      expect(s.delivered, 1);
      expect(events, contains(DriveEvent.arrived));
      expect(events, isNot(contains(DriveEvent.wrongWay)));
      expect(s.destination, isNot(s.driver.cell));
    });

    test('a waterlogged road halves the speed', () {
      final wet = RoadMap.parse('wet', ['######', '#HW..#', '######']);
      final s = RickshawShift(wet, baseSpeed: 2, minTrip: 1);
      s.update(0.01);
      expect(s.driver.speed, 1);
    });
  });
}
