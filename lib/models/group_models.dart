import 'package:flutter/foundation.dart';

/// Miembro del grupo (relación). Inmutable.
@immutable
class GroupMember {
  final String deviceId;
  final String publicKeyBase64;
  final String? displayName;
  final bool isHost;
  final DateTime joinedAt;

  /// `true` mientras el miembro está aprobado y activo.
  /// `false` si está pendiente de aprobación.
  final bool approved;

  /// Hash de recuperación del PIN del miembro, calculado como
  /// `SHA-256(PIN || deviceId || "ailoviu-recovery-v1")`.
  /// Se comparte a los demás para verificar identidad en
  /// recuperación. Nunca es el PIN en claro.
  final String? recoveryPinHash;

  const GroupMember({
    required this.deviceId,
    required this.publicKeyBase64,
    this.displayName,
    this.isHost = false,
    required this.joinedAt,
    this.approved = true,
    this.recoveryPinHash,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'publicKeyBase64': publicKeyBase64,
        if (displayName != null) 'displayName': displayName,
        'isHost': isHost,
        'joinedAt': joinedAt.toIso8601String(),
        'approved': approved,
        if (recoveryPinHash != null) 'recoveryPinHash': recoveryPinHash,
      };

  static GroupMember fromJson(Map<String, dynamic> json) => GroupMember(
        deviceId: json['deviceId'] as String,
        publicKeyBase64: json['publicKeyBase64'] as String,
        displayName: json['displayName'] as String?,
        isHost: json['isHost'] as bool? ?? false,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        approved: json['approved'] as bool? ?? true,
        recoveryPinHash: json['recoveryPinHash'] as String?,
      );

  GroupMember copyWith({
    String? displayName,
    bool? approved,
    bool? isHost,
    String? recoveryPinHash,
  }) =>
      GroupMember(
        deviceId: deviceId,
        publicKeyBase64: publicKeyBase64,
        displayName: displayName ?? this.displayName,
        isHost: isHost ?? this.isHost,
        joinedAt: joinedAt,
        approved: approved ?? this.approved,
        recoveryPinHash: recoveryPinHash ?? this.recoveryPinHash,
      );
}

/// Estado del grupo en este dispositivo.
@immutable
class GroupSnapshot {
  final String? groupId;
  final String? hostDeviceId;
  final Map<String, GroupMember> members;
  final String myDeviceId;

  const GroupSnapshot({
    this.groupId,
    this.hostDeviceId,
    this.members = const {},
    required this.myDeviceId,
  });

  /// `true` si hay al menos otro miembro aprobado.
  bool get isLinked {
    if (groupId == null) return false;
    return members.values
        .where((m) => m.deviceId != myDeviceId && m.approved)
        .isNotEmpty;
  }

  bool get isHost => hostDeviceId != null && hostDeviceId == myDeviceId;

  GroupMember? get me => members[myDeviceId];

  GroupMember? get host =>
      hostDeviceId == null ? null : members[hostDeviceId];

  List<GroupMember> get others =>
      members.values.where((m) => m.deviceId != myDeviceId).toList();

  List<GroupMember> get approvedOthers =>
      others.where((m) => m.approved).toList();

  GroupSnapshot copyWith({
    String? groupId,
    String? hostDeviceId,
    Map<String, GroupMember>? members,
  }) =>
      GroupSnapshot(
        groupId: groupId ?? this.groupId,
        hostDeviceId: hostDeviceId ?? this.hostDeviceId,
        members: members ?? this.members,
        myDeviceId: myDeviceId,
      );

  /// Todos los peers (aprobados y pendientes) menos el mío.
  Set<String> get peerDeviceIds =>
      members.keys.where((id) => id != myDeviceId).toSet();

  /// Solo los peers aprobados.
  Set<String> get approvedPeerDeviceIds => members.values
      .where((m) => m.deviceId != myDeviceId && m.approved)
      .map((m) => m.deviceId)
      .toSet();
}

/// Pregunta de recuperación configurada en este dispositivo.
@immutable
class RecoveryQuestion {
  /// Texto de la pregunta, mostrado en UI.
  final String questionPlain;

  /// Hash de la respuesta normalizada (lowercase, sin acentos,
  /// espacios colapsados). `SHA-256(salt || respuesta)`.
  final String answerHash;

  /// Salt base64 (32 bytes) usado para el hash.
  final String answerSalt;

  const RecoveryQuestion({
    required this.questionPlain,
    required this.answerHash,
    required this.answerSalt,
  });

  bool get isConfigured => questionPlain.isNotEmpty && answerHash.isNotEmpty;
}