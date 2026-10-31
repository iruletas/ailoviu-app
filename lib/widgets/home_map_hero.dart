import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/map_style.dart';
import '../models/home_models.dart';
import '../providers/home_providers.dart';
import '../providers/map_key_provider.dart';
import '../providers/relationship_providers.dart';
import '../providers/settings_providers.dart';
import '../services/location_service.dart';
import 'carto_key_dialog.dart';
import 'map_dock.dart';
import 'map_feedback.dart';

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
  final _mapController = MapController();
  bool _pressed = false;
  bool _requestingLocation = false;
  bool _mapReady = false;

  static const double _recenterThresholdMeters = 20.0;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  void _centerOnMyLocation(LatLng target, {bool haptic = true}) {
    if (!_mapReady) return;
    if (haptic) HapticFeedback.selectionClick();
    try {
      _mapController.move(target, MapStyle.initialZoom);
    } catch (_) {}
  }

  Future<void> _requestAndShareLocation() async {
    if (_requestingLocation) return;
    setState(() => _requestingLocation = true);

    try {
      final result =
          await ref.read(locationsProvider.notifier).forceRefreshMyLocation();

      if (!mounted) return;

      final mine = ref.read(locationsProvider).all[
          ref.read(myDeviceIdProvider).valueOrNull ?? ''];
      if (mine != null) {
        _centerOnMyLocation(LatLng(mine.latitude, mine.longitude));
      }

      switch (result) {
        case LocationResult.success:
          MapFeedback.showSuccess(context, 'Ubicación actualizada 📍');
          break;
        case LocationResult.serviceDisabled:
          _showLocationServiceDialog();
          break;
        case LocationResult.permissionDeniedForever:
          _showPermissionForeverDialog();
          break;
        case LocationResult.permissionDenied:
          MapFeedback.showError(
            context,
            'Permiso de ubicación denegado',
          );
          break;
        case LocationResult.timeout:
          MapFeedback.showErrorWithIcon(
            context,
            'La ubicación tardó demasiado',
            Icons.timer_rounded,
          );
          break;
        case LocationResult.stale:
          MapFeedback.showError(
            context,
            'No se obtuvo una ubicación fresca',
          );
          break;
        case LocationResult.error:
          MapFeedback.showError(
            context,
            'No se pudo obtener la ubicación',
          );
          break;
      }
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
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
              final service = ref.read(locationServiceProvider);
              await service.openLocationSettings();
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
              final service = ref.read(locationServiceProvider);
              await service.openAppSettings();
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

    ref.listen<LocationsSnapshot>(locationsProvider, (previous, next) {
      final prevLoc = previous?.all[next.myDeviceId];
      final nextLoc = next.all[next.myDeviceId];
      if (nextLoc == null) return;
      if (!_mapReady) return;

      final movedEnough = prevLoc == null ||
          _distanceKmBetween(
                lat1: prevLoc.latitude,
                lon1: prevLoc.longitude,
                lat2: nextLoc.latitude,
                lon2: nextLoc.longitude,
              ) *
                  1000 >
              _recenterThresholdMeters;

      if (!movedEnough) return;

      HapticFeedback.selectionClick();
      try {
        _mapController.move(
          LatLng(nextLoc.latitude, nextLoc.longitude),
          MapStyle.initialZoom,
        );
      } catch (_) {}
    });

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
    final cartoKey = ref.watch(cartoKeyProvider);
    final hasKey = cartoKey.isNotEmpty;

    final tileUrl = hasKey
        ? MapStyle.getTileUrl(cartoKey)
        : MapStyle.osmTileUrl;

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: MapStyle.initialZoom,
        minZoom: MapStyle.minZoom,
        maxZoom: MapStyle.maxZoom,
        backgroundColor: MapStyle.bgLight,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
        onMapReady: () {
          _mapReady = true;
        },
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          subdomains: hasKey ? const ['a', 'b', 'c', 'd'] : const [],
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.iruletas.ailoviu',
        ),
        if (locations.canDrawLines) _buildLinesLayer(locations),
        _buildAvatarsLayer(context, locations),
        const Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.all(4.0),
            child: Text(
              'OpenStreetMap · CARTO',
              style: TextStyle(
                fontSize: 9,
                color: Colors.black45,
              ),
            ),
          ),
        ),
      ],
    );

    return Stack(
      children: [
        map,
        Positioned(
          top: 8,
          right: 8,
          child: MapDock(
            busy: _requestingLocation,
            onMyLocationPressed: _requestAndShareLocation,
            onCartoPressed: hasKey
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    CartoKeyDialog.show(context);
                  },
          ),
        ),
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
    final partnerStatuses = ref.watch(statusesProvider);
    final myStatus = ref.watch(myStatusProvider);

    final locs = snapshot.everyone;
    final names = relationship.visibleNames;
    final markers = <Marker>[];

    for (var i = 0; i < locs.length; i++) {
      final loc = locs[i];
      final name = i < names.length ? names[i] : '';
      final isMe = loc.deviceId == snapshot.myDeviceId;

      final status = isMe ? myStatus : partnerStatuses[loc.deviceId];

      markers.add(
        Marker(
          point: LatLng(loc.latitude, loc.longitude),
          // Aumentamos el marcador para que el badge sobresalga
          // sin que Flutter lo recorte.
          width: 84,
          height: 84,
          child: _AvatarMarker(
            name: name,
            isMe: isMe,
            status: status,
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
  final PartnerStatus? status;
  final VoidCallback? onEditStatus;

  const _AvatarMarker({
    required this.name,
    required this.isMe,
    required this.status,
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

    final hasStatus = widget.status != null;
    final statusText = widget.status?.displayText ?? '';

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 1. El avatar en sí.
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: widget.isMe
                ? scheme.primaryContainer
                : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(22),
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
                    size: 24,
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
                      fontSize: 22,
                    ),
                  ),
          ),
        ),

        // 2. El badge (+ o estado), anclado a la esquina inferior derecha.
        // Usamos -11 para que sobresalga justo a la mitad.
        if (widget.isMe && widget.onEditStatus != null)
          Positioned(
            bottom: -11,
            right: -11,
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
                  padding: hasStatus
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                      : EdgeInsets.zero,
                  width: hasStatus ? null : 26,
                  height: hasStatus ? null : 26,
                  decoration: BoxDecoration(
                    color: hasStatus
                        ? scheme.surfaceContainerHigh
                        : scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.surface, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: hasStatus
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              statusText.length > 18
                                  ? '${statusText.substring(0, 18)}...'
                                  : statusText,
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Icon(
                          Icons.add_rounded,
                          size: 16,
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