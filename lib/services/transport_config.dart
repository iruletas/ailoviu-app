import 'key_store.dart';

/// Configuración del transporte, resuelta desde [KeyStore].
///
/// - Si hay config de Firebase, la app usa [FirebaseTransport].
/// - Si no hay config, la app es local-only (no hay sync).
///
/// No hay transporte manual (se descartó). No hay Cloudflare (se
/// descartó). Solo Firebase o local-only.
sealed class TransportConfig {
  const TransportConfig();

  /// Carga la config desde [KeyStore].
  static Future<TransportConfig> load(KeyStore keyStore) async {
    final raw = await keyStore.getTransportConfig();
    if (raw == null) return const NoneTransportConfig();

    final type = raw['type'] as String?;
    if (type == 'firebase') {
      try {
        return FirebaseTransportConfig.fromJson(raw);
      } catch (_) {
        return const NoneTransportConfig();
      }
    }
    return const NoneTransportConfig();
  }

  /// `true` si el transporte está configurado.
  bool get isConfigured;
}

class NoneTransportConfig extends TransportConfig {
  const NoneTransportConfig();

  @override
  bool get isConfigured => false;
}

class FirebaseTransportConfig extends TransportConfig {
  final String projectId;
  final String databaseUrl;
  final String storageBucket;
  final String apiKey;
  final String appId;
  final String messagingSenderId;

  const FirebaseTransportConfig({
    required this.projectId,
    required this.databaseUrl,
    required this.storageBucket,
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
  });

  @override
  bool get isConfigured => true;

  Map<String, dynamic> toJson() => {
        'type': 'firebase',
        'projectId': projectId,
        'databaseUrl': databaseUrl,
        'storageBucket': storageBucket,
        'apiKey': apiKey,
        'appId': appId,
        'messagingSenderId': messagingSenderId,
      };

  static FirebaseTransportConfig fromJson(Map<String, dynamic> json) {
    final projectId = json['projectId'] as String?;
    final databaseUrl = json['databaseUrl'] as String?;
    final storageBucket = json['storageBucket'] as String?;
    final apiKey = json['apiKey'] as String?;
    final appId = json['appId'] as String?;
    final messagingSenderId = json['messagingSenderId'] as String?;

    if (projectId == null ||
        databaseUrl == null ||
        apiKey == null ||
        appId == null ||
        messagingSenderId == null) {
      throw ArgumentError('Config de Firebase incompleta');
    }

    return FirebaseTransportConfig(
      projectId: projectId,
      databaseUrl: databaseUrl,
      storageBucket: storageBucket ?? '',
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
    );
  }

  /// Construye desde un `google-services.json` parseado.
  ///
  /// El JSON tiene estructura de Firebase. Extraemos los campos que
  /// necesitamos para inicializar Firebase en runtime.
  static FirebaseTransportConfig fromGoogleServicesJson(
    Map<String, dynamic> json,
  ) {
    final projectInfo = json['project_info'] as Map?;
    final projectId = projectInfo?['project_id'] as String?;
    final storageBucket = projectInfo?['storage_bucket'] as String?;

    final clientList = json['client'] as List?;
    if (clientList == null || clientList.isEmpty) {
      throw ArgumentError('google-services.json sin clientes');
    }
    final client = clientList.first as Map;
    final clientInfo = client['client_info'] as Map?;
    final appId = clientInfo?['mobilesdk_app_id'] as String?;

    final apiKeyList = client['api_key'] as List?;
    if (apiKeyList == null || apiKeyList.isEmpty) {
      throw ArgumentError('google-services.json sin api_key');
    }
    final apiKey = (apiKeyList.first as Map)['current_key'] as String?;

    final services = client['services'] as Map?;
    final appInvite = services?['appinvite_service'] as Map?;
    final otherClients =
        appInvite?['other_platform_oauth_client'] as List?;
    String? messagingSenderId;
    if (otherClients != null && otherClients.isNotEmpty) {
      final first = otherClients.first as Map;
      messagingSenderId = first['client_id'] as String?;
    }
    messagingSenderId ??= projectInfo?['project_number'] as String?;

    if (projectId == null || appId == null || apiKey == null) {
      throw ArgumentError('google-services.json incompleto');
    }

    return FirebaseTransportConfig(
      projectId: projectId,
      databaseUrl: 'https://$projectId-default-rtdb.firebaseio.com',
      storageBucket: storageBucket ?? '$projectId.appspot.com',
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId ?? '',
    );
  }
}