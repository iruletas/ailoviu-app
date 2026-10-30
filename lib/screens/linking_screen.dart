import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/group_models.dart';
import '../providers/linking_providers.dart';
import '../providers/sync_providers.dart';
import '../services/invite_service.dart';
import '../widgets/linking_member_row.dart';
import '../widgets/pending_join_card.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';
import 'recovery_screen.dart';

/// Pantalla de vinculación, rediseñada M3E.
class LinkingScreen extends ConsumerStatefulWidget {
  const LinkingScreen({super.key});

  @override
  ConsumerState<LinkingScreen> createState() => _LinkingScreenState();
}

class _LinkingScreenState extends ConsumerState<LinkingScreen> {
  GroupInvitePayload? _activeInvite;
  bool _busy = false;

  // ════════════════════════════════════════════════════════════════
  // Crear grupo
  // ════════════════════════════════════════════════════════════════

  Future<void> _createGroup() async {
    if (_busy) return;
    setState(() => _busy = true);

    final result = await showGeneralDialog<_CreateGroupFormResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: const _CreateGroupDialog(),
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

    if (result == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    try {
      final linking = ref.read(linkingServiceProvider);
      final created = await linking.createGroup(
        displayName: result.displayName,
        recoveryQuestionPlain: result.questionPlain,
        recoveryAnswer: result.answer,
      );
      if (mounted) {
        setState(() {
          _activeInvite = created.invite;
          _busy = false;
        });
        await HapticFeedback.mediumImpact();
      }
      ref.invalidate(groupSnapshotProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showErrorSnack('Error: $e');
      }
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Unirme
  // ════════════════════════════════════════════════════════════════

  Future<void> _joinGroup() async {
    if (_busy) return;
    setState(() => _busy = true);

    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (scanned == null || !mounted) {
      setState(() => _busy = false);
      return;
    }

    try {
      final invite = GroupInvitePayload.fromQrString(scanned);

      final name = await showGeneralDialog<String>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Cerrar',
        barrierColor: Colors.black.withValues(alpha: 0.4),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: const _DisplayNameDialog(),
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
      if (name == null || !mounted) {
        setState(() => _busy = false);
        return;
      }

      final linking = ref.read(linkingServiceProvider);
      final prepared = await linking.prepareJoin(
        invite: invite,
        displayName: name,
      );

      final sync = await ref.read(syncServiceProvider.future);
      final published = await sync.publishInvite(
        inviteToken: prepared.inviteToken,
        request: prepared.request,
      );

      if (!mounted) return;
      setState(() => _busy = false);

      if (!published) {
        _showErrorSnack(
          'No se pudo avisar al host. Revisa tu conexión y reintenta.',
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const _WaitingApprovalScreen()),
      );

      ref.invalidate(groupSnapshotProvider);
    } on InviteException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showErrorSnack(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showErrorSnack('Error: $e');
      }
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Mostrar QR
  // ════════════════════════════════════════════════════════════════

  Future<void> _showQr() async {
    final group = ref.read(groupSnapshotProvider).valueOrNull;
    if (group == null || !group.isHost) return;

    final transport = await ref.read(keyStoreProvider).getTransportConfig();
    if (transport == null) {
      _showErrorSnack('Configura Firebase primero en Conexiones');
      return;
    }

    final snapshot = await ref.read(linkingServiceProvider).snapshot();
    final my = snapshot.me;
    if (my == null) return;

    final question = await ref.read(keyStoreProvider).getRecoveryQuestion();
    if (question == null) {
      _showErrorSnack('Configura la pregunta de recuperación primero');
      return;
    }

    try {
      final invite = await ref.read(inviteServiceProvider).createJoinInvite(
            groupId: snapshot.groupId!,
            hostDeviceId: my.deviceId,
            hostPublicKeyBase64: my.publicKeyBase64,
            transportConfig: transport,
            recoveryQuestionPlain: question.questionPlain,
          );
      await HapticFeedback.lightImpact();
      if (mounted) setState(() => _activeInvite = invite);
    } catch (e) {
      if (mounted) _showErrorSnack('Error: $e');
    }
  }

  Future<void> _openRecovery() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecoveryScreen()),
    );
    if (mounted) ref.invalidate(groupSnapshotProvider);
  }

  void _showErrorSnack(String msg) {
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
    );
  }

