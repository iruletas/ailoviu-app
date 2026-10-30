// ... (imports anteriores)
import '../providers/map_key_provider.dart';
import 'carto_key_dialog.dart';

// ... dentro de _HomeMapHeroState

  Widget _buildMap(BuildContext context, LocationsSnapshot locations) {
    final center = _centerFor(locations);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = isDark && ref.watch(settingsProvider).amoled;
    final cartoKey = ref.watch(cartoKeyProvider);
    final hasKey = cartoKey.isNotEmpty;

    // Si no hay key, usamos OSM. Si hay, CARTO.
    final tileUrl = hasKey 
        ? (isDark ? MapStyle.getTileUrlDark(cartoKey) : MapStyle.getTileUrl(cartoKey))
        : MapStyle.osmTileUrl;

    final attribution = hasKey ? MapStyle.attributionCarto : MapStyle.attributionOsm;

    final map = FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: MapStyle.initialZoom,
        minZoom: MapStyle.minZoom,
        maxZoom: MapStyle.maxZoom,
        backgroundColor: isAmoled
            ? MapStyle.bgAmoled
            : (isDark ? MapStyle.bgDark : MapStyle.bgLight),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          // subdomains solo son necesarios para CARTO (a,b,c,d)
          subdomains: hasKey ? const ['a', 'b', 'c', 'd'] : const [],
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.iruletas.ailoviu',
        ),
        if (locations.canDrawLines) _buildLinesLayer(locations),
        _buildAvatarsLayer(context, locations),
        SimpleAttributionWidget(
          source: Text(
            attribution,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ),
      ],
    );

    // Solo aplicamos AMOLED si el usuario lo pidió y está en modo oscuro.
    // OSM se renderiza TAL CUAL si no hay key.
    Widget finalMap = map;
    if (isAmoled) {
      finalMap = ColorFiltered(
        colorFilter: const ColorFilter.matrix(MapStyle.amoledMatrix),
        child: map,
      );
    }

    // Si no hay key, agregamos el botón flotante de configuración
    if (!hasKey) {
      return Stack(
        children: [
          finalMap,
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              onPressed: () => CartoKeyDialog.show(context),
              icon: const Icon(Icons.key_rounded, size: 18),
              tooltip: 'Configurar mapa',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return finalMap;
  }