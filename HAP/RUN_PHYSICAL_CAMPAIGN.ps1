param(
  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [string]$WorkDir = ".\HAP\physical_campaign_work",

  [switch]$SkipPackBuild
)

$ErrorActionPreference = "Stop"
$PowerShellExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
  (Get-Command pwsh).Source
}
elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
  (Get-Command powershell).Source
}
else {
  throw "PowerShell executable not found."
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$CreatePack = Join-Path $Root "CREATE_CALIBRATION_PACK.ps1"
$Template = Join-Path $Root "calibration\PHYSICAL_RESULTS_TEMPLATE_v0.1.csv"
$Advisor = Join-Path $Root "NEXT_CALIBRATION_TEST.ps1"
$Progress = Join-Path $Root "CHECK_PHYSICAL_PROGRESS.ps1"
$Sealer = Join-Path $Root "SEAL_PHYSICAL_PROFILE.ps1"
$PilotBuilder = Join-Path $Root "BUILD_PHYSICAL_PILOT.ps1"

$requiredFiles = @(
  $ArchivePath,
  $Template,
  $Advisor,
  $Progress,
  $Sealer,
  $PilotBuilder
)

if (-not $SkipPackBuild) {
  $requiredFiles += $CreatePack
}

foreach ($required in $requiredFiles) {
  if (-not (Test-Path $required)) {
    throw "Required file not found: $required"
  }
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

$ResultsCsv = Join-Path $WorkDir "PHYSICAL_RESULTS_WORKING.csv"
$ProfileJson = Join-Path $WorkDir "PHYSICAL_PROFILE_v0.1.json"
$PilotOut = Join-Path $WorkDir "pilot"

if (-not (Test-Path $ResultsCsv)) {
  Copy-Item $Template $ResultsCsv
  Write-Host "Created working results file: $ResultsCsv" -ForegroundColor Cyan
}

if (-not $SkipPackBuild) {
  $PackOut = Join-Path $WorkDir "calibration_pack"

  $packArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $CreatePack,
    "-ArchivePath", $ArchivePath,
    "-OutputDir", $PackOut
  )

  & $PowerShellExe @packArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Calibration pack build failed."
  }
}

Write-Host ""
Write-Host "=== NEXT RECOMMENDED PHYSICAL TESTS ===" -ForegroundColor Cyan
& $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Advisor -ResultsCsv $ResultsCsv
if ($LASTEXITCODE -ne 0) {
  throw "Calibration advisor failed."
}

Write-Host ""
Write-Host "=== PHYSICAL GATE PROGRESS ===" -ForegroundColor Cyan
& $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Progress -ResultsCsv $ResultsCsv
$progressExit = $LASTEXITCODE

if ($progressExit -eq 0) {
  Write-Host ""
  Write-Host "All five interface gates are ready. Sealing real physical profile..." -ForegroundColor Green

  $sealArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $Sealer,
    "-ResultsCsv", $ResultsCsv,
    "-OutputJson", $ProfileJson
  )
  & $PowerShellExe @sealArgs

  if ($LASTEXITCODE -ne 0) {
    throw "Physical profile sealing failed."
  }

  $pilotArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $PilotBuilder,
    "-ProfileJson", $ProfileJson,
    "-ArchivePath", $ArchivePath,
    "-OutputDir", $PilotOut
  )
  & $PowerShellExe @pilotArgs

  if ($LASTEXITCODE -ne 0) {
    throw "Physical pilot package build failed."
  }

  Write-Host ""
  Write-Host "PASS: physical campaign promoted to the system pilot." -ForegroundColor Green
  Write-Host "Profile: $ProfileJson"
  Write-Host ("Pilot  : " + (Join-Path $PilotOut "HAP_PHYSICAL_PILOT_READY_v0.1.zip"))
  exit 0
}

if ($progressExit -eq 2) {
  Write-Host ""
  Write-Host "HOLD: more real fit tests are required." -ForegroundColor Yellow
  Write-Host "Record each result with HAP\RECORD_PHYSICAL_RESULT.ps1, then run this command again."
  Write-Host "Working CSV: $ResultsCsv"
  exit 0
}

throw "Physical progress checker failed with exit code $progressExit."
