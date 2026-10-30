import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../models/sync_models.dart';
import '../providers/home_providers.dart';
import '../providers/linking_providers.dart';
import '../providers/recovery_providers.dart';
import '../providers/sync_providers.dart';

/// Escucha los eventos de sync y los reparte.
class SyncRouter {
  SyncRouter(this._ref);

  final Ref _ref;
  StreamSubscription<SyncEvent>? _sub;

  void start() {
    _sub?.cancel();
    _sub = _ref.read(syncEventsProvider.stream).listen(_onEvent);
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
    } catch (_) {}
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

    // Si soy el host, reenvío a los demás miembros (que el guest no
    // conoce todavía) para que voten.
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

    // Si soy el host, chequear si ya votaron todos.
    if (!await _amIHost()) return;

    if (_ref.read(pendingJoinsProvider.notifier).hasAnyRejection(guestDeviceId)) {
      await _rejectJoin(guestDeviceId, event.payload.data['groupId'] as String?);
      return;
    }

    final group = await _ref.read(linkingServiceProvider).snapshot();
    final expected = group.approvedPeerDeviceIds;
    final unanimous = _ref
        .read(pendingJoinsProvider.notifier)
        .hasUnanimousApproval(guestDeviceId, expected);
    if (!unanimous) return;

    final request =
        _ref.read(pendingJoinsProvider)[guestDeviceId]?.request;
    if (request == null) return;

    final newMember = GroupMember(
      deviceId: request.guestDeviceId,
      publicKeyBase64: request.guestPublicKeyBase64,
      displayName: request.displayName,
      isHost: false,
      joinedAt: DateTime.now(),
      approved: true,
    );
    await _ref.read(linkingServiceProvider).acceptMember(newMember: newMember);

    // 1. Mandar memberAccept al guest con la lista de miembros.
    final sync = await _ref.read(syncServiceProvider.future);
    await sync.enqueue(
      type: SyncType.memberAccept,
      payload: {
        'members': group.members.values.map((m) => m.toJson()).toList(),
      },
      to: request.guestDeviceId,
    );

    // 2. Avisar a los demás miembros.
    for (final peer in group.approvedPeerDeviceIds) {
      await sync.enqueue(
        type: SyncType.memberJoin,
        payload: {'member': newMember.toJson()},
        to: peer,
      );
    }

    await _reloadSync();
    _ref.read(pendingJoinsProvider.notifier).remove(guestDeviceId);
  }

  Future<void> _rejectJoin(String guestDeviceId, String? groupId) async {
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
    } catch (_) {}
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

  // ── Recuperación ────────────────────────────────────────────────

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
    final unanimous = _ref
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

    await _reloadSync();
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
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}