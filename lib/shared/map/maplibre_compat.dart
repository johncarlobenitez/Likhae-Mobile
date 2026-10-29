import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

/// OpenStreetMap basemap served by OpenFreeMap. No client key is required.
const String libertyStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

class Position {
  final double lng;
  final double lat;

  const Position(this.lng, this.lat);
}

class Point {
  final Position coordinates;

  const Point({required this.coordinates});
}

class LineString {
  final List<Position> coordinates;

  const LineString({required this.coordinates});
}

class MbxEdgeInsets {
  final double top;
  final double left;
  final double bottom;
  final double right;

  const MbxEdgeInsets({
    this.top = 0,
    this.left = 0,
    this.bottom = 0,
    this.right = 0,
  });
}

class CameraOptions {
  final Point? center;
  final double? zoom;
  final MbxEdgeInsets? padding;
  final List<Point>? fitPoints;

  const CameraOptions({this.center, this.zoom, this.padding, this.fitPoints});
}

class MapLibreViewport {
  final Point center;
  final double zoom;

  const MapLibreViewport({required this.center, required this.zoom});
}

class MapContentGestureContext {
  final Point point;

  const MapContentGestureContext({required this.point});
}

enum TextAnchor { bottom, center }

enum IconAnchor { center }

/// Map widget and adapter for the map APIs used by these screens. Rendering
/// and annotations are provided by maplibre_gl.
class MapLibreMapWidget extends StatefulWidget {
  final MapLibreViewport viewport;
  final Future<void> Function(MapLibreSession) onMapCreated;
  final void Function(MapContentGestureContext)? onTapListener;

  const MapLibreMapWidget({
    super.key,
    required this.viewport,
    required this.onMapCreated,
    this.onTapListener,
  });

  @override
  State<MapLibreMapWidget> createState() => _MapLibreMapWidgetState();
}

class _MapLibreMapWidgetState extends State<MapLibreMapWidget> {
  ml.MapLibreMapController? _controller;
  bool _readyCallbackSent = false;
  bool _styleLoaded = false;

  void _sendReadyCallback() {
    final ml.MapLibreMapController? controller = _controller;
    if (_readyCallbackSent || controller == null || !_styleLoaded) return;
    _readyCallbackSent = true;
    unawaited(widget.onMapCreated(MapLibreSession(controller)));
  }

  @override
  Widget build(BuildContext context) {
    return ml.MapLibreMap(
      styleString: libertyStyleUrl,
      initialCameraPosition: ml.CameraPosition(
        target: _toLatLng(widget.viewport.center),
        zoom: widget.viewport.zoom,
      ),
      logoEnabled: false,
      onMapCreated: (ml.MapLibreMapController controller) {
        _controller = controller;
      },
      onStyleLoadedCallback: () {
        _styleLoaded = true;
        _sendReadyCallback();
      },
      onMapClick: (dynamic _, ml.LatLng location) {
        widget.onTapListener?.call(
          MapContentGestureContext(
            point: Point(
              coordinates: Position(location.longitude, location.latitude),
            ),
          ),
        );
      },
    );
  }
}

class MapLibreSession {
  final ml.MapLibreMapController _controller;
  late final AnnotationApi annotations = AnnotationApi(_controller);

  MapLibreSession(this._controller);

  Future<void> setCamera(CameraOptions options) async {
    final List<Point>? points = options.fitPoints;
    if (points != null && points.length > 1) {
      final List<Position> positions = points
          .map((Point point) => point.coordinates)
          .toList(growable: false);
      final double minLat = positions.map((Position p) => p.lat).reduce(_min);
      final double maxLat = positions.map((Position p) => p.lat).reduce(_max);
      final double minLng = positions.map((Position p) => p.lng).reduce(_min);
      final double maxLng = positions.map((Position p) => p.lng).reduce(_max);
      final MbxEdgeInsets padding = options.padding ?? const MbxEdgeInsets();
      await _controller.animateCamera(
        ml.CameraUpdate.newLatLngBounds(
          ml.LatLngBounds(
            southwest: ml.LatLng(minLat, minLng),
            northeast: ml.LatLng(maxLat, maxLng),
          ),
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
        ),
      );
      return;
    }
    final Point? center = options.center;
    if (center == null) return;
    await _controller.animateCamera(
      ml.CameraUpdate.newLatLngZoom(_toLatLng(center), options.zoom ?? 12),
    );
  }

