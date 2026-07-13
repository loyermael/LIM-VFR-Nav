@echo off
REM ============================================================
REM  L!M VFR Nav - lancer l'app dans Chrome (sur le PC)
REM  Aucun telephone requis. La 1re compilation prend 1-2 min,
REM  puis Chrome s'ouvre tout seul. Autorisez la localisation.
REM  Apercu rapide : l'import de carte est desactive sur le web,
REM  le GPS est la position (fixe) du PC ; fond de carte OSM.
REM ============================================================
setlocal
cd /d "%~dp0"

set "FLUTTER=flutter"
where flutter >nul 2>nul || set "FLUTTER=C:\flutter\bin\flutter.bat"

echo.
echo === Lancement dans Chrome (release) ===
echo (Compilation la 1re fois, patientez...)
echo Fermez l'onglet Chrome ou tapez "q" ici pour arreter.
echo.
call "%FLUTTER%" run -d chrome --release

echo.
pause
exit /b 0
