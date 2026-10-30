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
class HomeMapHero extends ConsumerStatefulWidget {
  const HomeMapHero({
    super.key,
    this.height = 280,
    this.onEditStatus,
  });

  final double height;

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
      final permission = await _locationService.ensurePermission();

      switch (permission) {
        case LocationResult.serviceDisabled:
          _showLocationServiceDialog();
          return;
        case LocationResult.permissionDeniedForever:
          _showPermissionForeverDialog();
          return;
        case LocationResult.permissionDenied:
          _showMessage('Permiso de ubicación denegado');
          return;
        case LocationResult.success:
          break;
        default:
          _showMessage('No se pudo obtener el permiso');
          return;
      }

      if (!mounted) return;

      final deviceId = ref.read(myDeviceIdProvider).valueOrNull ?? '';
      if (deviceId.isEmpty) {
        _showMessage('Espera a que la app termine de inicializar');
        return;
      }

      final attempt = await _locationService.getCurrentLocation(
        deviceId: deviceId,
      );

      switch (attempt.result) {
        case LocationResult.success:
          final loc = attempt.location;
          if (loc == null) {
            _showMessage('No se pudo obtener la ubicación');
            return;
          }
          await ref.read(locationsProvider.notifier).saveMyLocation(loc);
          _showMessage('Ubicación compartida');
          return;
        case LocationResult.timeout:
          _showMessage('La ubicación tardó demasiado. Intenta de nuevo.');
          return;
        case LocationResult.error:
        default:
          _showMessage('No se pudo obtener la ubicación');
          return;
      }
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

  void _showLocationServiceDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación del sistema apagada'),
        content: const Text(
          'Para compartir tu ubicación, activa el GPS o la ubicación '
          'del sistema desde los ajustes rápidos o la configuración '
          'de Android.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _locationService.openLocationSettings();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  void _showPermissionForeverDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso de ubicación'),
        content: const Text(
          'El permiso fue denegado permanentemente. Actívalo desde '
          'Ajustes de Android > Apps > Ailoviu > Permisos > Ubicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _locationService.openAppSettings();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
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

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(MapStyle.colorMatrix),
      child: FlutterMap(
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
      ),
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
    final partnerStatuses = ref.watch(statusesProvider);
    final myStatus = ref.watch(myStatusProvider);
    
    final locs = snapshot.everyone;
    final names = relationship.visibleNames;
    final markers = <Marker>[];

    for (var i = 0; i < locs.length; i++) {
      final loc = locs[i];
      final name = i < names.length ? names[i] : '';
      final isMe = loc.deviceId == snapshot.myDeviceId;
      
      // Si es mi avatar, chequeo myStatus. Si no, busco en partnerStatuses.
      final hasStatus = isMe 
          ? myStatus != null 
          : partnerStatuses.containsKey(loc.deviceId);

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
      color: scheme.surfaceContainerLow,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.map_rounded,
              size: 32,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Comparte tu ubicación para ver el mapa',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _requestingLocation ? null : _requestAndShareLocation,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
            ),
            child: _requestingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Compartir ubicación'),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceBadge(
    BuildContext context,
    LocationsSnapshot snapshot,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final locs = snapshot.everyone;
    if (locs.length < 2) return const SizedBox.shrink();

    var totalKm = 0.0;
    for (int i = 0; i < locs.length - 1; i++) {
      totalKm += _distanceKmBetween(
        lat1: locs[i].latitude,
        lon1: locs[i].longitude,
        lat2: locs[i + 1].latitude,
        lon2: locs[i + 1].longitude,
      );
    }

    final together = totalKm < 1.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 14,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: together
                    ? scheme.tertiaryContainer.withValues(alpha: 0.9)
                    : scheme.surfaceContainerHigh.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    together
                        ? Icons.favorite_rounded
                        : Icons.near_me_rounded,
                    size: 16,
                    color: together
                        ? scheme.onTertiaryContainer
                        : scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    together
                        ? '¡Están juntos!'
                        : '${totalKm.round()} km',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: together
                          ? scheme.onTertiaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _distanceKmBetween({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);
}

class _AvatarMarker extends StatefulWidget {
  final String name;
  final bool isMe;
  final bool hasStatus;
  final VoidCallback? onEditStatus;

  const _AvatarMarker({
    required this.name,
    required this.isMe,
    required this.hasStatus,
    this.onEditStatus,
  });

  @override
  State<_AvatarMarker> createState() => _AvatarMarkerState();
}

class _AvatarMarkerState extends State<_AvatarMarker> {
  bool _badgePressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = widget.name.trim().isEmpty
        ? null
        : widget.name.trim()[0].toUpperCase();

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: widget.isMe
                ? scheme.primaryContainer
                : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.surface,
              width: 3,
            ),
            boxShadow: widget.isMe
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: initial == null
                ? Icon(
                    Icons.person_outline,
                    size: 22,
                    color: widget.isMe
                        ? scheme.onPrimaryContainer
                        : scheme.onSecondaryContainer,
                  )
                : Text(
                    initial,
                    style: TextStyle(
                      color: widget.isMe
                          ? scheme.onPrimaryContainer
                          : scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
          ),
        ),

        // Indicador de estado (ahora sí aparece si hay estado)
        if (widget.hasStatus)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.tertiary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),

        // Badge "＋" para mi avatar
        if (widget.isMe && widget.onEditStatus != null)
          Positioned(
            bottom: -2,
            right: -2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _badgePressed = true),
              onTapUp: (_) => setState(() => _badgePressed = false),
              onTapCancel: () => setState(() => _badgePressed = false),
              onTap: widget.onEditStatus,
              child: AnimatedScale(
                scale: _badgePressed ? 0.88 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve:
                    _badgePressed ? Curves.easeOutCubic : Curves.easeOutBack,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 12,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}