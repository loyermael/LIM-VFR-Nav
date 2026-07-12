# Tester L!M VFR Nav

Guide pratique pour lancer et éprouver l'app. Vérifié avec **Flutter 3.44 stable**.

## Le plus simple : double-cliquer
- **`check.bat`** — vérifie que tout compile (`pub get` + `analyze` + `test`),
  **sans téléphone**. À lancer en premier.
- **`run.bat`** — lance l'app. Branche d'abord un téléphone Android (débogage
  USB) **ou** démarre un émulateur, puis double-clique.

(Les deux trouvent Flutter tout seuls dans `C:\flutter` ou le PATH.) Le reste de
ce guide détaille les mêmes étapes à la main.

## 0. Prérequis (une fois)
Flutter est installé dans `C:\flutter`. Le plus confortable : ajouter
`C:\flutter\bin` au **PATH** (Variables d'environnement Windows), rouvrir un
terminal. Sinon, préfixe chaque commande par le chemin complet
`C:\flutter\bin\flutter`.

```powershell
cd "C:\Users\loyer\Nextcloud\Data\13-Projet Perso\L!M VFR Nav"
flutter pub get
flutter doctor            # doit être vert pour Android ; sinon suivre les indications
```
Pour builder sur Android : `flutter doctor --android-licenses` (accepter), et
activer le **Mode développeur** Windows (`start ms-settings:developers`, requis
pour les symlinks de plugins).

## 1. Vérifs sans appareil (les plus rapides)
```powershell
flutter analyze   # attendu : 0 erreur / 0 warning (quelques lints "info")
flutter test      # attendu : 10 tests OK (units, calibration, plané, vent)
```
`flutter test` valide toute la géo/math sans téléphone.

## 2. Lancer sur un téléphone / tablette Android (cas réel)
1. Active le **débogage USB** sur l'appareil, branche-le.
2. ```powershell
   flutter devices     # l'appareil doit apparaître
   flutter run
   ```
3. Autorise la **localisation** quand l'app la demande.
Le GPS interne fournit la vraie position → importe une carte, calibre, navigue.

## 3. Simuler un vol sur émulateur (tester le mouvement sans voler)
1. Lance un émulateur Android (Device Manager d'Android Studio), puis `flutter run`.
2. Dans la barre d'outils de l'émulateur : **… (Extended controls) → Location**.
3. Onglet **Routes** ou **Import GPX/KML** → charge
   [`test_assets/spiral_lyon.gpx`](test_assets/spiral_lyon.gpx) (4 tours montants
   près de Lyon-Bron, ~85 kt) → **Play route**.
4. L'app reçoit une position **en spirale** : idéal pour éprouver tout le nav.

## 4. Scénario de test dans l'app
Avec la spirale qui joue (ou en vrai vol) :

1. **Cartes** (📄) → *Importer* → `carte_lyon_edition_01_2026.pdf` → choisir la
   **page 3** (le fond OACI) → **échelle 1:500 000** → **calibration 1 point** :
   toucher un repère connu, saisir sa lat/long (ex. Lyon-Bron ≈ `45.726 / 5.081`).
2. La carte s'affiche géoréférencée ; l'**avion** suit la trajectoire.
3. **Bandeau** : GS / TRK / ALT bougent ; après ~1 tour complet, **WIND** apparaît
   (estimation en spirale, #16).
4. **Profils avion** (✈) → crée un profil avec une **finesse** (ex. 40) et une TAS.
5. **Anneau de plané** (🪂) → active-le : l'empreinte verte se déforme sous le vent.
6. **Appui long** sur la carte → poser un **point** ; bouton **Direct-To** →
   ligne magenta + DIST/DTK/ETE + repère de virage.
7. Teste **dessin**, **mesure** (2 taps), **anneaux de distance**, **mode nuit**.

## Notes
- **Desktop/Web** ne sont pas ciblés (plugins GPS/PDF/SQLite limités) ; l'app est
  pensée pour Android/iOS.
- Sans MNT (relief), l'anneau de plané utilise l'**altitude d'arrivée** saisie
  dans ses réglages (0 = niveau mer).
