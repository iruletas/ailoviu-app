import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/map_key_provider.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_scaffold.dart';
import 'settings_components.dart';

/// Paso 3: API key de CARTO (opcional).
///
/// Si el usuario la deja vacía, el mapa usa OpenStreetMap (funciona,
/// se ve menos limpio). No es obligatoria.
///
/// Toda la persistencia vive en `cartoKeyProvider`. Este widget solo
/// lee el valor inicial y llama a `setKey` al continuar.
class OnboardingMapStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const OnboardingMapStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  ConsumerState<OnboardingMapStep> createState() => _OnboardingMapStepState();
}

class _OnboardingMapStepState extends ConsumerState<OnboardingMapStep> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _focused = false;
  String _initialKey = '';
  bool _obtenerPressed = false;

  @override
  void initState() {
    super.initState();
    _initialKey = ref.read(cartoKeyProvider);
    _controller = TextEditingController(text: _initialKey);
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
      setState(() {});
    }
  }

  void _clear() {
    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() {});
  }

  Future<void> _openCarto() async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse('https://carto.com/basemaps/apikey');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el navegador'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveAndContinue() async {
    HapticFeedback.mediumImpact();
    final trimmed = _controller.text.trim();
    if (trimmed != _initialKey) {
      await ref.read(cartoKeyProvider.notifier).setKey(trimmed);
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasKey = _controller.text.trim().isNotEmpty;

    return OnboardingScaffold(
      step: OnboardingStep.map,
      onSkip: widget.onSkip,
      bottomAction: _BottomNav(
        onBack: widget.onBack,
        primaryLabel: hasKey ? 'Guardar y continuar' : 'Continuar sin mapa',
        onPrimary: _saveAndContinue,
        primaryIsSecondaryStyle: !hasKey,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'El mapa',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'El mapa de Hogar usa OpenStreetMap por defecto. Si quieres '
            'que se vea más limpio, agrega una API key gratuita de CARTO.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Preview del mapa (mock, sin gastar tiles reales).
          _MapPreview(hasKey: hasKey),
          const SizedBox(height: 20),

          // Campo de API key.
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TonalMicroHeader(
                  icon: Icons.vpn_key_rounded,
                  title: 'API key de CARTO',
                  description:
                      'Opcional. Sin ella, el mapa funciona igual pero '
                      'con estilo OpenStreetMap.',
                ),
                const SizedBox(height: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _focused
                          ? scheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.vpn_key_rounded,
                        size: 18,
                        color: _focused
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'eyJhbGci…',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      // Toggle Paste ↔ Clear animado.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: RotationTransition(
                              turns: Tween<double>(
                                begin: 0.85,
                                end: 1.0,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: hasKey
                            ? IconButton(
                                key: const ValueKey('clear'),
                                onPressed: _clear,
                                icon: const Icon(Icons.clear_rounded),
                                visualDensity: VisualDensity.compact,
                              )
                            : IconButton(
                                key: const ValueKey('paste'),
                                onPressed: _paste,
                                icon: const Icon(
                                  Icons.content_paste_rounded,
                                ),
                                tooltip: 'Pegar',
                                visualDensity: VisualDensity.compact,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _obtenerPressed = true),
                  onTapUp: (_) => setState(() => _obtenerPressed = false),
                  onTapCancel: () =>
                      setState(() => _obtenerPressed = false),
                  onTap: _openCarto,
                  child: AnimatedScale(
                    scale: _obtenerPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: _obtenerPressed
                        ? Curves.easeOutCubic
                        : Curves.easeOutBack,
                    child: FilledButton.tonalIcon(
                      onPressed: _openCarto,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Obtener clave en carto.com'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// _MapPreview — mock visual del mapa, reactivo a hasKey
// ══════════════════════════════════════════════════════════════════════

class _MapPreview extends StatelessWidget {
  final bool hasKey;

  const _MapPreview({required this.hasKey});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasKey
              ? [
                  scheme.tertiaryContainer.withValues(alpha: 0.85),
                  scheme.primaryContainer.withValues(alpha: 0.85),
                ]
              : [
                  scheme.surfaceContainerHighest,
                  scheme.surfaceContainerHigh,
                ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Calles simuladas.
            Positioned.fill(
              child: CustomPaint(
                painter: _MapMockPainter(
                  lineColor: hasKey
                      ? scheme.onTertiaryContainer.withValues(alpha: 0.18)
                      : scheme.onSurfaceVariant.withValues(alpha: 0.15),
                ),
              ),
            ),
            // Pines simulados con bounce al cambiar de modo.
            Positioned(
              top: 56,
              left: 68,
              child: _BouncingPin(
                hasKey: hasKey,
                color: hasKey ? scheme.primary : scheme.onSurfaceVariant,
                letter: 'A',
              ),
            ),
            Positioned(
              top: 100,
              right: 78,
              child: _BouncingPin(
                hasKey: hasKey,
                color:
                    hasKey ? scheme.secondary : scheme.onSurfaceVariant,
                letter: 'B',
              ),
            ),
            // Badge de estado con pop-in al cambiar.
            Positioned(
              top: 12,
              left: 12,
              child: _StatusBadge(hasKey: hasKey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pin que da un pequeño salto vertical la primera vez que `hasKey`
/// pasa a `true`. No rebota al desactivar (sería ruido).
class _BouncingPin extends StatefulWidget {
  final bool hasKey;
  final Color color;
  final String letter;

  const _BouncingPin({
    required this.hasKey,
    required this.color,
    required this.letter,
  });

  @override
  State<_BouncingPin> createState() => _BouncingPinState();
}

class _BouncingPinState extends State<_BouncingPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant _BouncingPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.hasKey && widget.hasKey) {
      _controller.forward(from: 0.0);
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Salto elástico: 0 → -14 → 0 (con overshoot suave).
    final dy = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -14.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -14.0, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_controller);

    return AnimatedBuilder(
      animation: dy,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, dy.value),
          child: child,
        );
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.surface, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          widget.letter,
          style: TextStyle(
            color: scheme.surface,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Badge de estado con pop-in al cambiar de modo.
class _StatusBadge extends StatelessWidget {
  final bool hasKey;

  const _StatusBadge({required this.hasKey});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasKey
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Row(
          key: ValueKey(hasKey),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasKey ? Icons.check_circle_rounded : Icons.public_rounded,
              size: 14,
              color: hasKey
                  ? scheme.onTertiaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              hasKey ? 'CARTO limpio' : 'OpenStreetMap',
              style: theme.textTheme.labelSmall?.copyWith(
                color: hasKey
                    ? scheme.onTertiaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapMockPainter extends CustomPainter {
  final Color lineColor;

  _MapMockPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    for (int i = 1; i <= 3; i++) {
      final y = h * i / 4;
      final path = Path()..moveTo(0, y);
      final cx1 = w * 0.3;
      final cx2 = w * 0.7;
      path.cubicTo(cx1, y - 12, cx2, y + 12, w, y);
      canvas.drawPath(path, paint);
    }

    for (int i = 1; i <= 2; i++) {
      final x = w * i / 3;
      final path = Path()..moveTo(x, 0);
      final cy1 = h * 0.3;
      final cy2 = h * 0.7;
      path.cubicTo(x - 10, cy1, x + 10, cy2, x, h);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapMockPainter old) =>
      old.lineColor != lineColor;
}

// ══════════════════════════════════════════════════════════════════════
// _BottomNav — superficie flotante con morphing implícito del primario
// ══════════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  final VoidCallback onBack;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryIsSecondaryStyle;

  const _BottomNav({
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIsSecondaryStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // Colores objetivo del botón primario según el modo.
    final bg = primaryIsSecondaryStyle
        ? scheme.surfaceContainerHighest
        : scheme.primary;
    final fg = primaryIsSecondaryStyle
        ? scheme.onSurface
        : scheme.onPrimary;
    final borderColor = primaryIsSecondaryStyle
        ? scheme.outlineVariant.withValues(alpha: 0.4)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () {
              HapticFeedback.lightImpact();
              onBack();
            },
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón primario con morphing implícito (un solo widget,
          // colores animados). Mantenemos la ripple con Material+InkWell.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPrimary,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: 48,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: onPrimary,
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: fg,
                          ),
                          const SizedBox(width: 8),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            style: theme.textTheme.labelLarge!.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w600,
                            ),
                            child: Text(primaryLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}