// lib/widgets/shared/detail_hero_app_bar.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m3e_shapes/m3e_shapes.dart';

import 'cached_image.dart';
import 'shape_picker.dart';

/// Hero header compartido por las pantallas de detalle (álbum, artista).
///
/// **Comportamiento YouTube Music:** el header se adapta al alto del
/// título. Si el título es corto (1 línea), el header es compacto. Si
/// es largo (2-3 líneas), el header crece hacia abajo para que el
/// título quepa completo sin encimarse con la imagen.
///
/// Al hacer scroll, el título grande se desvanece y el título pequeño
/// aparece en la AppBar colapsada.
///
/// Layout vertical (de arriba hacia abajo):
///   - `kToolbarHeight` (56) reservado para la AppBar colapsada.
///   - `_topGap` (16) entre toolbar y la imagen.
///   - Imagen `_coverSize` (140) recortada con [shape].
///   - `_gapBetweenCoverAndTitle` (16).
///   - Título grande, alto calculado con `TextPainter`.
///   - `_bottomGap` (24).
class DetailHeroAppBar extends StatefulWidget {
  final String title;
  final String? imageUrl;
  final ScrollController controller;
  final M3EShape shape;
  final IconData placeholderIcon;
  final bool showShapeButton;
  final String shapeTooltip;
  final ValueChanged<M3EShape> onShapeSelected;

  const DetailHeroAppBar({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.controller,
    required this.shape,
    required this.placeholderIcon,
    required this.showShapeButton,
    required this.shapeTooltip,
    required this.onShapeSelected,
  });

  static const double _coverSize = 140.0;
  static const double _topGap = 16.0;
  static const double _gapBetweenCoverAndTitle = 16.0;
  static const double _bottomGap = 24.0;

  @override
  State<DetailHeroAppBar> createState() => _DetailHeroAppBarState();
}

class _DetailHeroAppBarState extends State<DetailHeroAppBar> {
  double _overlap = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant DetailHeroAppBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final shrinkRange = _expandedHeight(context) - kToolbarHeight;
    if (shrinkRange <= 0) return;
    final offset = widget.controller.offset;
    final next = (offset / shrinkRange).clamp(0.0, 1.0);
    if ((next - _overlap).abs() < 0.005) return;
    setState(() => _overlap = next);
  }

  /// Calcula el alto del título grande usando `TextPainter`.
  ///
  /// Mide cuántas líneas ocupa [DetailHeroAppBar.title] con el estilo de
  /// `headlineSmall w800` (letterSpacing -0.4) en el ancho disponible
  /// (`screenWidth - 40`, por el padding 20+20 del título).
  double _measureTitleHeight(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    );

    final maxWidth = MediaQuery.sizeOf(context).width - 40;
    final painter = TextPainter(
      text: TextSpan(text: widget.title, style: textStyle),
      maxLines: 3,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return painter.height;
  }

  /// Alto total del header expandido, calculado con el título dinámico.
  double _expandedHeight(BuildContext context) {
    return kToolbarHeight +
        DetailHeroAppBar._topGap +
        DetailHeroAppBar._coverSize +
        DetailHeroAppBar._gapBetweenCoverAndTitle +
        _measureTitleHeight(context) +
        DetailHeroAppBar._bottomGap;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = widget.shape;

    final isDark = theme.brightness == Brightness.dark;
    final gradientBottom = isDark ? scheme.surface : Colors.black87;

    final expandedHeight = _expandedHeight(context);
    final titleHeight = _measureTitleHeight(context);

    final bigTitleOpacity = ((1.0 - _overlap) / 0.6).clamp(0.0, 1.0);
    final smallTitleOpacity = ((_overlap - 0.7) / 0.3).clamp(0.0, 1.0);

    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      systemOverlayStyle: _overlap > 0.5
          ? (isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          : SystemUiOverlayStyle.light,
      title: AnimatedOpacity(
        opacity: smallTitleOpacity,
        duration: const Duration(milliseconds: 120),
        child: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
      actions: [
        if (widget.showShapeButton)
          IconButton(
            tooltip: widget.shapeTooltip,
            icon: Icon(
              Icons.auto_awesome_rounded,
              color: _overlap > 0.5 ? scheme.onSurface : Colors.white,
            ),
            onPressed: () {
              showShapePicker(
                context,
                current: shape,
                onSelected: widget.onShapeSelected,
              );
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        title: null,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: CachedImage(
                  url: widget.imageUrl,
                  fit: BoxFit.cover,
                  fallback: _HeroPlaceholder(seed: widget.title),
                ),
              )
            else
              _HeroPlaceholder(seed: widget.title),

            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black26,
                    Colors.black54,
                    gradientBottom,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),

            // Imagen arriba, con su tamaño original 140.
            Positioned(
              top: kToolbarHeight + DetailHeroAppBar._topGap,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CachedImage(
                    url: widget.imageUrl,
                    width: DetailHeroAppBar._coverSize,
                    height: DetailHeroAppBar._coverSize,
                    fit: BoxFit.cover,
                    shape: shape,
                    cacheWidth: (DetailHeroAppBar._coverSize * 3).toInt(),
                    fallback: CoverShapePreview(
                      shape: shape,
                      size: DetailHeroAppBar._coverSize,
                      seed: widget.title,
                      icon: widget.placeholderIcon,
                    ),
                  ),
                ),
              ),
            ),

            // Título grande, debajo de la imagen. Su alto ya está reservado
            // por el `expandedHeight` calculado, así que no se encima
            // aunque ocupe 2 o 3 líneas.
            Positioned(
              left: 20,
              right: 20,
              bottom: DetailHeroAppBar._bottomGap,
              child: AnimatedOpacity(
                opacity: bigTitleOpacity,
                duration: const Duration(milliseconds: 120),
                child: SizedBox(
                  height: titleHeight,
                  child: Text(
                    widget.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  final String seed;

  const _HeroPlaceholder({required this.seed});

  @override
  Widget build(BuildContext context) {
    final hash = seed.hashCode;
    final hue = (hash % 360).abs().toDouble();
    final baseColor = HSLColor.fromAHSL(1, hue, 0.35, 0.4).toColor();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            baseColor.withValues(alpha: 0.6),
          ],
        ),
      ),
    );
  }
}
