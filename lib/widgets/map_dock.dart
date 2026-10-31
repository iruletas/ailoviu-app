import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dock flotante vertical de controles del mapa.
class MapDock extends StatelessWidget {
  final bool busy;
  final VoidCallback onMyLocationPressed;
  final VoidCallback? onCartoPressed;

  const MapDock({
    super.key,
    required this.busy,
    required this.onMyLocationPressed,
    this.onCartoPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showCarto = onCartoPressed != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockButton(
                icon: Icons.my_location_rounded,
                background: scheme.primaryContainer,
                foreground: scheme.onPrimaryContainer,
                busy: busy,
                tooltip: 'Mi ubicación',
                onPressed: busy ? null : onMyLocationPressed,
              ),
              if (showCarto) ...[
                const SizedBox(height: 4),
                _DockButton(
                  icon: Icons.vpn_key_rounded,
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                  tooltip: 'Configurar mapa (CARTO)',
                  onPressed: onCartoPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final String tooltip;
  final bool busy;
  final VoidCallback? onPressed;

  const _DockButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: enabled ? _handleTap : null,
          child: AnimatedScale(
            scale: _pressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: widget.busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        strokeCap: StrokeCap.round,
                        color: widget.foreground,
                      ),
                    )
                  : Icon(
                      widget.icon,
                      size: 20,
                      color: widget.foreground,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}