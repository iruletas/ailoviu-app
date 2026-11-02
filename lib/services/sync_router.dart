import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../models/sync_models.dart';
import '../providers/home_providers.dart';
import '../providers/linking_providers.dart';
import '../providers/recovery_providers.dart';
import '../providers/sync_providers.dart';
import 'notification_service.dart';

/// Escucha los eventos de sync y los reparte.
class SyncRouter {
  SyncRouter(this._ref);

  final Ref _ref;
  StreamSubscription<SyncEvent>? _sub;
  StreamSubscription<InviteRequest>? _inviteSub;
  late final NotificationService _notifications =
      _ref.read(notificationServiceProvider);

  void start() {
    _sub?.cancel();
    _sub = _ref.read(syncEventsProvider.stream).listen(_onEvent);

    _inviteSub?.cancel();
    // Nos suscribimos al stream de invitaciones (solo host lo emitirá)
    final syncService = _ref.read(syncServiceProvider).valueOrNull;
    if (syncService != null) {
      _inviteSub = syncService.inviteRequests.listen(_onInviteRequest);
    } else {
      // Si el service aún no está listo, esperamos a que lo esté
      _ref.read(syncServiceProvider.future).then((service) {
        _inviteSub?.cancel();
        _inviteSub = service.inviteRequests.listen(_onInviteRequest);
      }).catchError((Object e) {
        debugPrint('[SyncRouter] Error obteniendo SyncService: $e');
      });
    }
  }

