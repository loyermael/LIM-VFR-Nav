import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/chart.dart';
import '../../state/annotation_state.dart';
import '../../state/chart_state.dart';
import '../../state/nav_state.dart';
import '../../state/tools_state.dart';
import '../../state/waypoint_state.dart';
import '../../state/notam_state.dart';
import '../../widgets/big_button.dart';
import '../dashboard/instrument_bar.dart';
import '../drawing/drawing_layer.dart';
import '../drawing/drawing_toolbar.dart';
import '../measure/measure_layer.dart';
import '../import/chart_import_screen.dart';
import '../waypoints/waypoint_editor.dart';
import '../waypoints/waypoint_layer.dart';
import '../navigation/direct_to_layer.dart';
import '../navigation/direct_to_panel.dart';
import '../navigation/glide_ring_layer.dart';
import '../navigation/glide_settings.dart';
import '../aircraft/aircraft_screen.dart';
import '../notam/notam_layer.dart';
import '../notam/notam_timeline.dart';
import '../notam/notam_alert.dart';
import '../notam/notam_screen.dart';
import '../notam/notam_sheet.dart';
import 'aircraft_layer.dart';
import 'chart_layer.dart';
import 'distance_rings_layer.dart';

/// The single in-flight screen: the moving map plus every overlay
/// (chart, rings, annotations, ruler, aircraft) and the control rail.
///
/// It owns the [MapController] and drives camera follow/rotation from GPS. It
/// also keeps the annotation layer pointed at whichever chart is active.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  NavState? _nav;
  String? _loadedChartId;
  bool _mapReady = false;

  static const LatLng _defaultCenter = LatLng(46.6, 2.4); // metropolitan France

  @override
  void initState() {
    super.initState();
    // Drive camera follow from GPS without rebuilding the whole tree per fix.
    _nav = context.read<NavState>()..addListener(_followAircraft);
  }

  @override
  void dispose() {
    _nav?.removeListener(_followAircraft);
    _map.dispose();
    super.dispose();
  }

  void _followAircraft() {
    if (!_mapReady) return;
    final nav = _nav!;
    final tools = context.read<ToolsState>();
    final pos = nav.flight.position;
    // Don't fight the pilot while they draw/measure, and only follow if asked.
    if (pos == null || !nav.followAircraft || tools.mapInteractionFrozen) return;
    _map.moveAndRotate(pos, _map.camera.zoom, nav.mapRotation);
  }

  LatLng _initialCenter(ChartDoc? chart) {
    final corners = chart?.corners;
    if (corners != null) {
      return LatLng(
        (corners.topLeft.latitude + corners.bottomRight.latitude) / 2,
        (corners.topLeft.longitude + corners.bottomRight.longitude) / 2,
      );
    }
    return _nav?.flight.position ?? _defaultCenter;
  }

  void _syncActiveChartLayers(ChartDoc? active) {
    if (active?.id == _loadedChartId) return;
    _loadedChartId = active?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (active != null && mounted) {
        context.read<AnnotationState>().loadForChart(active.id);
        context.read<WaypointState>().loadForChart(active.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chartState = context.watch<ChartState>();
    final tools = context.watch<ToolsState>();
    final active = chartState.active;
    _syncActiveChartLayers(active);

    final chartLayer = active != null ? buildChartLayer(active) : null;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _initialCenter(active),
              initialZoom: active?.corners != null ? 10 : 6,
              minZoom: 3,
              maxZoom: 18,
              backgroundColor: Theme.of(context).colorScheme.surface,
              onMapReady: () => _mapReady = true,
              // Long-press drops a placemark (disabled while a tool owns gestures).
              onLongPress: (_, latlng) {
                if (!tools.mapInteractionFrozen) {
                  showWaypointEditor(context, at: latlng);
                }
              },
              // Freeze pan/zoom so draw/measure gestures reach their tool.
              interactionOptions: InteractionOptions(
                flags: tools.mapInteractionFrozen
                    ? InteractiveFlag.none
                    : InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Online OSM base map for context (blank when offline; the
              // imported chart draws on top). Offline nav still works without it.
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lim.vfrnav',
                maxZoom: 19,
              ),
              if (chartLayer != null) chartLayer,
              const GlideRingLayer(),
              const DistanceRingsLayer(),
              const StrokesLayer(),
              WaypointLayer(
                onEdit: (w) => showWaypointEditor(context, existing: w),
              ),
              const DirectToLayer(),
              NotamLayer(
                onSelect: (notams) => showNotamDetails(context, notams),
              ),
              const MeasureLayer(),
              const SpeedVectorLayer(),
              const AircraftMarkerLayer(),
              // Gesture catchers on top; each is inert unless its tool is on.
              const DrawingGestureLayer(),
              const MeasureGestureLayer(),
            ],
          ),

          // Instrument strip + Direct-To banner + NOTAM alert (top).
          const Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InstrumentBar(),
                DirectToPanel(),
                NotamAlert(),
              ],
            ),
          ),

          // "No chart" hint.
          if (active == null) _noChartHint(context),
          if (active != null && !active.isCalibrated) _needsCalibrationHint(context),

          // Control rail (right).
          Align(
            alignment: Alignment.centerRight,
            child: _controlRail(context, tools),
          ),

          // Bottom stack: drawing palette (while drawing) + NOTAM timeline.
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tools.isDrawing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: DrawingToolbar(),
                  ),
                const NotamTimeline(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlRail(BuildContext context, ToolsState tools) {
    final nav = context.watch<NavState>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BigButton(
                icon: Icons.map_outlined,
                tooltip: 'Cartes',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChartImportScreen()),
                ),
              ),
              BigButton(
                icon: Icons.flight,
                tooltip: 'Profils avion',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AircraftScreen()),
                ),
              ),
            BigButton(
              icon: nav.followAircraft
                  ? Icons.my_location
                  : Icons.location_searching,
              tooltip: 'Suivre l\'avion',
              active: nav.followAircraft,
              onPressed: () => nav.setFollow(!nav.followAircraft),
            ),
            BigButton(
              icon: Icons.navigation_outlined,
              tooltip: 'Track-Up / North-Up',
              active: nav.trackUp,
              onPressed: nav.toggleTrackUp,
            ),
            BigButton(
              icon: Icons.push_pin_outlined,
              tooltip: 'Points / marqueurs',
              onPressed: () => showWaypointList(
                context,
                onSelect: (w) {
                  if (_mapReady) _map.move(w.position, _map.camera.zoom);
                },
              ),
            ),
            BigButton(
              icon: Icons.gesture,
              tooltip: 'Dessiner',
              active: tools.isDrawing,
              onPressed: () => tools.setTool(ActiveTool.draw),
            ),
            BigButton(
              icon: Icons.straighten,
              tooltip: 'Mesurer',
              active: tools.isMeasuring,
              onPressed: () => tools.setTool(ActiveTool.measure),
            ),
            BigButton(
              icon: Icons.track_changes,
              tooltip: 'Anneaux de distance',
              active: tools.ringsEnabled,
              onPressed: tools.toggleRings,
            ),
            BigButton(
              icon: Icons.paragliding,
              tooltip: 'Anneau de plané',
              active: tools.glideRingEnabled,
              onPressed: () => showGlideSettings(context),
            ),
            BigButton(
              icon: Icons.warning_amber,
              tooltip: 'NOTAM',
              active: context.watch<NotamState>().visible &&
                  context.watch<NotamState>().count > 0,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotamScreen()),
              ),
            ),
            BigButton(
              icon: tools.nightMode ? Icons.dark_mode : Icons.light_mode,
              tooltip: 'Mode nuit',
              active: tools.nightMode,
              onPressed: tools.toggleNightMode,
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _noChartHint(BuildContext context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Aucune carte importée'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ChartImportScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Importer une carte'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _needsCalibrationHint(BuildContext context) => const Align(
        alignment: Alignment.bottomLeft,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Card(
              color: Colors.orange,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Text('Carte non calibrée — ouvrez les Cartes pour la géoréférencer'),
              ),
            ),
          ),
        ),
      );
}
