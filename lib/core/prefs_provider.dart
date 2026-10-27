import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instancia única de [SharedPreferences] para toda la app.
///
/// Se inicializa una sola vez y los notifiers la consumen vía
/// `ref.read(prefsProvider.future)`. Evita repetir
/// `await SharedPreferences.getInstance()` en cada provider nuevo.
final prefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});