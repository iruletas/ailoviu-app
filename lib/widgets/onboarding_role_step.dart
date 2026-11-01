import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/onboarding_providers.dart';
import 'onboarding_scaffold.dart';

/// Paso 0: Selector de rol (Anfitrión / Invitado).
class OnboardingRoleStep extends StatefulWidget {
  final VoidCallback onHostSelected;
  final VoidCallback onGuestSelected;

  const OnboardingRoleStep({
    super.key,
    required this.onHostSelected,
    required this.onGuestSelected,
  });

  @override
  State<OnboardingRoleStep> createState() => _OnboardingRoleStepState();
}

class _OnboardingRoleStepState extends State<OnboardingRoleStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _heartScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: Curves.easeInOutCubicEmphasized,
      ),
    );

    _glowOpacity = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return OnboardingScaffold(
      step: OnboardingStep.welcome,
      showSkip: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          
          // ── Hero Central con Latido ────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _heartController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Gradiente radial tenue de fondo
                    Opacity(
                      opacity: _glowOpacity.value,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              scheme.primaryContainer,
                              scheme.primaryContainer.withValues(alpha: 0.0),
                            ],
                            stops: const [0.2, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Corazón con latido
                    Transform.scale(
                      scale: _heartScale.value,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 44,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 28),
          Text(
            '¿Quién configura la app?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Para que ambos tengan el mismo espacio, solo uno necesita '
            'configurar todo. El otro solo escanea un código.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          _RoleCard(
            icon: Icons.settings_suggest_rounded,
            title: 'Yo',
            subtitle: 'Voy a configurar la relación, el mapa y Firebase.',
            onTap: widget.onHostSelected,
            isPrimary: true,
            badgeText: 'Configuración completa',
          ),
          const SizedBox(height: 16),
          _RoleCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Mi pareja',
            subtitle: 'Solo voy a escanear el código que me muestre.',
            onTap: widget.onGuestSelected,
            isPrimary: false,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;
  final String? badgeText;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isPrimary,
    this.badgeText,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final bg = widget.isPrimary
        ? scheme.primaryContainer
        : scheme.surfaceContainerLow;
    
    final fg = widget.isPrimary
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
        
    final borderColor = widget.isPrimary
        ? scheme.primary.withValues(alpha: 0.3)
        : scheme.outlineVariant.withValues(alpha: 0.25);

    final iconBg = widget.isPrimary
        ? scheme.primary
        : scheme.secondaryContainer;
        
    final iconFg = widget.isPrimary
        ? scheme.onPrimary
        : scheme.onSecondaryContainer;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  // ── Squircle Reactivo ──────────────────────────────
                  AnimatedScale(
                    scale: _pressed ? 1.12 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: widget.isPrimary
                            ? [
                                BoxShadow(
                                  color: scheme.primary
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(widget.icon, size: 26, color: iconFg),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Cápsula de Flecha Animada ──────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(
                      _pressed ? 4.0 : 0.0, // Micro-desplazamiento
                      0,
                      0,
                    ),
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.isPrimary
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.12)
                          : scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: fg,
                    ),
                  ),
                ],
              ),
              if (widget.badgeText != null)
                Positioned(
                  top: -8,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.badgeText!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}