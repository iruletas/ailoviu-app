import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../models/sync_models.dart';
import '../providers/recovery_providers.dart';
import '../providers/sync_providers.dart';
import '../services/invite_service.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';
import 'linking_screen.dart' show QrScannerScreen;

/// Pantalla de recuperación de cuenta.
class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  GroupInvitePayload? _invite;
  bool _busy = false;

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (scanned == null || !mounted) return;

    try {
      final invite = GroupInvitePayload.fromQrString(scanned);
      if (!invite.isRecovery) {
        _showErrorToast('Ese QR no es de recuperación');
        return;
      }
      if (invite.isExpired) {
        _showErrorToast('El QR de recuperación expiró');
        return;
      }
      await HapticFeedback.mediumImpact();
      if (mounted) setState(() => _invite = invite);
    } on InviteException catch (e) {
      _showErrorToast(e.message);
    } catch (_) {
      _showErrorToast('QR de recuperación inválido');
    }
  }

  Future<void> _submit({
    required String displayName,
    required String oldDeviceId,
    required String answer,
    required String pin,
  }) async {
    if (_busy || _invite == null) return;
    setState(() => _busy = true);

    try {
      final me = await ref
          .read(linkingServiceProvider)
          .ensureLocalIdentity();

      final recovery = ref.read(recoveryServiceProvider);
      final request = await recovery.buildRequest(
        groupId: _invite!.groupId,
        myDeviceId: me.deviceId,
        myPublicKeyBase64: me.publicKeyBase64,
        displayName: displayName,
        oldDeviceId: oldDeviceId,
        recoveryPin: pin.trim().isEmpty ? null : pin.trim(),
      );

      final sync = await ref.read(syncServiceProvider.future);
      final ok = await sync.publishRecovery(
        inviteToken: _invite!.inviteToken,
        request: request,
      );

      if (!mounted) return;
      setState(() => _busy = false);

      if (!ok) {
        _showErrorToast(
          'No se pudo enviar la solicitud. Revisa tu conexión.',
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const _RecoveryWaitingScreen(),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showErrorToast('Error: $e');
      }
    }
  }

  void _showErrorToast(String msg) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                      msg,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

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
              'Recuperar cuenta',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeInOutCubicEmphasized,
                  switchOutCurve: Curves.easeInOutCubicEmphasized,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubicEmphasized,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: _invite == null
                      ? _StepOne(
                          key: const ValueKey('step1'),
                          onScan: _scan,
                        )
                      : _StepTwo(
                          key: const ValueKey('step2'),
                          invite: _invite!,
                          busy: _busy,
                          onRescan: () {
                            HapticFeedback.lightImpact();
                            setState(() => _invite = null);
                          },
                          onSubmit: _submit,
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

// ══════════════════════════════════════════════════════════════════════
// Press button (compresión táctil 0.96×)
// ══════════════════════════════════════════════════════════════════════

class _PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressableButton({
    required this.child,
    required this.onTap,
  });

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Paso 1
// ══════════════════════════════════════════════════════════════════════

class _StepOne extends StatelessWidget {
  final VoidCallback onScan;
  const _StepOne({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.restore_rounded,
                  size: 28,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cambiaste de teléfono',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Recupera tu cuenta escaneando el QR de recuperación. '
                'Otro miembro del grupo (o tu dispositivo viejo, si aún '
                'lo tienes) lo genera desde Vinculación.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TonalMicroHeader(
                icon: Icons.verified_user_rounded,
                title: 'Aprobación unánime',
                description:
                    'Todos los miembros del grupo tienen que aprobar tu '
                    'recuperación.',
              ),
              const SizedBox(height: 14),
              const TonalMicroHeader(
                icon: Icons.smartphone_rounded,
                title: 'Reemplaza tu dispositivo viejo',
                description:
                    'El deviceId viejo se reemplaza por el nuevo. El '
                    'dispositivo viejo deja de tener acceso al grupo.',
              ),
              const SizedBox(height: 14),
              const TonalMicroHeader(
                icon: Icons.shield_outlined,
                title: 'Verificación con factores',
                description:
                    'El grupo verifica la pregunta de recuperación y, '
                    'opcionalmente, tu PIN viejo.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PressableButton(
          onTap: () {
            HapticFeedback.lightImpact();
            onScan();
          },
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              onScan();
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Escanear QR de recuperación'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Paso 2
// ══════════════════════════════════════════════════════════════════════

class _StepTwo extends StatefulWidget {
  final GroupInvitePayload invite;
  final bool busy;
  final VoidCallback onRescan;
  final Future<void> Function({
    required String displayName,
    required String oldDeviceId,
    required String answer,
    required String pin,
  }) onSubmit;

  const _StepTwo({
    super.key,
    required this.invite,
    required this.busy,
    required this.onRescan,
    required this.onSubmit,
  });

  @override
  State<_StepTwo> createState() => _StepTwoState();
}

class _StepTwoState extends State<_StepTwo> {
  final _nameCtrl = TextEditingController();
  final _oldIdCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final oldId = widget.invite.recoveryOldDeviceId ?? '';
    if (oldId.isNotEmpty) _oldIdCtrl.text = oldId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldIdCtrl.dispose();
    _answerCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _oldIdCtrl.text.trim().isNotEmpty &&
      _answerCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Contexto del QR escaneado.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 20,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'QR de recuperación escaneado',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.busy ? null : widget.onRescan,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onTertiaryContainer,
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Cambiar'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (widget.invite.recoveryQuestionPlain != null)
                Text(
                  widget.invite.recoveryQuestionPlain!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        scheme.onTertiaryContainer.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Formulario.
        _RecoveryLabeledField(
          label: 'Tu nombre',
          hint: 'Ej. Ana',
          leadingIcon: Icons.person_rounded,
          controller: _nameCtrl,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _RecoveryLabeledField(
          label: 'Device ID viejo',
          hint: 'El ID del dispositivo que reemplazas',
          leadingIcon: Icons.phone_android_rounded,
          controller: _oldIdCtrl,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Pídelo a otro miembro del grupo, o míralo en la pantalla de '
            'Vinculación del dispositivo viejo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RecoveryLabeledField(
          label: 'Respuesta a la pregunta de recuperación',
          hint: 'La respuesta que configuraste',
          leadingIcon: Icons.psychology_rounded,
          controller: _answerCtrl,
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _RecoveryLabeledField(
          label: 'PIN viejo (opcional)',
          hint: 'Solo si lo recuerdas',
          leadingIcon: Icons.pin_rounded,
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),

        // Botón de enviar.
        _PressableButton(
          onTap: (_valid && !widget.busy)
              ? () {
                  HapticFeedback.mediumImpact();
                  widget.onSubmit(
                    displayName: _nameCtrl.text.trim(),
                    oldDeviceId: _oldIdCtrl.text.trim(),
                    answer: _answerCtrl.text.trim(),
                    pin: _pinCtrl.text.trim(),
                  );
                }
              : null,
          child: FilledButton.icon(
            onPressed: (_valid && !widget.busy)
                ? () {
                    HapticFeedback.mediumImpact();
                    widget.onSubmit(
                      displayName: _nameCtrl.text.trim(),
                      oldDeviceId: _oldIdCtrl.text.trim(),
                      answer: _answerCtrl.text.trim(),
                      pin: _pinCtrl.text.trim(),
                    );
                  }
                : null,
            icon: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      strokeCap: StrokeCap.round,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(widget.busy ? 'Enviando…' : 'Enviar solicitud'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Labeled field con leading icon + visibilidad de PIN
// ══════════════════════════════════════════════════════════════════════

class _RecoveryLabeledField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData leadingIcon;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  const _RecoveryLabeledField({
    required this.label,
    required this.hint,
    required this.leadingIcon,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
  });

  @override
  State<_RecoveryLabeledField> createState() => _RecoveryLabeledFieldState();
}

class _RecoveryLabeledFieldState extends State<_RecoveryLabeledField> {
  final _focusNode = FocusNode();
  bool _focused = false;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleVisibility() {
    HapticFeedback.selectionClick();
    setState(() => _obscured = !_obscured);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _focused ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                widget.leadingIcon,
                size: 18,
                color: _focused
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  maxLines: widget.maxLines,
                  keyboardType: widget.keyboardType,
                  obscureText: widget.obscureText && _obscured,
                  onChanged: widget.onChanged,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (widget.obscureText)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleVisibility,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _obscured
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Waiting screen con radar + breathing
// ══════════════════════════════════════════════════════════════════════

class _RecoveryWaitingScreen extends StatefulWidget {
  const _RecoveryWaitingScreen();

  @override
  State<_RecoveryWaitingScreen> createState() =>
      _RecoveryWaitingScreenState();
}

class _RecoveryWaitingScreenState extends State<_RecoveryWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  late final Animation<double> _breathing;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Respiración 1.0 → 1.06 → 1.0 sincronizada con el radar.
    _breathing = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _radarController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: AnimatedBuilder(
                    animation: _radarController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _RadarPainter(
                          color: scheme.primary,
                          t: _radarController.value,
                        ),
                        child: Center(
                          child: ScaleTransition(
                            scale: _breathing,
                            child: Container(
                              width: 96,
                              height: 96,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: Icon(
                                Icons.hourglass_top_rounded,
                                size: 44,
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Esperando aprobación',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'El grupo tiene que verificar tus factores y aprobar la '
                  'recuperación. Te avisaremos en cuanto esté listo.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                _PressableButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  child: FilledButton.tonal(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Volver'),
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

class _RadarPainter extends CustomPainter {
  final Color color;
  final double t;

  _RadarPainter({required this.color, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = maxRadius * phase;
      final opacity = (1.0 - phase) * 0.35;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t;
}