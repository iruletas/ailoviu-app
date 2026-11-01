import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';
import '../services/transport_config.dart';
import 'settings_components.dart';

class FirebaseCredentialsCard extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  final bool initiallyConfigured;

  const FirebaseCredentialsCard({
    super.key,
    required this.onSaved,
    this.initiallyConfigured = false,
  });

  @override
  ConsumerState<FirebaseCredentialsCard> createState() =>
      _FirebaseCredentialsCardState();
}

class _FirebaseCredentialsCardState
    extends ConsumerState<FirebaseCredentialsCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _focused = false;
  bool _busy = false;
  String? _inlineError;
  bool _expandedTutorial = false;
  bool _copiedPackage = false;

  static const String _packageName = 'com.iruletas.ailoviu';
  static const String _consoleUrl = 'console.firebase.google.com';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
    if (widget.initiallyConfigured) _preloadExisting();
  }

  Future<void> _preloadExisting() async {
    final raw = await ref.read(keyStoreProvider).getTransportConfig();
    if (!mounted || raw == null) return;
    setState(() {
      _controller.text = const JsonEncoder.withIndent('  ').convert(raw);
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

  Future<void> _copyToClipboard(String text, {required bool isPackage}) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    
    if (isPackage) {
      setState(() => _copiedPackage = true);
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _copiedPackage = false);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enlace copiado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _inlineError =
          'Pega primero el contenido del google-services.json.');
      return;
    }
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('El archivo debe ser un objeto JSON.');
      }
      final config = FirebaseTransportConfig.fromGoogleServicesJson(
        Map<String, dynamic>.from(decoded),
      );
      await ref.read(keyStoreProvider).setTransportConfig(config.toJson());
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _busy = false);
      widget.onSaved();
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _inlineError =
            'El JSON no es válido: ${e.message}. Revisa que hayas copiado '
            'el archivo completo, sin cortar líneas.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _inlineError =
            'No se pudo guardar. Revisa que el archivo sea exactamente el '
            'que Firebase te descargó, sin modificar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasText = _controller.text.trim().isNotEmpty;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TonalMicroHeader(
            icon: Icons.local_fire_department_rounded,
            title: 'Credenciales de Firebase',
            description:
                'Pega aquí el contenido del archivo google-services.json.',
          ),
          const SizedBox(height: 16),

          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _focused ? scheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: 6,
                  minLines: 4,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  decoration: const InputDecoration(
                    hintText: '{\n  "project_info": { ... }\n}',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() => _inlineError = null),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: _ActionChip(
                    key: ValueKey(hasText ? 'clear' : 'paste'),
                    icon: hasText
                        ? Icons.clear_rounded
                        : Icons.content_paste_rounded,
                    label: hasText ? 'Limpiar' : 'Pegar',
                    onTap: hasText ? _clear : _paste,
                  ),
                ),
              ],
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _inlineError == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, -8 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.errorContainer.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(width: 10),
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
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _busy ? null : _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _busy ? null : _save,
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: _busy
                          ? SizedBox(
                              key: const ValueKey('busy'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                strokeCap: StrokeCap.round,
                                color: scheme.onPrimary,
                              ),
                            )
                          : Row(
                              key: const ValueKey('label'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: scheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Validar y guardar',
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(
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
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.android_rounded,
                    size: 16,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Package name',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _packageName,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copyToClipboard(_packageName, isPackage: true),
                  child: AnimatedScale(
                    scale: _copiedPackage ? 0.9 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _copiedPackage
                            ? scheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                        child: Icon(
                          _copiedPackage
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          key: ValueKey(_copiedPackage),
                          size: 16,
                          color: _copiedPackage
                              ? scheme.onPrimaryContainer
                              : scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _TutorialSection(
            expanded: _expandedTutorial,
            onToggle: () {
              HapticFeedback.lightImpact();
              setState(() => _expandedTutorial = !_expandedTutorial);
            },
            packageName: _packageName,
            onCopyPackageName: () => _copyToClipboard(_packageName, isPackage: true),
            onCopyConsoleUrl: () => _copyToClipboard(_consoleUrl, isPackage: false),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
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

class _TutorialSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final String packageName;
  final VoidCallback onCopyPackageName;
  final VoidCallback onCopyConsoleUrl;

  const _TutorialSection({
    required this.expanded,
    required this.onToggle,
    required this.packageName,
    required this.onCopyPackageName,
    required this.onCopyConsoleUrl,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: expanded
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¿Cómo obtengo este archivo?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          height: 1,
                          color: scheme.outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 14),
                        _TutorialStep(
                          number: 1,
                          title: 'Entra a Firebase Console',
                          body:
                              'Abre console.firebase.google.com en tu navegador.',
                          trailing: _PackageCopyChip(
                            label: 'Copiar link',
                            onCopy: onCopyConsoleUrl,
                          ),
                        ),
                        _TutorialStep(
                          number: 2,
                          title: 'Activa "Sitio de escritorio"',
                          body:
                              'En tu navegador, toca los 3 puntos ⋮ y activa '
                              '"Sitio de escritorio". Firebase Console se ve '
                              'incompleto desde el celular sin esto, así que '
                              'asegúrate de hacerlo antes de crear el proyecto.',
                        ),
                        _TutorialStep(
                          number: 3,
                          title: 'Crea el proyecto',
                          body:
                              'Toca "Para comenzar, configura un proyecto de '
                              'Firebase". Ponle el nombre que quieras.',
                        ),
                        _TutorialStep(
                          number: 4,
                          title: 'Gemini y Google Analytics',
                          body:
                              'Te preguntará si quieres habilitar Gemini y '
                              'Google Analytics. Desactiva ambos, no los '
                              'necesitas.',
                        ),
                        _TutorialStep(
                          number: 5,
                          title: 'Crea la Realtime Database',
                          body:
                              'Abre el menú desplegable con el icono > en la '
                              'parte inferior izquierda > Bases de datos y '
                              'almacenamiento > Realtime Database > Crear base '
                              'de datos. Elige la ubicación más cercana y '
                              'selecciona "Comenzar en modo bloqueado".',
                        ),
                        _TutorialStep(
                          number: 6,
                          title: 'Habilita la autenticación',
                          body:
                              'Abre el menú desplegable > > Seguridad > '
                              'Authentication > Comenzar. En la lista de '
                              'proveedores, selecciona "Anónimo" y actívalo.',
                        ),
                        _TutorialStep(
                          number: 7,
                          title: 'Agrega una app Android',
                          body:
                              'Abre el menú desplegable > > Descripción '
                              'general del proyecto. Toca "Agregar app" y elige '
                              'el ícono de Android. Pon el package name de aquí '
                              'debajo y registra la app.',
                          trailing: _PackageCopyChip(
                            label: packageName,
                            onCopy: onCopyPackageName,
                          ),
                        ),
                        _TutorialStep(
                          number: 8,
                          title: 'Descarga el archivo',
                          body:
                              'En el paso 2 presiona "Descargar '
                              'google-services.json" y luego presiona '
                              '"Siguiente" ahí y en el paso 3, después "Ir a '
                              'la consola".',
                        ),
                        _TutorialStep(
                          number: 9,
                          title: 'Copia el contenido',
                          body:
                              'Abre el archivo descargado, selecciona todo, '
                              'copia y vuelve a la app para pegarlo en el '
                              'campo y tocar "Validar y guardar".',
                        ),
                        _TutorialStep(
                          number: 10,
                          title: 'Pega las reglas',
                          body:
                              'En la app, vuelve a la pantalla anterior y '
                              'copia las reglas. Luego ve a Firebase Console '
                              '> Realtime Database > Reglas, borra lo que '
                              'haya y pega las reglas. Toca "Publicar".',
                          isLast: true,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _PackageCopyChip extends StatefulWidget {
  final String label;
  final VoidCallback onCopy;

  const _PackageCopyChip({
    required this.label,
    required this.onCopy,
  });

  @override
  State<_PackageCopyChip> createState() => _PackageCopyChipState();
}

class _PackageCopyChipState extends State<_PackageCopyChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onCopy,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.copy_rounded,
                size: 12,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialStep extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  final Widget? trailing;
  final bool isLast;

  const _TutorialStep({
    required this.number,
    required this.title,
    required this.body,
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
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(1),
                    ),
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
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 8),
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