import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/onboarding_providers.dart';
import 'onboarding_scaffold.dart';
import 'settings_components.dart';

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
      step: OnboardingStep.role,
      customStepNumber: 2, 
      showSkip: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          
          Center(
            child: AnimatedBuilder(
              animation: _heartController,
              builder: (context, child) {
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
                          color: scheme.primary.withValues(alpha: 0.2),
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
            'Para que el espacio sea el mismo para todas las personas, '
            'solo una necesita configurar todo. Quien no configure, '
            'solo escaneará un código.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TonalMicroHeader(
                  icon: Icons.rocket_launch_rounded,
                  title: 'Vamos a configurar 4 cosas',
                  description:
                      'Toma unos 10 minutos. Puedes saltarte los pasos que '
                      'quieras y hacerlos después desde Ajustes.',
                ),
                const SizedBox(height: 18),
                _CheckBullet(text: 'Definir los nombres y la fecha de inicio'),
                const SizedBox(height: 12),
                _CheckBullet(text: 'Elegir el mapa para ver dónde están'),
                const SizedBox(height: 12),
                _CheckBullet(text: 'Conectar Firebase para que sea privado'),
                const SizedBox(height: 12),
                _CheckBullet(text: 'Mostrar el QR para vincular los dispositivos'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _RoleCard(
            icon: Icons.settings_suggest_rounded,
            title: 'Yo',
            subtitle: 'Soy quien configura el espacio de la relación.',
            onTap: widget.onHostSelected,
            isPrimary: true,
            badgeText: 'Configuración completa',
          ),
          const SizedBox(height: 16),
          _RoleCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Me invitaron',
            subtitle: 'Solo escaneo el código para unirme.',
            onTap: widget.onGuestSelected,
            isPrimary: false,
          ),
        ],
      ),
    );
  }
}

class _CheckBullet extends StatelessWidget {
  final String text;

  const _CheckBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.badgeText != null) ...[
                Container(
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
                const SizedBox(height: 12),
              ],
              Row(
                children: [
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(
                      _pressed ? 4.0 : 0.0,
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
            ],
          ),
        ),
      ),
    );
  }
}