# Baut FoodSnap AI für Release – mit Gemini-Anbindung.
#
#   .\build_release.ps1 -ProxyUrl https://...   -> App Bundle für den Play Store (kein Key in der App)
#   .\build_release.ps1 -Local                  -> APKs mit Key aus .env, NUR zum Testen auf eigenen Geräten
param(
    [string]$ProxyUrl,
    [switch]$Local
)

if ($ProxyUrl) {
    flutter build appbundle --release --dart-define=GEMINI_PROXY_URL=$ProxyUrl
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
