# L!M VFR Nav — Roadmap

## Principe directeur
Moving-map VFR **hors-ligne d'abord**, façon Avenza (« apporte ta carte »), mais
taillé pour le **vol à voile** et l'écosystème **L!M** (lien avec le vario). Toute
fonctionnalité doit rester utilisable **sans connexion en vol** ; les données
externes (aérodromes, espaces, relief) sont **embarquées/mises en cache au sol**.

## Socle livré (v0.1)
- Import cartes PDF / PNG / JPG / MBTiles, sélection de page PDF.
- Géoréférencement : **échelle + 1 point** (nord-en-haut) et **3 points** (affine).
- Carte mobile GPS : symbole avion, North-Up / Track-Up, suivi auto.
- Vecteur vitesse 2/5/10 min, bandeau GS / TRK / ALT.
- Scratchpad dessin vectoriel ancré au sol, anneaux de distance, réglette de mesure.
- Mode nuit, gros boutons, 100 % offline.

---

## Phase 1 — Quick wins (socle Avenza, sans donnée externe)
> S'appuient sur l'archi actuelle (`AnnotationState`, `LocationService`, `Units`).

- [x] **Placemarks / marqueurs perso** — appui long sur la carte → point (nom,
      note, couleur), persistés par carte, éditables, listés dans un panneau.
      `Waypoint` + `WaypointState` + `WaypointLayer`. ✅
- [ ] **Enregistrement de trace GPS** — fil d'Ariane à l'écran, export `.gpx`,
      rejeu. → bufferiser les fixes de `LocationService`.
- [x] **Direct-To un point** — depuis un placemark → ligne magenta avion→cible +
      bandeau DIST / DTK / ETE + repère de virage. `DirectToState` +
      `DirectToLayer` + `DirectToPanel`. ✅
- [ ] **Aller à une coordonnée** — saisie lat/long (décimal + DMS) → centre + marqueur.
- [ ] **Verrou écran cockpit** — bloque les interactions accidentelles en turbulence.
- [x] **Profils avion** — TAS, finesse, conso ; profil actif = source unique pour
      l'anneau de plané (#14) et le vent (#16). `AircraftProfile` + `AircraftState`
      + écran de gestion. ✅
- [ ] **Chrono & carnet de vol auto** — détection décollage/atterrissage (seuil GS),
      durée, journal local.

## Phase 2 — Différenciateurs planeur / L!M ✨
> L'identité du produit ; fort ROI vis-à-vis des apps GA généralistes.

- [x] **Anneau de plané (glide range ring)** — empreinte hauteur×finesse déformée
      par le vent (modèle "œuf"), altitude d'arrivée réglable. `glide_math.dart`
      + `GlideRingLayer` + réglages (finesse profil actif, vent manuel). Vent auto
      via #16, relief via #19. ✅
- [ ] **Lien avec le vario L!M** — recevoir Vz / vent / thermique en Wi-Fi ou BLE
      et les afficher sur la carte (nav + vario sur un écran). → cf. lm-vario-project.
- [x] **Vent estimé en vol** — fit de cercle sur les vecteurs vitesse-sol GPS en
      spirale (centre = vent, rayon = TAS). `WindEstimator` dans `NavState`,
      affiché au bandeau, alimente auto l'anneau de plané (bascule auto/manuel). ✅
- [ ] **Assistant thermique / spirale** — reprise de l'affichage de l'écran vario.

## Phase 3 — Cœur navigation VFR (dataset embarqué)
> Source : **OpenAIP** / open data SIA → base **SQLite offline** (mise à jour au sol).

- [ ] **Base aérodromes** — recherche OACI, fréquences, pistes/QFU, altitude ;
      **auto-remplit lat/long en calibration**.
- [ ] **Points de report VFR** — couche activable (obligatoires/recommandés).
- [ ] **Nearest** — terrains les plus proches, un tap = Direct-To.
- [ ] **Route multi-branches + log de nav** — waypoints → branches cap/dist/temps/ETO.
- [ ] **HSI / CDI + XTK** — écart latéral et guidage vers le point actif.
- [ ] **Import/export GPX & KML** des routes et marqueurs (interop SkyDemon / Google Earth).

## Phase 4 — Sécurité / conscience de situation
- [ ] **Alerte espaces aériens** (CTR/TMA/P/D/R) — géométries AIRAC OpenAIP.
- [ ] **Alerte relief « terrain ahead »** — MNT/DEM offline (SRTM), couleur hypsométrique.
- [ ] **Mode urgence** — plus proche terrain posable + cap direct.

## Phase 5 — Cartes & couches avancées (esprit Avenza)
- [ ] **Auto-géoréférencement GeoPDF / GeoTIFF** — lire les métadonnées de géoréf
      (le calibrage échelle/3-points devient le fallback).
- [ ] **Multi-couches** — cartes empilées, opacité, ordre.
- [ ] **Fond OSM / OpenTopo mis en cache** offline (carte de secours).

---

## Séquencement recommandé
1. Phase 1 : Placemarks + trace GPX + Direct-To (complètent le socle Avenza).
2. Phase 2 : Anneau de plané + lien vario (identité planeur).
3. Phase 3 : Base aérodromes OpenAIP (débloque Nearest, auto-coords, route).
4. Phases 4–5 selon l'appétit (sécurité, couches).

## Notes techniques
- **Datasets** : OpenAIP (aérodromes/espaces, licence à vérifier), SRTM (relief).
  Prévoir un import/téléchargement au sol → SQLite dans le stockage privé.
- **Interop** : GPX/KML pour routes & traces ; GeoPDF/GeoTIFF en entrée cartes.
- **Capteurs externes** : protocole GDL90 (ADS-B in) / FLARM pour le trafic, à
  étudier pour la Phase 2/4.
- Toujours vérifier la contrainte **offline en vol** avant d'ajouter une dépendance réseau.
