import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfx/pdfx.dart';

import '../models/chart.dart';
import 'storage_service.dart';

/// Imports chart source files into offline storage and maintains the chart list.
///
/// Supported inputs:
///   * PDF          -> first page rasterised to PNG (pdfx), then overlay-calibrated
///   * PNG / JPG     -> copied as-is, overlay-calibrated
///   * MBTiles       -> copied; natively georeferenced tile pyramid
///
/// (Georeferenced TIFF is not decoded natively by Flutter; convert to PNG/JPG
///  first — see README.)
class ChartRepository {
  ChartRepository(this._storage);
  final StorageService _storage;

  /// Render density for PDF import. 2.0 keeps aeronautical fine print crisp
  /// under pinch-zoom without exploding memory for A1-sized charts.
  static const double _pdfRenderScale = 2.0;

  Future<List<ChartDoc>> list() => _storage.loadCharts();

  /// Number of pages in a PDF (charts are often multi-page booklets; the map may
  /// not be page 1). Cheap — opens and closes the document.
  Future<int> pdfPageCount(String sourcePath) async {
    final doc = await PdfDocument.openFile(sourcePath);
    final n = doc.pagesCount;
    await doc.close();
    return n;
  }

  Future<ChartDoc> importFile(String sourcePath,
      {String? name, int pdfPage = 1}) async {
    final ext = sourcePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'mbtiles':
        return _importMbtiles(sourcePath, name);
      case 'pdf':
        return _importPdf(sourcePath, name, pdfPage);
      case 'png':
      case 'jpg':
      case 'jpeg':
        return _importImage(sourcePath, name);
      default:
        throw UnsupportedError(
          'Unsupported chart format ".$ext". Use PDF, PNG, JPG or MBTiles.',
        );
    }
  }

  Future<void> delete(ChartDoc chart) async {
    final all = await list();
    all.removeWhere((c) => c.id == chart.id);
    await _storage.saveCharts(all);
    final f = File(chart.filePath);
    if (await f.exists()) await f.delete();
  }

  /// Persists an updated ChartDoc (e.g. after calibration) back to the index.
  Future<void> update(ChartDoc chart) async {
    final all = await list();
    final i = all.indexWhere((c) => c.id == chart.id);
    if (i >= 0) {
      all[i] = chart;
    } else {
      all.add(chart);
    }
    await _storage.saveCharts(all);
  }

  // --- private importers ----------------------------------------------------

  Future<ChartDoc> _importImage(String sourcePath, String? name) async {
    final id = _newId();
    final dest = File('${_storage.chartsDir.path}/$id.png');
    final bytes = await File(sourcePath).readAsBytes();
    await dest.writeAsBytes(bytes, flush: true);
    final size = await _decodeSize(bytes);
    return _register(ChartDoc(
      id: id,
      name: name ?? _baseName(sourcePath),
      kind: ChartKind.rasterOverlay,
      filePath: dest.path,
      imageWidth: size.$1,
      imageHeight: size.$2,
    ));
  }

  Future<ChartDoc> _importPdf(
      String sourcePath, String? name, int pdfPage) async {
    final doc = await PdfDocument.openFile(sourcePath);
    final page = await doc.getPage(pdfPage.clamp(1, doc.pagesCount));
    final rendered = await page.render(
      width: page.width * _pdfRenderScale,
      height: page.height * _pdfRenderScale,
      format: PdfPageImageFormat.png,
    );
    await page.close();
    await doc.close();

    final id = _newId();
    final dest = File('${_storage.chartsDir.path}/$id.png');
    await dest.writeAsBytes(rendered!.bytes, flush: true);
    return _register(ChartDoc(
      id: id,
      name: name ?? _baseName(sourcePath),
      kind: ChartKind.rasterOverlay,
      filePath: dest.path,
      imageWidth: rendered.width!.toDouble(),
      imageHeight: rendered.height!.toDouble(),
      // PDF user-space is 72 pt/inch; we render at _pdfRenderScale, so the
      // raster resolution is a known DPI — needed for scale-based calibration.
      pixelsPerInch: 72.0 * _pdfRenderScale,
    ));
  }

  Future<ChartDoc> _importMbtiles(String sourcePath, String? name) async {
    final id = _newId();
    final dest = File('${_storage.chartsDir.path}/$id.mbtiles');
    await File(sourcePath).copy(dest.path);
    return _register(ChartDoc(
      id: id,
      name: name ?? _baseName(sourcePath),
      kind: ChartKind.mbtiles,
      filePath: dest.path,
    ));
  }

  Future<ChartDoc> _register(ChartDoc chart) async {
    final all = await list();
    all.add(chart);
    await _storage.saveCharts(all);
    return chart;
  }

  Future<(double, double)> _decodeSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final size = (img.width.toDouble(), img.height.toDouble());
    img.dispose();
    return size;
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  String _baseName(String path) =>
      path.split(RegExp(r'[\\/]')).last.replaceFirst(RegExp(r'\.[^.]+$'), '');
}
