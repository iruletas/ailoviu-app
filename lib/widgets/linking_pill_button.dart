import 'package:flutter/material.dart';

class LinkingPillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final bool filled;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const LinkingPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.busy,
    required this.filled,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  State<LinkingPillButton> createState() => _LinkingPillButtonState();
}

class _LinkingPillButtonState extends State<LinkingPillButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = !widget.busy;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(24),
            border: widget.filled
                ? null
                : Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4),
                  ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: widget.busy
                ? SizedBox(
                    key: const ValueKey('busy'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      strokeCap: StrokeCap.round,
                      color: widget.foreground,
                    ),
                  )
                : Row(
                    key: ValueKey('label-${widget.label}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: 18,
                        color: widget.foreground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: widget.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}