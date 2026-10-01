# Baut FoodSnap AI für Release – mit Gemini-Anbindung.
#
#   .\build_release.ps1 -ProxyUrl https://...   -> App Bundle für den Play Store (kein Key in der App)
#   .\build_release.ps1 -Local                  -> APKs mit Key aus .env, NUR zum Testen auf eigenen Geräten
param(
    [string]$ProxyUrl,
    [switch]$Local
)

if ($ProxyUrl) {
    # Obfuscation + ausgelagerte Debug-Symbole: ~0,7 MB kleinerer Download.
    # Symbole pro Version AUFBEWAHREN - nur damit lassen sich Absturzberichte lesen:
    #   flutter symbolize -i <stacktrace.txt> -d release_symbols/<version>/app.android-arm64.symbols
    $version = (Select-String -Path "$PSScriptRoot\pubspec.yaml" -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
    flutter build appbundle --release --dart-define=GEMINI_PROXY_URL=$ProxyUrl --obfuscate --split-debug-info="release_symbols/$version"
    Write-Host "Debug-Symbole liegen in release_symbols/$version - sichern, nicht loeschen!"
}
elseif ($Local) {
    if (-not (Test-Path "$PSScriptRoot\.env")) {
        Write-Error ".env fehlt (GEMINI_API_KEY=...)."
        exit 1
    }
    flutter build apk --release --split-per-abi --dart-define-from-file=.env
    Write-Warning "Diese APKs enthalten den Gemini-Key. NICHT in den Play Store hochladen!"
}
else {
    Write-Error "Bitte -ProxyUrl <url> (Play Store) oder -Local (Test mit .env) angeben. Ohne eines davon funktioniert die KI-Analyse nicht."
    exit 1
}
