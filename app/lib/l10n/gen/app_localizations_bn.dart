// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'ঢাকার একদিন';

  @override
  String get tagline => 'প্রতিদিন ঢাকার একজন নতুন মানুষ';

  @override
  String get rickshawName => 'রহিম চাচা';

  @override
  String get rickshawRole => 'রিকশাওয়ালা';

  @override
  String get busName => 'বাবু';

  @override
  String get busRole => 'লোকাল বাস কন্ডাক্টর';

  @override
  String get teaName => 'মনির মামা';

  @override
  String get teaRole => 'চা-দোকানি';

  @override
  String get comingSoon => 'শিগগির আসছে';

  @override
  String get fontCheck => 'ফন্ট পরীক্ষা';

  @override
  String get fontCheckFlutter => 'Flutter লেখা';

  @override
  String get fontCheckFlame => 'Flame খেলার লেখা';

  @override
  String get language => 'ভাষা';

  @override
  String get testBuild => 'পরীক্ষামূলক সংস্করণ';

  @override
  String unlocksAt(int level) {
    return 'মহল্লা লেভেল $level-এ খোলে';
  }
}
