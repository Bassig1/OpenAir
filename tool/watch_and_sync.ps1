# Waits for tool/oauth_client.json, then syncs Google Health → diagnostics/latest.json
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -ErrorAction SilentlyContinue
if (-not $root) { $root = "C:\Users\gurja\Projects\OpenAir" }
# PSScriptRoot is tool/ → repo root is parent
$root = Split-Path $PSScriptRoot -Parent
$client = Join-Path $root "tool\oauth_client.json"
$out = Join-Path $root "diagnostics\latest.json"

Write-Host "OpenAir auto-sync"
Write-Host "Waiting for Desktop OAuth client at:"
Write-Host "  $client"
Write-Host ""
Write-Host "Create it here (Desktop app), download JSON, save as oauth_client.json:"
Write-Host "  https://console.cloud.google.com/auth/clients/create?project=vibrant-petal-503305-b8"
Start-Process "https://console.cloud.google.com/auth/clients/create?project=vibrant-petal-503305-b8"

$deadline = (Get-Date).AddMinutes(15)
while (-not (Test-Path $client)) {
  if ((Get-Date) -gt $deadline) {
    Write-Error "Timed out waiting for oauth_client.json"
    exit 1
  }
  Start-Sleep -Seconds 3
}

Write-Host "Found oauth_client.json — starting browser consent + Health sync..."
python (Join-Path $root "tool\sync_google_health.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (Test-Path $out) {
  Write-Host ""
  Write-Host "Validating dump..."
  dart run (Join-Path $root "tool\validate_diagnostic.dart") $out
  Write-Host ""
  Write-Host "Done. Paste diagnostics/latest.json into Cursor or say: review the dump."
}
