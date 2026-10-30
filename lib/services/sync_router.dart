import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../models/sync_models.dart';
import '../providers/home_providers.dart';
import '../providers/linking_providers.dart';
import '../providers/recovery_providers.dart';
import '../providers/sync_providers.dart';

/// Escucha los eventos de sync y los reparte a cada feature.
///
/// Es la pieza que faltaba: sin esto, los sobres entrantes se
/// descartaban.
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
        case SyncType.message:
          // Los mensajes con intent=buzz no cambian estado local
          // (el buzz entrante se manifiesta vía notificación y
          // háptica). Los demás se manejan en features futuras.
          break;
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

  // ── Home ────────────────────────────────────────────────────────

  Future<void> _handleMemberJoin(SyncEvent event) async {
    final memberJson = event.payload.data['member'] as Map?;
    if (memberJson == null) return;
    final member = GroupMember.fromJson(
      Map<String, dynamic>.from(memberJson),
    );
    final linking = _ref.read(linkingServiceProvider);
    await linking.acceptMember(newMember: member);
    await _ref.read(syncServiceProvider.future).then((s) => s.reloadPeers());
  }

  Future<void> _handleMemberLeave(SyncEvent event) async {
    final deviceId = event.payload.data['deviceId'] as String?;
    if (deviceId == null) return;
    await _ref.read(linkingServiceProvider).removeMember(deviceId);
    await _ref.read(syncServiceProvider.future).then((s) => s.reloadPeers());
  }

  Future<void> _handleHostCredentials(SyncEvent event) async {
    final config = event.payload.data['config'] as Map?;
    if (config == null) return;
    await _ref.read(keyStoreProvider).setTransportConfig(
          Map<String, dynamic>.from(config),
        );
    await _ref.read(syncServiceProvider.future).then((s) => s.reloadPeers());
  }

  // ── Join ────────────────────────────────────────────────────────

  Future<void> _handleJoinRequest(SyncEvent event) async {
    // El host recibe el joinRequest por el buzón público y lo
    // reenvía a todos los miembros como joinRequest (ya cifrado con
    // el secret del par). Cada miembro lo persiste localmente como
    // "pendiente de mi voto".
    final request = _decodeInviteRequest(event.payload.data);
    if (request == null) return;

    await _ref.read(pendingJoinsProvider.notifier).add(request);

    // Si soy el host, además tengo que avisar a los otros miembros.
    final myId = await _ref.read(keyStoreProvider).getDeviceId();
    final hostId = await _ref.read(keyStoreProvider).getHostDeviceId();
    if (myId == null || hostId != myId) return;

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
    // Cada miembro vota sí/no. El host recolecta los votos. Cuando
    // todos los miembros aprobados votaron sí, dispara el
    // memberAccept al guest.
    final guestDeviceId = event.payload.data['guestDeviceId'] as String?;
    final vote = event.payload.data['vote'] as bool? ?? false;
    if (guestDeviceId == null) return;

    final pending = _ref.read(pendingJoinsProvider);
    final request = pending[guestDeviceId];
    if (request == null) return;

    if (!vote) {
      // Un solo rechazo cancela la solicitud.
      await _ref
          .read(pendingJoinsProvider.notifier)
          .remove(guestDeviceId);
      await _ref
          .read(syncServiceProvider.future)
          .then((s) => s.enqueue(
                type: SyncType.memberReject,
                payload: {'guestDeviceId': guestDeviceId},
                to: guestDeviceId,
              ));
      return;
    }

    // Si soy el host, chequear si ya votaron todos.
    final myId = await _ref.read(keyStoreProvider).getDeviceId();
    final hostId = await _ref.read(keyStoreProvider).getHostDeviceId();
    if (myId == null || hostId != myId) return;

    // TODO: tracking real de votos. Por ahora, aprobación directa.
    // En el bloque de UI se implementa el tracking con
    // `pendingJoinsProvider.notifier.registerVote`.
  }

  Future<void> _handleMemberAccept(SyncEvent event) async {
    // El guest recibió confirmación del host. Actualizar members con
    // la lista completa.
    final membersJson = event.payload.data['members'] as List?;
    if (membersJson == null) return;
    final linking = _ref.read(linkingServiceProvider);
    for (final raw in membersJson) {
      final m = GroupMember.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      await linking.acceptMember(newMember: m);
    }
    await _ref.read(syncServiceProvider.future).then((s) => s.reloadPeers());
    await _ref.read(pendingJoinsProvider.notifier).clearAll();
  }

  Future<void> _handleMemberReject(SyncEvent event) async {
    await _ref.read(pendingJoinsProvider.notifier).clearAll();
  }

  // ── Recovery ────────────────────────────────────────────────────

  Future<void> _handleRecoveryRequest(SyncEvent event) async {
    final request = _decodeInviteRequest(event.payload.data);
    if (request == null) return;
    await _ref.read(pendingRecoveriesProvider.notifier).add(request);

    // Host reenvía a los demás miembros.
    final myId = await _ref.read(keyStoreProvider).getDeviceId();
    final hostId = await _ref.read(keyStoreProvider).getHostDeviceId();
    if (myId == null || hostId != myId) return;

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
    // Igual que joinVote pero para recuperación. Tracking real de
    // votos en el bloque de UI.
  }

  Future<void> _handleRecoveryAccept(SyncEvent event) async {
    final oldId = event.payload.data['oldDeviceId'] as String?;
    final newMemberJson = event.payload.data['newMember'] as Map?;
    if (oldId == null || newMemberJson == null) return;

    final newMember = GroupMember.fromJson(
      Map<String, dynamic>.from(newMemberJson),
    );
    final recovery = _ref.read(recoveryServiceProvider);
    await recovery.promoteRecovery(
      oldDeviceId: oldId,
      newDeviceId: newMember.deviceId,
      newDevicePublicKeyBase64: newMember.publicKeyBase64,
      displayName: newMember.displayName ?? '',
      newRecoveryPinHash: newMember.recoveryPinHash,
    );
    await _ref.read(syncServiceProvider.future).then((s) => s.reloadPeers());
    await _ref.read(pendingRecoveriesProvider.notifier).clearAll();
  }

  Future<void> _handleRecoveryPinUpdate(SyncEvent event) async {
    final deviceId = event.payload.data['deviceId'] as String?;
    final hash = event.payload.data['recoveryPinHash'] as String?;
    if (deviceId == null || hash == null) return;
    await _ref.read(linkingServiceProvider).updatePeerRecoveryPin(
          deviceId: deviceId,
          recoveryPinHash: hash,
        );
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