  Future<CameraOptions> cameraForCoordinatesPadding(
    List<Point> points,
    CameraOptions camera,
    dynamic coordinatesPadding,
    double maxZoom,
    dynamic offset,
  ) async {
    if (points.isEmpty) return camera;
    final double lat =
        points.map((Point point) => point.coordinates.lat).reduce(_min) +
        (points.map((Point point) => point.coordinates.lat).reduce(_max) -
                points
                    .map((Point point) => point.coordinates.lat)
                    .reduce(_min)) /
            2;
    final double lng =
        points.map((Point point) => point.coordinates.lng).reduce(_min) +
        (points.map((Point point) => point.coordinates.lng).reduce(_max) -
                points
                    .map((Point point) => point.coordinates.lng)
                    .reduce(_min)) /
            2;
    return CameraOptions(
      center: Point(coordinates: Position(lng, lat)),
      zoom: maxZoom,
      padding: camera.padding,
      fitPoints: List<Point>.unmodifiable(points),
    );
  }
}

class AnnotationApi {
  final ml.MapLibreMapController controller;

  const AnnotationApi(this.controller);

  Future<CircleAnnotationManager> createCircleAnnotationManager() async =>
      CircleAnnotationManager(controller);

  Future<PointAnnotationManager> createPointAnnotationManager() async =>
      PointAnnotationManager(controller);

  Future<PolylineAnnotationManager> createPolylineAnnotationManager() async =>
      PolylineAnnotationManager(controller);
}

class CircleAnnotationOptions {
  final Point geometry;
  final int circleColor;
  final double circleRadius;
  final int circleStrokeColor;
  final double circleStrokeWidth;
  final double circleSortKey;

  const CircleAnnotationOptions({
    required this.geometry,
    this.circleColor = 0xFF561C17,
    this.circleRadius = 8,
    this.circleStrokeColor = 0xFFFFFFFF,
    this.circleStrokeWidth = 0,
    this.circleSortKey = 0,
  });
}

class CircleAnnotation {
  final ml.Circle _native;
  Point geometry;
  int circleColor;
  double circleRadius;
  int circleStrokeColor;
  double circleStrokeWidth;
  double circleSortKey;

  CircleAnnotation(this._native, CircleAnnotationOptions options)
    : geometry = options.geometry,
      circleColor = options.circleColor,
      circleRadius = options.circleRadius,
      circleStrokeColor = options.circleStrokeColor,
      circleStrokeWidth = options.circleStrokeWidth,
      circleSortKey = options.circleSortKey;
}

class CircleAnnotationManager {
  final ml.MapLibreMapController _controller;
  final List<CircleAnnotation> _annotations = <CircleAnnotation>[];

  CircleAnnotationManager(this._controller);

  Future<CircleAnnotation> create(CircleAnnotationOptions options) async {
    final ml.Circle native = await _controller.addCircle(
      _circleOptions(options),
    );
    final CircleAnnotation annotation = CircleAnnotation(native, options);
    _annotations.add(annotation);
    return annotation;
  }

  Future<List<CircleAnnotation?>> createMulti(
    List<CircleAnnotationOptions> options,
  ) async {
    final List<ml.Circle> native = await _controller.addCircles(
      options.map(_circleOptions).toList(growable: false),
    );
    final List<CircleAnnotation?> created = <CircleAnnotation?>[];
    for (int i = 0; i < native.length; i++) {
      final CircleAnnotation annotation = CircleAnnotation(
        native[i],
        options[i],
      );
      _annotations.add(annotation);
      created.add(annotation);
    }
    return created;
  }

