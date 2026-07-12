import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/annotation.dart';
import '../models/chart.dart';

/// Owns all on-device persistence. Everything lives in the app's private
/// documents directory so imported charts and annotations survive restarts and
/// are available fully offline.
///
/// Layout:
///   <docs>/charts.json            -> index of ChartDoc
///   <docs>/charts/<id>.png|.mbtiles
///   <docs>/annotations/<id>.json  -> strokes for that chart
class StorageService {
  late final Directory _root;
  late final SharedPreferences _prefs;

  Directory get chartsDir => Directory('${_root.path}/charts');
  Directory get annotationsDir => Directory('${_root.path}/annotations');
  File get _indexFile => File('${_root.path}/charts.json');

  Future<void> init() async {
    _root = await getApplicationDocumentsDirectory();
    _prefs = await SharedPreferences.getInstance();
    await chartsDir.create(recursive: true);
    await annotationsDir.create(recursive: true);
  }

  // --- Chart index ----------------------------------------------------------

  Future<List<ChartDoc>> loadCharts() async {
    if (!await _indexFile.exists()) return [];
    final raw = jsonDecode(await _indexFile.readAsString()) as List;
    return raw
        .map((e) => ChartDoc.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCharts(List<ChartDoc> charts) async {
    await _indexFile.writeAsString(
      jsonEncode(charts.map((c) => c.toJson()).toList()),
    );
  }

  // --- Annotations (one file per chart) ------------------------------------

  Future<List<Stroke>> loadStrokes(String chartId) async {
    final f = File('${annotationsDir.path}/$chartId.json');
    if (!await f.exists()) return [];
    final raw = jsonDecode(await f.readAsString()) as List;
    return raw.map((e) => Stroke.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveStrokes(String chartId, List<Stroke> strokes) async {
    final f = File('${annotationsDir.path}/$chartId.json');
    await f.writeAsString(jsonEncode(strokes.map((s) => s.toJson()).toList()));
  }

  // --- Small settings -------------------------------------------------------

  String? get lastChartId => _prefs.getString('lastChartId');
  set lastChartId(String? id) {
    if (id == null) {
      _prefs.remove('lastChartId');
    } else {
      _prefs.setString('lastChartId', id);
    }
  }

  bool get nightMode => _prefs.getBool('nightMode') ?? false;
  set nightMode(bool v) => _prefs.setBool('nightMode', v);
}
