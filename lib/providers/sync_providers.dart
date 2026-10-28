import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_models.dart';
import '../services/crypto_service.dart';
import '../services/firebase_transport.dart';
import '../services/key_store.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../services/sync_service.dart';
import '../services/transport_config.dart';

/// [KeyStore] único para toda la app.
final keyStoreProvider = Provider<KeyStore>((ref) => KeyStore());

/// [CryptoService] único.
final cryptoServiceProvider = Provider<CryptoService>(
  (ref) => CryptoService(),
);

/// [NotificationService] único.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// [PushService] único.
final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(),
);

/// [SyncService] único, inicializado de forma asíncrona.
///
/// El provider es `FutureProvider` porque `initialize()` es async y
/// necesita leer de [KeyStore].
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

/// Stream de eventos de sync (sobres entrantes ya descifrados).
final syncEventsProvider = StreamProvider<SyncEvent>((ref) {
  final service = ref.watch(syncServiceProvider).valueOrNull;
  if (service == null) return const Stream.empty();
  return service.events;
});

/// Estado actual del sync.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider).valueOrNull;
  if (service == null) return Stream.value(SyncStatus.unpaired);
  return service.status;
});

/// Config del transporte actual.
final transportConfigProvider = FutureProvider<TransportConfig>((ref) async {
  final keyStore = ref.watch(keyStoreProvider);
  return TransportConfig.load(keyStore);
});

/// `true` si la app está emparejada.
final isPairedProvider = FutureProvider<bool>((ref) async {
  final keyStore = ref.watch(keyStoreProvider);
  return keyStore.isPaired();
});