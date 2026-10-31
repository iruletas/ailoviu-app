import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../providers/linking_providers.dart';
import '../providers/sync_providers.dart';
import '../services/invite_service.dart';
import '../widgets/create_group_dialog.dart';
import '../widgets/display_name_dialog.dart';
import '../widgets/empty_group_card.dart';
import '../widgets/linking_member_row.dart';
import '../widgets/pending_join_card.dart';
import '../widgets/qr_invite_card.dart';
import '../widgets/qr_scanner_screen.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';
import '../widgets/waiting_approval_screen.dart';
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

    final result = await showGeneralDialog<CreateGroupFormResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: const CreateGroupDialog(),
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
          child: const DisplayNameDialog(),
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
        MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
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
                    EmptyGroupCard(
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
          QrInviteCard(invite: _activeInvite!),
        ],
        const SizedBox(height: 16),
      ],

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