  Future<void> _onEvent(SyncEvent event) async {
    try {
      switch (event.payload.type) {
        case SyncType.state:
          await handleHomeSyncPayload(
            ref: _ref,
            type: event.payload.type,
            data: event.payload.data,
          );
          break;
        case SyncType.memberJoin:
          await _handleMemberJoin(event);
          break;
        case SyncType.memberLeave:
          await _handleMemberLeave(event);
          break;
        case SyncType.hostCredentials:
          await _handleHostCredentials(event);
          break;
        case SyncType.joinRequest:
          await _handleJoinRequest(event);
          break;
        case SyncType.joinVote:
          await _handleJoinVote(event);
          break;
        case SyncType.memberAccept:
          await _handleMemberAccept(event);
          break;
        case SyncType.memberReject:
          await _handleMemberReject(event);
          break;
        case SyncType.recoveryRequest:
          await _handleRecoveryRequest(event);
          break;
        case SyncType.recoveryVote:
          await _handleRecoveryVote(event);
          break;
        case SyncType.recoveryAccept:
          await _handleRecoveryAccept(event);
          break;
        case SyncType.recoveryPinUpdate:
          await _handleRecoveryPinUpdate(event);
          break;
        case SyncType.recoveryQuestionUpdate:
          await _handleRecoveryQuestionUpdate(event);
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('[SyncRouter] Error en _onEvent (${event.envelope.type.name}): $e');
    }
  }

  /// Se dispara cuando llega una solicitud nueva al buzón del QR
  /// (sin sobre cifrado, directo de `invites/{token}/requests`).
  Future<void> _onInviteRequest(InviteRequest request) async {
    try {
      // Si ya la tenemos pendiente, no hacemos nada.
      if (_ref.read(pendingJoinsProvider).containsKey(request.guestDeviceId)) {
        return;
      }

      // Validamos el proof
      final token = await _ref.read(keyStoreProvider).getActiveInviteToken();
      if (token == null) return;

      final inviteService = _ref.read(inviteServiceProvider);
      final isValid = inviteService.verifyProof(
        inviteToken: token,
        guestDeviceId: request.guestDeviceId,
        proof: request.proof,
      );

      if (!isValid) {
        debugPrint('[SyncRouter] Proof inválido para ${request.guestDeviceId}');
        return;
      }

      // Agregamos al provider para que aparezca la tarjeta
      _ref.read(pendingJoinsProvider.notifier).add(request);

      // Notificación local
      await _notifications.show(
        title: 'Nueva solicitud',
        body: '${request.displayName} quiere unirse a tu relación.',
        id: NotificationService.stableId('join_${request.guestDeviceId}'),
      );
    } catch (e) {
      debugPrint('[SyncRouter] Error procesando invite request: $e');
    }
  }

  // ── Miembros ────────────────────────────────────────────────────

  Future<void> _handleMemberJoin(SyncEvent event) async {
    final memberJson = event.payload.data['member'] as Map?;
    if (memberJson == null) return;
    final member = GroupMember.fromJson(
      Map<String, dynamic>.from(memberJson),
    );
    await _ref.read(linkingServiceProvider).acceptMember(newMember: member);
    await _reloadSync();
  }

  Future<void> _handleMemberLeave(SyncEvent event) async {
    final deviceId = event.payload.data['deviceId'] as String?;
    if (deviceId == null) return;
    await _ref.read(linkingServiceProvider).removeMember(deviceId);
    await _reloadSync();
  }

  Future<void> _handleHostCredentials(SyncEvent event) async {
    final config = event.payload.data['config'] as Map?;
    if (config == null) return;
    await _ref.read(keyStoreProvider).setTransportConfig(
          Map<String, dynamic>.from(config),
        );
    await _reloadSync();
  }

  // ── Join ────────────────────────────────────────────────────────

  Future<void> _handleJoinRequest(SyncEvent event) async {
    final request = _decodeInviteRequest(event.payload.data);
    if (request == null) return;
    _ref.read(pendingJoinsProvider.notifier).add(request);

    if (!await _amIHost()) return;
    final sync = await _ref.read(syncServiceProvider.future);
    final group = await _ref.read(linkingServiceProvider).snapshot();
    for (final peer in group.approvedPeerDeviceIds) {
      await sync.enqueue(
        type: SyncType.joinRequest,
        payload: request.toJson(),
        to: peer,
      );
    }
  }

  Future<void> _handleJoinVote(SyncEvent event) async {
    final guestDeviceId = event.payload.data['guestDeviceId'] as String?;
    final voterDeviceId = event.payload.data['voterDeviceId'] as String?;
    final vote = event.payload.data['vote'] as bool? ?? false;
    if (guestDeviceId == null || voterDeviceId == null) return;

    _ref.read(pendingJoinsProvider.notifier).registerVote(
          guestDeviceId,
          voterDeviceId,
          vote,
        );

    if (!await _amIHost()) return;

    if (_ref.read(pendingJoinsProvider.notifier).hasAnyRejection(guestDeviceId)) {
      await _rejectJoin(guestDeviceId);
      return;
    }

    // Si estoy solo (2 personas), el voto del host es suficiente.
    final group = await _ref.read(linkingServiceProvider).snapshot();
    final expected = group.approvedPeerDeviceIds;
    final isSoloHost = expected.isEmpty;

    final unanimous = isSoloHost ||
        _ref
            .read(pendingJoinsProvider.notifier)
            .hasUnanimousApproval(guestDeviceId, expected);

    if (!unanimous) return;

    await _approveMember(guestDeviceId, group);
  }

  /// Aprobación directa sin votación (para cuando el host está solo).
  Future<void> approvePendingJoinDirect(String guestDeviceId) async {
    final group = await _ref.read(linkingServiceProvider).snapshot();
    if (!group.isHost) return;
    if (group.approvedPeerDeviceIds.isNotEmpty) {
      // Hay más miembros, hay que votar
      return;
    }
    await _approveMember(guestDeviceId, group);
  }

  Future<void> _approveMember(
    String guestDeviceId,
    GroupSnapshot group,
  ) async {
    final pending = _ref.read(pendingJoinsProvider)[guestDeviceId];
    if (pending == null) return;
    final request = pending.request;

    final newMember = GroupMember(
      deviceId: request.guestDeviceId,
      publicKeyBase64: request.guestPublicKeyBase64,
      displayName: request.displayName,
      isHost: false,
      joinedAt: DateTime.now(),
      approved: true,
      recoveryPinHash: request.recoveryPinHash,
    );

    // 1. Guardamos al miembro y su secreto ANTES de enviar memberAccept,
    //    para que el sobre tenga a quién ir.
    await _ref.read(linkingServiceProvider).acceptMember(newMember: newMember);
    await _reloadSync();

    // 2. Mandamos memberAccept al invitado con la lista actualizada.
    final updatedGroup = await _ref.read(linkingServiceProvider).snapshot();
    final sync = await _ref.read(syncServiceProvider.future);
    await sync.enqueue(
      type: SyncType.memberAccept,
      payload: {
        'members': updatedGroup.members.values.map((m) => m.toJson()).toList(),
      },
      to: request.guestDeviceId,
    );

    // 3. Avisamos a los demás.
    for (final peer in updatedGroup.approvedPeerDeviceIds) {
      if (peer == request.guestDeviceId) continue;
      await sync.enqueue(
        type: SyncType.memberJoin,
        payload: {'member': newMember.toJson()},
        to: peer,
      );
    }

    _ref.read(pendingJoinsProvider.notifier).remove(guestDeviceId);

    // 4. Limpiamos el token activo y el buzón del invite.
    await _ref.read(keyStoreProvider).clearActiveInviteToken();
    await _reloadSync();
  }

  Future<void> _rejectJoin(String guestDeviceId) async {
    final request = _ref.read(pendingJoinsProvider)[guestDeviceId]?.request;
    _ref.read(pendingJoinsProvider.notifier).remove(guestDeviceId);
    if (request == null) return;
    try {
      final sync = await _ref.read(syncServiceProvider.future);
      await sync.enqueue(
        type: SyncType.memberReject,
        payload: {'guestDeviceId': guestDeviceId},
        to: guestDeviceId,
      );
    } catch (e) {
      debugPrint('[SyncRouter] Error enviando reject: $e');
    }
  }

  Future<void> _handleMemberAccept(SyncEvent event) async {
    final membersJson = event.payload.data['members'] as List?;
    if (membersJson == null) return;
    for (final raw in membersJson) {
      final m = GroupMember.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      await _ref.read(linkingServiceProvider).acceptMember(newMember: m);
    }
    await _reloadSync();
    _ref.read(pendingJoinsProvider.notifier).clearAll();
  }

  Future<void> _handleMemberReject(SyncEvent event) async {
    _ref.read(pendingJoinsProvider.notifier).clearAll();
  }

  // ── Recuperación (sin cambios de fondo) ─────────────────────────

  Future<void> _handleRecoveryRequest(SyncEvent event) async {
    final request = _decodeInviteRequest(event.payload.data);
    if (request == null) return;
    _ref.read(pendingRecoveriesProvider.notifier).add(request);

    if (!await _amIHost()) return;
    final sync = await _ref.read(syncServiceProvider.future);
    final group = await _ref.read(linkingServiceProvider).snapshot();
    for (final peer in group.approvedPeerDeviceIds) {
      await sync.enqueue(
        type: SyncType.recoveryRequest,
        payload: request.toJson(),
        to: peer,
      );
    }
  }

  Future<void> _handleRecoveryVote(SyncEvent event) async {
    final guestDeviceId = event.payload.data['guestDeviceId'] as String?;
    final voterDeviceId = event.payload.data['voterDeviceId'] as String?;
    final vote = event.payload.data['vote'] as bool? ?? false;
    if (guestDeviceId == null || voterDeviceId == null) return;

    _ref.read(pendingRecoveriesProvider.notifier).registerVote(
          guestDeviceId,
          voterDeviceId,
          vote,
        );

    if (!await _amIHost()) return;

    if (_ref
        .read(pendingRecoveriesProvider.notifier)
        .hasAnyRejection(guestDeviceId)) {
      _ref
          .read(pendingRecoveriesProvider.notifier)
          .remove(guestDeviceId);
      return;
    }

    final group = await _ref.read(linkingServiceProvider).snapshot();
    final expected = group.approvedPeerDeviceIds;
    final isSoloHost = expected.isEmpty;
    final unanimous = isSoloHost ||
        _ref
            .read(pendingRecoveriesProvider.notifier)
            .hasUnanimousApproval(guestDeviceId, expected);

    if (!unanimous) return;

    final request =
        _ref.read(pendingRecoveriesProvider)[guestDeviceId]?.request;
    if (request == null || request.recoveryOldDeviceId == null) return;

    final newMember = await _ref.read(recoveryServiceProvider).promoteRecovery(
          oldDeviceId: request.recoveryOldDeviceId!,
          newDeviceId: request.guestDeviceId,
          newDevicePublicKeyBase64: request.guestPublicKeyBase64,
          displayName: request.displayName,
          newRecoveryPinHash: request.recoveryPinHash,
        );

    await _reloadSync();

    final sync = await _ref.read(syncServiceProvider.future);
    await sync.enqueue(
      type: SyncType.recoveryAccept,
      payload: {
        'oldDeviceId': request.recoveryOldDeviceId,
        'newMember': newMember.toJson(),
      },
      to: request.guestDeviceId,
    );
    for (final peer in group.approvedPeerDeviceIds) {
      if (peer == request.guestDeviceId) continue;
      await sync.enqueue(
        type: SyncType.memberLeave,
        payload: {'deviceId': request.recoveryOldDeviceId},
        to: peer,
      );
      await sync.enqueue(
        type: SyncType.memberJoin,
        payload: {'member': newMember.toJson()},
        to: peer,
      );
    }

    _ref.read(pendingRecoveriesProvider.notifier).clearAll();
  }

  Future<void> _handleRecoveryAccept(SyncEvent event) async {
    final oldId = event.payload.data['oldDeviceId'] as String?;
    final newMemberJson = event.payload.data['newMember'] as Map?;
    if (oldId == null || newMemberJson == null) return;

    final newMember = GroupMember.fromJson(
      Map<String, dynamic>.from(newMemberJson),
    );
    await _ref.read(recoveryServiceProvider).promoteRecovery(
          oldDeviceId: oldId,
          newDeviceId: newMember.deviceId,
          newDevicePublicKeyBase64: newMember.publicKeyBase64,
          displayName: newMember.displayName ?? '',
          newRecoveryPinHash: newMember.recoveryPinHash,
        );
    await _reloadSync();
    _ref.read(pendingRecoveriesProvider.notifier).clearAll();
  }

  Future<void> _handleRecoveryPinUpdate(SyncEvent event) async {
    final deviceId = event.payload.data['deviceId'] as String?;
    final hash = event.payload.data['recoveryPinHash'] as String?;
    if (deviceId == null) return;
    if (hash == null) {
      await _ref.read(keyStoreProvider).removePeerRecoveryPin(deviceId);
    } else {
      await _ref.read(linkingServiceProvider).updatePeerRecoveryPin(
            deviceId: deviceId,
            recoveryPinHash: hash,
          );
    }
  }

  Future<void> _handleRecoveryQuestionUpdate(SyncEvent event) async {
    final plain = event.payload.data['questionPlain'] as String?;
    final hash = event.payload.data['answerHash'] as String?;
    final salt = event.payload.data['answerSalt'] as String?;
    if (plain == null || hash == null || salt == null) return;
    await _ref.read(linkingServiceProvider).applyRecoveryQuestion(
          RecoveryQuestion(
            questionPlain: plain,
            answerHash: hash,
            answerSalt: salt,
          ),
        );
  }

  // ── util ────────────────────────────────────────────────────────

  Future<bool> _amIHost() async {
    final myId = await _ref.read(keyStoreProvider).getDeviceId();
    final hostId = await _ref.read(keyStoreProvider).getHostDeviceId();
    return myId != null && hostId == myId;
  }

  Future<void> _reloadSync() async {
    final service = await _ref.read(syncServiceProvider.future);
    await service.reloadPeers();
  }

  InviteRequest? _decodeInviteRequest(Map<String, dynamic> data) {
    try {
      return InviteRequest.fromJson(data);
    } catch (e) {
      debugPrint('[SyncRouter] Error decodificando InviteRequest: $e');
      return null;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _inviteSub?.cancel();
    _inviteSub = null;
  }
}