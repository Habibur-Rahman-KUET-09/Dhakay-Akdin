import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'economy/balance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // One-handed, portrait play (docs/DETAILED_DESIGN.md §৪.১).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final balance = await Balance.load();
  final prefs = await SharedPreferences.getInstance();
  runApp(DhakarEkdinApp(balance: balance, prefs: prefs));
}
