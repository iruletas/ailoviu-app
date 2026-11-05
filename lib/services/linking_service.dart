import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/group_models.dart';
import '../models/sync_models.dart';
import 'crypto_service.dart';
import 'invite_service.dart';
import 'key_store.dart';

class LinkingService {
  LinkingService({
    required KeyStore keyStore,
    required CryptoService crypto,
    required InviteService inviteService,
  })  : _keyStore = keyStore,
        _crypto = crypto,
        _invites = inviteService;

  final KeyStore _keyStore;
  final CryptoService _crypto;
  final InviteService _invites;
  final _uuid = const Uuid();

  // ══════════════════════════════════════════════════════════════════
  // Identidad y grupo
  // ══════════════════════════════════════════════════════════════════

  Future<({String deviceId, String publicKeyBase64})>
      ensureLocalIdentity() async {
    var deviceId = await _keyStore.getDeviceId();
    if (deviceId == null) {
      deviceId = _uuid.v4();
      await _keyStore.setDeviceId(deviceId);
    }

    var privateKey = await _keyStore.getIdentityPrivateKey();
    var publicKey = await _keyStore.getIdentityPublicKey();
    if (privateKey == null || publicKey == null) {
      final pair = await _crypto.generateIdentityKeyPair();
      await _keyStore.setIdentityPrivateKey(pair.privateKeyBase64);
      await _keyStore.setIdentityPublicKey(pair.publicKeyBase64);
      publicKey = pair.publicKeyBase64;
    }

    return (deviceId: deviceId, publicKeyBase64: publicKey);
  }

