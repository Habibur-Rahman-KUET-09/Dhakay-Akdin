import 'dart:convert';
import 'dart:io';

import 'package:dhakar_ekdin/economy/balance.dart';
import 'package:flutter_test/flutter_test.dart';

Balance balance() => Balance(
  jsonDecode(File('assets/content/balance.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final e = balance().economy;

  test('10% of a day goes to the community fund; losses pay nothing in', () {
    expect(e.split(600), (keep: 540, fund: 60));
    expect(e.split(455), (keep: 409, fund: 46));
    expect(e.split(0), (keep: 0, fund: 0));
    expect(e.split(-30), (keep: -30, fund: 0));
  });

  test('day XP grows with the rating and a story chapter', () {
    expect(e.dayXp(rating: 0), 50);
    expect(e.dayXp(rating: 4), 130);
    expect(e.dayXp(rating: 5, chapter: true), 250);
    expect(e.dayXp(rating: 9), 150, reason: 'rating is capped at 5');
  });

  test(
    'mohalla levels: level 5 after 720 XP (about five days), capped at 50',
    () {
      expect(e.toNext(1), 120);
      expect(e.levelFor(0), (level: 1, into: 0));
      expect(e.levelFor(119), (level: 1, into: 119));
      expect(e.levelFor(120), (level: 2, into: 0));
      expect(e.levelFor(720).level, 5);
      expect(e.levelFor(10000000).level, 50);
    },
  );

  test('every price and duration in balance.json is a positive number', () {
    final bad = <String>[];
    void walk(Object? v, String path) {
      if (v is Map) {
        v.forEach((k, x) => walk(x, path.isEmpty ? '$k' : '$path.$k'));
      } else if (v is num && v < 0) {
        bad.add(path);
      } else if (v is List) {
        for (final x in v) {
          walk(x, path);
        }
      }
    }

    walk(balance().raw, '');
    expect(bad, isEmpty);
    expect(balance().n('rickshaw.daily_target'), 600);
    expect(() => balance().n('rickshaw.passengers'), throwsStateError);
  });
}
