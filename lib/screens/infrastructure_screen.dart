import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_models.dart';
import '../providers/map_key_provider.dart';
import '../providers/sync_providers.dart';
import '../services/transport_config.dart';
import '../widgets/carto_key_dialog.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';
import 'linking_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// PROVIDERS LOCALES (estado asíncrono del KeyStore)
// ═══════════════════════════════════════════════════════════════════════

/// `true` si hay una config de Firebase guardada en el KeyStore.
final _firebaseConfiguredProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final raw = await ref.watch(keyStoreProvider).getTransportConfig();
  return raw != null;
});

/// `true` si hay una pregunta de recuperación guardada en el KeyStore.
final _recoveryConfiguredProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final q = await ref.watch(keyStoreProvider).getRecoveryQuestion();
  return q != null;
});

// ═══════════════════════════════════════════════════════════════════════
// TRANSICIÓN ORGÁNICA
// ═══════════════════════════════════════════════════════════════════════

Future<void> _openOrganic(BuildContext context, Widget screen) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// PANTALLA
// ═══════════════════════════════════════════════════════════════════════

/// Pantalla de infraestructura y conexiones.
///
/// - Vinculación (grupo de la relación).
/// - Geolocalización (API Key de CARTO).
/// - Firebase (pegado de `google-services.json`).
/// - Recuperación (pregunta y respuesta).
class InfrastructureScreen extends ConsumerWidget {
  const InfrastructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final hasKey = ref.watch(cartoKeyProvider).isNotEmpty;
    final firebaseOk = ref.watch(_firebaseConfiguredProvider).valueOrNull ??
        false;
    final recoveryOk = ref.watch(_recoveryConfiguredProvider).valueOrNull ??
        false;

    final activeServices = (hasKey ? 1 : 0) + (firebaseOk ? 1 : 0);
    const totalServices = 2;

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
              'Conexiones',
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
                // ── 1. Hero de estado global ───────────────────────────
                _NetworkStatusHero(
                  active: activeServices,
                  total: totalServices,
                ),
                const SizedBox(height: 24),

