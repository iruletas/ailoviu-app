import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/recovery_service.dart';
import 'sync_providers.dart';

/// Servicio de recuperación.
final recoveryServiceProvider = Provider<RecoveryService>(
  (ref) => RecoveryService(
    keyStore: ref.watch(keyStoreProvider),
    crypto: ref.watch(cryptoServiceProvider),
    linking: ref.watch(linkingServiceProvider),
  ),
);