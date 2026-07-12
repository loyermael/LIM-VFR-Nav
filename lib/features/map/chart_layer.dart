import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/chart.dart';

/// Builds the flutter_map layer for a given chart:
///
///  * [ChartKind.rasterOverlay] -> a [RotatedOverlayImage] positioned by the
///    affine georeference corners. The three corners fully describe the
///    (possibly rotated/skewed) placement of a scanned OACI chart.
///  * [ChartKind.mbtiles]       -> a [TileLayer] served from the local SQLite
///    tile pyramid by [MbtilesTileProvider].
///
/// Returns null when the chart isn't ready to display (e.g. uncalibrated
/// raster), so the caller can show a "calibrate this chart" prompt.
Widget? buildChartLayer(ChartDoc chart) {
  switch (chart.kind) {
    case ChartKind.rasterOverlay:
      final corners = chart.corners;
      if (corners == null) return null; // not calibrated yet
      return OverlayImageLayer(
        overlayImages: [
          RotatedOverlayImage(
            topLeftCorner: corners.topLeft,
            bottomLeftCorner: corners.bottomLeft,
            bottomRightCorner: corners.bottomRight,
            imageProvider: FileImage(File(chart.filePath)),
            // Aeronautical fine print must stay crisp under pinch-zoom.
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ],
      );
    case ChartKind.mbtiles:
      return TileLayer(
        tileProvider: MbtilesTileProvider(chart.filePath),
        // MBTiles are self-contained; never touch the network.
        tileDisplay: const TileDisplay.fadeIn(),
      );
  }
}

/// Serves map tiles straight out of a `.mbtiles` file (a SQLite database with a
/// `tiles(zoom_level, tile_column, tile_row, tile_data)` table). MBTiles use the
/// TMS row convention, so the Y coordinate is flipped relative to flutter_map's
/// XYZ scheme. Everything is on-disk — no connectivity needed in flight.
class MbtilesTileProvider extends TileProvider {
  MbtilesTileProvider(this.path);
  final String path;
  Database? _db;

  Future<Database> _open() async =>
      _db ??= await openReadOnlyDatabase(path);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _MbtilesImage(this, coordinates);

  Future<Uint8List?> _readTile(TileCoordinates c) async {
    final db = await _open();
    final flippedY = (1 << c.z) - 1 - c.y; // XYZ -> TMS
    final rows = await db.query(
      'tiles',
      columns: ['tile_data'],
      where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?',
      whereArgs: [c.z, c.x, flippedY],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['tile_data'] as Uint8List;
  }

  @override
  void dispose() {
    _db?.close();
    _db = null;
    super.dispose();
  }
}

/// [ImageProvider] that loads a single tile blob from the MBTiles DB.
class _MbtilesImage extends ImageProvider<_MbtilesImage> {
  _MbtilesImage(this.provider, this.coords);
  final MbtilesTileProvider provider;
  final TileCoordinates coords;

  @override
  Future<_MbtilesImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _MbtilesImage key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_load(decode));
  }

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final bytes = await provider._readTile(coords);
    if (bytes == null) {
      // A transparent 1x1 tile keeps flutter_map happy for empty cells.
      throw StateError('No tile at ${coords.z}/${coords.x}/${coords.y}');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is _MbtilesImage &&
      other.coords == coords &&
      other.provider == provider;

  @override
  int get hashCode => Object.hash(provider, coords);
}
