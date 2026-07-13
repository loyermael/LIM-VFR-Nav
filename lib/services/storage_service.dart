import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/aircraft_profile.dart';
import '../models/annotation.dart';
import '../models/chart.dart';
import '../models/notam.dart';
import '../models/waypoint.dart';

/// Owns all on-device persistence. On mobile/desktop everything lives in the
/// app's private documents directory so imported charts and annotations survive
/// restarts and are available fully offline.
///
/// Layout:
///   <docs>/charts.json            -> index of ChartDoc
///   <docs>/charts/<id>.png|.mbtiles
///   <docs>/annotations/<id>.json  -> strokes for that chart
///
/// On **web** there is no app document directory (path_provider is unsupported),
/// so the JSON documents are kept in an in-memory map for the session — enough
/// to run the app in a browser for testing; `shared_preferences` still works.
class StorageService {
  Directory? _root;
  late final SharedPreferences _prefs;
  final Map<String, String> _webStore = {};

  Directory get chartsDir => Directory('${_root!.path}/charts');
  Directory get annotationsDir => Directory('${_root!.path}/annotations');

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (kIsWeb) return; // no filesystem on web
    _root = await getApplicationDocumentsDirectory();
    await chartsDir.create(recursive: true);
    await annotationsDir.create(recursive: true);
  }

  // --- JSON document helpers (branch native file <-> web in-memory) --------

  Future<String?> _read(String name) async {
    if (kIsWeb) return _webStore[name];
    final f = File('${_root!.path}/$name');
    return await f.exists() ? f.readAsString() : null;
  }

  Future<void> _write(String name, String content) async {
    if (kIsWeb) {
      _webStore[name] = content;
      return;
    }
    await File('${_root!.path}/$name').writeAsString(content);
  }

  // --- Chart index ----------------------------------------------------------

  Future<List<ChartDoc>> loadCharts() async {
    final raw = await _read('charts.json');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => ChartDoc.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCharts(List<ChartDoc> charts) =>
      _write('charts.json', jsonEncode(charts.map((c) => c.toJson()).toList()));

  // --- Annotations (one file per chart) ------------------------------------

  Future<List<Stroke>> loadStrokes(String chartId) async {
    final raw = await _read('annotations/$chartId.json');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Stroke.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveStrokes(String chartId, List<Stroke> strokes) => _write(
      'annotations/$chartId.json',
      jsonEncode(strokes.map((s) => s.toJson()).toList()));

  // --- Waypoints (one file per chart) --------------------------------------

  Future<List<Waypoint>> loadWaypoints(String chartId) async {
    final raw = await _read('annotations/$chartId.waypoints.json');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Waypoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveWaypoints(String chartId, List<Waypoint> items) => _write(
      'annotations/$chartId.waypoints.json',
      jsonEncode(items.map((w) => w.toJson()).toList()));

  // --- NOTAMs (global, synced on the ground, read offline in flight) -------

  Future<List<Notam>> loadNotams() async {
    final raw = await _read('notams.json');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Notam.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveNotams(List<Notam> notams) =>
      _write('notams.json', jsonEncode(notams.map((n) => n.toJson()).toList()));

  DateTime? get notamSyncedAt {
    final s = _prefs.getString('notamSyncedAt');
    return s == null ? null : DateTime.tryParse(s);
  }

  set notamSyncedAt(DateTime? t) {
    if (t == null) {
      _prefs.remove('notamSyncedAt');
    } else {
      _prefs.setString('notamSyncedAt', t.toIso8601String());
    }
  }

  // --- Aircraft profiles (small structured settings, kept in prefs) --------

  List<AircraftProfile> loadAircraftProfiles() {
    final s = _prefs.getString('aircraftProfiles');
    if (s == null) return [];
    return (jsonDecode(s) as List)
        .map((e) => AircraftProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAircraftProfiles(List<AircraftProfile> profiles) =>
      _prefs.setString(
          'aircraftProfiles', jsonEncode(profiles.map((p) => p.toJson()).toList()));

  String? get activeAircraftId => _prefs.getString('activeAircraftId');
  set activeAircraftId(String? id) {
    if (id == null) {
      _prefs.remove('activeAircraftId');
    } else {
      _prefs.setString('activeAircraftId', id);
    }
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