  Future<void> update(CircleAnnotation annotation) async {
    await _controller.updateCircle(
      annotation._native,
      _circleOptions(
        CircleAnnotationOptions(
          geometry: annotation.geometry,
          circleColor: annotation.circleColor,
          circleRadius: annotation.circleRadius,
          circleStrokeColor: annotation.circleStrokeColor,
          circleStrokeWidth: annotation.circleStrokeWidth,
          circleSortKey: annotation.circleSortKey,
        ),
      ),
    );
  }

  Future<void> delete(CircleAnnotation annotation) async {
    await _controller.removeCircle(annotation._native);
    _annotations.remove(annotation);
  }

  Future<void> deleteAll() async {
    final List<CircleAnnotation> existing = List<CircleAnnotation>.of(
      _annotations,
    );
    for (final CircleAnnotation annotation in existing) {
      await _controller.removeCircle(annotation._native);
    }
    _annotations.clear();
  }
}

class PointAnnotationOptions {
  final Point geometry;
  final String textField;
  final TextAnchor textAnchor;
  final List<double?> textOffset;
  final double textSize;
  final int textColor;
  final int textHaloColor;
  final double textHaloWidth;
  final IconAnchor? iconAnchor;
  final Uint8List? image;
  final double? iconSize;
  final double? symbolSortKey;

  const PointAnnotationOptions({
    required this.geometry,
    this.textField = '',
    this.textAnchor = TextAnchor.center,
    this.textOffset = const <double?>[0, 0],
    this.textSize = 12,
    this.textColor = 0xFF342E2E,
    this.textHaloColor = 0xFFFFFFFF,
    this.textHaloWidth = 0,
    this.iconAnchor,
    this.image,
    this.iconSize,
    this.symbolSortKey,
  });
}

class PointAnnotation {
  final ml.Symbol _native;
  Point geometry;
  String textField;
  final String? _imageId;
  final double? _iconSize;

  PointAnnotation(
    this._native,
    PointAnnotationOptions options, {
    String? imageId,
  }) : geometry = options.geometry,
       textField = options.textField,
       _imageId = imageId,
       _iconSize = options.iconSize;
}

class PointAnnotationManager {
  final ml.MapLibreMapController _controller;
  final List<PointAnnotation> _annotations = <PointAnnotation>[];
  final Set<String> _registeredImages = <String>{};

  PointAnnotationManager(this._controller);

  Future<PointAnnotation> create(PointAnnotationOptions options) async {
    String? imageId;
    if (options.image != null) {
      imageId = 'likhae-symbol-${identityHashCode(options.image!)}';
      if (_registeredImages.add(imageId)) {
        await _controller.addImage(imageId, options.image!);
      }
    }
    final ml.Symbol native = await _controller.addSymbol(
      _symbolOptions(options, imageId: imageId),
    );
    final PointAnnotation annotation = PointAnnotation(
      native,
      options,
      imageId: imageId,
    );
    _annotations.add(annotation);
    return annotation;
  }

  Future<List<PointAnnotation?>> createMulti(
    List<PointAnnotationOptions> options,
  ) async {
    final List<ml.Symbol> native = await _controller.addSymbols(
      options.map(_symbolOptions).toList(growable: false),
    );
    final List<PointAnnotation?> created = <PointAnnotation?>[];
    for (int i = 0; i < native.length; i++) {
      final PointAnnotation annotation = PointAnnotation(native[i], options[i]);
      _annotations.add(annotation);
      created.add(annotation);
    }
    return created;
  }

  Future<void> update(PointAnnotation annotation) async {
    await _controller.updateSymbol(
      annotation._native,
      ml.SymbolOptions(
        geometry: _toLatLng(annotation.geometry),
        textField: annotation.textField,
        iconImage: annotation._imageId,
        iconSize: annotation._iconSize,
      ),
    );
  }

  Future<void> deleteAll() async {
    for (final PointAnnotation annotation in List<PointAnnotation>.of(
      _annotations,
    )) {
      await _controller.removeSymbol(annotation._native);
    }
    _annotations.clear();
  }
}

