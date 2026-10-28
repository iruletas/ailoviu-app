import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_settings_providers.dart';
import '../services/auth_keys.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';
import 'pin_setup_screen.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final auth = ref.watch(authSettingsProvider);
    final notifier = ref.read(authSettingsProvider.notifier);
    final featureLocks = ref.watch(featureLocksProvider);
    final featureNotifier = ref.read(featureLocksProvider.notifier);

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
              'Seguridad',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SectionLabel('Bloqueo de la app'),
                const SizedBox(height: 8),
                BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AppLockRow(
                        enabled: auth.appLockEnabled,
                        systemAvailable: auth.systemAuthAvailable,
                        pinConfigured: auth.appPinFallbackConfigured,
                        onChanged: (v) => _toggleAppLock(context, ref, v),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          opacity: auth.appLockEnabled ? 1.0 : 0.0,
                          child: auth.appLockEnabled
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Column(
                                    children: [
                                      Divider(
                                        height: 1,
                                        color: scheme.outlineVariant
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 16),
                                      _TimeoutSelector(
                                        current: auth.appLockTimeout,
                                        onChanged: (t) =>
                                            notifier.setAppLockTimeout(t),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _MethodCard(auth: auth, onCreatePin: () => _createPin(context)),
                const SizedBox(height: 16),
                _FeatureLocksCard(
                  featureLocks: featureLocks,
                  onChanged: (id, v) =>
                      featureNotifier.setRequiresAuth(id, v),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAppLock(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    HapticFeedback.lightImpact();
    final auth = ref.read(authSettingsProvider);
    final notifier = ref.read(authSettingsProvider.notifier);

    if (!value) {
      await notifier.setAppLockEnabled(false);
      return;
    }

    if (auth.systemAuthAvailable || auth.appPinFallbackConfigured) {
      await notifier.setAppLockEnabled(true);
      return;
    }

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (created == true) {
      await notifier.setAppLockEnabled(true);
    }
  }

  Future<void> _createPin(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
  }
}

// ── Fila principal de app-lock ────────────────────────────────────────────

class _AppLockRow extends StatelessWidget {
  final bool enabled;
  final bool systemAvailable;
  final bool pinConfigured;
  final ValueChanged<bool> onChanged;

  const _AppLockRow({
    required this.enabled,
    required this.systemAvailable,
    required this.pinConfigured,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final bg = enabled ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = enabled ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    final icon = enabled ? Icons.lock_rounded : Icons.lock_open_rounded;

    final subtitle = systemAvailable
        ? 'Usa huella, PIN o patrón del sistema'
        : (pinConfigured
            ? 'Usa el PIN de Ailoviu'
            : 'Configura un PIN para activar');

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: 20,
              color: fg,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pedir desbloqueo al abrir',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(value: enabled, onChanged: onChanged),
      ],
    );
  }
}

// ── Selector de timeout ──────────────────────────────────────────────────

class _TimeoutSelector extends StatelessWidget {
  final Duration? current;
  final ValueChanged<Duration?> onChanged;

  const _TimeoutSelector({required this.current, required this.onChanged});

  static const _options = <(String, Duration?)>[
    ('Inmediato', Duration.zero),
    ('1 min', Duration(minutes: 1)),
    ('5 min', Duration(minutes: 5)),
    ('15 min', Duration(minutes: 15)),
    ('Nunca', null),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Re-bloquear después de',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tiempo en segundo plano antes de volver a pedir desbloqueo.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in _options)
              _TimeoutPill(
                label: opt.$1,
                selected: current == opt.$2,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(opt.$2);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _TimeoutPill extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeoutPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TimeoutPill> createState() => _TimeoutPillState();
}

class _TimeoutPillState extends State<_TimeoutPill> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
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
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : (widget.selected ? 1.05 : 1.0),
        duration: const Duration(milliseconds: 160),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          child: Text(
            widget.label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight:
                  widget.selected ? FontWeight.w800 : FontWeight.w600,
              color: widget.selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de método de desbloqueo ──────────────────────────────────────

class _MethodCard extends StatelessWidget {
  final dynamic auth;
  final VoidCallback onCreatePin;

  const _MethodCard({required this.auth, required this.onCreatePin});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final (bg, fg, icon, title, subtitle) = () {
      if (auth.systemAuthAvailable) {
        return (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.verified_user_rounded,
          'Protegido por el sistema',
          'Huella, PIN o patrón del dispositivo',
        );
      }
      if (auth.appPinFallbackConfigured) {
        return (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.pin_rounded,
          'PIN de Ailoviu',
          'Fallback para dispositivos sin bloqueo',
        );
      }
      return (
        scheme.errorContainer.withValues(alpha: 0.3),
        scheme.onErrorContainer,
        Icons.error_outline_rounded,
        'Sin método configurado',
        'Configura un PIN para proteger la app',
      );
    }();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (!auth.systemAuthAvailable && !auth.appPinFallbackConfigured)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: onCreatePin,
              child: const Text('Configurar'),
            )
          else if (auth.appPinFallbackConfigured &&
              !auth.systemAuthAvailable)
            TextButton(
              onPressed: onCreatePin,
              child: const Text('Cambiar'),
            ),
        ],
      ),
    );
  }
}

// ── Tarjeta de bloqueo por función ───────────────────────────────────────

class _FeatureLocksCard extends StatelessWidget {
  final Map<String, dynamic> featureLocks;
  final void Function(String id, bool value) onChanged;

  const _FeatureLocksCard({
    required this.featureLocks,
    required this.onChanged,
  });

  static IconData _iconFor(String id) {
    switch (id) {
      case PrivateFeatures.diary:
        return Icons.menu_book_outlined;
      case PrivateFeatures.letters:
        return Icons.mail_outline_rounded;
      case PrivateFeatures.privateStates:
        return Icons.visibility_outlined;
      case PrivateFeatures.gallery:
        return Icons.photo_library_outlined;
      case PrivateFeatures.memories:
        return Icons.auto_awesome_outlined;
      default:
        return Icons.lock_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TonalMicroHeader(
            icon: Icons.vpn_key_outlined,
            title: 'Bloqueo por función',
            description:
                'Pide desbloqueo al entrar a estas secciones. Al salir, se vuelve a pedir.',
          ),
          const SizedBox(height: 16),
          for (final id in PrivateFeatures.all) ...[
            _FeatureRow(
              icon: _iconFor(id),
              label: PrivateFeatures.labelOf(id),
              value: featureLocks[id]?.requiresAuth ?? false,
              onChanged: (v) => onChanged(id, v),
            ),
            if (id != PrivateFeatures.all.last)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}