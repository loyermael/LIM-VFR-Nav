# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

L!M VFR Nav — an offline VFR moving-map (Flutter, iOS + Android) that renders
pilot-imported aeronautical charts and navigates on live GPS. Everything must
keep working with **no network** once a chart is imported; never add a code path
that requires connectivity for the in-flight map.

## Commands

```bash
flutter create .              # ONE-TIME: generates android/ios/... (not committed); safe, won't touch lib/
flutter pub get               # install deps
flutter run                   # run on device/emulator
flutter analyze               # lint (rules in analysis_options.yaml)
flutter test                  # all tests
flutter test test/foo_test.dart               # a single test file
flutter test --plain-name "affine fit"        # a single test by name
flutter build apk --release   # Android; build ios --release on macOS
```

Platform folders (`android/`, `ios/`) are intentionally not in the repo — run
`flutter create .` first, then add location permissions (see README). There is
no CI and no committed `pubspec.lock`.

## Architecture

### State (provider / ChangeNotifier), wired in `lib/main.dart`
Four notifiers, each owns one concern — read them to understand app behaviour:
- **`NavState`** (`state/nav_state.dart`) — subscribes to the GPS stream, holds
  the latest `FlightState`, and owns `followAircraft` / `trackUp`. `mapRotation`
  (= `-track` in Track-Up) is the single source of truth for map + icon rotation.
  Also feeds each fix to a `WindEstimator` (`core/wind_estimator.dart`) and
  exposes `wind` — a circle-fit wind estimate from GPS while circling (#16),
  shown in the instrument bar and consumed by the glide ring.
- **`ChartState`** — the imported-chart library and which `ChartDoc` is active.
- **`AnnotationState`** — scratchpad strokes for the active chart + pen settings;
  persists per-chart on every mutation.
- **`WaypointState`** — placemarks for the active chart (long-press to add via
  `waypoints/waypoint_editor.dart`, rendered by `WaypointLayer`); same
  per-chart load/persist pattern as `AnnotationState`. `MapScreen`'s
  `_syncActiveChartLayers` loads both when the active chart changes.
- **`DirectToState`** — ephemeral (non-persisted) active Direct-To target set
  from the waypoint editor/list. `DirectToLayer` draws the magenta course line;
  `DirectToPanel` derives DIST/DTK/ETE + turn cue live from `NavState.flight`.
- **`NotamState`** — synced NOTAMs + view controls (map visibility, timeline
  "flight time"). `core/notam_parser.dart` decodes the **Q-line** geometry
  (`4523N00450E005` → centre+radius); `notam_filter.dart` keeps VFR-relevant
  ones; `notam/notam_layer.dart` draws zones (translucent circles) + aerodrome
  flags; `notam/notam_alert.dart` runs the 3-min intrusion warning off
  `NavState` fixes. Sources in `services/notam_source.dart` (HTTP + bundled
  sample); persisted globally via `StorageService.loadNotams/saveNotams`.
- **`AirspaceState`** — airspace set (bundled sample) + toggles (draw on map,
  show vertical profile). `core/airspace_geo.dart` holds the two key algorithms:
  `verticalProfile` (path samples → distance/altitude boxes per airspace crossed)
  and `detectThreats` (inside / imminent within look-ahead, at the aircraft's
  level). `core/geometry.dart` has point-in-polygon + segment intersection.
  `airspace/vertical_profile.dart` is the retractable bottom panel (blinks red on
  penetration); `airspace/airspace_layer.dart` draws footprints. Airfield info
  (long-press → `info/point_info.dart`) and the nav log (`navlog/nav_log.dart`,
  magnetic via `core/magnetic.dart`) round out the SDVFR-style tools.
- **`AircraftState`** — saved `AircraftProfile`s + the active one, persisted in
  `shared_preferences` (not a per-chart file). The active profile is the single
  source of TAS / glide ratio / fuel for the glide ring (#14), wind (#16), etc.
  Managed in `aircraft/aircraft_screen.dart`.
- **`ToolsState`** — night mode, the active tool (`none`/`draw`/`measure`),
  distance-ring config, the ruler `Measurement`, and the glide-ring config
  (enabled, arrival altitude, manual wind). The glide footprint is computed by
  `core/glide_math.dart` and drawn by `navigation/glide_ring_layer.dart` using
  the active aircraft's glide ratio + TAS (manual wind until #16, arrival alt
  until terrain/DEM in #19).

`MapScreen` is the only screen. It owns the `MapController`, drives camera
follow/rotation via a `NavState` listener (not rebuilds), and keeps
`AnnotationState` pointed at the active chart.

### Coordinate strategy — the most important thing to know
The app deliberately **avoids manual forward (LatLng→screen) projection** because
those flutter_map APIs churn across versions. Instead:
- All overlays that could be manual painting are expressed as flutter_map layers
  that take **LatLng** and re-project themselves every frame: strokes and the
  ruler are `PolylineLayer`s, rings are a `CircleLayer` (`useRadiusInMeter`), the
  aircraft/speed-vector/labels are `MarkerLayer`/`PolylineLayer`. This is what
  keeps annotations "vector, anchored to the ground" through pan/zoom/rotate.
- The **only** screen→geographic conversion is `MapCamera.offsetToCrs(offset)`,
  used in exactly two gesture catchers: `drawing/drawing_layer.dart` and
  `measure/measure_layer.dart`. If you bump `flutter_map` and projection breaks,
  those two files are the only place to fix.

### Georeferencing pipeline (raster charts)
`import → calibrate → overlay`:
1. `ChartRepository` (`services/chart_repository.dart`) imports a source file:
   PDF is rasterised to PNG via `pdfx`; PNG/JPG copied; `.mbtiles` copied. Result
   is a `ChartDoc` with pixel dimensions but no georef yet.
2. `CalibrationScreen` supports **two modes** (`_CalMode`):
   - **Scale mode** (default for PDFs): import asks the printed scale
     (`scale_dialog.dart`, stored as `ChartDoc.scaleDenominator`). Ground metres
     per pixel = `0.0254 * scale / pixelsPerInch` (DPI is known because we render
     PDFs at a fixed density — `pixelsPerInch = 72 * _pdfRenderScale`). The pilot
     places **one** anchor point; `AffineGeoref.fromScaleAnchor()` builds the
     transform assuming north-up (optional heading for rotated sheets).
   - **3-point mode** (general / image scans of unknown scale): ≥3
     `CalibrationPoint`s → `AffineGeoref.fit()` least-squares affine.
   Pixel capture in both: `InteractiveViewer(constrained:false)` +
   `TransformationController.toScene()` returns image-pixel coords when the child
   is sized to the exact image dimensions.
3. `cornersFor(w,h)` yields the 3 corners fed to flutter_map's
   `RotatedOverlayImage` — an affine transform is exactly representable by it,
   which is why the overlay path uses it. `supportsScaleCalibration` /
   `metersPerPixelFromScale` on `ChartDoc` gate the scale path (need scale + DPI).

MBTiles skip calibration (natively tiled). `chart_layer.dart` serves them via a
custom `MbtilesTileProvider` reading tile blobs straight from the SQLite file —
note the **XYZ→TMS Y-flip** (`(1<<z)-1-y`).

### Rendering & gesture rules (in `MapScreen.build` children order)
Layers are stacked chart → rings → strokes → measure → speed vector → aircraft →
gesture catchers (last, on top). While a tool is active, `ToolsState.mapInteractionFrozen`
disables map pan/zoom (`InteractiveFlag.none`) so the gesture reaches the tool;
each gesture catcher shrinks to `SizedBox.shrink()` when its tool is off, letting
gestures fall through to the map. Only one tool is active at a time (`setTool`
toggles). Camera follow is suppressed while frozen so it can't fight the pilot.

### Units & conventions
`core/units.dart` centralises all conversions and great-circle math (haversine
distance, true bearing, `destination()` for the speed vector and ring labels).
GPS arrives in SI (m, m/s); the UI shows aviation units (NM, kt, ft, 3-digit
bearings). Bearings are **TRUE** throughout — there is no magnetic-variation
model yet, so don't present a value as magnetic.

## Gotchas
- Georeferenced **TIFF** is not decodable by Flutter's image pipeline — convert to
  PNG/JPG before import (the importer rejects `.tif`).
- Stroke width is stored in logical pixels (constant on-screen thickness), not
  metres — intentional, so a highlight stays legible at every zoom.
- `assets/icons/` must exist (declared in `pubspec.yaml`); keep the `.gitkeep`.
