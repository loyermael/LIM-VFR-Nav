import '../core/geo_math.dart';
import 'geo_calibration.dart';

/// How a chart is rendered on the map.
enum ChartKind {
  /// A single raster image (from PDF/TIFF/PNG) placed via an affine
  /// georeference and drawn with [RotatedOverlayImage].
  rasterOverlay,

  /// A pre-tiled, natively georeferenced .mbtiles pyramid drawn with a
  /// [TileLayer] backed by [MbtilesTileProvider].
  mbtiles,
}

/// An imported chart the pilot can navigate on. Persisted as JSON in the app's
/// private storage so the whole set is available fully offline.
class ChartDoc {
  final String id;
  final String name;
  final ChartKind kind;

  /// Absolute path to the backing file in app storage (the rendered PNG for a
  /// raster overlay, or the .mbtiles database).
  final String filePath;

  /// Source raster dimensions (raster overlays only).
  final double imageWidth;
  final double imageHeight;

  /// Tie-points and the fitted transform (raster overlays only). Null until the
  /// chart has been calibrated.
  final List<CalibrationPoint> calibration;
  final AffineGeoref? georef;

  /// Printed map scale denominator, e.g. 500000 for a 1:500 000 OACI chart.
  /// Asked at import time; enables the fast single-point calibration.
  final int? scaleDenominator;

  /// Raster resolution in pixels per inch. Known for PDF imports (we control the
  /// render density); null for arbitrary image scans, where scale alone can't
  /// yield a ground size.
  final double? pixelsPerInch;

  const ChartDoc({
    required this.id,
    required this.name,
    required this.kind,
    required this.filePath,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.calibration = const [],
    this.georef,
    this.scaleDenominator,
    this.pixelsPerInch,
  });

  bool get isCalibrated => kind == ChartKind.mbtiles || georef != null;

  /// True when we know both the scale and the DPI, so a one-point, north-up
  /// calibration is possible.
  bool get supportsScaleCalibration =>
      scaleDenominator != null && pixelsPerInch != null;

  /// Ground metres per image pixel derived from scale + DPI
  /// (`0.0254 m/inch * scale / ppi`). Null unless [supportsScaleCalibration].
  double? get metersPerPixelFromScale => supportsScaleCalibration
      ? 0.0254 * scaleDenominator! / pixelsPerInch!
      : null;

  ImageCorners? get corners =>
      georef?.cornersFor(imageWidth, imageHeight);

  ChartDoc copyWith({
    String? name,
    List<CalibrationPoint>? calibration,
    AffineGeoref? georef,
    int? scaleDenominator,
    double? pixelsPerInch,
  }) =>
      ChartDoc(
        id: id,
        name: name ?? this.name,
        kind: kind,
        filePath: filePath,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        calibration: calibration ?? this.calibration,
        georef: georef ?? this.georef,
        scaleDenominator: scaleDenominator ?? this.scaleDenominator,
        pixelsPerInch: pixelsPerInch ?? this.pixelsPerInch,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'filePath': filePath,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
        'calibration': calibration.map((c) => c.toJson()).toList(),
        'georef': georef?.toJson(),
        'scaleDenominator': scaleDenominator,
        'pixelsPerInch': pixelsPerInch,
      };

  factory ChartDoc.fromJson(Map<String, dynamic> j) => ChartDoc(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: ChartKind.values.byName(j['kind'] as String),
        filePath: j['filePath'] as String,
        imageWidth: (j['imageWidth'] as num?)?.toDouble() ?? 0,
        imageHeight: (j['imageHeight'] as num?)?.toDouble() ?? 0,
        calibration: ((j['calibration'] as List?) ?? [])
            .map((e) => CalibrationPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        georef: j['georef'] == null
            ? null
            : AffineGeoref.fromJson(j['georef'] as Map<String, dynamic>),
        scaleDenominator: (j['scaleDenominator'] as num?)?.toInt(),
        pixelsPerInch: (j['pixelsPerInch'] as num?)?.toDouble(),
      );
}
