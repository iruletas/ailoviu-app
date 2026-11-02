import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/linking_providers.dart';
import '../providers/onboarding_providers.dart';
import '../providers/relationship_providers.dart';
import '../providers/sync_providers.dart';
import '../services/background_sync.dart';
import '../services/invite_service.dart';
import '../services/linking_service.dart';
import 'onboarding_scaffold.dart';
import 'qr_invite_card.dart';
import 'qr_scanner_screen.dart';
import 'settings_components.dart';
import 'waiting_approval_screen.dart';

class OnboardingLinkingStep extends ConsumerStatefulWidget {
  /// Si es `true`, salta la selección de rol y va directo al escáner.
  final bool isGuestFlow;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  const OnboardingLinkingStep({
    super.key,
    this.isGuestFlow = false,
    required this.onFinish,
    required this.onBack,
  });

  @override
  ConsumerState<OnboardingLinkingStep> createState() =>
      _OnboardingLinkingStepState();
}

class _OnboardingLinkingStepState
    extends ConsumerState<OnboardingLinkingStep> {
  GroupInvitePayload? _invite;
  bool _busy = false;
  String? _error;

  static const _suggestedQuestion =
      '¿Cómo se llamaba nuestra primera mascota?';

  Future<void> _createGroup() async {
    if (_busy) return;
    final rel = ref.read(relationshipProvider);
    final me = rel.visibleNames.isNotEmpty ? rel.visibleNames.first : '';
    if (me.trim().isEmpty) {
      setState(() => _error = 'Primero agrega tu nombre en el paso anterior.');
      return;
    }
    final transport = await ref.read(keyStoreProvider).getTransportConfig();
    if (transport == null) {
      setState(() => _error =
          'Configura Firebase en el paso anterior antes de crear el grupo.');
      return;
    }
    final form = await _askGroupForm(me);
    if (form == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final linking = ref.read(linkingServiceProvider);
      final created = await linking.createGroup(
        displayName: form.name,
        recoveryQuestionPlain: form.question,
        recoveryAnswer: form.answer,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _invite = created.invite;
        _busy = false;
      });
      ref.invalidate(groupSnapshotProvider);

      // CLAVE: arrancar el transporte del host para escuchar el QR.
      try {
        final sync = await ref.read(syncServiceProvider.future);
        await sync.reloadPeers();
        unawaited(BackgroundSyncService.bootstrap());
      } catch (e) {
        debugPrint('[OnboardingLinking] No se pudo arrancar el sync: $e');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo crear el grupo: $e';
      });
    }
  }

  Future<void> _joinGroup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (scanned == null || !mounted) {
      setState(() => _busy = false);
      return;
    }

    try {
      final invite = GroupInvitePayload.fromQrString(scanned);
      
      final profile = await showModalBottomSheet<({String name, String question, String answer})>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _GroupFormSheet(
            isGuest: true,
            initialName: '',
            suggestedQuestion: _suggestedQuestion,
          ),
        ),
      );
      
      if (profile == null || !mounted) {
        setState(() => _busy = false);
        return;
      }

      final linking = ref.read(linkingServiceProvider);
      final prepared = await linking.prepareJoin(
        invite: invite,
        displayName: profile.name,
      );

      final sync = await ref.read(syncServiceProvider.future);
      final published = await sync.publishInvite(
        inviteToken: prepared.inviteToken,
        request: prepared.request,
      );

      if (!mounted) return;
      setState(() => _busy = false);

      if (!published) {
        setState(() => _error = 'No se pudo avisar al host. Revisa tu conexión.');
        return;
      }

      // El invitado queda escuchando su inbox para recibir memberAccept.
      try {
        await sync.reloadPeers();
        unawaited(BackgroundSyncService.bootstrap());
      } catch (e) {
        debugPrint('[OnboardingLinking] No se pudo arrancar el sync: $e');
      }

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
      );
      
      if (mounted) widget.onFinish();
    } on InviteException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  Future<({String name, String question, String answer})?> _askGroupForm(
    String initialName,
  ) {
    return showModalBottomSheet<({String name, String question, String answer})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _GroupFormSheet(
          isGuest: false,
          initialName: initialName,
          suggestedQuestion: _suggestedQuestion,
        ),
      ),
    );
  }

  Future<void> _confirmSkip() async {
    final transport = await ref.read(keyStoreProvider).getTransportConfig();
    final firebaseOk = transport != null;
    if (!mounted) return;

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
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.link_off_rounded,
                    size: 32,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Saltar la vinculación?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  firebaseOk
                      ? 'Tu relación se verá solo en este celular. Podrás '
                          'vincular después desde Ajustes → Conexiones → '
                          'Vinculación sin reconfigurar Firebase.'
                      : 'Tu relación se verá solo en este celular. Además, '
                          'como no configuraste Firebase, no habrá sync '
                          'hasta que lo hagas desde Ajustes → Conexiones.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context, true);
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        child: const Text('Saltar'),
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

    if (confirmed == true) widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final rel = ref.watch(relationshipProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasInvite = _invite != null;
    final isGuest = widget.isGuestFlow;

    // La etiqueta del botón principal ya no depende de un selector de rol
    String primaryLabel;
    VoidCallback onPrimary;
    bool showPrimary = true;

    if (hasInvite) {
      primaryLabel = 'Terminar';
      onPrimary = widget.onFinish;
    } else if (isGuest) {
      primaryLabel = 'Escanear QR';
      onPrimary = _joinGroup;
    } else {
      primaryLabel = 'Crear grupo y mostrar QR';
      onPrimary = _createGroup;
    }

    return OnboardingScaffold(
      step: OnboardingStep.linking,
      showSkip: false,
      bottomAction: showPrimary
          ? _BottomNav(
              onBack: widget.onBack,
              primaryLabel: primaryLabel,
              onPrimary: onPrimary,
              busy: _busy,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            isGuest ? 'Unirse a la relación' : _title(rel),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isGuest 
                ? 'Pídele a tu pareja que abra Ailoviu y te muestre el código QR desde su pantalla.'
                : 'Cuando abran Ailoviu en su celular, verán el mismo espacio que tú.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.fastOutSlowIn,
            switchOutCurve: Curves.fastOutSlowIn,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1.0)
                      .animate(curved),
                  child: child,
                ),
              );
            },
            child: hasInvite
                ? _QrFrame(
                    key: const ValueKey('qr'),
                    invite: _invite!,
                  )
                : (isGuest 
                    ? const _GuestExplanationCard(key: ValueKey('guest_expl'))
                    : const _ExplanationCard(key: ValueKey('explanation'))),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          TextButton(
            onPressed: _confirmSkip,
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              shape: const StadiumBorder(),
            ),
            child: const Text('Saltar por ahora'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _title(AppRelationship rel) {
    if (rel.type == RelationshipType.polyamorous) {
      return 'Prepara todo para tus parejas';
    }
    if (rel.type == RelationshipType.other) {
      return 'Prepara todo para tu relación';
    }
    return 'Prepara todo para tu pareja';
  }
}

