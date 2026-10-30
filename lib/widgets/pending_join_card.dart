import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_models.dart';
import '../providers/linking_providers.dart';
import '../providers/sync_providers.dart';
import 'settings_components.dart';

/// Tarjeta de "Fulano quiere unirse al grupo", rediseñada en M3E.
///
/// - Squircle de avatar con pulso continuo mientras está pendiente.
/// - Badge "Solicitud de acceso" con dot radiante.
/// - Timestamp en MiniChip.
/// - Botones en píldora 48px con física de press.
/// - Loader con switch animado.
/// - Haptic gradual (light rechazar, medium aprobar).
/// - Toast flotante al confirmar el voto.
class PendingJoinCard extends ConsumerStatefulWidget {
  final PendingJoin pending;

  const PendingJoinCard({super.key, required this.pending});

  @override
  ConsumerState<PendingJoinCard> createState() => _PendingJoinCardState();
}

class _PendingJoinCardState extends ConsumerState<PendingJoinCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  bool _busy = false;
  bool _myVote = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _vote(bool approve) async {
    if (_busy) return;

    // Haptic gradual: light para rechazar, medium para aprobar.
    if (approve) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.lightImpact();
    }

    setState(() {
      _busy = true;
      _myVote = approve;
    });

    final myId = await ref.read(keyStoreProvider).getDeviceId();
    if (myId == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    ref.read(pendingJoinsProvider.notifier).registerVote(
          widget.pending.request.guestDeviceId,
          myId,
          approve,
        );

    try {
      final sync = await ref.read(syncServiceProvider.future);
      final sentIds = await sync.enqueue(
        type: SyncType.joinVote,
        payload: {
          'guestDeviceId': widget.pending.request.guestDeviceId,
          'voterDeviceId': myId,
          'vote': approve,
          'groupId': widget.pending.request.groupId,
        },
      );
      if (sentIds.isNotEmpty && mounted) {
        _showVoteToast();
      }
    } catch (_) {}

    if (mounted) setState(() => _busy = false);
  }

  void _showVoteToast() {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Voto registrado · Esperando unanimidad del grupo',
                  style: TextStyle(
                    color: scheme.onSurface,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final request = widget.pending.request;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: BentoCard(
        background: scheme.secondaryContainer.withValues(alpha: 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar con pulse.
                ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _buildAvatarInitial(scheme, request.displayName),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        request.displayName.isEmpty
                            ? 'Alguien quiere unirse'
                            : '${request.displayName} quiere unirse',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      MiniChip(
                        label: _timeAgo(widget.pending.receivedAt),
                        background: scheme.surfaceContainerHighest,
                        foreground: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: 'Solicitud de acceso',
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                  dotColor: scheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _myVote ? 0.4 : 1.0,
                    child: _PillActionButton(
                      label: 'Rechazar',
                      icon: Icons.close_rounded,
                      filled: false,
                      background: scheme.errorContainer,
                      foreground: scheme.onErrorContainer,
                      enabled: !_busy && !_myVote,
                      onTap: () => _vote(false),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillActionButton(
                    label: _myVote ? 'Aprobaste' : 'Aprobar',
                    icon: _myVote
                        ? Icons.verified_rounded
                        : Icons.check_rounded,
                    filled: true,
                    background: _myVote
                        ? scheme.tertiaryContainer
                        : scheme.primary,
                    foreground: _myVote
                        ? scheme.onTertiaryContainer
                        : scheme.onPrimary,
                    enabled: !_busy && !_myVote,
                    busy: _busy,
                    onTap: () => _vote(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarInitial(ColorScheme scheme, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Icon(
        Icons.person_outline_rounded,
        size: 22,
        color: scheme.onPrimaryContainer,
      );
    }
    return Text(
      trimmed[0].toUpperCase(),
      style: TextStyle(
        color: scheme.onPrimaryContainer,
        fontWeight: FontWeight.w800,
        fontSize: 20,
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }
}

// ══════════════════════════════════════════════════════════════════════
// Helpers
// ══════════════════════════════════════════════════════════════════════

class _StatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color dotColor;

  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool busy;
  final bool enabled;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _PillActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.background,
    required this.foreground,
    required this.enabled,
    required this.onTap,
    this.busy = false,
  });

  @override
  State<_PillActionButton> createState() => _PillActionButtonState();
}

class _PillActionButtonState extends State<_PillActionButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final enabled = widget.enabled && !widget.busy;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(24),
            border: widget.filled
                ? null
                : Border.all(
                    color: scheme.error.withValues(alpha: 0.25),
                  ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: widget.busy
                ? SizedBox(
                    key: const ValueKey('busy'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      strokeCap: StrokeCap.round,
                      color: widget.foreground,
                    ),
                  )
                : Row(
                    key: ValueKey('label-${widget.label}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: 18,
                        color: widget.foreground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: widget.foreground,
                          fontWeight: FontWeight.w700,
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