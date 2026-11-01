import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import '../providers/relationship_providers.dart';
import '../widgets/auth_gate.dart';
import '../widgets/main_shell_placeholder.dart';

/// Pantalla final del onboarding.
///
/// Celebra a la relación con los datos reales que el usuario configuró:
/// nombres, tipo, días juntos. La transición emocional entre "ya
/// configuraste todo" y "ahora empieza lo bonito".
class OnboardingWelcomeRelationshipScreen extends ConsumerStatefulWidget {
  const OnboardingWelcomeRelationshipScreen({super.key});

  @override
  ConsumerState<OnboardingWelcomeRelationshipScreen> createState() =>
      _OnboardingWelcomeRelationshipScreenState();
}

class _OnboardingWelcomeRelationshipScreenState
    extends ConsumerState<OnboardingWelcomeRelationshipScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _glow;

  late final Animation<double> _heartScale;
  late final Animation<double> _heartMorph;
  late final Animation<double> _namesFade;
  late final Animation<double> _daysFade;
  late final Animation<double> _messageFade;
  late final Animation<double> _buttonFade;

  bool _buttonPressed = false;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Corazón: escala elástica + morph de forma (cookie4 → heart).
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
    ]).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _heartMorph = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.05, 0.5, curve: Curves.easeOutCubic),
    );

    // Cascada de contenido.
    _namesFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.45, 0.70, curve: Curves.easeOut),
    );
    _daysFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
    );
    _messageFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.65, 0.90, curve: Curves.easeOut),
    );
    _buttonFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _entrance.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _enterApp() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AuthGate(child: MainShellPlaceholder()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rel = ref.watch(relationshipProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final names = rel.visibleNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              Color.alphaBlend(
                scheme.primaryContainer.withValues(alpha: 0.25),
                scheme.surface,
              ),
              Color.alphaBlend(
                scheme.tertiaryContainer.withValues(alpha: 0.18),
                scheme.surface,
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // ── Corazón hero con morph + glow dual ────────────
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _heartScale,
                    _heartMorph,
                    _glow,
                  ]),
                  builder: (context, child) {
                    final glowT = _glow.value;
                    // Glow alterna primary ↔ tertiary.
                    final glowColor = Color.lerp(
                      scheme.primary,
                      scheme.tertiary,
                      glowT,
                    )!;
                    final alpha = 0.28 + glowT * 0.18;

                    return Transform.scale(
                      scale: _heartScale.value,
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(alpha: alpha),
                              blurRadius: 24 + glowT * 16,
                              spreadRadius: 2 + glowT * 4,
                            ),
                          ],
                        ),
                        child: M3EMorphClip(
                          from: M3EShape.cookie4Sided,
                          to: M3EShape.heart,
                          progress: _heartMorph.value,
                          child: ColoredBox(
                            color: scheme.primary,
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 60,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // ── Título ────────────────────────────────────────
                FadeTransition(
                  opacity: _namesFade,
                  child: Column(
                    children: [
                      Text(
                        'Todo listo',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Píldoras tonales para los nombres.
                      if (names.isNotEmpty)
                        _NamesRow(names: names)
                      else
                        Text(
                          'Su espacio está listo',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),

                      // Tipo de relación (misma geometría que DaysChip).
                      if (names.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            rel.type.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Días juntos ───────────────────────────────────
                if (rel.startDate != null)
                  FadeTransition(
                    opacity: _daysFade,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _DaysChip(startDate: rel.startDate!),
                    ),
                  ),

                // ── Mensaje cálido ────────────────────────────────
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _messageFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _closingMessage(names),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ── Botón con InkWell único ───────────────────────
                FadeTransition(
                  opacity: _buttonFade,
                  child: AnimatedScale(
                    scale: _buttonPressed ? 0.97 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: _buttonPressed
                        ? Curves.easeOutCubic
                        : Curves.easeOutBack,
                    child: Material(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(28),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: _enterApp,
                        onTapDown: (_) =>
                            setState(() => _buttonPressed = true),
                        onTapUp: (_) =>
                            setState(() => _buttonPressed = false),
                        onTapCancel: () =>
                            setState(() => _buttonPressed = false),
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 20,
                                color: scheme.onPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Entrar a Ailoviu',
                                style: theme.textTheme.labelLarge?.copyWith(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _closingMessage(List<String> names) {
    final namesLabel = names.isEmpty
        ? ''
        : names.length == 1
            ? names.first
            : names.length == 2
                ? '${names[0]} y ${names[1]}'
                : '${names.sublist(0, names.length - 1).join(', ')} y '
                    '${names.last}';

    return namesLabel.isEmpty
        ? 'Este es el espacio de ustedes. Lo que compartan viaja cifrado, '
            'y nadie más puede leerlo. Ni siquiera nosotros.'
        : 'Este es el espacio de $namesLabel. Lo que compartan viaja '
            'cifrado, y nadie más puede leerlo. Ni siquiera nosotros.';
  }
}

// ══════════════════════════════════════════════════════════════════════
// _NamesRow — píldoras tonales para cada integrante
// ══════════════════════════════════════════════════════════════════════

class _NamesRow extends StatelessWidget {
  final List<String> names;

  const _NamesRow({required this.names});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < names.length; i++) ...[
          if (i > 0)
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_rounded,
                size: 12,
                color: scheme.onPrimaryContainer,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                scheme.primaryContainer.withValues(alpha: 0.35),
                scheme.surfaceContainerHigh,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              names[i],
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// _DaysChip — geometría unificada a 16px
// ══════════════════════════════════════════════════════════════════════

class _DaysChip extends StatelessWidget {
  final DateTime startDate;

  const _DaysChip({required this.startDate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final days = DateTime.now().difference(startDate).inDays;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            '$days ${days == 1 ? 'día' : 'días'} juntos',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}