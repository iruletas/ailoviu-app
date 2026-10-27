import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/play/play_screen.dart';
import 'features/settings/settings_screen.dart';

// ── Layout ────────────────────────────────────────────────────────────────
const double _kBarMaxWidth = 480.0;
const double _kBarHeight = 64.0;
const double _kBarHorizontalMargin = 16.0;
const double _kBarTopMargin = 8.0;
const double _kBarBorderRadius = 32.0;
const double _kButtonBorderRadius = 28.0;
const double _kIconSize = 24.0;

const double _kSettingsFabSize = 48.0;
const double _kSettingsFabGap = 12.0;

// ── Animación ─────────────────────────────────────────────────────────────
const Duration _kTabTransitionBase = Duration(milliseconds: 250);
const Duration _kWidthAnimDuration = Duration(milliseconds: 300);
const Duration _kLabelAnimDuration = Duration(milliseconds: 220);

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
    activeIcon: Icons.calendar_today_rounded,
    label: 'Calendario',
  ),
  _NavDestination(
    icon: Icons.chat_bubble_outline_rounded,
    activeIcon: Icons.chat_bubble_rounded,
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
      MessagesScreen(),
      PlayScreen(),
    ];

    // viewPaddingOf no depende del teclado (a diferencia de .padding).
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    final navbarTop = safeTop + _kBarTopMargin;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Contenido con padding superior para no quedar bajo la navbar.
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

          // Navbar flotante arriba.
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
                  const SizedBox(width: _kSettingsFabGap),
                  _SettingsFab(onPressed: _openSettings),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _SettingsFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kSettingsFabSize / 2),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      color: colorScheme.surfaceContainerHigh,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: _kSettingsFabSize,
          height: _kSettingsFabSize,
          child: Icon(
            Icons.settings_outlined,
            size: 22,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

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
      borderRadius: BorderRadius.circular(_kBarBorderRadius),
      color: colorScheme.surfaceContainerHigh,
      child: Container(
        height: _kBarHeight,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
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
            final inactiveWidth =
                (totalWidth - activeWidth) / (_kNavDestinations.length - 1);
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
    );
  }
}

class _NavButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: _kWidthAnimDuration,
      curve: Curves.easeOutCubic,
      width: isActive ? activeWidth : inactiveWidth,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(_kButtonBorderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kButtonBorderRadius),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? destination.activeIcon : destination.icon,
                  size: _kIconSize,
                  color: isActive
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
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
                              destination.label,
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