  // ════════════════════════════════════════════════════════════════
  // build
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final groupAsync = ref.watch(groupSnapshotProvider);
    final pendingJoins = ref.watch(pendingJoinsProvider).values.toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    return Scaffold(
      backgroundColor: scheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupSnapshotProvider);
          final service = await ref.read(syncServiceProvider.future);
          await service.reloadPeers();
        },
        child: CustomScrollView(
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
                'Vinculación',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (groupAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (groupAsync.valueOrNull == null ||
                      groupAsync.valueOrNull!.groupId == null)
                    _EmptyGroupCard(
                      busy: _busy,
                      onCreate: _createGroup,
                      onJoin: _joinGroup,
                    )
                  else
                    ..._buildLinkedContent(
                      context,
                      groupAsync.valueOrNull!,
                    ),
                  if (pendingJoins.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const SectionLabel('Solicitudes pendientes'),
                    const SizedBox(height: 8),
                    for (final p in pendingJoins) ...[
                      PendingJoinCard(pending: p),
                      const SizedBox(height: 10),
                    ],
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLinkedContent(
    BuildContext context,
    GroupSnapshot group,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final members = group.members.values.toList()
      ..sort((a, b) {
        if (a.isHost && !b.isHost) return -1;
        if (!a.isHost && b.isHost) return 1;
        return a.joinedAt.compareTo(b.joinedAt);
      });
    final approvedCount =
        members.where((m) => m.approved).length;

    return [
      // Header de miembros con badge.
      BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TonalMicroHeader(
                    icon: Icons.groups_rounded,
                    title: group.isHost ? 'Eres el anfitrión' : 'Miembros',
                    description:
                        'Todos comparten los datos cifrados del grupo.',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$approvedCount ${approvedCount == 1 ? "activo" : "activos"}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final m in members)
              LinkingMemberRow(
                member: m,
                isMe: m.deviceId == group.myDeviceId,
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Invitar (solo host).
      if (group.isHost) ...[
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TonalMicroHeader(
                icon: Icons.qr_code_rounded,
                title: 'Invitar',
                description:
                    'Genera un QR que el nuevo miembro escanea. '
                    'Caduca a los 10 minutos.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _showQr,
                icon: const Icon(Icons.qr_code_rounded),
                label: const Text('Mostrar QR'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
        ),
        if (_activeInvite != null) ...[
          const SizedBox(height: 16),
          _QrCard(invite: _activeInvite!),
        ],
        const SizedBox(height: 16),
      ],

      // Recuperación.
      BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TonalMicroHeader(
              icon: Icons.restore_rounded,
              title: 'Recuperación',
              description:
                  'Si cambiaste de teléfono, recupera tu cuenta con la '
                  'aprobación del grupo.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _openRecovery();
              },
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Recuperar cuenta'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

// ══════════════════════════════════════════════════════════════════════
// Empty card
// ══════════════════════════════════════════════════════════════════════

class _EmptyGroupCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _EmptyGroupCard({
    required this.busy,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              scheme.primaryContainer.withValues(alpha: 0.85),
              scheme.surfaceContainerLow,
            ),
            scheme.surfaceContainerLow,
          ],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.groups_rounded,
              size: 26,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vincular dispositivos',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'El primero crea el grupo. Los demás se unen escaneando el QR.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _PillButton(
            label: 'Crear grupo',
            icon: Icons.add_rounded,
            busy: busy,
            filled: true,
            background: scheme.primary,
            foreground: scheme.onPrimary,
            onTap: onCreate,
          ),
          const SizedBox(height: 10),
          _PillButton(
            label: 'Unirme a un grupo',
            icon: Icons.qr_code_scanner_rounded,
            busy: false,
            filled: false,
            background: scheme.secondaryContainer,
            foreground: scheme.onSecondaryContainer,
            onTap: onJoin,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Si es tu primera vez, configura Firebase antes en '
                    '"Conexiones → Firebase".',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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

// ══════════════════════════════════════════════════════════════════════
// QR card
// ══════════════════════════════════════════════════════════════════════

class _QrCard extends StatelessWidget {
  final GroupInvitePayload invite;
  const _QrCard({required this.invite});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: scheme.surfaceContainerLow,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Escanea para unirte',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () async {
                  await HapticFeedback.lightImpact();
                  Clipboard.setData(
                    ClipboardData(text: invite.encodeForQr()),
                  );
                  if (context.mounted) {
                    _showCopiedToast(context);
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                ),
                tooltip: 'Copiar como texto',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
              child: QrImageView(
                data: invite.encodeForQr(),
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_rounded,
                    size: 14,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Caduca a las ${_formatTime(invite.expiresAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showCopiedToast(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
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
                  'QR copiado al portapapeles',
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

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ══════════════════════════════════════════════════════════════════════
// Pill button reutilizable
// ══════════════════════════════════════════════════════════════════════

class _PillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final bool filled;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.filled,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = !widget.busy;

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
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4),
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
                      const SizedBox(width: 8),
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
// Crear grupo dialog
// ══════════════════════════════════════════════════════════════════════

class _CreateGroupFormResult {
  final String displayName;
  final String questionPlain;
  final String answer;

  const _CreateGroupFormResult({
    required this.displayName,
    required this.questionPlain,
    required this.answer,
  });
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();

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
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.group_add_rounded,
                        size: 28,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Crear grupo',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu pregunta y respuesta de recuperación permiten '
                    'recuperar tu cuenta si cambias de teléfono.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'Tu nombre',
                    hint: 'Ej. Ana',
                    controller: _nameCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Pregunta de recuperación',
                    hint: 'Ej. ¿Cómo se llama nuestra mascota?',
                    controller: _questionCtrl,
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Respuesta',
                    hint: 'La respuesta que recordarás',
                    controller: _answerCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
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
                          onPressed: _valid
                              ? () => Navigator.of(context).pop(
                                    _CreateGroupFormResult(
                                      displayName: _nameCtrl.text.trim(),
                                      questionPlain:
                                          _questionCtrl.text.trim(),
                                      answer: _answerCtrl.text.trim(),
                                    ),
                                  )
                              : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Crear'),
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
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Labeled field
// ══════════════════════════════════════════════════════════════════════

class _LabeledField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  final _focusNode = FocusNode();
  bool _focused = false;

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
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
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

// ══════════════════════════════════════════════════════════════════════
// Display name dialog
// ══════════════════════════════════════════════════════════════════════

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog();

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      Icons.badge_rounded,
                      size: 28,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Cómo te llamas?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Se mostrará a los demás miembros del grupo.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Tu nombre',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
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
                        onPressed: _ctrl.text.trim().isEmpty
                            ? null
                            : () => Navigator.of(context)
                                .pop(_ctrl.text.trim()),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Continuar'),
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

// ══════════════════════════════════════════════════════════════════════
// Scanner M3E (público: lo reutiliza recovery_screen)
// ══════════════════════════════════════════════════════════════════════

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController();
  late final AnimationController _laserController;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _laserController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    const frameSize = 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_handled) return;
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code == null) return;
              _handled = true;
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(code);
            },
          ),

          // Top bar flotante.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    TonalBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Escanear QR',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Marco squircle con láser animado.
          Center(
            child: SizedBox(
              width: frameSize,
              height: frameSize,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.9),
                        width: 3,
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, _) {
                        final t = _laserController.value;
                        return Align(
                          alignment: Alignment(0, t * 2 - 1),
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  scheme.primary.withValues(alpha: 0),
                                  scheme.primary,
                                  scheme.primary.withValues(alpha: 0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Linterna flotante.
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _FlashToggleButton(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashToggleButton extends StatefulWidget {
  final MobileScannerController controller;
  const _FlashToggleButton({required this.controller});

  @override
  State<_FlashToggleButton> createState() => _FlashToggleButtonState();
}

class _FlashToggleButtonState extends State<_FlashToggleButton> {
  bool _on = false;
  bool _pressed = false;

  Future<void> _toggle() async {
    await HapticFeedback.lightImpact();
    try {
      await widget.controller.toggleTorch();
      if (mounted) setState(() => _on = !_on);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _toggle,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: _on
                ? scheme.primaryContainer
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _on
                    ? Icons.flashlight_on_rounded
                    : Icons.flashlight_off_rounded,
                size: 18,
                color: _on ? scheme.onPrimaryContainer : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'Linterna',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _on ? scheme.onPrimaryContainer : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Waiting approval screen con radar ripple
// ══════════════════════════════════════════════════════════════════════

class _WaitingApprovalScreen extends StatefulWidget {
  const _WaitingApprovalScreen();

  @override
  State<_WaitingApprovalScreen> createState() =>
      _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<_WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
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
                  'Los demás miembros del grupo tienen que aprobar tu '
                  'entrada. Te avisaremos en cuanto esté listo.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Volver'),
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