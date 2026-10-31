import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/map_key_provider.dart';
import '../providers/sync_providers.dart';
import '../widgets/carto_key_dialog.dart';
import '../widgets/firebase_tile.dart';
import '../widgets/linking_tile.dart';
import '../widgets/map_tiles.dart';
import '../widgets/network_status_hero.dart';
import '../widgets/recovery_question_tile.dart';
import '../widgets/settings_components.dart';
import '../widgets/tonal_back_button.dart';

class InfrastructureScreen extends ConsumerWidget {
  const InfrastructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final hasKey = ref.watch(cartoKeyProvider).isNotEmpty;
    final transportAsync = ref.watch(transportConfigProvider);
    final hasFirebase = transportAsync.valueOrNull?.isConfigured ?? false;

    final activeServices = (hasKey ? 1 : 0) + (hasFirebase ? 1 : 0);
    const totalServices = 2;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: TonalBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: Text(
              'Conexiones',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                NetworkStatusHero(
                  active: activeServices,
                  total: totalServices,
                ),
                const SizedBox(height: 24),
                
                const SectionLabel('Vinculación'),
                const SizedBox(height: 8),
                const LinkingTile(),
                const SizedBox(height: 24),
                
                const SectionLabel('Geolocalización'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  child: SettingsTileExpressive(
                    leading: const MapLeading(),
                    title: 'Mapa',
                    subtitle: const MapSubtitle(),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasKey)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: scheme.tertiary,
                              size: 18,
                            ),
                          ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      CartoKeyDialog.show(context);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                
                const SectionLabel('Sincronización y respaldo'),
                const SizedBox(height: 8),
                const FirebaseTile(),
                const SizedBox(height: 24),
                
                const SectionLabel('Recuperación'),
                const SizedBox(height: 8),
                const RecoveryQuestionTile(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}