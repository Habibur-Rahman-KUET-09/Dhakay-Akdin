import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../economy/balance.dart';
import '../l10n/gen/app_localizations.dart';
import '../characters/rickshaw/rickshaw_page.dart';
import 'font_check_page.dart';

const _buildVersion = String.fromEnvironment(
  'BUILD_VERSION',
  defaultValue: 'dev',
);

/// The mohalla screen (§৩). For now: the three characters (the rickshaw
/// can be driven since week 2) and the font check of week 1.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.balance,
    required this.locale,
    required this.onLocale,
  });

  final Balance balance;
  final Locale locale;
  final ValueChanged<Locale> onLocale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final characters = [
      (l.rickshawName, l.rickshawRole, Icons.pedal_bike, Palette.magenta, 1),
      (
        l.teaName,
        l.teaRole,
        Icons.emoji_food_beverage,
        Palette.parrot,
        balance.n('unlocks.tea_stall').toInt(),
      ),
      (
        l.busName,
        l.busRole,
        Icons.directions_bus,
        Palette.sky,
        balance.n('unlocks.bus').toInt(),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.cream,
        title: Text(
          l.appTitle,
          style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            key: const ValueKey('language'),
            onPressed: () =>
                onLocale(Locale(locale.languageCode == 'bn' ? 'en' : 'bn')),
            child: Text(locale.languageCode == 'bn' ? 'English' : 'বাংলা'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.tagline, style: t.titleMedium),
          const SizedBox(height: 16),
          for (final (name, role, icon, colour, level) in characters)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: colour,
                    child: Icon(icon, color: Colors.white),
                  ),
                  title: Text(
                    name,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    level > 1 ? '$role · ${l.unlocksAt(level)}' : role,
                  ),
                  trailing: level == 1
                      ? FilledButton(
                          key: const ValueKey('drive'),
                          onPressed: () => RickshawPage.open(context, balance),
                          child: Text(l.rickshawDrive),
                        )
                      : Text(l.comingSoon, style: t.bodySmall),
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('font-check'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FontCheckPage())),
            icon: const Icon(Icons.text_fields),
            label: Text(l.fontCheck),
          ),
          const SizedBox(height: 24),
          Text(
            '${l.testBuild} · $_buildVersion',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
