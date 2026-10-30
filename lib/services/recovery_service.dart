import '../models/group_models.dart';
import '../models/sync_models.dart';
import 'crypto_service.dart';
import 'key_store.dart';
import 'linking_service.dart';

/// Orquesta el flujo de recuperación de cuenta (A + B + C, con C
/// obligatorio).
///
/// - El **guest** (dispositivo nuevo) arma la solicitud con
///   `buildRequest()`.
/// - Cada **miembro existente** verifica A (respuesta clave
///   ingresada manualmente por él) y B (recovery pin hash) con
///   `verifyFactors()`.
/// - Cuando **todos** aprueban, el host (`promoteRecovery`) aplica
///   el reemplazo: borra al viejo y acepta al nuevo.
class RecoveryService {
  RecoveryService({
    required KeyStore keyStore,
    required CryptoService crypto,
    required LinkingService linking,
  })  : _keyStore = keyStore,
        _crypto = crypto,
        _linking = linking;

  final KeyStore _keyStore;
  final CryptoService _crypto;
  final LinkingService _linking;

  /// Arma la solicitud de recuperación desde el dispositivo nuevo.
  /// El `recoveryPinHash` es opcional: si el usuario recuerda el PIN,
  /// lo mandamos como factor B. Si no, la recuperación va solo con
  /// A + C.
  Future<InviteRequest> buildRequest({
    required String groupId,
    required String myDeviceId,
    required String myPublicKeyBase64,
    required String displayName,
    required String oldDeviceId,
    String? recoveryPin,
  }) {
    String? pinHash;
    if (recoveryPin != null && recoveryPin.isNotEmpty) {
      pinHash = _crypto.hashRecoveryPin(
        pin: recoveryPin,
        deviceId: oldDeviceId,
      );
    }
    return Future.value(
      InviteRequest(
        groupId: groupId,
        guestDeviceId: myDeviceId,
        guestPublicKeyBase64: myPublicKeyBase64,
        displayName: displayName.trim(),
        proof: '', // no aplica en recovery: la verificación es A+B
        createdAt: DateTime.now().millisecondsSinceEpoch,
        recoveryPinHash: pinHash,
        recoveryOldDeviceId: oldDeviceId,
      ),
    );
  }

  /// Verificación de factores en un miembro existente. Se llama
  /// cuando el miembro abre el diálogo de la solicitud.
  ///
  /// - `answerFromMember`: la respuesta que el miembro **escribe en
  ///   el diálogo**. No viene del guest.
  /// - `recoveryPinHashFromGuest`: el hash del PIN viejo, si el guest
  ///   lo mandó.
  ///
  /// Reglas:
  /// - **C siempre presente** (lo maneja el router con la votación).
  /// - A se verifica si el miembro escribe la respuesta correcta.
  /// - B se verifica si el guest mandó el hash y el miembro tiene
  ///   `peerRecoveryPins[oldDeviceId]`.
  /// - Aceptable: A ✓ y B ✓; A ✓ sin B; B ✓ sin A. Inaceptable: ni
  ///   A ni B.
  Future<RecoveryFactorResult> verifyFactors({
    required String recoveryOldDeviceId,
    required String? answerFromMember,
    required String? recoveryPinHashFromGuest,
  }) async {
    final question = await _keyStore.getRecoveryQuestion();
    if (question == null) {
      return RecoveryFactorResult(
        aOk: false,
        bOk: false,
        detail: 'No hay pregunta de recuperación configurada',
      );
    }

    var aOk = false;
    if (answerFromMember != null && answerFromMember.isNotEmpty) {
      final hash = _crypto.hashRecoveryAnswer(
        answer: answerFromMember,
        saltBase64: question.answerSalt,
      );
      aOk = _constantTimeEquals(hash, question.answerHash);
    }

    var bOk = false;
    if (recoveryPinHashFromGuest != null &&
        recoveryPinHashFromGuest.isNotEmpty) {
      final pins = await _keyStore.getPeerRecoveryPins();
      final expected = pins[recoveryOldDeviceId];
      if (expected != null) {
        bOk = _constantTimeEquals(expected, recoveryPinHashFromGuest);
      }
    }

    final cOk = true; // siempre, por diseño
    final allowed = (aOk || bOk) && cOk;

    return RecoveryFactorResult(
      aOk: aOk,
      bOk: bOk,
      detail: allowed
          ? 'Factores verificados'
          : 'Ni la respuesta ni el PIN coinciden',
    );
  }

  /// El host promueve la recuperación: borra al viejo y acepta al
  /// nuevo. Devuelve el `GroupMember` del nuevo.
  Future<GroupMember> promoteRecovery({
    required String oldDeviceId,
    required String newDeviceId,
    required String newDevicePublicKeyBase64,
    required String displayName,
    String? newRecoveryPinHash,
  }) async {
    if (oldDeviceId == newDeviceId) {
      throw LinkingException('El deviceId nuevo no puede ser el viejo');
    }
    await _keyStore.removePeer(oldDeviceId);
    await _keyStore.removePeerRecoveryPin(oldDeviceId);

    final newMember = GroupMember(
      deviceId: newDeviceId,
      publicKeyBase64: newDevicePublicKeyBase64,
      displayName: displayName.trim(),
      isHost: false,
      joinedAt: DateTime.now(),
      approved: true,
      recoveryPinHash: newRecoveryPinHash,
    );
    return _linking.acceptMember(newMember: newMember);
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

class RecoveryFactorResult {
  final bool aOk;
  final bool bOk;
  final String detail;

  const RecoveryFactorResult({
    required this.aOk,
    required this.bOk,
    required this.detail,
  });

  /// `true` si A o B pasaron (con C implícito).
  bool get isAllowed => aOk || bOk;
}