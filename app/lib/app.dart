import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'economy/balance.dart';
import 'l10n/gen/app_localizations.dart';
import 'ui/home_page.dart';

class DhakarEkdinApp extends StatefulWidget {
  const DhakarEkdinApp({super.key, required this.balance, required this.prefs});

  final Balance balance;
  final SharedPreferences prefs;

  static const langKey = 'lang';

  @override
  State<DhakarEkdinApp> createState() => _DhakarEkdinAppState();
}

class _DhakarEkdinAppState extends State<DhakarEkdinApp> {
  /// Bangla first (GDD); English is a choice.
  late Locale _locale = Locale(
    widget.prefs.getString(DhakarEkdinApp.langKey) ?? 'bn',
  );

  void _setLocale(Locale l) {
    setState(() => _locale = l);
    widget.prefs.setString(DhakarEkdinApp.langKey, l.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      theme: GameTheme.build(),
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Keep layouts intact on phones with large text, and clear of the
      // system navigation bar (Android 15+ draws edge to edge).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return ColoredBox(
          color: Palette.cream,
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 1,
                  maxScaleFactor: 1.3,
                ),
              ),
              child: child!,
            ),
          ),
        );
      },
      home: HomePage(
        balance: widget.balance,
        locale: _locale,
        onLocale: _setLocale,
      ),
    );
  }
}
