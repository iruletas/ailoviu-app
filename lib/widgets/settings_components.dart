import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import '../providers/settings_providers.dart';

/// Contenedor tonal con esquinas superredondeadas para agrupar ajustes.
class SettingsGroupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SettingsGroupCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Burbuja tonal 40x40 que envuelve un ícono.
class TonalIconBubble extends StatelessWidget {
  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;

  const TonalIconBubble({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: foreground ?? scheme.onPrimaryContainer,
      ),
    );
  }
}

enum HapticFeedbackType { light, medium }

/// ListTile expresivo con presión física y háptica.
class SettingsTileExpressive extends StatefulWidget {
  final Widget leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final HapticFeedbackType haptic;

  const SettingsTileExpressive({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.haptic = HapticFeedbackType.light,
  });

  @override
  State<SettingsTileExpressive> createState() =>
      _SettingsTileExpressiveState();
}

class _SettingsTileExpressiveState extends State<SettingsTileExpressive> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    switch (widget.haptic) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              widget.leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      widget.subtitle!,
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta uppercase de sección.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

/// Chip tonal pequeño para subtítulos ricos.
class MiniChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool bold;

  const MiniChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

/// Pill de estado ancho (para badges de acción).
class PillStatus extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  const PillStatus({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Fila de badges que resume el estado del tema actual.
class ThemeBadges extends StatelessWidget {
  final AppSettings settings;
  const ThemeBadges({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modeLabel = switch (settings.themeMode) {
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Oscuro',
      ThemeMode.system => 'Sistema',
    };

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MiniChip(
          label: modeLabel,
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        ),
        if (settings.amoled)
          MiniChip(
            label: 'AMOLED',
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
            bold: true,
          ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: settings.seedColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.outlineVariant,
              width: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMPONENTES PARA APPEARANCE SCREEN
// ═══════════════════════════════════════════════════════════════════════

/// Tarjeta Bento: contenedor tonal con padding generoso.
class BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;

  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Micro-encabezado tonal: ícono en burbuja + título + descripción.
class TonalMicroHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Color? bubbleBackground;
  final Color? bubbleForeground;

  const TonalMicroHeader({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.bubbleBackground,
    this.bubbleForeground,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TonalIconBubble(
          icon: icon,
          background: bubbleBackground ?? scheme.primaryContainer,
          foreground: bubbleForeground ?? scheme.onPrimaryContainer,
          size: 36,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta táctil de brillo (Sistema / Claro / Oscuro).
class BrightnessCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const BrightnessCard({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<BrightnessCard> createState() => _BrightnessCardState();
}

class _BrightnessCardState extends State<BrightnessCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  widget.selected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: widget.selected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight:
                      widget.selected ? FontWeight.w800 : FontWeight.w600,
                  color: widget.selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de color semilla con morphing real (circle → cookie4Sided)
/// vía `m3e_shapes`. Glow del propio color + escala al seleccionar.
class SeedColorChip extends StatefulWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const SeedColorChip({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<SeedColorChip> createState() => _SeedColorChipState();
}

class _SeedColorChipState extends State<SeedColorChip>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _morphController;

  static const double _size = 56.0;
  static const double _borderWidth = 2.5;
  static const M3EShape _idleShape = M3EShape.circle;
  static const M3EShape _activeShape = M3EShape.cookie4Sided;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.selected ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant SeedColorChip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      if (widget.selected) {
        _morphController.forward();
      } else {
        _morphController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final checkColor =
        ThemeData.estimateBrightnessForColor(widget.color) ==
                Brightness.dark
            ? Colors.white
            : Colors.black;
    final borderColor =
        selected ? scheme.onSurface : scheme.outlineVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.85 : (selected ? 1.10 : 1.0),
        duration: const Duration(milliseconds: 200),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedBuilder(
          animation: _morphController,
          builder: (context, _) {
            return Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_size / 2),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Borde (forma morphing)
                  M3EMorphClip(
                    from: _idleShape,
                    to: _activeShape,
                    progress: _morphController.value,
                    child: ColoredBox(color: borderColor),
                  ),
                  // Relleno del chip (forma morphing, con padding = grosor borde)
                  Padding(
                    padding: const EdgeInsets.all(_borderWidth),
                    child: M3EMorphClip(
                      from: _idleShape,
                      to: _activeShape,
                      progress: _morphController.value,
                      child: ColoredBox(
                        color: widget.color,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: selected ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.check_rounded,
                              color: checkColor,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}