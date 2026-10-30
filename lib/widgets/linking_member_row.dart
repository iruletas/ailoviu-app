import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../models/sync_models.dart';
import '../providers/sync_providers.dart';
import 'settings_components.dart';

/// Fila de un miembro del grupo, rediseñada en M3E.
///
/// - Micro-bento por fila (20px radio, borde 25%).
/// - Avatar squircle con dot de estado (radiante si pendiente).
/// - Badges pill: Anfitrión / Tú / Activo / Pendiente.
/// - Botón tonal destructivo con press physics.
/// - Glass confirm dialog para expulsar.
/// - Toast flotante de error si falla.
/// - Animación de salida colapsada (AnimatedSize + fade).
class LinkingMemberRow extends ConsumerStatefulWidget {
  final GroupMember member;
  final bool isMe;

  const LinkingMemberRow({
    super.key,
    required this.member,
    required this.isMe,
  });

  @override
  ConsumerState<LinkingMemberRow> createState() => _LinkingMemberRowState();
}

class _LinkingMemberRowState extends ConsumerState<LinkingMemberRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _removing = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (!widget.member.approved) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LinkingMemberRow old) {
    super.didUpdateWidget(old);
    if (!widget.member.approved && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.member.approved && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _confirmRemove() async {
    await HapticFeedback.lightImpact();
    final confirmed = await _showGlassConfirm();
    if (confirmed != true || !mounted) return;

    setState(() => _removing = true);

    try {
      await ref.read(linkingServiceProvider).removeMember(widget.member.deviceId);
      final sync = await ref.read(syncServiceProvider.future);
      await sync.enqueue(
        type: SyncType.memberLeave,
        payload: {'deviceId': widget.member.deviceId},
      );
      await sync.reloadPeers();
      // La animación de salida es la del AnimatedSize en build.
    } catch (e) {
      if (mounted) {
        setState(() => _removing = false);
        _showErrorToast('No se pudo expulsar: $e');
      }
    }
  }

  void _showErrorToast(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showGlassConfirm() {
    final name = (widget.member.displayName ?? '').trim();
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: _GlassConfirmDialog(
          title: 'Expulsar a ${name.isEmpty ? 'este miembro' : name}',
          message:
              'Dejará de recibir mensajes y no podrá volver a ver los '
              'datos nuevos del grupo. El historial anterior ya no '
              'será accesible para esta persona.',
        ),
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
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final m = widget.member;
    final name = (m.displayName ?? '').trim();
    final initial = name.isEmpty ? null : name[0].toUpperCase();

    final avatarBg =
        m.isHost ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final avatarFg =
        m.isHost ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: _removing
          ? const SizedBox(width: double.infinity)
          : AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              opacity: _removing ? 0.0 : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    setState(() => _pressed = true);
                  },
                  onTapUp: (_) {
                    setState(() => _pressed = false);
                  },
                  onTapCancel: () {
                    setState(() => _pressed = false);
                  },
                  child: AnimatedScale(
                    scale: _pressed ? 0.98 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outlineVariant
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(
                            initial: initial,
                            bg: avatarBg,
                            fg: avatarFg,
                            approved: m.approved,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name.isEmpty ? 'Sin nombre' : name,
                                        style:
                                            theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    if (m.isHost)
                                      _MicroBadge(
                                        icon: Icons.star_rounded,
                                        label: 'Anfitrión',
                                        background: scheme.tertiaryContainer,
                                        foreground:
                                            scheme.onTertiaryContainer,
                                      ),
                                    if (widget.isMe)
                                      _MicroBadge(
                                        label: 'Tú',
                                        background: scheme.primaryContainer,
                                        foreground:
                                            scheme.onPrimaryContainer,
                                        bold: true,
                                      ),
                                    _MicroBadge(
                                      label: m.approved ? 'Activo' : 'Pendiente',
                                      background: m.approved
                                          ? scheme.secondaryContainer
                                          : scheme.errorContainer
                                              .withValues(alpha: 0.4),
                                      foreground: m.approved
                                          ? scheme.onSecondaryContainer
                                          : scheme.onErrorContainer,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!widget.isMe && m.approved)
                            _DestructiveActionButton(
                              onTap: _confirmRemove,
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

  Widget _buildAvatar({
    required String? initial,
    required Color bg,
    required Color fg,
    required bool approved,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: initial == null
              ? Icon(
                  Icons.person_outline,
                  size: 20,
                  color: fg,
                )
              : Text(
                  initial,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: approved
              ? _StaticDot(
                  color: Theme.of(context).colorScheme.primary,
                  borderColor: Theme.of(context).colorScheme.surface,
                )
              : _PulsingDot(
                  controller: _pulseController,
                  color: Theme.of(context).colorScheme.error,
                  borderColor: Theme.of(context).colorScheme.surface,
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Sub-widgets
// ══════════════════════════════════════════════════════════════════════

class _StaticDot extends StatelessWidget {
  final Color color;
  final Color borderColor;
  const _StaticDot({required this.color, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final Color borderColor;

  const _PulsingDot({
    required this.controller,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4 + t * 0.4),
                blurRadius: 4 + t * 4,
                spreadRadius: t * 1.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MicroBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final bool bold;

  const _MicroBadge({
    required this.label,
    this.icon,
    required this.background,
    required this.foreground,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestructiveActionButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DestructiveActionButton({required this.onTap});

  @override
  State<_DestructiveActionButton> createState() =>
      _DestructiveActionButtonState();
}

class _DestructiveActionButtonState extends State<_DestructiveActionButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.person_remove_rounded,
            size: 20,
            color: scheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class _GlassConfirmDialog extends StatelessWidget {
  final String title;
  final String message;

  const _GlassConfirmDialog({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person_remove_rounded,
                    size: 32,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: scheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(true),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Expulsar'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}