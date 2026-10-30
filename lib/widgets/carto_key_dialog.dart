import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/map_key_provider.dart';

class CartoKeyDialog extends ConsumerStatefulWidget {
  const CartoKeyDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        // Fondo de cristal esmerilado
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: const CartoKeyDialog(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Entrada elástica (Spring Scale-Fade)
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubicEmphasized,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<CartoKeyDialog> createState() => _CartoKeyDialogState();
}

class _CartoKeyDialogState extends ConsumerState<CartoKeyDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isFocused = false;
  String _initialKey = '';

  @override
  void initState() {
    super.initState();
    _initialKey = ref.read(cartoKeyProvider);
    _controller = TextEditingController(text: _initialKey);
    _focusNode = FocusNode();
    
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    await ref.read(cartoKeyProvider.notifier).setKey(_controller.text);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _paste() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      _controller.text = data.text!;
    }
  }

  Future<void> _openCarto() async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse('https://carto.com/basemaps/apikey');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el navegador'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasText = _controller.text.isNotEmpty;
    final hasChanged = _controller.text != _initialKey;

    // Evitamos que el diálogo ocupe toda la pantalla
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Header
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.key_rounded,
                  size: 28,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'API Key de CARTO',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),

              // 2. Tarjeta Informativa Bento
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pega tu clave para activar el estilo de mapa limpio. '
                      'Si la dejas vacía, se usará OpenStreetMap por defecto.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _openCarto,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Obtener clave en carto.com'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: theme.textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Campo de Entrada
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isFocused ? scheme.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.vpn_key_rounded,
                      color: _isFocused ? scheme.primary : scheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          hintText: 'eyJhbGci...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    // Botón de pegar / limpiar
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: hasText
                          ? IconButton(
                              key: const ValueKey('clear'),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _controller.clear();
                              },
                              icon: const Icon(Icons.clear_rounded),
                              visualDensity: VisualDensity.compact,
                            )
                          : IconButton(
                              key: const ValueKey('paste'),
                              onPressed: _paste,
                              icon: const Icon(Icons.content_paste_rounded),
                              tooltip: 'Pegar',
                              visualDensity: VisualDensity.compact,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Botones de Acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                        backgroundColor: scheme.surfaceContainerHighest,
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedScale(
                      scale: hasChanged ? 1.0 : 0.96,
                      duration: const Duration(milliseconds: 200),
                      child: FilledButton.icon(
                        onPressed: hasChanged ? _save : null, // Solo guarda si cambió
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Guardar'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                        ),
                      ),
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