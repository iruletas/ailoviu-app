import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/seed_palette.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isEffectivelyDark = switch (settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: TonalBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: Text(
              'Tema y color',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            expandedHeight: 180,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 20,
                bottom: 16,
                end: 20,
              ),
              title: Text(
                'Tema y color',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TonalMicroHeader(
                        icon: Icons.brightness_6_outlined,
                        title: 'Modo de brillo',
                        description:
                            'Elige cómo se adapta la app a la luz de tu entorno.',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: BrightnessCard(
                              icon: Icons.phone_android_outlined,
                              label: 'Sistema',
                              selected:
                                  settings.themeMode == ThemeMode.system,
                              onTap: () => notifier
                                  .setThemeMode(ThemeMode.system),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: BrightnessCard(
                              icon: Icons.light_mode_outlined,
                              label: 'Claro',
                              selected:
                                  settings.themeMode == ThemeMode.light,
                              onTap: () =>
                                  notifier.setThemeMode(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: BrightnessCard(
                              icon: Icons.dark_mode_outlined,
                              label: 'Oscuro',
                              selected:
                                  settings.themeMode == ThemeMode.dark,
                              onTap: () =>
                                  notifier.setThemeMode(ThemeMode.dark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _AmoledCard(
                  enabled: isEffectivelyDark,
                  value: settings.amoled && isEffectivelyDark,
                  onChanged: (v) {
                    if (isEffectivelyDark) {
                      notifier.setAmoled(v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TonalMicroHeader(
                        icon: Icons.palette_outlined,
                        title: 'Color semilla',
                        description:
                            'Define el acento de toda la app a partir de un color.',
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final color in kSeedPalette)
                            SeedColorChip(
                              color: color,
                              selected: color.toARGB32() ==
                                  settings.seedColor.toARGB32(),
                              onTap: () => notifier.setSeedColor(color),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta AMOLED con opacidad reactiva ─────────────────────────────────
// Privada: es específica de esta pantalla. Si mañana se reusa (poco
// probable), se extrae con el 2º uso real delante.
class _AmoledCard extends StatefulWidget {
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AmoledCard({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_AmoledCard> createState() => _AmoledCardState();
}

class _AmoledCardState extends State<_AmoledCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (!widget.enabled) return;
    HapticFeedback.lightImpact();
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return AnimatedOpacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 250),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
        onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        onTap: widget.enabled ? _handleTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
          child: BentoCard(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dark_mode_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AMOLED',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!widget.enabled)
                        MiniChip(
                          label: 'Solo en modo oscuro',
                          background: scheme.surfaceContainerHighest,
                          foreground: scheme.onSurfaceVariant,
                        )
                      else
                        Text(
                          'Negros puros para ahorrar batería en pantallas OLED',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: widget.value,
                  onChanged:
                      widget.enabled ? (v) => widget.onChanged(v) : null,
                  thumbIcon: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Icon(Icons.check)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}