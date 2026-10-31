import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tipo de feedback del mapa.
enum MapFeedbackKind { success, error }

/// Sistema de toasts flotantes para el mapa.
///
/// No usa `ScaffoldMessenger` porque el `SnackBar` queda detrás de
/// `ClipRRect`/`BackdropFilter` del mapa y se ve mal. En su lugar,
/// inserta un `OverlayEntry` centrado abajo del mapa con `position`
/// relativa a la pantalla.
///
/// Uso típico desde `home_map_hero.dart`:
///
/// ```dart
/// MapFeedback.showSuccess(context, 'Ubicación actualizada 📍');
/// MapFeedback.showError(context, 'Permiso de ubicación denegado');
/// ```
///
/// Los métodos `show*` son **fire-and-forget**: no devuelven Future
/// ni requieren `await`. Se auto-cierran a los 2.2s.
class MapFeedback {
  MapFeedback._();

  /// Tiempo visible antes de auto-cerrarse.
  static const Duration _visibleFor = Duration(milliseconds: 2200);

  /// Distancia desde el borde inferior de la pantalla.
  static const double _bottomOffset = 110;

  /// Cápsula de éxito. `surfaceContainerHighest` al 92% con
  /// `my_location_rounded` en color primary.
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      kind: MapFeedbackKind.success,
      icon: Icons.my_location_rounded,
    );
  }

  /// Cápsula de error. `errorContainer` al 94% con
  /// `location_off_rounded` (o `error_outline_rounded` si se
  /// especifica). Háptica `mediumImpact` al mostrarse.
  static void showError(
    BuildContext context,
    String message, {
    IconData icon = Icons.location_off_rounded,
  }) {
    HapticFeedback.mediumImpact();
    _show(
      context,
      message: message,
      kind: MapFeedbackKind.error,
      icon: icon,
    );
  }

  /// Emite una cápsula con ícono custom. Útil para "GPS tardando…"
  /// o mensajes de timeout con ícono `timer_rounded`.
  static void showErrorWithIcon(
    BuildContext context,
    String message,
    IconData icon,
  ) {
    HapticFeedback.mediumImpact();
    _show(
      context,
      message: message,
      kind: MapFeedbackKind.error,
      icon: icon,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required MapFeedbackKind kind,
    required IconData icon,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final isSuccess = kind == MapFeedbackKind.success;
    final background = isSuccess
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.92)
        : scheme.errorContainer.withValues(alpha: 0.94);
    final foreground =
        isSuccess ? scheme.onSurface : scheme.onErrorContainer;
    final borderColor = isSuccess
        ? scheme.outlineVariant.withValues(alpha: 0.35)
        : scheme.error.withValues(alpha: 0.30);
    final iconColor =
        isSuccess ? scheme.primary : scheme.onErrorContainer;

    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 16,
        right: 16,
        bottom: _bottomOffset + MediaQuery.of(ctx).viewPadding.bottom,
        child: IgnorePointer(
          child: _AnimatedCapsule(
            reduceMotion: reduceMotion,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: iconColor),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          message,
                          style: textTheme.bodySmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
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
    );

    overlay.insert(entry);

    // Auto-cierre. Se captura el overlay para no usar un BuildContext
    // que pudo desmontarse.
    Timer(_visibleFor, () {
      if (entry.mounted) entry.remove();
    });
  }
}

/// Aparición con slide-up + fade cortos. Respeta reduce-motion.
class _AnimatedCapsule extends StatefulWidget {
  final Widget child;
  final bool reduceMotion;

  const _AnimatedCapsule({
    required this.child,
    required this.reduceMotion,
  });

  @override
  State<_AnimatedCapsule> createState() => _AnimatedCapsuleState();
}

class _AnimatedCapsuleState extends State<_AnimatedCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    if (widget.reduceMotion) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}