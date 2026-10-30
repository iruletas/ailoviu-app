import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_models.dart';

/// Solicitud de join pendiente de votación.
class PendingJoin {
  final InviteRequest request;
  /// Votos: `deviceId → bool`. `true` = aprobó, `false` = rechazó.
  final Map<String, bool> votes;
  final DateTime receivedAt;

  const PendingJoin({
    required this.request,
    this.votes = const {},
    required this.receivedAt,
  });

  PendingJoin copyWith({Map<String, bool>? votes}) => PendingJoin(
        request: request,
        votes: votes ?? this.votes,
        receivedAt: receivedAt,
      );

  bool? voteOf(String deviceId) => votes[deviceId];
}

/// Solicitud de recuperación pendiente de votación.
class PendingRecovery {
  final InviteRequest request;
  final Map<String, bool> votes;
  final DateTime receivedAt;

  const PendingRecovery({
    required this.request,
    this.votes = const {},
    required this.receivedAt,
  });

  PendingRecovery copyWith({Map<String, bool>? votes}) => PendingRecovery(
        request: request,
        votes: votes ?? this.votes,
        receivedAt: receivedAt,
      );

  bool? voteOf(String deviceId) => votes[deviceId];
}

// ══════════════════════════════════════════════════════════════════════
// PendingJoinsNotifier
// ══════════════════════════════════════════════════════════════════════

class PendingJoinsNotifier
    extends StateNotifier<Map<String, PendingJoin>> {
  PendingJoinsNotifier() : super(const {});

  /// Agrega una solicitud si no existe. Idempotente.
  void add(InviteRequest request) {
    if (state.containsKey(request.guestDeviceId)) return;
    final updated = Map<String, PendingJoin>.from(state);
    updated[request.guestDeviceId] = PendingJoin(
      request: request,
      receivedAt: DateTime.now(),
    );
    state = updated;
  }

  /// Registra el voto de un miembro para una solicitud.
  void registerVote(String guestDeviceId, String memberDeviceId, bool vote) {
    final current = state[guestDeviceId];
    if (current == null) return;
    final votes = Map<String, bool>.from(current.votes);
    votes[memberDeviceId] = vote;
    final updated = Map<String, PendingJoin>.from(state);
    updated[guestDeviceId] = current.copyWith(votes: votes);
    state = updated;
  }

  /// `true` si **todos** los `expectedVoters` ya votaron `true`.
  bool hasUnanimousApproval(
    String guestDeviceId,
    Set<String> expectedVoters,
  ) {
    final current = state[guestDeviceId];
    if (current == null) return false;
    if (expectedVoters.isEmpty) return false;
    for (final voter in expectedVoters) {
      if (current.votes[voter] != true) return false;
    }
    return true;
  }

  /// `true` si algún votante rechazó.
  bool hasAnyRejection(String guestDeviceId) {
    final current = state[guestDeviceId];
    if (current == null) return false;
    return current.votes.values.any((v) => v == false);
  }

  void remove(String guestDeviceId) {
    if (!state.containsKey(guestDeviceId)) return;
    final updated = Map<String, PendingJoin>.from(state)
      ..remove(guestDeviceId);
    state = updated;
  }

  void clearAll() {
    if (state.isEmpty) return;
    state = const {};
  }
}

final pendingJoinsProvider =
    StateNotifierProvider<PendingJoinsNotifier, Map<String, PendingJoin>>(
  (ref) => PendingJoinsNotifier(),
);

// ══════════════════════════════════════════════════════════════════════
// PendingRecoveriesNotifier
// ══════════════════════════════════════════════════════════════════════

class PendingRecoveriesNotifier
    extends StateNotifier<Map<String, PendingRecovery>> {
  PendingRecoveriesNotifier() : super(const {});

  void add(InviteRequest request) {
    if (state.containsKey(request.guestDeviceId)) return;
    final updated = Map<String, PendingRecovery>.from(state);
    updated[request.guestDeviceId] = PendingRecovery(
      request: request,
      receivedAt: DateTime.now(),
    );
    state = updated;
  }

  void registerVote(String guestDeviceId, String memberDeviceId, bool vote) {
    final current = state[guestDeviceId];
    if (current == null) return;
    final votes = Map<String, bool>.from(current.votes);
    votes[memberDeviceId] = vote;
    final updated = Map<String, PendingRecovery>.from(state);
    updated[guestDeviceId] = current.copyWith(votes: votes);
    state = updated;
  }

  bool hasUnanimousApproval(
    String guestDeviceId,
    Set<String> expectedVoters,
  ) {
    final current = state[guestDeviceId];
    if (current == null) return false;
    if (expectedVoters.isEmpty) return false;
    for (final voter in expectedVoters) {
      if (current.votes[voter] != true) return false;
    }
    return true;
  }

  bool hasAnyRejection(String guestDeviceId) {
    final current = state[guestDeviceId];
    if (current == null) return false;
    return current.votes.values.any((v) => v == false);
  }

  void remove(String guestDeviceId) {
    if (!state.containsKey(guestDeviceId)) return;
    final updated = Map<String, PendingRecovery>.from(state)
      ..remove(guestDeviceId);
    state = updated;
  }

  void clearAll() {
    if (state.isEmpty) return;
    state = const {};
  }
}

final pendingRecoveriesProvider = StateNotifierProvider<
    PendingRecoveriesNotifier, Map<String, PendingRecovery>>(
  (ref) => PendingRecoveriesNotifier(),
);