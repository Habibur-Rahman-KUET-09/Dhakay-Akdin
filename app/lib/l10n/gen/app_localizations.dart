import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'A Day in Dhaka'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Every day, a different Dhaka life'**
  String get tagline;

  /// No description provided for @rickshawName.
  ///
  /// In en, this message translates to:
  /// **'Rahim Chacha'**
  String get rickshawName;

  /// No description provided for @rickshawRole.
  ///
  /// In en, this message translates to:
  /// **'Rickshaw puller'**
  String get rickshawRole;

  /// No description provided for @busName.
  ///
  /// In en, this message translates to:
  /// **'Babu'**
  String get busName;

  /// No description provided for @busRole.
  ///
  /// In en, this message translates to:
  /// **'Local bus conductor'**
  String get busRole;

  /// No description provided for @teaName.
  ///
  /// In en, this message translates to:
  /// **'Monir Mama'**
  String get teaName;

  /// No description provided for @teaRole.
  ///
  /// In en, this message translates to:
  /// **'Tea stall keeper'**
  String get teaRole;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @fontCheck.
  ///
  /// In en, this message translates to:
  /// **'Font check'**
  String get fontCheck;

  /// No description provided for @fontCheckFlutter.
  ///
  /// In en, this message translates to:
  /// **'Flutter text'**
  String get fontCheckFlutter;

  /// No description provided for @fontCheckFlame.
  ///
  /// In en, this message translates to:
  /// **'Flame game text'**
  String get fontCheckFlame;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @testBuild.
  ///
  /// In en, this message translates to:
  /// **'Test build'**
  String get testBuild;

  /// No description provided for @unlocksAt.
  ///
  /// In en, this message translates to:
  /// **'Opens at mohalla level {level}'**
  String unlocksAt(int level);

  /// No description provided for @rickshawDrive.
  ///
  /// In en, this message translates to:
  /// **'Drive'**
  String get rickshawDrive;

  /// No description provided for @rickshawToGo.
  ///
  /// In en, this message translates to:
  /// **'Destination: {tiles} blocks away'**
  String rickshawToGo(int tiles);

  /// No description provided for @rickshawNoRoute.
  ///
  /// In en, this message translates to:
  /// **'No legal way from here: turn round'**
  String get rickshawNoRoute;

  /// No description provided for @rickshawTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips {count}'**
  String rickshawTrips(int count);

  /// No description provided for @rickshawHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe the way you want to turn before the junction'**
  String get rickshawHint;

  /// No description provided for @rickshawWhichWay.
  ///
  /// In en, this message translates to:
  /// **'Which way? Swipe'**
  String get rickshawWhichWay;

  /// No description provided for @rickshawWrongWay.
  ///
  /// In en, this message translates to:
  /// **'One-way street! Wrong way'**
  String get rickshawWrongWay;

  /// No description provided for @rickshawArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived! New destination'**
  String get rickshawArrived;

  /// No description provided for @rickshawToPlace.
  ///
  /// In en, this message translates to:
  /// **'{place} · {tiles} blocks'**
  String rickshawToPlace(String place, int tiles);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
