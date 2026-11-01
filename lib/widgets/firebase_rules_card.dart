import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_components.dart';

/// Muestra las reglas de Firebase como code block tonal y permite
/// copiarlas. Lee `assets/firebase_rules.json` con `rootBundle`.
class FirebaseRulesCard extends StatefulWidget {
  const FirebaseRulesCard({super.key});

  @override
  State<FirebaseRulesCard> createState() => _FirebaseRulesCardState();
}

class _FirebaseRulesCardState extends State<FirebaseRulesCard> {
  String? _rules;
  bool _copied = false;

  static const String _assetPath = 'assets/firebase_rules.json';
  static const String _consoleUrl =
      'https://console.firebase.google.com/project/_/database/rules';

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final text = await rootBundle.loadString(_assetPath);
      if (mounted) setState(() => _rules = text);
    } catch (_) {
      if (mounted) setState(() => _rules = null);
    }
  }

  Future<void> _copyRules() async {
    if (_rules == null) return;
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: _rules!));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _openConsole() async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(_consoleUrl);
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

    final lineCount = _rules?.split('\n').length ?? 0;
    final codeBg = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.06),
      scheme.surfaceContainerLowest,
    );
    final codeFg = scheme.onSurface;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TonalMicroHeader(
            icon: Icons.security_rounded,
            title: 'Reglas de seguridad',
            description:
                'Estas reglas son las que impiden que nadie más entre a '
                'tus datos. Solo tú y tu pareja tienen llave.',
          ),
          const SizedBox(height: 16),

          // ── Code block tonal con barra tipo terminal ──────────────
          Container(
            decoration: BoxDecoration(
              color: codeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Barra tipo terminal.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'firebase_rules.json',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'JSON',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$lineCount líneas',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Código.
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(14),
                  child: _rules == null
                      ? Center(
                          child: Text(
                            'No se pudo cargar firebase_rules.json',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _rules!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.5,
                              color: codeFg,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Botón copiar con morph a tertiary ─────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _rules == null ? null : _copyRules,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              height: 48,
              decoration: BoxDecoration(
                color: _copied
                    ? scheme.tertiaryContainer
                    : scheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _rules == null ? null : _copyRules,
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Row(
                        key: ValueKey(_copied),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied
                                ? Icons.check_rounded
                                : Icons.copy_rounded,
                            size: 18,
                            color: _copied
                                ? scheme.onTertiaryContainer
                                : scheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _copied ? 'Copiadas' : 'Copiar reglas',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: _copied
                                  ? scheme.onTertiaryContainer
                                  : scheme.onPrimary,
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
          const SizedBox(height: 10),

          // ── Botón Console tonal ───────────────────────────────────
          FilledButton.tonalIcon(
            onPressed: _openConsole,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Abrir Firebase Console'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
          ),
          const SizedBox(height: 14),

          // ── Instrucciones con icono en cápsula ────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.info_outline_rounded,
                    size: 16,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'En Firebase Console, ve a Realtime Database → Reglas, '
                    'pega el texto copiado y toca "Publicar". Sin esto, la '
                    'app no puede escribir en Firebase.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      height: 1.4,
                    ),
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