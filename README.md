# L!M VFR Nav

An **offline VFR moving-map** for tablets and phones (Flutter, iOS + Android).
Import your own aeronautical charts (OACI PDF/scan or `.mbtiles`), georeference
them, and navigate on the live GPS position with a speed vector, distance rings,
a tap-to-measure ruler, and a freehand annotation scratchpad — all with **no
network connection required in flight**.

## Feature status

| Spec area | State |
|-----------|-------|
| Custom chart import (PDF → raster, PNG/JPG, MBTiles) | ✅ |
| Scale-based 1-point georeferencing (asks scale on import) | ✅ |
| Manual 3-point affine georeferencing | ✅ |
| Raster overlay + MBTiles tile rendering | ✅ |
| GPS position, aircraft symbol, North-Up / Track-Up | ✅ |
| Speed vector (2 / 5 / 10 min) | ✅ |
| Instrument bar (GS / TRK / ALT) | ✅ |
| Freehand geo-anchored drawing + palette/undo/erase | ✅ |
| Distance rings (aircraft- or point-centred) | ✅ |
| Tap-to-measure ruler (NM + bearing) | ✅ |
| Night mode, big buttons, fully offline | ✅ |
| Georeferenced **TIFF** import | ⚠️ convert to PNG/JPG first (no native TIFF decoder) |

## First-time setup

Built and analysed with **Flutter 3.44 (stable)**. The **android/** and **ios/**
folders (with the GPS permissions already set) are committed; desktop/web targets
are not (mobile-only) — regenerate them with `flutter create .` if ever needed.

```bash
flutter pub get
flutter analyze     # clean: 0 errors / 0 warnings (a few info-level lints)
flutter test        # 10 passing tests (units, affine georef, glide, wind)
```

## Run

```bash
flutter run                       # on a connected device/emulator
flutter run -d <deviceId>         # pick a device
flutter analyze                   # lint / static analysis
flutter test                      # unit + widget tests
flutter build apk --release       # Android release
flutter build ios --release       # iOS release (on macOS)
```

## Importing charts

Use the **Cartes** button (top of the control rail). Supported inputs: `.pdf`,
`.png`, `.jpg/.jpeg`, `.mbtiles`.

For a raster chart the app first **asks its printed scale** (e.g. 1 : 500 000,
the OACI France standard). Then the calibration screen opens in one of two modes:

- **Échelle (1 point)** — the fast path for a printed, north-up VFR sheet: zoom
  in, tap a single recognisable feature, and enter its decimal Lat/Lng. Ground
  size comes from the scale + render DPI. If the sheet isn't north-up, set the
  "cap du haut de carte".
- **3 points** — general fallback (e.g. scans of unknown scale): tap ≥ 3
  features and enter each one's Lat/Lng; a full affine is fitted.

MBTiles are already georeferenced and display immediately.
