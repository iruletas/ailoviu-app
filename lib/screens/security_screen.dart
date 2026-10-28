import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_models.dart';
import '../providers/auth_settings_providers.dart';
import '../services/auth_keys.dart';
import '../services/auth_service.dart';
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

    // Protección efectiva: si el app-lock global está activo O
    // cualquier feature privada requiere auth, la app está protegida.
    final anyFeatureLocked =
        featureLocks.values.any((f) => f.requiresAuth);
    final anyProtectionActive = auth.appLockEnabled || anyFeatureLocked;

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
                _MethodCard(
                  auth: auth,
                  protectionActive: anyProtectionActive,
                  onChangePin: () => _createPin(context),
                  onRemovePin: () => _confirmRemovePin(context, ref),
                ),
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
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN actualizado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmRemovePin(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authSettingsProvider);
    if (!auth.systemAuthAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes quitar el PIN: es tu único método de desbloqueo.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
          backgroundColor: scheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.errorContainer,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 32,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Quitar PIN de respaldo',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Podrás seguir desbloqueando con huella o PIN del sistema.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Quitar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      final service = await ref.read(authServiceProvider.future);
      await service.clearAppPin();
      await ref
          .read(authSettingsProvider.notifier)
          .markAppPinConfigured(false);
    }
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

    final bg =
        enabled ? scheme.primaryContainer : scheme.surfaceContainerHighest;
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
              color: widget.selected ? scheme.primary : Colors.transparent,
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
  final AppAuthSettings auth;
  final bool protectionActive;
  final VoidCallback onChangePin;
  final VoidCallback onRemovePin;

  const _MethodCard({
    required this.auth,
    required this.protectionActive,
    required this.onChangePin,
    required this.onRemovePin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // Caso "apagado": no hay app-lock y ninguna feature bloqueada.
    // La tarjeta es informativa: muestra qué método SE USARÁ, pero
    // sin color tonal ni afirmación de "protegido".
    if (!protectionActive) {
      return _OffMethodCard(auth: auth);
    }

    // Caso "activo": al menos una protección está encendida.
    if (auth.systemAuthAvailable) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    size: 22,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Protegido por el sistema',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Huella, PIN o patrón del dispositivo',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer
                              .withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: scheme.onSecondaryContainer.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 12),
            if (auth.appPinFallbackConfigured)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'PIN de respaldo configurado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer
                            .withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onChangePin,
                    child: Text(
                      'Cambiar',
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: onRemovePin,
                    child: Text(
                      'Quitar',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sin PIN de respaldo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer
                            .withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onChangePin,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'Añadir',
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    if (auth.appPinFallbackConfigured) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.onTertiaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.pin_rounded,
                size: 22,
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PIN de Ailoviu',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Único método disponible en este dispositivo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer
                          .withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onChangePin,
              child: Text(
                'Cambiar',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      );
    }

    // Protección activa pero sin método disponible. Es un estado
    // inconsistente: el usuario tiene alguna feature bloqueada, pero
    // no hay forma de autenticarse. CTA para configurar PIN.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.onErrorContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 22,
              color: scheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sin método configurado',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Configura un PIN para proteger la app',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        scheme.onErrorContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: onChangePin,
            child: const Text('Configurar'),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta en estado "apagado": informativa, neutra, sin color tonal.
/// Solo aparece cuando ni el app-lock ni ninguna feature privada
/// requieren auth. Comunica qué método *se usará* al activar.
class _OffMethodCard extends StatelessWidget {
  final AppAuthSettings auth;

  const _OffMethodCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final hasSystem = auth.systemAuthAvailable;
    final hasPin = auth.appPinFallbackConfigured;

    // Ícono neutro (nunca verified_user ni pin lleno, que comunican
    // "activo"). Preferimos fingerprint si hay sistema, pin outlined
    // si solo hay PIN, error si no hay nada.
    final IconData icon;
    final Color iconColor;
    final String title;
    final String subtitle;

    if (hasSystem) {
      icon = Icons.fingerprint_rounded;
      iconColor = scheme.onSurfaceVariant;
      title = 'Huella, PIN o patrón';
      subtitle = 'Se activará al encender el bloqueo';
    } else if (hasPin) {
      icon = Icons.pin_outlined;
      iconColor = scheme.onSurfaceVariant;
      title = 'PIN de Ailoviu';
      subtitle = 'Se activará al encender el bloqueo';
    } else {
      icon = Icons.lock_outline_rounded;
      iconColor = scheme.onSurfaceVariant;
      title = 'Sin método configurado';
      subtitle = 'Configura un PIN para poder activar el bloqueo';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: iconColor),
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
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
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
        ],
      ),
    );
  }
}

// ── Tarjeta de bloqueo por función ───────────────────────────────────────

class _FeatureLocksCard extends StatelessWidget {
  final Map<String, PrivateFeatureLock> featureLocks;
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