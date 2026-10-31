import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_models.dart';
import '../providers/sync_providers.dart';
import '../services/linking_service.dart';
import '../services/transport_config.dart';
import 'map_feedback.dart';
import 'settings_components.dart';

class FirebaseTile extends ConsumerWidget {
  const FirebaseTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final transportAsync = ref.watch(transportConfigProvider);
    final hasConfig = transportAsync.valueOrNull?.isConfigured ?? false;

    final bubbleBg =
        hasConfig ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final bubbleFg = hasConfig
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;

    return SettingsGroupCard(
      child: SettingsTileExpressive(
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: hasConfig
                ? [
                    BoxShadow(
                      color: scheme.tertiary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              hasConfig ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              key: ValueKey(hasConfig),
              size: 20,
              color: bubbleFg,
            ),
          ),
        ),
        title: 'Firebase',
        subtitle: hasConfig
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  MiniChip(
                    label: 'Configurado',
                    background: scheme.tertiaryContainer,
                    foreground: scheme.onTertiaryContainer,
                    bold: true,
                  ),
                ],
              )
            : MiniChip(
                label: 'Sin configurar',
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
              ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant,
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          _FirebaseConfigSheet.show(context);
        },
      ),
    );
  }
}

class _FirebaseConfigSheet extends ConsumerStatefulWidget {
  const _FirebaseConfigSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: const _FirebaseConfigSheet(),
      ),
    );
  }

  @override
  ConsumerState<_FirebaseConfigSheet> createState() =>
      _FirebaseConfigSheetState();
}

class _FirebaseConfigSheetState extends ConsumerState<_FirebaseConfigSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _focused = false;
  bool _saving = false;
  bool _expanded = false;
  bool _hasExisting = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final cfg = await ref.read(keyStoreProvider).getTransportConfig();
    if (!mounted) return;
    setState(() {
      _hasExisting = cfg != null;
      _expanded = cfg == null;
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
    if (data?.text != null) {
      _controller.text = data!.text!;
      setState(() => _inlineError = null);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _inlineError = 'Pega el contenido de google-services.json');
      return;
    }

    setState(() {
      _saving = true;
      _inlineError = null;
    });

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('El JSON debe ser un objeto');
      }
      final config = FirebaseTransportConfig.fromGoogleServicesJson(
        Map<String, dynamic>.from(decoded),
      );

      await ref.read(keyStoreProvider).setTransportConfig(config.toJson());

      // Propagar a peers si soy host.
      final group = await ref.read(linkingServiceProvider).snapshot();
      if (group.isHost && group.approvedPeerDeviceIds.isNotEmpty) {
        try {
          final sync = await ref.read(syncServiceProvider.future);
          await sync.enqueue(
            type: SyncType.hostCredentials,
            payload: {'config': config.toJson()},
          );
        } catch (_) {}
      }

      ref.invalidate(transportConfigProvider);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      MapFeedback.showSuccess(context, 'Firebase configurado');
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _inlineError = 'JSON inválido: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _inlineError = 'No se pudo configurar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: 24,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Firebase',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hasExisting && !_expanded
                              ? 'Ya está configurado. Puedes reconfigurarlo.'
                              : 'Pega el contenido completo de tu google-services.json.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_hasExisting && !_expanded) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Firebase configurado en este dispositivo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _expanded = true;
                      _inlineError = null;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reconfigurar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                ),
              ] else ...[
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _paste,
                            icon: const Icon(
                              Icons.content_paste_rounded,
                              size: 16,
                            ),
                            label: const Text('Pegar'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _inlineError == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer
                                      .withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 16,
                                      color: scheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _inlineError!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
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
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                          backgroundColor: scheme.surfaceContainerHighest,
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(
                            color:
                                scheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  strokeCap: StrokeCap.round,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_saving ? 'Guardando…' : 'Guardar'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}