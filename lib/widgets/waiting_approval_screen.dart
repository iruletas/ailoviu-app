import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';
import '../providers/sync_providers.dart';

class WaitingApprovalScreen extends ConsumerStatefulWidget {
  const WaitingApprovalScreen({super.key});

  @override
  ConsumerState<WaitingApprovalScreen> createState() =>
      _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends ConsumerState<WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Revisión inicial por si ya está aprobado cuando entra.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkApproved());
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  /// Cierra la pantalla si el guest ya fue aprobado.
  void _checkApproved() {
    if (!mounted || _popped) return;
    final myId = ref.read(myDeviceIdProvider).valueOrNull ?? '';
    final group = ref.read(groupSnapshotProvider).valueOrNull;
    if (group == null || myId.isEmpty) return;
    final me = group.members[myId];
    if (me != null && me.approved) {
      _popped = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final myId = ref.watch(myDeviceIdProvider).valueOrNull ?? '';

    // Escucha cambios en el snapshot. Cuando el host aprueba, el
    // SyncRouter invalida el provider, llega un valor nuevo con
    // me.approved = true, y esta pantalla se cierra sola.
    ref.listen(groupSnapshotProvider, (prev, next) {
      if (_popped) return;
      final group = next.valueOrNull;
      if (group == null || myId.isEmpty) return;
      final me = group.members[myId];
      if (me != null && me.approved) {
        _popped = true;
        if (mounted) Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: AnimatedBuilder(
                    animation: _radarController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _RadarPainter(
                          color: scheme.primary,
                          t: _radarController.value,
                        ),
                        child: Center(
                          child: Container(
                            width: 96,
                            height: 96,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Icon(
                              Icons.hourglass_top_rounded,
                              size: 44,
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Esperando aprobación',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu amor tiene que aprobar tu entrada. '
                  'En cuanto lo haga, esta pantalla se cierra sola.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Color color;
  final double t;

  _RadarPainter({required this.color, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = maxRadius * phase;
      final opacity = (1.0 - phase) * 0.35;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t;
}