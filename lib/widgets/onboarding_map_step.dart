import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/map_key_provider.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_scaffold.dart';
import 'settings_components.dart';

/// Paso 3: API key de CARTO (opcional).
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Texto copiado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    if (trimmed.length < 20) {
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
    final isValidLength = _controller.text.trim().length >= 20;

    return OnboardingScaffold(
      step: OnboardingStep.map,
      onSkip: widget.onSkip,
      bottomAction: _BottomNav(
        onBack: widget.onBack,
        primaryLabel: isValidLength ? 'Guardar y continuar' : 'Continuar sin mapa',
        onPrimary: isValidLength ? _saveAndContinue : widget.onNext,
        primaryIsSecondaryStyle: !isValidLength,
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

          _MapPreview(hasKey: isValidLength),
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
          
          // Tarjeta de instrucciones
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TonalMicroHeader(
                  icon: Icons.assignment_rounded,
                  title: 'Cómo obtener tu API Key',
                  description: 'Sigue estos pasos en el sitio de CARTO.',
                ),
                const SizedBox(height: 16),
                _InstructionStep(
                  number: '1',
                  text: 'Abre carto.com/basemaps/apikey en tu navegador.',
                ),
                _InstructionStep(
                  number: '2',
                  text: 'Llena el formulario con tu correo y tu nombre.',
                ),
                _InstructionStep(
                  number: '3',
                  text: 'En "Is this a commercial project?", elige "No".',
                ),
                _InstructionStep(
                  number: '4',
                  text: 'En "What are you building?", pega este texto:',
                  trailing: TextButton.icon(
                    onPressed: _copyCartoText,
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copiar texto'),
                  ),
                ),
                _InstructionStep(
                  number: '5',
                  text: 'Acepta los términos, resuelve el CAPTCHA y pide la clave.',
                ),
                _InstructionStep(
                  number: '6',
                  text: 'Revisa tu correo. CARTO te enviará la API Key ahí.',
                  isLast: true,
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
// Widgets auxiliares
// ══════════════════════════════════════════════════════════════════════

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  final Widget? trailing;
  final bool isLast;

  const _InstructionStep({
    required this.number,
    required this.text,
    this.trailing,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 4),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(24),
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
                          Icon(Icons.arrow_forward_rounded, size: 20, color: fg),
                          const SizedBox(width: 8),
                          Text(
                            primaryLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: fg,
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
        ],
      ),
    );
  }
}

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
                  lineColor: hasKey
                      ? scheme.onTertiaryContainer.withValues(alpha: 0.18)
                      : scheme.onSurfaceVariant.withValues(alpha: 0.15),
                ),
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

class _MapMockPainter extends CustomPainter {
  final Color lineColor;
  _MapMockPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (int i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapMockPainter old) => old.lineColor != lineColor;
}