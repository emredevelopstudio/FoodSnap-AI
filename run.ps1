# Startet FoodSnap AI immer MIT Gemini-Key aus .env (ohne Key: "KI nicht konfiguriert").
# Nutzung:  .\run.ps1            -> Debug auf dem verbundenen Handy
#           .\run.ps1 -Release   -> Release auf dem verbundenen Handy
param([switch]$Release)

if (-not (Test-Path "$PSScriptRoot\.env")) {
    Write-Error ".env fehlt. Lege sie mit GEMINI_API_KEY=... im Projektordner an (siehe .env.example)."
    exit 1
}

$mode = if ($Release) { "--release" } else { "--debug" }
flutter run $mode --dart-define-from-file=.env
