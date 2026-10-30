import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../models/sync_models.dart';
import '../services/crypto_service.dart';
import '../services/firebase_transport.dart';
import '../services/invite_service.dart';
import '../services/key_store.dart';
import '../services/linking_service.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../services/sync_router.dart';
import '../services/sync_service.dart';
import '../services/transport_config.dart';

final keyStoreProvider = Provider<KeyStore>((ref) => KeyStore());

final cryptoServiceProvider = Provider<CryptoService>(
  (ref) => CryptoService(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final pushServiceProvider = Provider<PushService>((ref) => PushService());

final inviteServiceProvider = Provider<InviteService>(
  (ref) => InviteService(ref.watch(cryptoServiceProvider)),
);

final linkingServiceProvider = Provider<LinkingService>(
  (ref) => LinkingService(
    keyStore: ref.watch(keyStoreProvider),
    crypto: ref.watch(cryptoServiceProvider),
    inviteService: ref.watch(inviteServiceProvider),
  ),
);

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final service = SyncService(
    keyStore: ref.watch(keyStoreProvider),
    crypto: ref.watch(cryptoServiceProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
  await service.initialize();
  ref.onDispose(service.dispose);
  return service;
});

final syncEventsProvider = StreamProvider<SyncEvent>((ref) {
  final service = ref.watch(syncServiceProvider).valueOrNull;
  if (service == null) return const Stream.empty();
  return service.events;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider).valueOrNull;
  if (service == null) return Stream.value(SyncStatus.unpaired);
  return service.status;
});

final transportConfigProvider = FutureProvider<TransportConfig>((ref) async {
  return TransportConfig.load(ref.watch(keyStoreProvider));
});

/// Snapshot del grupo.
final groupSnapshotProvider = FutureProvider<GroupSnapshot>((ref) async {
  return ref.watch(linkingServiceProvider).snapshot();
});

/// `true` si hay al menos otro miembro aprobado.
final isLinkedProvider = FutureProvider<bool>((ref) async {
  final group = await ref.watch(groupSnapshotProvider.future);
  return group.isLinked;
});

/// Router de sync. Se mantiene vivo mientras `app.dart` lo observe.
final syncRouterProvider = Provider<SyncRouter>((ref) {
  final router = SyncRouter(ref);
  router.start();
  ref.onDispose(router.dispose);
  return router;
});