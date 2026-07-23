# OpenAir Google Health OAuth helper (ASCII-only for Windows PowerShell 5.1)
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\setup_google_oauth.ps1

$ErrorActionPreference = "Stop"

$PackageName = "com.openair.openair"
$Sha1 = "7E:94:37:DD:EF:47:05:C0:BC:CA:7C:15:A0:98:66:C7:23:03:6A:78"
$DefaultProject = "openair-health-$([guid]::NewGuid().ToString('N').Substring(0,8))"

function Add-GcloudToPath {
  $candidates = @(
    "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin",
    "C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin"
  )
  foreach ($p in $candidates) {
    if (Test-Path (Join-Path $p "gcloud.cmd")) {
      $env:Path = "$p;" + $env:Path
      return $true
    }
  }
  return $false
}

Write-Host "=== OpenAir OAuth setup ===" -ForegroundColor Green

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  [void](Add-GcloudToPath)
}
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Google Cloud SDK (winget)..." -ForegroundColor Yellow
  winget install -e --id Google.CloudSDK --accept-package-agreements --accept-source-agreements
  [void](Add-GcloudToPath)
}
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  throw "gcloud not found. Reopen PowerShell after Cloud SDK install, then re-run this script."
}

Write-Host ""
Write-Host "A browser will open for Google sign-in." -ForegroundColor Cyan
Write-Host "Use the SAME account as Fitbit / Google Health."
Write-Host ""
gcloud auth login --brief
$account = (gcloud config get-value account 2>$null)
if ([string]::IsNullOrWhiteSpace($account) -or $account -eq "(unset)") {
  throw "Login failed - no active account."
}
Write-Host "Signed in as $account" -ForegroundColor Cyan

$ProjectId = Read-Host "Project id to create/use [$DefaultProject]"
if ([string]::IsNullOrWhiteSpace($ProjectId)) { $ProjectId = $DefaultProject }

$described = $null
try { $described = gcloud projects describe $ProjectId --format="value(projectId)" 2>$null } catch { $described = $null }
if (-not $described) {
  Write-Host "Creating project $ProjectId ..."
  gcloud projects create $ProjectId --name="OpenAir Health"
}
gcloud config set project $ProjectId | Out-Null

Write-Host "Enabling Google Health API on $ProjectId ..."
gcloud services enable health.googleapis.com --project $ProjectId

$clipboard = @"
OpenAir OAuth values
--------------------
Project: $ProjectId
Test user: $account
Android package: $PackageName
Android SHA-1: $Sha1

Scopes (Data Access):
https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly
https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly
https://www.googleapis.com/auth/googlehealth.sleep.readonly
https://www.googleapis.com/auth/googlehealth.profile.readonly

In Console:
1) Audience = Testing, then add test user
2) Data Access, then add the 4 scopes above
3) Create OAuth client - Android (package + SHA-1)
4) Create OAuth client - Web, then copy Client ID
5) OpenAir Settings, paste Web Client ID, Save, Connect
"@
Set-Clipboard -Value $clipboard
Write-Host "Copied setup values to clipboard." -ForegroundColor Green

Start-Process "https://console.cloud.google.com/apis/api/health.googleapis.com/overview?project=$ProjectId"
Start-Sleep -Milliseconds 800
Start-Process "https://console.cloud.google.com/auth/audience?project=$ProjectId"
Start-Sleep -Milliseconds 800
Start-Process "https://console.cloud.google.com/auth/scopes?project=$ProjectId"
Start-Sleep -Milliseconds 800
Start-Process "https://console.cloud.google.com/auth/clients/create?project=$ProjectId"

Write-Host ""
Write-Host "Automated portion done:" -ForegroundColor Green
Write-Host "  - Logged in as $account"
Write-Host "  - Project $ProjectId ready"
Write-Host "  - Google Health API enabled"
Write-Host "  - Console pages opened + values on clipboard"
Write-Host ""
Write-Host "Finish the browser steps, then paste the Web Client ID into OpenAir Settings."
Write-Host ""

$webId = Read-Host "Paste Web Client ID here when you have it (or Enter to skip)"
if (-not [string]::IsNullOrWhiteSpace($webId)) {
  $repoRoot = Split-Path $PSScriptRoot -Parent
  $out = Join-Path $repoRoot "oauth_web_client_id.txt"
  Set-Content -Path $out -Value $webId.Trim() -Encoding ASCII
  Write-Host "Saved $out - paste that same ID into the app. Do not commit this file." -ForegroundColor Green
}