                // ── 2. Vinculación ─────────────────────────────────────
                const SectionLabel('Vinculación'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  child: SettingsTileExpressive(
                    leading: const _LinkingLeading(),
                    title: 'Vinculación',
                    subtitle: const _LinkingSubtitle(),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openOrganic(context, const LinkingScreen()).then((_) {
                        ref.invalidate(groupSnapshotProvider);
                        ref.invalidate(_recoveryConfiguredProvider);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // ── 3. Geolocalización ─────────────────────────────────
                const SectionLabel('Geolocalización'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  child: SettingsTileExpressive(
                    leading: const _MapLeading(),
                    title: 'Mapa',
                    subtitle: const _MapSubtitle(),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasKey)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: scheme.tertiary,
                              size: 18,
                            ),
                          ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      CartoKeyDialog.show(context);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // ── 4. Sincronización y respaldo (Firebase) ────────────
                const SectionLabel('Sincronización y respaldo'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  child: SettingsTileExpressive(
                    leading: const _FirebaseLeading(),
                    title: 'Firebase',
                    subtitle: const _FirebaseSubtitle(),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (firebaseOk)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: scheme.tertiary,
                              size: 18,
                            ),
                          ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await _FirebaseConfigSheet.show(context);
                      ref.invalidate(_firebaseConfiguredProvider);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // ── 5. Recuperación ────────────────────────────────────
                const SectionLabel('Recuperación'),
                const SizedBox(height: 8),
                BentoCard(
                  background: scheme.surfaceContainerHigh,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TonalMicroHeader(
                        icon: recoveryOk
                            ? Icons.shield_rounded
                            : Icons.shield_outlined,
                        title: 'Pregunta de recuperación',
                        description:
                            'Te ayuda a recuperar tu cuenta si cambias de '
                            'teléfono.',
                        bubbleBackground: recoveryOk
                            ? scheme.tertiaryContainer
                            : scheme.secondaryContainer,
                        bubbleForeground: recoveryOk
                            ? scheme.onTertiaryContainer
                            : scheme.onSecondaryContainer,
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutBack,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                          ),
                          child: recoveryOk
                              ? MiniChip(
                                  key: const ValueKey('rec-on'),
                                  label: 'Configurada',
                                  background: scheme.tertiaryContainer,
                                  foreground: scheme.onTertiaryContainer,
                                  bold: true,
                                )
                              : MiniChip(
                                  key: const ValueKey('rec-off'),
                                  label: 'Sin configurar',
                                  background: scheme.surfaceContainerHighest,
                                  foreground: scheme.onSurfaceVariant,
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PillButton(
                        label: recoveryOk
                            ? 'Cambiar pregunta'
                            : 'Configurar pregunta',
                        icon: Icons.edit_rounded,
                        style: _PillStyle.tonal,
                        onTap: () => _configureRecovery(context, ref),
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

  // ─────────────────────────────────────────────────────────────────
  // Recuperación: diálogo + guardado + propagación
  // ─────────────────────────────────────────────────────────────────

  Future<void> _configureRecovery(BuildContext context, WidgetRef ref) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);

    final result = await showGeneralDialog<_RecoveryFormResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: const _RecoveryDialog(),
      ),
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubicEmphasized,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (result == null) return;
    if (!context.mounted) return;

    try {
      final q = await ref.read(linkingServiceProvider).setRecoveryQuestion(
            questionPlain: result.question,
            answer: result.answer,
          );
      ref.invalidate(_recoveryConfiguredProvider);

      ref.invalidate(groupSnapshotProvider);
      final snap = await ref.read(groupSnapshotProvider.future);

      var propagated = true;
      if (snap.approvedOthers.isNotEmpty) {
        try {
          final sync = await ref.read(syncServiceProvider.future);
          await sync.enqueue(
            type: SyncType.recoveryQuestionUpdate,
            payload: {
              'questionPlain': q.questionPlain,
              'answerHash': q.answerHash,
              'answerSalt': q.answerSalt,
            },
          );
        } catch (_) {
          propagated = false;
        }
      }

      HapticFeedback.mediumImpact();
      if (propagated) {
        _insertToast(overlay, 'Pregunta de recuperación guardada');
      } else {
        _insertToast(
          overlay,
          'Se guardó aquí, pero no se pudo enviar a tu pareja',
          error: true,
        );
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
      _insertToast(
        overlay,
        'No se pudo guardar la pregunta',
        error: true,
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMPONENTES DE ESTADO
// ═══════════════════════════════════════════════════════════════════════

/// Hero Card que muestra el estado global de los servicios.
class _NetworkStatusHero extends StatelessWidget {
  final int active;
  final int total;

  const _NetworkStatusHero({
    required this.active,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final allActive = active == total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              scheme.primaryContainer.withValues(alpha: 0.15),
              scheme.surfaceContainerLow,
            ),
            Color.alphaBlend(
              scheme.tertiaryContainer.withValues(alpha: 0.10),
              scheme.surfaceContainerLow,
            ),
          ],
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.hub_rounded,
              size: 24,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Infraestructura y Nube',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (allActive) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '$active de $total ${total == 1 ? "servicio activo" : "servicios activos"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: allActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMPONENTES REACTIVOS: VINCULACIÓN
// ═══════════════════════════════════════════════════════════════════════

class _LinkingLeading extends ConsumerWidget {
  const _LinkingLeading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final linked =
        ref.watch(groupSnapshotProvider).valueOrNull?.isLinked ?? false;

    final bg = linked ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final fg =
        linked ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    final icon = linked ? Icons.link_rounded : Icons.link_off_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: linked
            ? [
                BoxShadow(
                  color: scheme.tertiary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          icon,
          key: ValueKey(linked),
          size: 20,
          color: fg,
        ),
      ),
    );
  }
}

class _LinkingSubtitle extends ConsumerWidget {
  const _LinkingSubtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final snap = ref.watch(groupSnapshotProvider).valueOrNull;

    final linked = snap?.isLinked ?? false;
    final hasGroup = snap?.groupId != null;
    final count = snap == null
        ? 0
        : snap.members.values.where((m) => m.approved).length;

    final chip = linked
        ? MiniChip(
            key: const ValueKey('link-on'),
            label: 'Vinculado',
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
            bold: true,
          )
        : MiniChip(
            key: const ValueKey('link-off'),
            label: 'Sin vincular',
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: chip,
        ),
        if (hasGroup && count > 0) ...[
          const SizedBox(width: 8),
          Text(
            count == 1 ? '1 miembro' : '$count miembros',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMPONENTES REACTIVOS PARA EL MAPA
// ═══════════════════════════════════════════════════════════════════════

class _MapLeading extends ConsumerWidget {
  const _MapLeading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasKey = ref.watch(cartoKeyProvider).isNotEmpty;

    final bg = hasKey ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final fg = hasKey ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    final icon = hasKey ? Icons.map_rounded : Icons.map_outlined;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: hasKey
            ? [
                BoxShadow(
                  color: scheme.tertiary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          icon,
          key: ValueKey(hasKey),
          size: 20,
          color: fg,
        ),
      ),
    );
  }
}

class _MapSubtitle extends ConsumerWidget {
  const _MapSubtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasKey = ref.watch(cartoKeyProvider).isNotEmpty;

    Widget chip;
    if (hasKey) {
      chip = Row(
        key: const ValueKey('carto'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.tertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          MiniChip(
            label: 'CARTO Limpio',
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
            bold: true,
          ),
        ],
      );
    } else {
      chip = MiniChip(
        key: const ValueKey('osm'),
        label: 'OpenStreetMap',
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
      child: chip,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMPONENTES REACTIVOS PARA FIREBASE
// ═══════════════════════════════════════════════════════════════════════

class _FirebaseLeading extends ConsumerWidget {
  const _FirebaseLeading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ok = ref.watch(_firebaseConfiguredProvider).valueOrNull ?? false;

    final bg = ok ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final fg = ok ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    final icon = ok
        ? Icons.local_fire_department_rounded
        : Icons.local_fire_department_outlined;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: ok
            ? [
                BoxShadow(
                  color: scheme.tertiary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          icon,
          key: ValueKey(ok),
          size: 20,
          color: fg,
        ),
      ),
    );
  }
}

class _FirebaseSubtitle extends ConsumerWidget {
  const _FirebaseSubtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final ok = ref.watch(_firebaseConfiguredProvider).valueOrNull ?? false;

    final Widget content = ok
        ? MiniChip(
            key: const ValueKey('fb-on'),
            label: 'Configurado',
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
            bold: true,
          )
        : Text(
            'Base de datos y sync E2EE',
            key: const ValueKey('fb-off'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      child: content,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BOTTOM SHEET: CONFIGURACIÓN DE FIREBASE
// ═══════════════════════════════════════════════════════════════════════

class _FirebaseConfigSheet extends ConsumerStatefulWidget {
  const _FirebaseConfigSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const _FirebaseConfigSheet(),
    );
  }

  @override
  ConsumerState<_FirebaseConfigSheet> createState() =>
      _FirebaseConfigSheetState();
}

class _FirebaseConfigSheetState extends ConsumerState<_FirebaseConfigSheet> {
  final _controller = TextEditingController();

  bool _loaded = false;
  bool _configured = false;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    bool configured = false;
    try {
      configured =
          await ref.read(keyStoreProvider).getTransportConfig() != null;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _configured = configured;
      _loaded = true;
    });
  }

  bool get _showField => !_configured || _editing;

  Future<void> _save() async {
    if (_saving) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final text = _controller.text.trim();

    if (text.isEmpty) {
      HapticFeedback.heavyImpact();
      _insertToast(
        overlay,
        'Pega primero el contenido de google-services.json',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);

    // 1. Parseo y validación (sin cerrar el sheet si falla).
    final FirebaseTransportConfig config;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('El JSON no es un objeto');
      }
      config = FirebaseTransportConfig.fromGoogleServicesJson(decoded);
    } catch (_) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _saving = false);
      _insertToast(
        overlay,
        'El JSON no es válido. Revisa que sea tu google-services.json',
        error: true,
      );
      return;
    }

    // 2. Persistencia + propagación al grupo si soy host.
    try {
      final json = config.toJson();
      await ref.read(keyStoreProvider).setTransportConfig(json);
      ref.invalidate(_firebaseConfiguredProvider);
      ref.invalidate(transportConfigProvider);

      ref.invalidate(groupSnapshotProvider);
      final snap = await ref.read(groupSnapshotProvider.future);

      var propagated = true;
      if (snap.isHost) {
        try {
          final sync = await ref.read(syncServiceProvider.future);
          await sync.enqueue(
            type: SyncType.hostCredentials,
            payload: {'config': json},
          );
        } catch (_) {
          propagated = false;
        }
      }

      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();

      if (propagated) {
        _insertToast(overlay, 'Firebase configurado');
      } else {
        _insertToast(
          overlay,
          'Firebase quedó configurado, pero no se pudo enviar al grupo',
          error: true,
        );
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _saving = false);
      _insertToast(
        overlay,
        'No se pudo guardar la configuración',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: SingleChildScrollView(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TonalMicroHeader(
                          icon: Icons.local_fire_department_rounded,
                          title: 'Firebase',
                          description:
                              'Pega tu google-services.json para activar la '
                              'sincronización E2EE.',
                          bubbleBackground: scheme.tertiaryContainer,
                          bubbleForeground: scheme.onTertiaryContainer,
                        ),
                        const SizedBox(height: 16),
                        if (!_loaded)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          if (_configured)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: scheme.tertiary,
                                    ),
                                    const SizedBox(width: 8),
                                    MiniChip(
                                      label: 'Configurado',
                                      background: scheme.tertiaryContainer,
                                      foreground: scheme.onTertiaryContainer,
                                      bold: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_showField) ...[
                            TextField(
                              controller: _controller,
                              enabled: !_saving,
                              minLines: 6,
                              maxLines: 10,
                              keyboardType: TextInputType.multiline,
                              autocorrect: false,
                              enableSuggestions: false,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: '{ "project_info": { ... } }',
                                hintStyle: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                                filled: true,
                                fillColor: scheme.surfaceContainerHighest,
                                contentPadding: const EdgeInsets.all(18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: scheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _PillButton(
                                    label: 'Cancelar',
                                    style: _PillStyle.tonal,
                                    onTap: _saving
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _PillButton(
                                    label: 'Guardar',
                                    icon: Icons.check_rounded,
                                    style: _PillStyle.filled,
                                    busy: _saving,
                                    onTap: _save,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              'Ya hay una configuración guardada en este '
                              'dispositivo. Si pegas una nueva, reemplaza a '
                              'la actual.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _PillButton(
                                    label: 'Cancelar',
                                    style: _PillStyle.tonal,
                                    onTap: () => Navigator.of(context).pop(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _PillButton(
                                    label: 'Reconfigurar',
                                    icon: Icons.edit_rounded,
                                    style: _PillStyle.filled,
                                    onTap: () =>
                                        setState(() => _editing = true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DIÁLOGO: PREGUNTA DE RECUPERACIÓN
// ═══════════════════════════════════════════════════════════════════════

class _RecoveryFormResult {
  final String question;
  final String answer;

  const _RecoveryFormResult({required this.question, required this.answer});
}

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog();

  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();

  @override
  void dispose() {
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _questionCtrl.text.trim().isNotEmpty &&
      _answerCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      _RecoveryFormResult(
        question: _questionCtrl.text.trim(),
        answer: _answerCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: TonalIconBubble(
                        icon: Icons.shield_rounded,
                        size: 56,
                        background: scheme.primaryContainer,
                        foreground: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pregunta de recuperación',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Si cambias de teléfono, tu pareja usará esta pregunta '
                      'para confirmar que eres tú.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _GlassField(
                      label: 'Pregunta',
                      hint: 'Ej. ¿Cómo se llama nuestra mascota?',
                      controller: _questionCtrl,
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _GlassField(
                      label: 'Respuesta',
                      hint: 'La respuesta que recordarás',
                      controller: _answerCtrl,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _PillButton(
                            label: 'Cancelar',
                            style: _PillStyle.tonal,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PillButton(
                            label: 'Guardar',
                            icon: Icons.check_rounded,
                            style: _PillStyle.filled,
                            onTap: _valid ? _submit : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _GlassField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: 1,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BOTÓN PILL (física de press 0.92 → easeOutBack)
// ═══════════════════════════════════════════════════════════════════════

enum _PillStyle { filled, tonal }

class _PillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final _PillStyle style;
  final bool busy;
  final double height;
  final VoidCallback? onTap;

  const _PillButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.style = _PillStyle.filled,
    this.busy = false,
    this.height = 52,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null && !widget.busy;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final Color bg;
    final Color fg;
    switch (widget.style) {
      case _PillStyle.filled:
        bg = scheme.primary;
        fg = scheme.onPrimary;
        break;
      case _PillStyle.tonal:
        bg = scheme.secondaryContainer;
        fg = scheme.onSecondaryContainer;
        break;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => _setPressed(true) : null,
      onTapUp: _enabled ? (_) => _setPressed(false) : null,
      onTapCancel: _enabled ? () => _setPressed(false) : null,
      onTap: _enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: (widget.onTap == null && !widget.busy) ? 0.4 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: widget.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: ShapeDecoration(
              color: bg,
              shape: const StadiumBorder(),
            ),
            child: widget.busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
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

// ═══════════════════════════════════════════════════════════════════════
// TOAST FLOTANTE GLASS (cápsula)
// ═══════════════════════════════════════════════════════════════════════

/// Inserta un toast en el overlay raíz, por encima de sheets y diálogos.
/// Se captura el [OverlayState] antes de cerrar un sheet para poder
/// mostrar el toast después de hacer `pop`.
void _insertToast(
  OverlayState? overlay,
  String message, {
  bool error = false,
}) {
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _GlassToast(
      message: message,
      error: error,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _GlassToast extends StatefulWidget {
  final String message;
  final bool error;
  final VoidCallback onDone;

  const _GlassToast({
    required this.message,
    required this.error,
    required this.onDone,
  });

  @override
  State<_GlassToast> createState() => _GlassToastState();
}

class _GlassToastState extends State<_GlassToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.6),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(
      Duration(milliseconds: widget.error ? 3400 : 2400),
    );
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final bottom = (media.viewInsets.bottom > media.padding.bottom
            ? media.viewInsets.bottom
            : media.padding.bottom) +
        24;

    final bg = widget.error
        ? scheme.errorContainer.withValues(alpha: 0.94)
        : scheme.surfaceContainerHigh.withValues(alpha: 0.92);
    final fg = widget.error ? scheme.onErrorContainer : scheme.onSurface;
    final iconColor = widget.error ? scheme.error : scheme.primary;
    final icon = widget.error
        ? Icons.error_rounded
        : Icons.check_circle_rounded;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: ShapeDecoration(
                          color: bg,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 18, color: iconColor),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  color: fg,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