  Future<GroupSnapshot> snapshot() async {
    final myId = await _keyStore.getDeviceId() ?? '';
    return GroupSnapshot(
      groupId: await _keyStore.getGroupId(),
      hostDeviceId: await _keyStore.getHostDeviceId(),
      members: await _keyStore.getGroupMembers(),
      myDeviceId: myId,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Crear grupo (host)
  // ══════════════════════════════════════════════════════════════════

  Future<CreateGroupResult> createGroup({
    required String displayName,
    required String recoveryQuestionPlain,
    required String recoveryAnswer,
    String? partnerDisplayName,
    DateTime? startDate,
    Duration inviteTtl = const Duration(minutes: 10),
  }) async {
    final existingGroupId = await _keyStore.getGroupId();
    if (existingGroupId != null) {
      final members = await _keyStore.getGroupMembers();
      if (members.length > 1) {
        throw LinkingException('Ya hay un grupo activo en este dispositivo');
      }
      await _keyStore.clearGroup();
    }

    final transportConfig = await _keyStore.getTransportConfig();
    if (transportConfig == null) {
      throw LinkingException(
        'Configura Firebase antes de crear el grupo',
      );
    }

    final identity = await ensureLocalIdentity();

    final salt = _crypto.generateSaltBase64();
    final answerHash = _crypto.hashRecoveryAnswer(
      answer: recoveryAnswer,
      saltBase64: salt,
    );
    final question = RecoveryQuestion(
      questionPlain: recoveryQuestionPlain.trim(),
      answerHash: answerHash,
      answerSalt: salt,
    );
    await _keyStore.setRecoveryQuestion(question);

    final groupId = _uuid.v4();
    await _keyStore.setGroupId(groupId);
    await _keyStore.setHostDeviceId(identity.deviceId);

    final me = GroupMember(
      deviceId: identity.deviceId,
      publicKeyBase64: identity.publicKeyBase64,
      displayName: displayName.trim(),
      isHost: true,
      joinedAt: DateTime.now(),
      approved: true,
    );
    await _keyStore.setGroupMembers({identity.deviceId: me});

    final cartoKey = await _keyStore.getCartoKey();

    final invite = await _invites.createJoinInvite(
      groupId: groupId,
      hostDeviceId: identity.deviceId,
      hostPublicKeyBase64: identity.publicKeyBase64,
      transportConfig: transportConfig,
      recoveryQuestionPlain: question.questionPlain,
      cartoKey: cartoKey,
      hostDisplayName: displayName,
      partnerDisplayName: partnerDisplayName,
      startDateIso: startDate?.toIso8601String(),
      ttl: inviteTtl,
    );

    await _keyStore.setActiveInviteToken(invite.inviteToken);

    return CreateGroupResult(
      groupId: groupId,
      myDeviceId: identity.deviceId,
      invite: invite,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Unirse (guest)
  // ══════════════════════════════════════════════════════════════════

  Future<PrepareJoinResult> prepareJoin({
    required GroupInvitePayload invite,
    required String displayName,
  }) async {
    if (!invite.isJoin) {
      throw LinkingException('Este QR no es de vinculación');
    }
    if (invite.isExpired) {
      throw LinkingException('El QR expiró. Pide uno nuevo.');
    }

    final existingGroup = await _keyStore.getGroupId();
    if (existingGroup != null && existingGroup != invite.groupId) {
      final members = await _keyStore.getGroupMembers();
      if (members.length > 1) {
        throw LinkingException(
          'Este dispositivo ya pertenece a otro grupo. '
          'Sal de él antes de unirte a uno nuevo.',
        );
      }
    }

    // Desciframos el paquete (transportConfig + cartoKey + relación).
    final payload = await _invites.decryptInvitePayload(invite);

    final transportConfig = payload['transportConfig'] as Map?;
    if (transportConfig == null) {
      throw LinkingException('El QR no trae la configuración de Firebase.');
    }
    await _keyStore.setTransportConfig(
      Map<String, dynamic>.from(transportConfig),
    );

    final cartoKey = payload['cartoKey'] as String?;
    if (cartoKey != null && cartoKey.isNotEmpty) {
      await _keyStore.setCartoKey(cartoKey);
    }

    // Datos de relación del payload (pueden faltar en QRs viejos).
    final hostDisplayName = payload['hostDisplayName'] as String?;
    final partnerDisplayName = payload['partnerDisplayName'] as String?;
    final startIso = payload['startDateIso'] as String?;
    final startDate = startIso != null ? DateTime.tryParse(startIso) : null;

    final identity = await ensureLocalIdentity();

    await _keyStore.setGroupId(invite.groupId);
    await _keyStore.setHostDeviceId(invite.hostDeviceId);

    // Si el host ya puso el nombre del partner en el QR y el guest no
    // escribió uno, usamos el del QR. Así no queda vacío.
    final effectiveName = displayName.trim().isEmpty
        ? (partnerDisplayName?.trim() ?? '')
        : displayName.trim();

    final me = GroupMember(
      deviceId: identity.deviceId,
      publicKeyBase64: identity.publicKeyBase64,
      displayName: effectiveName.isEmpty ? null : effectiveName,
      isHost: false,
      joinedAt: DateTime.now(),
      approved: false,
    );

    final hostMember = GroupMember(
      deviceId: invite.hostDeviceId,
      publicKeyBase64: invite.hostPublicKeyBase64,
      displayName: hostDisplayName,
      isHost: true,
      joinedAt: DateTime.now(),
      approved: true,
    );

    final members = await _keyStore.getGroupMembers();
    members[identity.deviceId] = me;
    members[invite.hostDeviceId] = hostMember;
    await _keyStore.setGroupMembers(members);

    // Derivar y guardar el secreto compartido con el host.
    final myPrivateKey = await _keyStore.getIdentityPrivateKey();
    if (myPrivateKey != null) {
      try {
        final secret = await _crypto.deriveSharedSecretBase64(
          myPrivateKeyBase64: myPrivateKey,
          theirPublicKeyBase64: invite.hostPublicKeyBase64,
        );
        await _keyStore.setPeerSharedSecret(invite.hostDeviceId, secret);
      } catch (e) {
        debugPrint('[LinkingService] Error derivando secreto con host: $e');
      }
    }

    final proof = _invites.proofFor(
      invite: invite,
      guestDeviceId: identity.deviceId,
    );
    final request = InviteRequest(
      groupId: invite.groupId,
      guestDeviceId: identity.deviceId,
      guestPublicKeyBase64: identity.publicKeyBase64,
      displayName: me.displayName ?? '',
      proof: proof,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    return PrepareJoinResult(
      inviteToken: invite.inviteToken,
      request: request,
      hostDisplayName: hostDisplayName,
      partnerDisplayName: partnerDisplayName,
      startDate: startDate,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Aceptar / rechazar / expulsar
  // ══════════════════════════════════════════════════════════════════

  Future<GroupMember> acceptMember({
    required GroupMember newMember,
  }) async {
    final myId = await _keyStore.getDeviceId();
    final myPrivateKey = await _keyStore.getIdentityPrivateKey();
    if (myId == null || myPrivateKey == null) {
      throw LinkingException('Falta identidad local');
    }

    final secret = await _crypto.deriveSharedSecretBase64(
      myPrivateKeyBase64: myPrivateKey,
      theirPublicKeyBase64: newMember.publicKeyBase64,
    );

    final members = await _keyStore.getGroupMembers();
    final existing = members[newMember.deviceId];
    final merged = existing == null
        ? newMember.copyWith(approved: true)
        : existing.copyWith(approved: true);
    members[newMember.deviceId] = merged;
    await _keyStore.setGroupMembers(members);
    await _keyStore.setPeerSharedSecret(newMember.deviceId, secret);

    if (newMember.recoveryPinHash != null) {
      await _keyStore.setPeerRecoveryPin(
        newMember.deviceId,
        newMember.recoveryPinHash!,
      );
    }

    return merged;
  }

  Future<void> rejectMember(String deviceId) async {
    await _keyStore.removePeer(deviceId);
    await _keyStore.removePeerRecoveryPin(deviceId);
  }

  Future<void> removeMember(String deviceId) async {
    final myId = await _keyStore.getDeviceId();
    if (deviceId == myId) {
      throw LinkingException('No puedes expulsarte a ti mismo');
    }

    await _keyStore.removePeer(deviceId);
    await _keyStore.removePeerRecoveryPin(deviceId);

    final hostId = await _keyStore.getHostDeviceId();
    if (hostId == deviceId) {
      final members = await _keyStore.getGroupMembers();
      final remaining = members.values
          .where((m) => m.deviceId != deviceId && m.approved)
          .toList()
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
      if (remaining.isNotEmpty) {
        await _keyStore.setHostDeviceId(remaining.first.deviceId);
      }
    }
  }

  Future<void> updateDisplayName({
    required String deviceId,
    required String displayName,
  }) async {
    final members = await _keyStore.getGroupMembers();
    final m = members[deviceId];
    if (m == null) return;
    members[deviceId] = m.copyWith(displayName: displayName.trim());
    await _keyStore.setGroupMembers(members);
  }

  Future<void> updatePeerRecoveryPin({
    required String deviceId,
    required String recoveryPinHash,
  }) async {
    await _keyStore.setPeerRecoveryPin(deviceId, recoveryPinHash);
    final members = await _keyStore.getGroupMembers();
    final m = members[deviceId];
    if (m != null) {
      members[deviceId] = m.copyWith(recoveryPinHash: recoveryPinHash);
      await _keyStore.setGroupMembers(members);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // Pregunta de recuperación
  // ══════════════════════════════════════════════════════════════════

  Future<RecoveryQuestion> setRecoveryQuestion({
    required String questionPlain,
    required String answer,
  }) async {
    final salt = _crypto.generateSaltBase64();
    final hash = _crypto.hashRecoveryAnswer(
      answer: answer,
      saltBase64: salt,
    );
    final q = RecoveryQuestion(
      questionPlain: questionPlain.trim(),
      answerHash: hash,
      answerSalt: salt,
    );
    await _keyStore.setRecoveryQuestion(q);
    return q;
  }

  Future<void> applyRecoveryQuestion(RecoveryQuestion question) async {
    await _keyStore.setRecoveryQuestion(question);
  }

  // ══════════════════════════════════════════════════════════════════
  // PIN de recuperación (factor B local)
  // ══════════════════════════════════════════════════════════════════

  Future<String> setLocalRecoveryPin(String pin) async {
    final myId = await _keyStore.getDeviceId();
    if (myId == null) throw LinkingException('Falta deviceId local');
    final hash = _crypto.hashRecoveryPin(pin: pin, deviceId: myId);

    final members = await _keyStore.getGroupMembers();
    final me = members[myId];
    if (me != null) {
      members[myId] = me.copyWith(recoveryPinHash: hash);
      await _keyStore.setGroupMembers(members);
    }
    return hash;
  }

  Future<void> clearLocalRecoveryPin() async {
    final myId = await _keyStore.getDeviceId();
    if (myId == null) return;
    final members = await _keyStore.getGroupMembers();
    final me = members[myId];
    if (me != null) {
      members[myId] = GroupMember(
        deviceId: me.deviceId,
        publicKeyBase64: me.publicKeyBase64,
        displayName: me.displayName,
        isHost: me.isHost,
        joinedAt: me.joinedAt,
        approved: me.approved,
      );
      await _keyStore.setGroupMembers(members);
    }
  }
}

class CreateGroupResult {
  final String groupId;
  final String myDeviceId;
  final GroupInvitePayload invite;

  const CreateGroupResult({
    required this.groupId,
    required this.myDeviceId,
    required this.invite,
  });
}

class PrepareJoinResult {
  final String inviteToken;
  final InviteRequest request;

  /// Datos de la relación que venían en el QR. Pueden ser null si el
  /// QR es viejo o si el host no los puso.
  final String? hostDisplayName;
  final String? partnerDisplayName;
  final DateTime? startDate;

  const PrepareJoinResult({
    required this.inviteToken,
    required this.request,
    this.hostDisplayName,
    this.partnerDisplayName,
    this.startDate,
  });
}

class LinkingException implements Exception {
  final String message;
  LinkingException(this.message);
  @override
  String toString() => message;
}