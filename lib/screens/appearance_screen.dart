import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart'';
import '../core/seed_palette.dart'';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // Determina si AMOLED es aplicable (brillo efectivo oscuro).
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isEffectivelyDark = switch (settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Tema y color')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Modo de brillo',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.phone_android_outlined),
                label: Text('Sistema'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Claro'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Oscuro'),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (set) {
              notifier.setThemeMode(set.first);
            },
          ),

          const SizedBox(height: 24),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('AMOLED'),
            subtitle: Text(
              isEffectivelyDark
                  ? 'Negros puros para ahorrar batería en pantallas OLED'
                  : 'Solo disponible en modo oscuro',
            ),
            value: settings.amoled && isEffectivelyDark,
            onChanged: isEffectivelyDark
                ? (v) => notifier.setAmoled(v)
                : null,
          ),

          const Divider(height: 48),

          Text('Color semilla',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in kSeedPalette)
                _SeedChip(
                  color: color,
                  selected: color.toARGB32() == settings.seedColor.toARGB32(),
                  onTap: () => notifier.setSeedColor(color),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeedChip extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SeedChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: scheme.onSurface, width: 3)
              : Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: selected
            ? Icon(
                Icons.check,
                color: ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : null,
      ),
    );
  }
}