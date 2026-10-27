import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/relationship_providers.dart'';
import '../providers/settings_providers.dart'';
import 'about/about_screen.dart';
import 'appearance/appearance_screen.dart';
import 'relationship/relationship_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final rel = ref.watch(relationshipProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const _SectionHeader('Apariencia'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tema y color'),
            subtitle: Text(_themeSubtitle(settings)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppearanceScreen()),
            ),
          ),
          const _SectionHeader('Relación'),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Datos de la relación'),
            subtitle: Text(_relationshipSubtitle(rel)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RelationshipScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de Ailoviu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
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

  String _relationshipSubtitle(AppRelationship rel) {
    final names = rel.visibleNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final hasDate = rel.startDate != null;
    if (names.isEmpty && !hasDate) return 'Sin configurar';
    final parts = <String>[];
    if (names.isNotEmpty) parts.add(names.join(' & '));
    if (hasDate) {
      final d = rel.startDate!;
      parts.add(
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}',
      );
    }
    return parts.join(' · ');
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
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.primary,
            ),
      ),
    );
  }
}