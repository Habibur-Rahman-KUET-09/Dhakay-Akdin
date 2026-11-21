import 'dart:convert';
import 'dart:io';

import 'package:dhakar_ekdin/app.dart';
import 'package:dhakar_ekdin/characters/rickshaw/rickshaw_game.dart';
import 'package:dhakar_ekdin/characters/rickshaw/rickshaw_page.dart';
import 'package:dhakar_ekdin/characters/rickshaw/road_map.dart';
import 'package:dhakar_ekdin/economy/balance.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a swipe is read as an absolute direction once it is long enough', () {
    expect(swipeDirection(const Offset(10, 5)), isNull);
    expect(swipeDirection(const Offset(30, 10)), Dir.e);
    expect(swipeDirection(const Offset(-30, 10)), Dir.w);
    expect(swipeDirection(const Offset(5, -40)), Dir.n);
    expect(swipeDirection(const Offset(-20, 25)), Dir.s);
  });

  testWidgets('the rickshaw card opens the map; swipes steer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final balance = Balance(
      jsonDecode(File('assets/content/balance.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(DhakarEkdinApp(balance: balance, prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drive')));
    // The game keeps ticking, so the page never "settles".
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RickshawPage), findsOneWidget);
    expect(find.textContaining('গন্তব্য'), findsOneWidget);
    expect(find.text('ট্রিপ 0'), findsOneWidget);

    final game = tester
        .widget<GameWidget<RickshawGame>>(find.byType(GameWidget<RickshawGame>))
        .game!;
    final driver = game.shift.driver;
    expect(driver.cell, isNot(game.map.home), reason: 'it drives by itself');
    final back = driver.heading.opposite;
    await tester.drag(
      find.byKey(const ValueKey('rickshaw-swipe')),
      Offset(back.dx * 80.0, back.dy * 80.0),
    );
    await tester.pump();
    expect(driver.heading, back, reason: 'a swipe back turns round at once');

    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(RickshawPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
