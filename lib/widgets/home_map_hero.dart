import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/map_style.dart';
import '../models/home_models.dart';
import '../providers/home_providers.dart';
import '../providers/relationship_providers.dart';
import '../services/location_service.dart';

/// Mapa hero de Hogar.
///
/// - Fondo: OSM con tinte suave.
/// - Un avatar por miembro en squircle.
/// - Línea entre cada par de avatares.
/// - Badge "＋" en mi avatar para editar mi estado.
/// - Pill flotante de cristal con la distancia total.
/// - Empty state con CTA que pide permiso y comparte ubicación.
/// - Compresión táctil del contenedor completo.
class HomeMapHero extends ConsumerStatefulWidget {
  const HomeMapHero({
    super.key,
    this.height = 280,
    this.onEditStatus,
  });

  final double height;

  /// Callback al tocar el badge "＋" de mi avatar.
  final VoidCallback? onEditStatus;

  @override
  ConsumerState<HomeMapHero> createState() => _HomeMapHeroState();
}

class _HomeMapHeroState extends ConsumerState<HomeMapHero> {
  final _locationService = LocationService();
  bool _pressed = false;
  bool _requestingLocation = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  Future<void> _requestAndShareLocation() async {
    if (_requestingLocation) return;
    setState(() => _requestingLocation = true);

    try {
      final granted = await _locationService.requestPermission();
      if (!granted || !mounted) {
        _showMessage('Permiso de ubicación denegado');
        return;
      }

      final deviceId = ref.read(myDeviceIdProvider).valueOrNull ?? '';
      if (deviceId.isEmpty) {
        _showMessage('Espera a que la app termine de inicializar');
        return;
      }

      final loc = await _locationService.getCurrentLocation(
        deviceId: deviceId,
      );
      if (loc == null) {
        _showMessage('No se pudo obtener la ubicación');
        return;
      }

      await ref.read(locationsProvider.notifier).saveMyLocation(loc);
      _showMessage('Ubicación compartida');
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final points = locations.everyone;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: SizedBox(
              height: widget.height,
              child: Stack(
                children: [
                  _buildMap(context, locations),
                  if (points.isEmpty)
                    _buildEmptyState(context)
                  else
                    _buildDistanceBadge(context, locations),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, LocationsSnapshot locations) {
    final center = _centerFor(locations);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: MapStyle.initialZoom,
        minZoom: MapStyle.minZoom,
        maxZoom: MapStyle.maxZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapStyle.tileUrl,
          userAgentPackageName: 'com.iruletas.ailoviu',
        ),
        if (locations.canDrawLines) _buildLinesLayer(locations),
        _buildAvatarsLayer(context, locations),
      ],
    );
  }

  LatLng _centerFor(LocationsSnapshot snapshot) {
    if (snapshot.all.isEmpty) {
      return const LatLng(MapStyle.defaultLat, MapStyle.defaultLon);
    }
    var lat = 0.0;
    var lon = 0.0;
    for (final loc in snapshot.all.values) {
      lat += loc.latitude;
      lon += loc.longitude;
    }
    return LatLng(lat / snapshot.all.length, lon / snapshot.all.length);
  }

  Widget _buildLinesLayer(LocationsSnapshot snapshot) {
    final locs = snapshot.everyone;
    final polylines = <Polyline>[];
    for (int i = 0; i < locs.length; i++) {
      for (int j = i + 1; j < locs.length; j++) {
        polylines.add(
          Polyline(
            points: [
              LatLng(locs[i].latitude, locs[i].longitude),
              LatLng(locs[j].latitude, locs[j].longitude),
            ],
            color: MapStyle.lineColor.withValues(alpha: 0.7),
            strokeWidth: MapStyle.lineWidth,
          ),
        );
      }
    }
    return PolylineLayer(polylines: polylines);
  }

  Widget _buildAvatarsLayer(
    BuildContext context,
    LocationsSnapshot snapshot,
  ) {
    final relationship = ref.read(relationshipProvider);
    final statuses = ref.watch(statusesProvider);
    final locs = snapshot.everyone;
    final names = relationship.visibleNames;
    final markers = <Marker>[];

    for (var i = 0; i < locs.length; i++) {
      final loc = locs[i];
      final name = i < names.length ? names[i] : '';
      final isMe = loc.deviceId == snapshot.myDeviceId;
      final hasStatus = statuses.containsKey(loc.deviceId);
      markers.add(
        Marker(
          point: LatLng(loc.latitude, loc.longitude),
          width: 72,
          height: 72,
          child: _AvatarMarker(
            name: name,
            isMe: isMe,
            hasStatus: hasStatus,
            onEditStatus: isMe ? widget.onEditStatus : null,
          ),
        ),
      );
    }
    return MarkerLayer(markers: markers);
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme