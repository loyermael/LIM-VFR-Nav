@echo off
REM ============================================================
REM  L!M VFR Nav - lancer l'app
REM  Branchez un telephone Android (debogage USB) OU demarrez
REM  un emulateur, PUIS double-cliquez ce fichier.
REM ============================================================
setlocal
cd /d "%~dp0"

set "FLUTTER=flutter"
where flutter >nul 2>nul || set "FLUTTER=C:\flutter\bin\flutter.bat"

echo.
echo === Recuperation des dependances (pub get) ===
call "%FLUTTER%" pub get || goto :err

echo.
echo === Appareils detectes ===
call "%FLUTTER%" devices

echo.
echo === Lancement de l'app (flutter run) ===
echo (Si "No devices found" : branchez un telephone ou lancez un emulateur, puis relancez.)
echo Dans la fenetre : appuyez sur "r" pour recharger, "q" pour quitter.
echo.
call "%FLUTTER%" run

echo.
pause
exit /b 0

:err
echo.
echo ECHEC : Flutter introuvable ou pub get en erreur.
echo Verifiez que Flutter est installe dans C:\flutter ou dans le PATH.
pause
exit /b 1
