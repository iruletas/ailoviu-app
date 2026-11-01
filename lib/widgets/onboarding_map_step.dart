import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/map_key_provider.dart';
import '../providers/onboarding_providers.dart';
import '../providers/relationship_providers.dart';
import 'onboarding_scaffold.dart';
import 'settings_components.dart';

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
  String? _inlineError;
  bool _expandedTutorial = false;
  bool _copiedText = false;

  static const String _cartoUrl = 'https://carto.com/basemaps/apikey';
  static const String _cartoText = 
      'Ailoviu is a personal app to share real-time location with my partner.';

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
    if (data?.text == null) return;
    _controller.text = data!.text!;
    setState(() => _inlineError = null);
  }

  void _clear() {
    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() => _inlineError = null);
  }

  Future<void> _copyCartoText() async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(const ClipboardData(text: _cartoText));
    if (!mounted) return;
    setState(() => _copiedText = true);
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copiedText = false);
    });
  }

  Future<void> _openCarto() async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(_cartoUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        setState(() => _inlineError = 'No se pudo abrir el navegador.');
      }
    }
  }

  Future<void> _saveAndContinue() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isNotEmpty && trimmed.length < 20) {
      HapticFeedback.heavyImpact();
      setState(() => _inlineError = 'La clave es muy corta. Revisa el correo que te envió CARTO.');
      return;
    }
    
    HapticFeedback.mediumImpact();
    if (trimmed != _initialKey) {
      await ref.read(cartoKeyProvider.notifier).setKey(trimmed);
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasText = _controller.text.trim().isNotEmpty;
    final rel = ref.watch(relationshipProvider);
    
    // Adaptación de nombres para los avatares del mapa
    final names = rel.visibleNames.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    final initialA = names.isNotEmpty ? names[0][0].toUpperCase() : 'A';
    final initialB = names.length > 1 ? names[1][0].toUpperCase() : 'B';

    return OnboardingScaffold(
      step: OnboardingStep.map,
      onSkip: widget.onSkip,
      bottomAction: _BottomNav(
        onBack: widget.onBack,
        primaryLabel: hasText ? 'Guardar y continuar' : 'Continuar sin mapa',
        onPrimary: _saveAndContinue,
        primaryIsSecondaryStyle: !hasText,
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

          // Mapa con avatares y rebote
          _MapPreview(
            hasKey: hasText,
            initialA: initialA,
            initialB: initialB,
          ),
          const SizedBox(height: 20),

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
                          onChanged: (_) => setState(() => _inlineError = null),
                          decoration: const InputDecoration(
                            hintText: 'Pega la clave aquí',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (hasText)
                        IconButton(
                          onPressed: _clear,
                          icon: const Icon(Icons.clear_rounded),
                          visualDensity: VisualDensity.compact,
                        )
                      else
                        IconButton(
                          onPressed: _paste,
                          icon: const Icon(Icons.content_paste_rounded),
                          tooltip: 'Pegar',
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
                
                if (_inlineError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 16, color: scheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _inlineError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _obtenerPressed = true),
                  onTapUp: (_) => setState(() => _obtenerPressed = false),
                  onTapCancel: () => setState(() => _obtenerPressed = false),
                  onTap: _openCarto,
                  child: AnimatedScale(
                    scale: _obtenerPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: _obtenerPressed ? Curves.easeOutCubic : Curves.easeOutBack,
                    child: FilledButton.tonalIcon(
                      onPressed: _openCarto,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Abrir carto.com'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          _TutorialSection(
            expanded: _expandedTutorial,
            onToggle: () {
              HapticFeedback.lightImpact();
              setState(() => _expandedTutorial = !_expandedTutorial);
            },
            cartoText: _cartoText,
            copiedText: _copiedText,
            onCopyText: _copyCartoText,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Tutorial Desplegable ───────────────────────────────────────────────
class _TutorialSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final String cartoText;
  final bool copiedText;
  final VoidCallback onCopyText;

  const _TutorialSection({
    required this.expanded,
    required this.onToggle,
    required this.cartoText,
    required this.copiedText,
    required this.onCopyText,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: expanded ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cómo obtener tu API Key',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 14),
                        _InstructionStep(
                          number: '1',
                          text: 'Abre carto.com/basemaps/apikey en tu navegador.',
                        ),
                        _InstructionStep(
                          number: '2',
                          text: 'Llena el formulario con estos datos:',
                          isLast: false,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 34, bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BulletText('Email address: Tu correo electrónico.'),
                              _BulletText('Your name, or your organisation: Tu nombre.'),
                              _BulletText('Is this a commercial project?: Selecciona "No — personal, hobby, academic, or a non-profit".'),
                              _BulletText('What are you building?: Pega este texto:'),
                              const SizedBox(height: 8),
                              // Caja de texto copiable
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cartoText,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          height: 1.4,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: onCopyText,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: copiedText ? scheme.tertiaryContainer : scheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          child: Icon(
                                            copiedText ? Icons.check_rounded : Icons.copy_rounded,
                                            key: ValueKey(copiedText),
                                            size: 16,
                                            color: copiedText ? scheme.onTertiaryContainer : scheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _InstructionStep(
                          number: '3',
                          text: 'Marca la casilla de aceptación, resuelve el reCAPTCHA y toca "Request API key".',
                        ),
                        _InstructionStep(
                          number: '4',
                          text: 'Revisa tu correo electrónico. Ahí te llegará un mensaje con tu API Key.',
                        ),
                        _InstructionStep(
                          number: '5',
                          text: 'Copia esa clave, vuelve a la app y pégala en el campo de arriba.',
                          isLast: true,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;
  const _BulletText(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('· ', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  final bool isLast;

  const _InstructionStep({
    required this.number,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  number,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mapa Restaurado ────────────────────────────────────────────────────
class _MapPreview extends StatelessWidget {
  final bool hasKey;
  final String initialA;
  final String initialB;

  const _MapPreview({
    required this.hasKey,
    required this.initialA,
    required this.initialB,
  });

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
              ? [scheme.tertiaryContainer, scheme.primaryContainer]
              : [scheme.surfaceContainerHighest, scheme.surfaceContainerHigh],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MapMockPainter(
                  hasKey: hasKey,
                  lineColor: hasKey
                      ? scheme.onTertiaryContainer.withValues(alpha: 0.18)
                      : scheme.onSurfaceVariant.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              top: 56,
              left: 68,
              child: _BouncingPin(
                hasKey: hasKey,
                color: hasKey ? scheme.primary : scheme.onSurfaceVariant,
                letter: initialA,
              ),
            ),
            Positioned(
              top: 100,
              right: 78,
              child: _BouncingPin(
                hasKey: hasKey,
                color: hasKey ? scheme.secondary : scheme.onSurfaceVariant,
                letter: initialB,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasKey ? scheme.tertiaryContainer : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  hasKey ? 'CARTO limpio' : 'OpenStreetMap',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: hasKey ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _BouncingPinState extends State<_BouncingPin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1.0);
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
    final dy = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -14.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 60),
    ]).animate(_controller);

    return AnimatedBuilder(
      animation: dy,
      builder: (context, child) => Transform.translate(offset: Offset(0, dy.value), child: child),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.surface, width: 2.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Text(
          widget.letter,
          style: TextStyle(color: scheme.surface, fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }
}

class _MapMockPainter extends CustomPainter {
  final bool hasKey;
  final Color lineColor;

  _MapMockPainter({required this.hasKey, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    if (!hasKey) {
      // OSM: líneas rectas
      for (int i = 1; i <= 3; i++) {
        final y = size.height * i / 4;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      for (int i = 1; i <= 2; i++) {
        final x = size.width * i / 3;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    } else {
      // CARTO: líneas curvas
      final w = size.width;
      final h = size.height;
      for (int i = 1; i <= 3; i++) {
        final y = h * i / 4;
        final path = Path()..moveTo(0, y);
        path.cubicTo(w * 0.3, y - 12, w * 0.7, y + 12, w, y);
        canvas.drawPath(path, paint);
      }
      for (int i = 1; i <= 2; i++) {
        final x = w * i / 3;
        final path = Path()..moveTo(x, 0);
        path.cubicTo(x - 10, h * 0.3, x + 10, h * 0.7, x, h);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapMockPainter old) => old.hasKey != hasKey || old.lineColor != lineColor;
}

// ── _BottomNav (igual que antes) ───────────────────────────────────────
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

    final bg = primaryIsSecondaryStyle ? scheme.surfaceContainerHighest : scheme.primary;
    final fg = primaryIsSecondaryStyle ? scheme.onSurface : scheme.onPrimary;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () { HapticFeedback.lightImpact(); onBack(); },
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPrimary,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: 48,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
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
                          Icon(Icons.arrow_forward_rounded, size: 20, color: fg),
                          const SizedBox(width: 8),
                          Text(
                            primaryLabel,
                            style: theme.textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w600),
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