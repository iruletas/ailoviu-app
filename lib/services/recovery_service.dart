import '../models/group_models.dart';
import '../models/sync_models.dart';
import 'crypto_service.dart';
import 'key_store.dart';
import 'linking_service.dart';

/// Orquesta el flujo de recuperación (A + B + C).
///
/// - **A** (pregunta clave): el miembro existente **escribe la
///   respuesta** en el diálogo. No la manda el guest, porque eso
///   sería un ataque trivial. La app hashea y compara.
/// - **B** (PIN viejo): el guest manda `recoveryPinHash`. El host
///   lo compara contra `peerRecoveryPins[oldDeviceId]`.
/// - **C** (aprobación de todos): siempre. Lo maneja el router con
///   la votación.
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
  ///
  /// - `recoveryPin` es opcional. Si viene, se calcula el hash y se
  ///   incluye en la request (factor B).
  /// - La respuesta (factor A) **no** se incluye: el host la pide.
  Future<InviteRequest> buildRequest({
    required String groupId,
    required String myDeviceId,
    required String myPublicKeyBase64,
    required String displayName,
    required String oldDeviceId,
    String? recoveryPin,
  }) async {
    String? pinHash;
    if (recoveryPin != null && recoveryPin.isNotEmpty) {
      pinHash = _crypto.hashRecoveryPin(
        pin: recoveryPin,
        deviceId: oldDeviceId,
      );
    }
    return InviteRequest(
      groupId: groupId,
      guestDeviceId: myDeviceId,
      guestPublicKeyBase64: myPublicKeyBase64,
      displayName: displayName.trim(),
      proof: '',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      recoveryPinHash: pinHash,
      recoveryOldDeviceId: oldDeviceId,
    );
  }

  /// Verificación de factores en un miembro existente.
  ///
  /// - `answerFromMember`: la respuesta que el miembro escribe en el
  ///   diálogo. `null` si no la escribió.
  /// - `recoveryPinHashFromGuest`: el hash del PIN viejo, si el
  ///   guest lo mandó.
  ///
  /// Reglas:
  /// - **C siempre presente** (la votación la maneja el router).
  /// - Aceptable: A ✓ y B ✓; A ✓ sin B; B ✓ sin A.
  /// - Inaceptable: ni A ni B.
  Future<RecoveryFactorResult> verifyFactors({
    required String recoveryOldDeviceId,
    required String? answerFromMember,
    required String? recoveryPinHashFromGuest,
  }) async {
    final question = await _keyStore.getRecoveryQuestion();
    if (question == null) {
      return const RecoveryFactorResult(
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

    final allowed = aOk || bOk;
    return RecoveryFactorResult(
      aOk: aOk,
      bOk: bOk,
      detail: allowed
          ? 'Factores verificados'
          : 'Ni la respuesta ni el PIN coinciden',
    );
  }

  /// El host promueve la recuperación: borra al viejo y acepta al
  /// nuevo.
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

  bool get isAllowed => aOk || bOk;
}