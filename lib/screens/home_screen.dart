import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/relationship_providers.dart';
import '../widgets/buzz_button.dart';
import '../widgets/days_together_card.dart';
import '../widgets/home_map_hero.dart';
import '../widgets/menstruation_preview_card.dart';
import '../widgets/next_event_card.dart';
import '../widgets/status_editor_sheet.dart';

/// Pestaña "Hogar".
///
/// Dashboard que se abre al entrar. Muestra:
/// - Mapa hero con avatares, líneas y badge "＋" de estado.
/// - Días juntos (con badge festivo en aniversarios/hitos).
/// - Próximo día especial (placeholder).
/// - Menstruación (placeholder).
/// - Buzz flotante en la esquina superior izquierda.
///
/// No navega a features: solo muestra el estado actual.
///
/// NOTA sobre padding: el `main_shell.dart` ya reserva el espacio de
/// la navbar flotante con `Padding(bottom: bottomReserved)` alrededor
/// del `PageView`. Este widget NO debe volver a reservar ese espacio.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Alto del BuzzButton + separación, para que el mapa no se choque
  /// con el botón flotante. El BuzzButton mide ~56px; dejamos 72px
  /// de espacio total (56 + 8 de gap + 8 de margen superior).
  static const double _kBuzzReservedHeight = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationship = ref.watch(relationshipProvider);

    return Stack(
      children: [
        // ── Contenido scrollable ────────────────────────────────────
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Mapa hero — top reservado para el BuzzButton.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    _kBuzzReservedHeight,
                    16,
                    0,
                  ),
                  child: HomeMapHero(
                    onEditStatus: () => StatusEditorSheet.show(context),
                  ),
                ),
              ),

              // Fila Bento: días juntos + próximo evento.
              // IntrinsicHeight iguala la altura de ambas cards para
              // que los bordes inferiores coincidan al píxel.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DaysTogetherCard(
                            startDate: relationship.startDate,
                            onTap: () {
                              // TODO: navegar a RelationshipScreen cuando
                              // exista el flujo "editar fecha desde Hogar".
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: NextEventCard(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Menstruación (placeholder).
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: MenstruationPreviewCard(),
                ),
              ),
            ],
          ),
        ),

        // ── Buzz flotante arriba a la izquierda ─────────────────────
        // Sin DecoratedBox alrededor: el BuzzButton ya tiene su propio
        // squircle opaco con glow. Envolverlo en un círculo extra rompe
        // su geometría y crea una "doble caja" visual.
        Positioned(
          top: 0,
          left: 16,
          child: SafeArea(
            bottom: false,
            child: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: BuzzButton(),
            ),
          ),
        ),
      ],
    );
  }
}