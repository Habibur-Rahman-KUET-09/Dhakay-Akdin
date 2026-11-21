import 'dart:convert';
import 'dart:io';

import 'package:dhakar_ekdin/app.dart';
import 'package:dhakar_ekdin/economy/balance.dart';
import 'package:dhakar_ekdin/ui/font_check_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home in Bangla by default, switchable to English, remembered', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final balance = Balance(
      jsonDecode(File('assets/content/balance.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(DhakarEkdinApp(balance: balance, prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('ঢাকার একদিন'), findsOneWidget);
    expect(find.text('রহিম চাচা'), findsOneWidget);
    expect(find.text('মনির মামা'), findsOneWidget);
    expect(find.text('বাবু'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('language')));
    await tester.pumpAndSettle();
    expect(find.text('A Day in Dhaka'), findsOneWidget);
    expect(prefs.getString('lang'), 'en');
  });

  testWidgets('the font check page draws every line in Flutter text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'lang': 'bn'});
    final prefs = await SharedPreferences.getInstance();
    final balance = Balance(
      jsonDecode(File('assets/content/balance.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(DhakarEkdinApp(balance: balance, prefs: prefs));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('font-check')));
    await tester.tap(find.byKey(const ValueKey('font-check')));
    // The Flame game keeps ticking, so the page never "settles".
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (final line in fontCheckLines) {
      expect(find.text(line), findsOneWidget);
    }
  });
}
