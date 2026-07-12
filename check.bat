@echo off
REM ============================================================
REM  L!M VFR Nav - verification (sans telephone)
REM  Double-cliquez pour lancer analyze + tests.
REM ============================================================
setlocal
cd /d "%~dp0"

set "FLUTTER=flutter"
where flutter >nul 2>nul || set "FLUTTER=C:\flutter\bin\flutter.bat"

echo.
echo === Recuperation des dependances (pub get) ===
call "%FLUTTER%" pub get || goto :err

echo.
echo === Analyse statique (analyze) ===
call "%FLUTTER%" analyze

echo.
echo === Tests unitaires (test) ===
call "%FLUTTER%" test

echo.
echo Termine.
pause
exit /b 0

:err
echo.
echo ECHEC : Flutter introuvable ou pub get en erreur.
echo Verifiez que Flutter est installe dans C:\flutter ou dans le PATH.
pause
exit /b 1
