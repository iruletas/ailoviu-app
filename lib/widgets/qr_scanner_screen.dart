import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'tonal_back_button.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController();
  late final AnimationController _laserController;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _laserController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    const frameSize = 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_handled) return;
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code == null) return;
              _handled = true;
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(code);
            },
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    TonalBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Escanear QR',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: SizedBox(
              width: frameSize,
              height: frameSize,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.9),
                        width: 3,
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, _) {
                        final t = _laserController.value;
                        return Align(
                          alignment: Alignment(0, t * 2 - 1),
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  scheme.primary.withValues(alpha: 0),
                                  scheme.primary,
                                  scheme.primary.withValues(alpha: 0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _FlashToggleButton(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashToggleButton extends StatefulWidget {
  final MobileScannerController controller;
  const _FlashToggleButton({required this.controller});

  @override
  State<_FlashToggleButton> createState() => _FlashToggleButtonState();
}

class _FlashToggleButtonState extends State<_FlashToggleButton> {
  bool _on = false;
  bool _pressed = false;

  Future<void> _toggle() async {
    await HapticFeedback.lightImpact();
    try {
      await widget.controller.toggleTorch();
      if (mounted) setState(() => _on = !_on);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _toggle,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: _on
                ? scheme.primaryContainer
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _on
                    ? Icons.flashlight_on_rounded
                    : Icons.flashlight_off_rounded,
                size: 18,
                color: _on ? scheme.onPrimaryContainer : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'Linterna',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _on ? scheme.onPrimaryContainer : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}