// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'A Day in Dhaka';

  @override
  String get tagline => 'Every day, a different Dhaka life';

  @override
  String get rickshawName => 'Rahim Chacha';

  @override
  String get rickshawRole => 'Rickshaw puller';

  @override
  String get busName => 'Babu';

  @override
  String get busRole => 'Local bus conductor';

  @override
  String get teaName => 'Monir Mama';

  @override
  String get teaRole => 'Tea stall keeper';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get fontCheck => 'Font check';

  @override
  String get fontCheckFlutter => 'Flutter text';

  @override
  String get fontCheckFlame => 'Flame game text';

  @override
  String get language => 'Language';

  @override
  String get testBuild => 'Test build';

  @override
  String unlocksAt(int level) {
    return 'Opens at mohalla level $level';
  }

  @override
  String get rickshawDrive => 'Drive';

  @override
  String rickshawToGo(int tiles) {
    return 'Destination: $tiles blocks away';
  }

  @override
  String get rickshawNoRoute => 'No legal way from here: turn round';

  @override
  String rickshawTrips(int count) {
    return 'Trips $count';
  }

  @override
  String get rickshawHint =>
      'Swipe the way you want to turn before the junction';

  @override
  String get rickshawWhichWay => 'Which way? Swipe';

  @override
  String get rickshawWrongWay => 'One-way street! Wrong way';

  @override
  String get rickshawArrived => 'Arrived! New destination';

  @override
  String rickshawToPlace(String place, int tiles) {
    return '$place · $tiles blocks';
  }
}
