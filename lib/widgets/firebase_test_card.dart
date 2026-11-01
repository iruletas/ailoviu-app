import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';
import '../services/firebase_test_service.dart';
import 'settings_components.dart';

/// Prueba la conexión de punta a punta con Firebase y muestra el
/// resultado con mensaje accionable + detalle técnico colapsable.
class FirebaseTestCard extends ConsumerStatefulWidget {
  final ValueChanged<bool> onResult;

  const FirebaseTestCard({
    super.key,
    required this.onResult,
  });

  @override
  ConsumerState<FirebaseTestCard> createState() => _FirebaseTestCardState();
}

class _FirebaseTestCardState extends ConsumerState<FirebaseTestCard> {
  FirebaseTestReport? _report;
  bool _busy = false;
  bool _showTechnicalDetail = false;
  bool _pressed = false;

  Future<void> _runTest() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() {
      _busy = true;
      _showTechnicalDetail = false;
    });

    final keyStore = ref.read(keyStoreProvider);
    final service = FirebaseTestService(keyStore: keyStore);
    final report = await service.testConnection();

    if (!mounted) return;

    if (report.isSuccess) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.vibrate();
    }

    setState(() {
      _busy = false;
      _report = report;
    });

    // Avisamos al paso 4 si el test pasó o falló
    widget.onResult(report.isSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final report = _report;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TonalMicroHeader(
            icon: Icons.wifi_tethering_rounded,
            title: 'Probar conexión',
            description:
                'Asegúrate de que todo funcione antes de continuar. Esto '
                'verifica las credenciales, la base de datos y las reglas.',
          ),
          const SizedBox(height: 16),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _busy
                ? null
                : (_) => setState(() => _pressed = true),
            onTapUp: _busy
                ? null
                : (_) => setState(() => _pressed = false),
            onTapCancel: _busy
                ? null
                : () => setState(() => _pressed = false),
            onTap: _busy ? null : _runTest,
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _busy ? null : _runTest,
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: _busy
                            ? SizedBox(
                                key: const ValueKey('busy'),
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  strokeCap: StrokeCap.round,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : Row(
                                key: const ValueKey('label'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 18,
                                    color: scheme.onPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    report == null
                                        ? 'Probar conexión'
                                        : 'Volver a probar',
                                    style: theme.textTheme.labelLarge
                                        ?.copyWith(
                                      color: scheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: report == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _ResultBanner(
                      report: report,
                      showTechnicalDetail: _showTechnicalDetail,
                      onToggleDetail: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _showTechnicalDetail = !_showTechnicalDetail;
                        });
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Banner con barra lateral de acento, icono en squircle, chip para el
/// detalle técnico y cápsula de log.
class _ResultBanner extends StatelessWidget {
  final FirebaseTestReport report;
  final bool showTechnicalDetail;
  final VoidCallback onToggleDetail;

  const _ResultBanner({
    required this.report,
    required this.showTechnicalDetail,
    required this.onToggleDetail,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isSuccess = report.isSuccess;

    final bg = isSuccess ? scheme.tertiaryContainer : scheme.errorContainer;
    final fg = isSuccess
        ? scheme.onTertiaryContainer
        : scheme.onErrorContainer;
    final accent = isSuccess ? scheme.tertiary : scheme.error;
    final icon = isSuccess
        ? Icons.check_circle_rounded
        : _iconForResult(report.result);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -10 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(icon, size: 18, color: fg),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSuccess ? 'Todo listo' : 'Algo falta',
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: fg,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    report.message,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: fg.withValues(alpha: 0.9),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (report.technicalDetail != null) ...[
                          const SizedBox(height: 12),
                          _DetailChip(
                            expanded: showTechnicalDetail,
                            onTap: onToggleDetail,
                            fg: fg,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: showTechnicalDetail
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: _TechnicalConsole(
                                      detail: report.technicalDetail!,
                                      result: report.result,
                                      fg: fg,
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconForResult(FirebaseTestResult result) {
    switch (result) {
      case FirebaseTestResult.success:
        return Icons.check_circle_rounded;
      case FirebaseTestResult.missingConfig:
        return Icons.insert_drive_file_outlined;
      case FirebaseTestResult.configError:
        return Icons.description_outlined;
      case FirebaseTestResult.authError:
        return Icons.lock_outline_rounded;
      case FirebaseTestResult.permissionDenied:
        return Icons.gpp_bad_outlined;
      case FirebaseTestResult.networkError:
        return Icons.wifi_off_rounded;
      case FirebaseTestResult.readBackError:
        return Icons.visibility_off_outlined;
      case FirebaseTestResult.unknown:
        return Icons.error_outline_rounded;
    }
  }
}

class _DetailChip extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  final Color fg;

  const _DetailChip({
    required this.expanded,
    required this.onTap,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.terminal_rounded,
              size: 12,
              color: fg.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6),
            Text(
              expanded ? 'Ocultar detalle' : 'Ver detalle técnico',
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(
                Icons.expand_more_rounded,
                size: 12,
                color: fg.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicalConsole extends StatelessWidget {
  final String detail;
  final FirebaseTestResult result;
  final Color fg;

  const _TechnicalConsole({
    required this.detail,
    required this.result,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          Opacity(opacity: value, child: child),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _resultKey(result),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: fg.withValues(alpha: 0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              detail,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.4,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _resultKey(FirebaseTestResult result) {
    switch (result) {
      case FirebaseTestResult.success:
        return 'OK';
      case FirebaseTestResult.missingConfig:
        return 'MISSING_CONFIG';
      case FirebaseTestResult.configError:
        return 'CONFIG_ERROR';
      case FirebaseTestResult.authError:
        return 'AUTH_ERROR';
      case FirebaseTestResult.permissionDenied:
        return 'PERMISSION_DENIED';
      case FirebaseTestResult.networkError:
        return 'NETWORK_ERROR';
      case FirebaseTestResult.readBackError:
        return 'READ_BACK_ERROR';
      case FirebaseTestResult.unknown:
        return 'UNKNOWN';
    }
  }
}