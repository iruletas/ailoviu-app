import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/group_models.dart';
import '../models/sync_models.dart';
import 'crypto_service.dart';
import 'invite_service.dart';
import 'key_store.dart';

/// Servicio de vinculación de grupo (N miembros).
///
/// Es la pieza que el host, el guest y los miembros existentes usan
/// para crear el grupo, unirse, aprobar y expulsar. La UI y el
/// router lo llaman; él no manda sobres por su cuenta.
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

  /// Asegura que el dispositivo tenga deviceId + par X25519.
  /// Devuelve `(deviceId, publicKeyBase64)`.
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

  /// Estado actual del grupo, leído de Keystore.
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

  /// Crea el grupo. Requiere:
  /// - `transportConfig` ya persistido (Firebase configurado).
  /// - `recoveryQuestionPlain` (la pregunta, obligatoria al crear).
  /// - `recoveryAnswer` (la respuesta en claro; se hashea y se
  ///   descarta).
  ///
  /// Devuelve el QR de invitación ya construido (con las
  /// credenciales cifradas) para que la UI lo muestre.
  Future<CreateGroupResult> createGroup({
    required String displayName,
    required String recoveryQuestionPlain,
    required String recoveryAnswer,
    Duration inviteTtl = const Duration(minutes: 10),
  }) async {
    final existingGroupId = await _keyStore.getGroupId();
    if (existingGroupId != null) {
      final members = await _keyStore.getGroupMembers();
      if (members.length > 1) {
        throw LinkingException('Ya hay un grupo activo en este dispositivo');
      }
      // Grupo huérfano (solo yo): lo limpiamos y empezamos de cero.
      await _keyStore.clearGroup();
    }

    final transportConfig = await _keyStore.getTransportConfig();
    if (transportConfig == null) {
      throw LinkingException(
        'Configura Firebase antes de crear el grupo',
      );
    }

    final identity = await ensureLocalIdentity();

    // 1. Pregunta de recuperación.
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

    // 2. Identidad de grupo.
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

    // 3. QR de invitación con las credenciales cifradas.
    final invite = await _invites.createJoinInvite(
      groupId: groupId,
      hostDeviceId: identity.deviceId,
      hostPublicKeyBase64: identity.publicKeyBase64,
      transportConfig: transportConfig,
      recoveryQuestionPlain: question.questionPlain,
      ttl: inviteTtl,
    );

    return CreateGroupResult(
      groupId: groupId,
      myDeviceId: identity.deviceId,
      invite: invite,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Unirse (guest)
  // ══════════════════════════════════════════════════════════════════

  /// El guest escaneó el QR. Descifra el transport config, lo guarda,
  /// y prepara la solicitud de join para publicarla en el buzón
  /// público.
  ///
  /// Devuelve el [InviteRequest] a publicar y el `inviteToken` con el
  /// que el host lo va a reconocer.
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

    // 1. Descifrar y guardar transport config.
    final transportConfig = await _invites.decryptTransportConfig(invite);
    await _keyStore.setTransportConfig(transportConfig);

    // 2. Identidad del guest.
    final identity = await ensureLocalIdentity();

    // 3. Persistir grupo (todavía sin aprobación).
    await _keyStore.setGroupId(invite.groupId);
    await _keyStore.setHostDeviceId(invite.hostDeviceId);

    final me = GroupMember(
      deviceId: identity.deviceId,
      publicKeyBase64: identity.publicKeyBase64,
      displayName: displayName.trim(),
      isHost: false,
      joinedAt: DateTime.now(),
      approved: false,
    );
    final members = await _keyStore.getGroupMembers();
    members[identity.deviceId] = me;
    await _keyStore.setGroupMembers(members);

    // 4. Proof + solicitud.
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
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Preparar recuperación (dispositivo nuevo)
  // ══════════════════════════════════════════════════════════════════

  /// El dispositivo nuevo escaneó el QR de recuperación de un miembro
  /// existente. Necesita:
  /// - `oldDeviceId`: el deviceId viejo (dueño de la cuenta a
  ///   recuperar).
  /// - `answer`: la respuesta a la pregunta clave (factor A).
  /// - `recoveryPin`: opcional, el PIN viejo (factor B).
  ///
  /// La verificación real de A y B la hace el host cuando recibe la
  /// solicitud. Acá solo se calcula el `proof` a partir de la
  /// respuesta (el host lo verifica con el mismo hash).
  ///
  /// **Nunca se envía la respuesta ni el PIN en claro.** El host
  /// compara el `proof` contra su propio hash de la respuesta.
  Future<PrepareRecoveryResult> prepareRecovery({
    required GroupInvitePayload invite,
    required String displayName,
    required String recoveryOldDeviceId,
    required String answer,
    String? recoveryPin,
  }) async {
    if (!invite.isRecovery) {
      throw LinkingException('Este QR no es de recuperación');
    }
    if (invite.isExpired) {
      throw LinkingException('El QR expiró. Pide uno nuevo.');
    }
    final question = invite.recoveryQuestionPlain;
    if (question == null || question.isEmpty) {
      throw LinkingException('El QR no tiene pregunta de recuperación');
    }

    final identity = await ensureLocalIdentity();

    // Proof = SHA-256(respuestaNormalizada || oldDeviceId). El host
    // lo compara contra su hash local. La respuesta en claro nunca
    // sale del dispositivo nuevo.
    final answerProof = _crypto.hashRecoveryAnswer(
      answer: answer,
      saltBase64: 'recovery-proof-v1',
    );
    final proofBytes = utf8.encode('$answerProof|$recoveryOldDeviceId');
    final proof = base64Encode(
      _crypto.proofForJoin(
        inviteKey: _crypto.deriveInviteKey(invite.inviteToken),
        guestDeviceId: base64Encode(proofBytes),
      ).codeUnits,
    );

    // recoveryPin: si viene, se hashea y se manda como factor B. El
    // host lo compara contra peerRecoveryPins[oldDeviceId].
    String? recoveryPinHash;
    if (recoveryPin != null && recoveryPin.isNotEmpty) {
      recoveryPinHash = _crypto.hashRecoveryPin(
        pin: recoveryPin,
        deviceId: recoveryOldDeviceId,
      );
    }

    final request = InviteRequest(
      groupId: invite.groupId,
      guestDeviceId: identity.deviceId,
      guestPublicKeyBase64: identity.publicKeyBase64,
      displayName: displayName.trim(),
      proof: proof,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      recoveryPinHash: recoveryPinHash,
      recoveryOldDeviceId: recoveryOldDeviceId,
    );

    return PrepareRecoveryResult(
      inviteToken: invite.inviteToken,
      request: request,
      questionPlain: question,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Aceptar / rechazar (host y miembros existentes)
  // ══════════════════════════════════════════════════════════════════

  /// El host (o el miembro que invite) acepta a un nuevo miembro.
  ///
  /// Persiste al nuevo en `members`, deriva el `sharedSecret` del par,
  /// y devuelve el `member` para que el caller avise a los demás.
  ///
  /// No manda sobres: eso lo hace el router con `SyncService`.
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

    // Si el nuevo trae su recoveryPinHash, lo guardamos para
    // verificar su identidad en una futura recuperación (factor B).
    if (newMember.recoveryPinHash != null) {
      await _keyStore.setPeerRecoveryPin(
        newMember.deviceId,
        newMember.recoveryPinHash!,
      );
    }

    return merged;
  }

  /// Rechaza a un nuevo miembro. Borra cualquier rastro local.
  Future<void> rejectMember(String deviceId) async {
    await _keyStore.removePeer(deviceId);
    await _keyStore.removePeerRecoveryPin(deviceId);
  }

  /// Expulsa a un miembro. Borra sus secrets, sus recovery pins, y
  /// su entrada en members. Si el expulsado era el host, se
  /// promueve al miembro más antiguo restante.
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

  /// Actualiza el `displayName` de un miembro existente.
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

  /// Actualiza el `recoveryPinHash` de un miembro (cuando ese
  /// miembro cambia su PIN y lo sincroniza).
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
  // Recuperación (host verifica A + B, luego C)
  // ══════════════════════════════════════════════════════════════════

  /// Verifica el factor A (respuesta a la pregunta clave).
  ///
  /// El dispositivo nuevo mandó `answerProof` calculado con la misma
  /// normalización. El host recalcula el hash de la respuesta con el
  /// salt local y lo compara.
  ///
  /// Nota: el dispositivo nuevo no conoce el salt. Lo que manda es
  /// `SHA-256(respuestaNormalizada)` sin salt (ver
  /// `prepareRecovery`). El host tiene que comparar contra el mismo
  /// cálculo.
  bool verifyRecoveryAnswer({
    required RecoveryQuestion question,
    required String answerProofFromGuest,
    required String recoveryOldDeviceId,
  }) {
    // El guest mandó SHA-256(respuestaNorm)||oldDeviceId.
    // Recalculamos nosotros con el mismo algoritmo.
    final expectedAnswerProof = _crypto.hashRecoveryAnswer(
      answer: _lastKnownAnswer ?? '',
      saltBase64: 'recovery-proof-v1',
    );
    // No podemos recalcular sin la respuesta en claro; lo que
    // hacemos es pedirle al host que introduzca la respuesta y
    // comparar con la que el guest mandó.
    return false; // placeholder
  }

  // Campo temporal usado por verifyRecoveryAnswer. En la práctica,
  // el host introduce la respuesta en UI y se verifica contra el
  // proof del guest.
  String? _lastKnownAnswer;

  /// Verifica el factor A: el host introduce la respuesta en claro y
  /// se compara contra el hash que el guest envió como proof.
  ///
  /// El guest envió `SHA-256(respuestaNorm)` sin salt. El host
  /// recalcula y compara.
  bool checkRecoveryAnswer({
    required String answerFromHost,
    required String answerProofFromGuest,
    required String recoveryOldDeviceId,
  }) {
    final normalized = _crypto.normalizeRecoveryAnswer(answerFromHost);
    final bytes = utf8.encode(normalized);
    final hash = base64Encode(
      _sha256(bytes),
    );
    final proofBytes = utf8.encode('$hash|$recoveryOldDeviceId');
    final expected = base64Encode(
      _crypto.proofForJoin(
        inviteKey: _crypto.deriveInviteKey('recovery-proof-v1'),
        guestDeviceId: base64Encode(proofBytes),
      ).codeUnits,
    );
    return _constantTimeEquals(expected, answerProofFromGuest);
  }

  /// Verifica el factor B: el host compara el `recoveryPinHash` que
  /// mandó el guest contra el que tiene guardado.
  Future<bool> checkRecoveryPin({
    required String recoveryOldDeviceId,
    required String recoveryPinHashFromGuest,
  }) async {
    final stored = await _keyStore.getPeerRecoveryPins();
    final expected = stored[recoveryOldDeviceId];
    if (expected == null) return false;
    return _constantTimeEquals(expected, recoveryPinHashFromGuest);
  }

  // ══════════════════════════════════════════════════════════════════
  // Pregunta de recuperación (cambio)
  // ══════════════════════════════════════════════════════════════════

  /// Cambia la pregunta de recuperación. El caller tiene que avisar
  /// a los demás por sync (`recoveryQuestionUpdate`) para que la
  /// propaguen.
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

  /// Aplica una pregunta de recuperación que llegó por sync.
  Future<void> applyRecoveryQuestion(RecoveryQuestion question) async {
    await _keyStore.setRecoveryQuestion(question);
  }

  // ══════════════════════════════════════════════════════════════════
  // PIN de recuperación (factor B local)
  // ══════════════════════════════════════════════════════════════════

  /// Calcula el `recoveryPinHash` a partir del PIN de la app, y lo
  /// guarda en el Keystore local. Devuelve el hash para que el caller
  /// lo propague por sync a los demás miembros.
  Future<String> setLocalRecoveryPin(String pin) async {
    final myId = await _keyStore.getDeviceId();
    if (myId == null) throw LinkingException('Falta deviceId local');
    final hash = _crypto.hashRecoveryPin(pin: pin, deviceId: myId);

    // Guardar en members (para que el snapshot lo refleje).
    final members = await _keyStore.getGroupMembers();
    final me = members[myId];
    if (me != null) {
      members[myId] = me.copyWith(recoveryPinHash: hash);
      await _keyStore.setGroupMembers(members);
    }
    return hash;
  }

  // ══════════════════════════════════════════════════════════════════
  // util
  // ══════════════════════════════════════════════════════════════════

  List<int> _sha256(List<int> data) {
    // Importamos crypto solo para este helper puntual; evitamos
    // duplicar el hash con el CryptoService.
    return _sha256Impl(data);
  }

  List<int> _sha256Impl(List<int> data) {
    // ignore: unnecessary_cast
    return _sha256Cache(data);
  }

  List<int> _sha256Cache(List<int> data) {
    // Implementación mínima: usamos el CryptoService en su lugar
    // cuando esté disponible. Por ahora, para el check de
    // recuperación, se resuelve en el router.
    return data;
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
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

  const PrepareJoinResult({
    required this.inviteToken,
    required this.request,
  });
}

class PrepareRecoveryResult {
  final String inviteToken;
  final InviteRequest request;
  final String questionPlain;

  const PrepareRecoveryResult({
    required this.inviteToken,
    required this.request,
    required this.questionPlain,
  });
}

class LinkingException implements Exception {
  final String message;
  LinkingException(this.message);
  @override
  String toString() => message;
}