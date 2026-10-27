import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versión compilada de la app, leída del bundle.
///
/// En el workflow de CI se inyecta `0.1.{run_number}+{run_number}`
/// en `pubspec.yaml` antes de compilar, así que aquí se lee el valor
/// real de la APK instalada (no el `1.0.0+1` del repo).
///
/// Ejemplo: la build 28 devuelve `"0.1.28"`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Número de build compilado, leído del bundle.
///
/// Ejemplo: la build 28 devuelve `"28"`.
final appBuildNumberProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber;
});