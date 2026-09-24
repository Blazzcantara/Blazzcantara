param(
  [string]$WorkbenchDir = "."
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

$Root = (Resolve-Path $WorkbenchDir).Path
$ResultsCsv = Join-Path $Root "WORK\PHYSICAL_RESULTS_WORKING.csv"
$CalibrationPack = Join-Path $Root "CALIBRATION_PACK"
$QueueBuilder = Join-Path $Root "BUILD_NEXT_PRINT_QUEUE.ps1"
$DashboardBuilder = Join-Path $Root "BUILD_PHYSICAL_DASHBOARD.ps1"

foreach ($required in @($ResultsCsv,$CalibrationPack,$QueueBuilder,$DashboardBuilder)) {
  if (-not (Test-Path $required)) { throw "Workbench file missing: $required" }
}

$queueOut = Join-Path $Root "WORK\NEXT_PRINT_QUEUE"
$dashOut = Join-Path $Root "WORK\DASHBOARD"

$queueArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $QueueBuilder,
  "-CalibrationPackDir", $CalibrationPack,
  "-ResultsCsv", $ResultsCsv,
  "-OutputDir", $queueOut
)
& $PowerShellExe @queueArgs
if ($LASTEXITCODE -ne 0) { throw "Next print queue refresh failed." }

$pilot = Join-Path $Root "WORK\PILOT_RESULTS_WORKING.csv"
$structural = Join-Path $Root "WORK\STRUCTURAL_RESULTS_WORKING.csv"
$show = Join-Path $Root "WORK\SHOW_RESULTS_WORKING.csv"

$dashArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $DashboardBuilder,
  "-CalibrationResultsCsv", $ResultsCsv,
  "-OutputDir", $dashOut
)

if (Test-Path $pilot) { $dashArgs += @("-PilotResultsCsv",$pilot) }
if (Test-Path $structural) { $dashArgs += @("-StructuralResultsCsv",$structural) }
if (Test-Path $show) { $dashArgs += @("-ShowResultsCsv",$show) }

& $PowerShellExe @dashArgs
if ($LASTEXITCODE -ne 0) { throw "Physical dashboard refresh failed." }

Write-Host ""
Write-Host "PASS: workbench refreshed" -ForegroundColor Green
Write-Host "Next queue: $queueOut"
Write-Host "Dashboard : $dashOut"
