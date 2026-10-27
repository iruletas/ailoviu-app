import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'calendar_screen.dart';
import 'connection_screen.dart';
import 'play_screen.dart';
import 'settings_screen.dart';

// ── Layout ────────────────────────────────────────────────────────────────
const double _kBarMaxWidth = 480.0;
const double _kBarHeight = 64.0;
const double _kBarHorizontalMargin = 16.0;
const double _kBarTopMargin = 8.0;
const double _kBarBorderRadius = 32.0;
const double _kButtonBorderRadius = 28.0;
const double _kIconSize = 24.0;

const double _kSettingsPillWidth = 56.0;
const double _kSettingsPillHeight = 44.0;
const double _kSettingsPillGap = 10.0;

// ── Animación ─────────────────────────────────────────────────────────────
const Duration _kTabTransitionBase = Duration(milliseconds: 250);
const Duration _kWidthAnimDuration = Duration(milliseconds: 300);
const Duration _kLabelAnimDuration = Duration(milliseconds: 220);
const Duration _kIconScaleDuration = Duration(milliseconds: 260);
const Duration _kPressScaleDuration = Duration(milliseconds: 120);

/// Cambia a true para ver el micro-indicador pulsante del botón de ajustes.
/// Cuando exista un provider de "novedades" o "cuenta", se conecta aquí.
const bool kShowSettingsBadge = false;

class _NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

const List<_NavDestination> _kNavDestinations = [
  _NavDestination(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Inicio',
  ),
  _NavDestination(
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Calendario',
  ),
  _NavDestination(
    icon: Icons.mail_outline_rounded,
    activeIcon: Icons.mark_chat_unread_rounded,
    label: 'Mensajes',
  ),
  _NavDestination(
    icon: Icons.sports_esports_outlined,
    activeIcon: Icons.sports_esports_rounded,
    label: 'Juegos',
  ),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final PageController _pageController =
      PageController(initialPage: _currentIndex);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    final distance = (index - _currentIndex).abs();
    if (distance == 1) {
      _pageController.animateToPage(
        index,
        duration: _kTabTransitionBase,
        curve: Curves.easeInOutCubic,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      HomeScreen(),
      CalendarScreen(),
      ConnectionScreen(),
      PlayScreen(),
    ];

    final safeTop = MediaQuery.viewPaddingOf(context).top;
    final navbarTop = safeTop + _kBarTopMargin;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: navbarTop + _kBarHeight + _kBarTopMargin,
              ),
              child: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (i) {
                  if (i != _currentIndex) setState(() => _currentIndex = i);
                },
                children: [
                  for (final page in pages) _KeepAliveWrapper(child: page),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: navbarTop,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kBarHorizontalMargin,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: _kBarMaxWidth),
                        child: _ExpressiveNavBar(
                          currentIndex: _currentIndex,
                          onSelect: _onTabSelected,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _kSettingsPillGap),
                  _SettingsCapsule(
                    onPressed: _openSettings,
                    showBadge: kShowSettingsBadge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navbar flotante tipo pastilla ────────────────────────────────────────
class _ExpressiveNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  const _ExpressiveNavBar({required this.currentIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_kBarBorderRadius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kBarBorderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: _kBarHeight,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.78),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(_kBarBorderRadius),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final activeWidth = totalWidth * 0.5;
                final inactiveWidth = (totalWidth - activeWidth) /
                    (_kNavDestinations.length - 1);
                return Row(
                  children: [
                    for (int i = 0; i < _kNavDestinations.length; i++)
                      _NavButton(
                        destination: _kNavDestinations[i],
                        isActive: i == currentIndex,
                        onTap: () => onSelect(i),
                        activeWidth: activeWidth,
                        inactiveWidth: inactiveWidth,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final _NavDestination destination;
  final bool isActive;
  final VoidCallback onTap;
  final double activeWidth;
  final double inactiveWidth;

  const _NavButton({
    required this.destination,
    required this.isActive,
    required this.onTap,
    required this.activeWidth,
    required this.inactiveWidth,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = widget.isActive;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: _kPressScaleDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: _kWidthAnimDuration,
          curve: Curves.easeOutCubic,
          width: isActive ? widget.activeWidth : widget.inactiveWidth,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(_kButtonBorderRadius),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isActive ? 1.15 : 1.0,
                  duration: _kIconScaleDuration,
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isActive
                        ? widget.destination.activeIcon
                        : widget.destination.icon,
                    size: _kIconSize,
                    semanticLabel: widget.destination.label,
                    color: isActive
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                AnimatedSize(
                  duration: _kLabelAnimDuration,
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    duration: _kLabelAnimDuration,
                    curve: Curves.easeOut,
                    opacity: isActive ? 1.0 : 0.0,
                    child: isActive
                        ? Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              widget.destination.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
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

// ── Botón de Ajustes: cápsula flotante M3E ────────────────────────────────
class _SettingsCapsule extends StatefulWidget {
  final VoidCallback onPressed;
  final bool showBadge;
  const _SettingsCapsule({
    required this.onPressed,
    this.showBadge = false,
  });

  @override
  State<_SettingsCapsule> createState() => _SettingsCapsuleState();
}

class _SettingsCapsuleState extends State<_SettingsCapsule>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.showBadge) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SettingsCapsule old) {
    super.didUpdateWidget(old);
    if (widget.showBadge && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.showBadge && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: _kPressScaleDuration,
        curve: Curves.easeOutCubic,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              shape: StadiumBorder(
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              color: colorScheme.tertiaryContainer,
              child: SizedBox(
                width: _kSettingsPillWidth,
                height: _kSettingsPillHeight,
                child: Center(
                  child: Icon(
                    Icons.settings_rounded,
                    size: 22,
                    semanticLabel: 'Ajustes',
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
            if (widget.showBadge)
              Positioned(
                top: -2,
                right: -2,
                child: _PulsingBadge(controller: _pulseController),
              ),
          ],
        ),
      ),
    );
  }
}

class _PulsingBadge extends StatelessWidget {
  final AnimationController controller;
  const _PulsingBadge({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final glow = 4 + (t * 6);
        final opacity = 0.4 + (t * 0.6);
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.error,
            boxShadow: [
              BoxShadow(
                color: colorScheme.error.withValues(alpha: opacity * 0.6),
                blurRadius: glow,
                spreadRadius: glow * 0.4,
              ),
            ],
            border: Border.all(
              color: colorScheme.surface,
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});
  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}