class PolylineAnnotationOptions {
  final LineString geometry;
  final int lineColor;
  final double lineWidth;
  final double lineOpacity;
  final int? lineBorderColor;
  final double? lineBorderWidth;

  const PolylineAnnotationOptions({
    required this.geometry,
    this.lineColor = 0xFF561C17,
    this.lineWidth = 4,
    this.lineOpacity = 1,
    this.lineBorderColor,
    this.lineBorderWidth,
  });
}

class PolylineAnnotation {
  final ml.Line _native;
  LineString geometry;
  int lineColor;
  double lineWidth;
  double lineOpacity;

  PolylineAnnotation(this._native, PolylineAnnotationOptions options)
    : geometry = options.geometry,
      lineColor = options.lineColor,
      lineWidth = options.lineWidth,
      lineOpacity = options.lineOpacity;
}

class PolylineAnnotationManager {
  final ml.MapLibreMapController _controller;
  final List<PolylineAnnotation> _annotations = <PolylineAnnotation>[];

  PolylineAnnotationManager(this._controller);

  Future<PolylineAnnotation> create(PolylineAnnotationOptions options) async {
    final ml.Line native = await _controller.addLine(_lineOptions(options));
    final PolylineAnnotation annotation = PolylineAnnotation(native, options);
    _annotations.add(annotation);
    return annotation;
  }

  Future<void> update(PolylineAnnotation annotation) async {
    await _controller.updateLine(
      annotation._native,
      _lineOptions(
        PolylineAnnotationOptions(
          geometry: annotation.geometry,
          lineColor: annotation.lineColor,
          lineWidth: annotation.lineWidth,
          lineOpacity: annotation.lineOpacity,
        ),
      ),
    );
  }

  Future<void> delete(PolylineAnnotation annotation) async {
    await _controller.removeLine(annotation._native);
    _annotations.remove(annotation);
  }

  Future<void> deleteAll() async {
    for (final PolylineAnnotation annotation in List<PolylineAnnotation>.of(
      _annotations,
    )) {
      await _controller.removeLine(annotation._native);
    }
    _annotations.clear();
  }
}

ml.CircleOptions _circleOptions(CircleAnnotationOptions options) =>
    ml.CircleOptions(
      geometry: _toLatLng(options.geometry),
      circleColor: _mapColor(options.circleColor),
      circleRadius: options.circleRadius,
      circleStrokeColor: _mapColor(options.circleStrokeColor),
      circleStrokeWidth: options.circleStrokeWidth,
    );

ml.SymbolOptions _symbolOptions(
  PointAnnotationOptions options, {
  String? imageId,
}) => ml.SymbolOptions(
  geometry: _toLatLng(options.geometry),
  textField: options.textField,
  textAnchor: options.textAnchor == TextAnchor.bottom ? 'bottom' : 'center',
  textOffset: Offset(
    options.textOffset.isEmpty ? 0 : options.textOffset[0] ?? 0,
    options.textOffset.length < 2 ? 0 : options.textOffset[1] ?? 0,
  ),
  textSize: options.textSize,
  textColor: _mapColor(options.textColor),
  textHaloColor: _mapColor(options.textHaloColor),
  textHaloWidth: options.textHaloWidth,
  iconImage: imageId,
  iconSize: options.iconSize,
  iconAnchor: options.iconAnchor == null ? null : 'center',
  zIndex: options.symbolSortKey?.toInt(),
);

ml.LineOptions _lineOptions(PolylineAnnotationOptions options) =>
    ml.LineOptions(
      geometry: options.geometry.coordinates
          .map((Position point) => ml.LatLng(point.lat, point.lng))
          .toList(growable: false),
      lineColor: _mapColor(options.lineColor),
      lineWidth: options.lineWidth,
      lineOpacity: options.lineOpacity,
      lineJoin: 'round',
    );

ml.LatLng _toLatLng(Point point) =>
    ml.LatLng(point.coordinates.lat, point.coordinates.lng);

String _mapColor(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

double _min(double first, double second) => first < second ? first : second;

double _max(double first, double second) => first > second ? first : second;
