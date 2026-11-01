import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/relationship_providers.dart';
import 'onboarding_scaffold.dart';
import 'settings_components.dart';

/// Paso 1: Bienvenida y enmarque emocional.
///
/// No configura nada. Solo explica qué va a pasar y por qué vale la
/// pena la fricción de los pasos 2-4.
///
/// Lee `relationshipProvider` para adaptar el copy si el usuario ya
/// tenía datos configurados de antes (raro, pero pasa si repite el
/// onboarding desde Ajustes).
class OnboardingWelcomeStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkipAll;

  const OnboardingWelcomeStep({
    super.key,
    required this.onNext,
    required this.onSkipAll,
  });

  @override
  ConsumerState<OnboardingWelcomeStep> createState() =>
      _OnboardingWelcomeStepState();
}

class _OnboardingWelcomeStepState
    extends ConsumerState<OnboardingWelcomeStep>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _glowController;
  late final Animation<double> _heartScale;

  bool _startButtonPressed = false;

  @override
  void initState() {
    super.initState();

    // Entrada del corazón: overshoot elástico.
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40,
      ),
    ]).animate(_entranceController);

    // Glow respirando continuamente.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _confirmSkipAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
          backgroundColor: scheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.tertiaryContainer,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 28,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Saltar la configuración?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu relación se verá solo en este celular. No podrás '
                  'compartir estados, ubicaciones ni zumbidos con tu '
                  'pareja hasta que configures Firebase y la vincules.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Puedes hacerlo después desde Ajustes → Conexiones.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context, true);
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Saltar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) widget.onSkipAll();
  }

  @override
  Widget build(BuildContext context) {
    final relationship = ref.watch(relationshipProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return OnboardingScaffold(
      step: OnboardingStep.welcome,
      showSkip: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          // ── Corazón hero con rebote + glow pulsante ───────────────
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _heartScale,
                _glowController,
              ]),
              builder: (context, child) {
                final glowT = _glowController.value;
                final blur = 20 + glowT * 14;
                final spread = 1 + glowT * 4;
                final alpha = 0.24 + glowT * 0.16;

                return Transform.scale(
                  scale: _heartScale.value,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: alpha),
                          blurRadius: blur,
                          spreadRadius: spread,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 44,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Bienvenido a Ailoviu',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            _partnerCopy(relationship),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // ── Card: qué vamos a hacer ───────────────────────────────
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TonalMicroHeader(
                  icon: Icons.rocket_launch_rounded,
                  title: 'Vamos a configurar 4 cosas',
                  description:
                      'Toma 3 minutos. Puedes saltarte los pasos que '
                      'quieras y hacerlos después desde Ajustes.',
                ),
                const SizedBox(height: 18),
                _StaggeredStepBullet(
                  index: 0,
                  number: 1,
                  title: 'Su relación',
                  subtitle: 'Nombres, tipo y fecha de inicio.',
                ),
                const SizedBox(height: 14),
                _StaggeredStepBullet(
                  index: 1,
                  number: 2,
                  title: 'El mapa',
                  subtitle: 'Una API key gratuita para un mapa más limpio.',
                ),
                const SizedBox(height: 14),
                _StaggeredStepBullet(
                  index: 2,
                  number: 3,
                  title: 'Firebase',
                  subtitle:
                      'Tu propio servidor privado. Solo tú y tu pareja '
                      'tienen llave.',
                ),
                const SizedBox(height: 14),
                _StaggeredStepBullet(
                  index: 3,
                  number: 4,
                  title: 'La vinculación',
                  subtitle:
                      'El QR que une los dos celulares por primera vez.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Card: por qué vale la pena (sin borde) ────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 20,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Todo esto vale la pena',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Configurar tu propio Firebase sirve para una sola '
                        'cosa: que lo que compartan sea de ustedes y de '
                        'nadie más. Ni nosotros podemos verlo.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer
                              .withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── CTA principal con compresión física ───────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              setState(() => _startButtonPressed = true);
            },
            onTapUp: (_) {
              setState(() => _startButtonPressed = false);
            },
            onTapCancel: () {
              setState(() => _startButtonPressed = false);
            },
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onNext();
            },
            child: AnimatedScale(
              scale: _startButtonPressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: _startButtonPressed
                  ? Curves.easeOutCubic
                  : Curves.easeOutBack,
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onNext();
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text('Empezar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Saltar todo ───────────────────────────────────────────
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _confirmSkipAll();
            },
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              shape: const StadiumBorder(),
            ),
            child: const Text('Saltar configuración'),
          ),
        ],
      ),
    );
  }

  /// Copy del paso 1, adaptado al tipo de relación si ya hay datos.
  static String _partnerCopy(AppRelationship rel) {
    final names = rel.visibleNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return 'Vamos a dejar todo listo para que tu persona favorita abra '
          'la app y vea el mismo espacio que tú.';
    }

    if (names.length == 1) {
      return 'Vamos a dejar todo listo para que ${names.first} abra la '
          'app y vea el mismo espacio que tú.';
    }

    final joined = names.length == 2
        ? '${names[0]} y ${names[1]}'
        : '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';

    return 'Vamos a dejar todo listo para que $joined abran la app y '
        'vean el mismo espacio que tú.';
  }
}

/// Fila de la lista de "qué vamos a configurar", con:
/// - Cápsula numerada tonal (1-4) en vez de ícono suelto.
/// - Aparición escalonada (delay según [index]).
class _StaggeredStepBullet extends StatelessWidget {
  final int index;
  final int number;
  final String title;
  final String subtitle;

  const _StaggeredStepBullet({
    required this.index,
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 420 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // El delay se simula mapeando `value` con un offset por índice.
        // Con `duration` creciente por índice, el efecto global es una
        // cascada de 80 ms entre filas.
        final delayedValue =
            ((value - index * 0.08) / (1 - index * 0.08)).clamp(0.0, 1.0);
        final opacity = delayedValue;
        final dy = (1 - delayedValue) * 12;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$number',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}