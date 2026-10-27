import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_providers.dart';
import 'about/about_screen.dart';
import 'appearance/appearance_screen.dart';
import 'couple/couple_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const _SectionHeader('Apariencia'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tema y color'),
            subtitle: Text(_themeSubtitle(s)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AppearanceScreen())),
          ),
          const _SectionHeader('Nosotros'),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Datos de la pareja'),
            subtitle: Text(_startDateSubtitle(s.startDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CoupleScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de Ailoviu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
    );
  }

  String _themeSubtitle(AppSettings s) {
    final mode = switch (s.themeMode) {
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Oscuro',
      ThemeMode.system => 'Sistema',
    };
    return '${mode}${s.amoled ? ' · AMOLED' : ''}';
  }

  String _startDateSubtitle(DateTime? d) {
    if (d == null) return 'Sin configurar';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}