// ── Tarjeta de Explicación (Invitado) ──────────────────────────────────
class _GuestExplanationCard extends StatelessWidget {
  const _GuestExplanationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TonalMicroHeader(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Escanear el código',
            description:
                'Pídele a tu pareja que abra Ailoviu y te muestre el código QR '
                'desde su pantalla.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Asegúrate de tener la cámara lista. El código caduca a los 10 minutos.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
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

// ── Tarjeta de Explicación (Anfitrión) ─────────────────────────────────
class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TonalMicroHeader(
            icon: Icons.qr_code_rounded,
            title: 'Un QR, dos celulares',
            description:
                'Tú creas el grupo. Tu pareja escanea el QR desde su '
                'celular. A partir de ahí, todo se comparte cifrado.',
          ),
          const SizedBox(height: 16),
          const _StaggeredBullet(
            index: 0,
            number: 1,
            text: 'Tocas "Crear grupo" abajo.',
          ),
          const SizedBox(height: 12),
          const _StaggeredBullet(
            index: 1,
            number: 2,
            text: 'Te aparece un QR en esta pantalla.',
          ),
          const SizedBox(height: 12),
          const _StaggeredBullet(
            index: 2,
            number: 3,
            text:
                'Tu pareja abre Ailoviu → Ajustes → Conexiones → Vinculación '
                '→ Unirme, y lo escanea.',
          ),
          const SizedBox(height: 12),
          const _StaggeredBullet(
            index: 3,
            number: 4,
            text: '¡Listo! Ya están en el mismo espacio.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El QR caduca a los 10 minutos. Si se vence, se genera '
                    'otro desde Vinculación.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
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

class _StaggeredBullet extends StatelessWidget {
  final int index;
  final int number;
  final String text;

  const _StaggeredBullet({
    required this.index,
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 420 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final delayed =
            ((value - index * 0.08) / (1 - index * 0.08)).clamp(0.0, 1.0);
        return Opacity(
          opacity: delayed,
          child: Transform.translate(
            offset: Offset(0, (1 - delayed) * 10),
            child: child,
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrFrame extends StatefulWidget {
  final GroupInvitePayload invite;
  const _QrFrame({super.key, required this.invite});

  @override
  State<_QrFrame> createState() => _QrFrameState();
}

class _QrFrameState extends State<_QrFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final t = _glow.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.15 + t * 0.18),
                blurRadius: 20 + t * 14,
                spreadRadius: 1 + t * 3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: QrInviteCard(invite: widget.invite),
    );
  }
}

class _GroupFormSheet extends StatefulWidget {
  final bool isGuest;
  final String initialName;
  final String suggestedQuestion;

  const _GroupFormSheet({
    required this.isGuest,
    required this.initialName,
    required this.suggestedQuestion,
  });

  @override
  State<_GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<_GroupFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _questionCtrl;
  late final TextEditingController _answerCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _questionCtrl = TextEditingController(text: widget.suggestedQuestion);
    _answerCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _questionCtrl.text.trim().isNotEmpty &&
      _answerCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      (
        name: _nameCtrl.text.trim(),
        question: _questionCtrl.text.trim(),
        answer: _answerCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    widget.isGuest ? Icons.badge_rounded : Icons.group_add_rounded,
                    size: 24,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isGuest ? 'Tus datos' : 'Crear grupo',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tu pregunta de recuperación protege tu cuenta '
                        'si pierdes este celular.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SheetField(
              label: 'Tu nombre',
              hint: 'Ej. Ana',
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _SheetField(
              label: 'Pregunta de recuperación',
              hint: 'La que quieras',
              controller: _questionCtrl,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _SheetField(
              label: 'Respuesta',
              hint: 'Algo que recuerdes bien',
              controller: _answerCtrl,
              // Sin restricciones de caracteres, acepta todo
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: _valid ? _submit : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(widget.isGuest ? 'Unirse' : 'Crear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _SheetField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  State<_SheetField> createState() => _SheetFieldState();
}

class _SheetFieldState extends State<_SheetField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
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
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            maxLines: widget.maxLines,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNav extends StatefulWidget {
  final VoidCallback onBack;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool busy;

  const _BottomNav({
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
    this.busy = false,
  });

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onBack();
            },
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: widget.busy
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            widget.onPrimary();
                          },
                    onTapDown: widget.busy
                        ? null
                        : (_) => setState(() => _pressed = true),
                    onTapUp: widget.busy
                        ? null
                        : (_) => setState(() => _pressed = false),
                    onTapCancel: widget.busy
                        ? null
                        : () => setState(() => _pressed = false),
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: widget.busy
                            ? SizedBox(
                                key: const ValueKey('busy'),
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  strokeCap: StrokeCap.round,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : Row(
                                key: const ValueKey('label'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: scheme.onPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.primaryLabel,
                                    style:
                                        theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.onPrimary,
                                      fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}