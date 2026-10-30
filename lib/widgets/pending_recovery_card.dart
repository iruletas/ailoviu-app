import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_models.dart';
import '../providers/linking_providers.dart';
import '../providers/recovery_providers.dart';
import '../providers/sync_providers.dart';
import 'settings_components.dart';

/// Tarjeta de "Fulano quiere recuperar su cuenta", rediseñada M3E.
///
/// - Bento tertiaryContainer con borde.
/// - Badge "Restablecimiento de cuenta" con dot.
/// - Squircle con pulse jitter.
/// - Chip con deviceId viejo en monoespaciado.
/// - Botón píldora con morph a estado verificado.
class PendingRecoveryCard extends ConsumerStatefulWidget {
  final PendingRecovery pending;

  const PendingRecoveryCard({super.key, required this.pending});

  @override
  ConsumerState<PendingRecoveryCard> createState() =>
      _PendingRecoveryCardState();
}

class _PendingRecoveryCardState extends ConsumerState<PendingRecoveryCard>
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
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
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

  Future<void> _openVerifyDialog() async {
    final request = widget.pending.request;
    final oldId = request.recoveryOldDeviceId;
    if (oldId == null) return;

    final question = await ref.read(keyStoreProvider).getRecoveryQuestion();
    if (!mounted) return;

    final result = await showGeneralDialog<_VerifyDialogResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: _VerifyFactorsDialog(
            questionPlain: question?.questionPlain,
            recoveryOldDeviceId: oldId,
            recoveryPinHashFromGuest: request.recoveryPinHash,
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubicEmphasized,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    await _vote(result.approved);
  }

  Future<void> _vote(bool approve) async {
    if (_busy) return;

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

    ref.read(pendingRecoveriesProvider.notifier).registerVote(
          widget.pending.request.guestDeviceId,
          myId,
          approve,
        );

    try {
      final sync = await ref.read(syncServiceProvider.future);
      await sync.enqueue(
        type: SyncType.recoveryVote,
        payload: {
          'guestDeviceId': widget.pending.request.guestDeviceId,
          'voterDeviceId': myId,
          'vote': approve,
        },
      );
    } catch (_) {}

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final request = widget.pending.request;
    final oldId = request.recoveryOldDeviceId ?? '';
    final shortId = oldId.length > 8 ? oldId.substring(0, 8) : oldId;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: BentoCard(
        background: Color.alphaBlend(
          scheme.tertiaryContainer.withValues(alpha: 0.85),
          scheme.surfaceContainerLow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 24,
                      color: scheme.onTertiaryContainer,
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
                        '${request.displayName} quiere recuperar su cuenta',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.smartphone_rounded,
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Reemplaza: $shortId…',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: 'Restablecimiento',
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                  dotColor: scheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PillActionButton(
              label: _myVote ? 'Voto registrado' : 'Verificar factores y votar',
              icon: _myVote ? Icons.verified_rounded : Icons.verified_user_rounded,
              background: _myVote
                  ? scheme.secondaryContainer
                  : scheme.tertiary,
              foreground: _myVote
                  ? scheme.onSecondaryContainer
                  : scheme.onTertiary,
              enabled: !_busy && !_myVote,
              busy: _busy,
              onTap: _openVerifyDialog,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Pill helper
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
  final bool busy;
  final bool enabled;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _PillActionButton({
    required this.label,
    required this.icon,
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
                      Icon(widget.icon, size: 18, color: widget.foreground),
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

// ══════════════════════════════════════════════════════════════════════
// Diálogo de verificación rediseñado
// ══════════════════════════════════════════════════════════════════════

class _VerifyFactorsDialog extends ConsumerStatefulWidget {
  final String? questionPlain;
  final String recoveryOldDeviceId;
  final String? recoveryPinHashFromGuest;

  const _VerifyFactorsDialog({
    required this.questionPlain,
    required this.recoveryOldDeviceId,
    required this.recoveryPinHashFromGuest,
  });

  @override
  ConsumerState<_VerifyFactorsDialog> createState() =>
      _VerifyFactorsDialogState();
}

class _VerifyFactorsDialogState extends ConsumerState<_VerifyFactorsDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _answerCtrl;
  late final FocusNode _focusNode;
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  bool _verifying = false;
  bool _focusActive = false;
  bool _ok = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _answerCtrl = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _focusActive = _focusNode.hasFocus);
      }
    });

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _feedback = null;
    });

    await HapticFeedback.lightImpact();

    final result = await ref.read(recoveryServiceProvider).verifyFactors(
          recoveryOldDeviceId: widget.recoveryOldDeviceId,
          answerFromMember: _answerCtrl.text,
          recoveryPinHashFromGuest: widget.recoveryPinHashFromGuest,
        );

    if (!mounted) return;

    if (result.isAllowed) {
      await HapticFeedback.mediumImpact();
      setState(() {
        _verifying = false;
        _ok = true;
        _feedback = 'Factores verificados correctamente';
      });
    } else {
      await _shakeController.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _ok = false;
        _feedback = result.detail.isEmpty
            ? 'No se pudo verificar la identidad'
            : result.detail;
      });
    }
  }

  Future<void> _approve() async {
    await HapticFeedback.heavyImpact();
    if (mounted) {
      Navigator.of(context).pop(const _VerifyDialogResult(approved: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(_shake.value, 0),
              child: child,
            ),
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
                    // Hero header.
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.verified_user_rounded,
                          size: 28,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verificar identidad',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Comprueba los factores de seguridad del miembro',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pregunta en mini-bento.
                    if (widget.questionPlain != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Pregunta clave del grupo',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.questionPlain!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Campo de respuesta con focus expansion.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _focusActive
                              ? scheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.question_answer_rounded,
                            size: 18,
                            color: _focusActive
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _answerCtrl,
                              focusNode: _focusNode,
                              decoration: const InputDecoration(
                                hintText: 'Escribe la respuesta aquí…',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cápsula de feedback animada.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _feedback == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _ok
                                      ? scheme.primaryContainer
                                      : scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _ok
                                          ? Icons.check_circle_rounded
                                          : Icons.error_outline_rounded,
                                      size: 16,
                                      color: _ok
                                          ? scheme.onPrimaryContainer
                                          : scheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _feedback!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: _ok
                                              ? scheme.onPrimaryContainer
                                              : scheme.onErrorContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // Acciones.
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _verifying
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _verifying ? null : _verify,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: const StadiumBorder(),
                            ),
                            child: _verifying
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      strokeCap: StrokeCap.round,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Text('Verificar'),
                          ),
                        ),
                      ],
                    ),

                    // Botón de aprobar que emerge con spring.
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      offset: _ok ? Offset.zero : const Offset(0, 0.4),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        scale: _ok ? 1.0 : 0.9,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 260),
                          opacity: _ok ? 1.0 : 0.0,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: FilledButton.icon(
                              onPressed: _ok ? _approve : null,
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                              ),
                              label: const Text('Aprobar recuperación'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: const StadiumBorder(),
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                              ),
                            ),
                          ),
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
    );
  }
}

class _VerifyDialogResult {
  final bool approved;
  const _VerifyDialogResult({required this.approved});
}