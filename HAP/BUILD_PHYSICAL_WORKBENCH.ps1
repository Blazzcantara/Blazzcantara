param(
  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [string]$OutputDir = ".\HAP\physical_workbench_out"
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
$PackBuilder = Join-Path $Root "CREATE_CALIBRATION_PACK.ps1"
$Template = Join-Path $Root "calibration\PHYSICAL_RESULTS_TEMPLATE_v0.1.csv"

if (-not (Test-Path $ArchivePath)) { throw "Archive not found: $ArchivePath" }
if (-not (Test-Path $PackBuilder)) { throw "Calibration pack builder missing." }
if (-not (Test-Path $Template)) { throw "Physical results template missing." }

$Stage = Join-Path $OutputDir "HAP_PHYSICAL_WORKBENCH_v0.1"
$PackOut = Join-Path $OutputDir "_pack_build"

if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
if (Test-Path $PackOut) { Remove-Item $PackOut -Recurse -Force }

New-Item -ItemType Directory -Force -Path $Stage | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Stage "WORK") | Out-Null
$StageResolved = (Resolve-Path $Stage).Path

$packArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $PackBuilder,
  "-ArchivePath", $ArchivePath,
  "-OutputDir", $PackOut
)
& $PowerShellExe @packArgs
if ($LASTEXITCODE -ne 0) { throw "Calibration pack build failed." }

$packDir = Join-Path $PackOut "HAP_PHYSICAL_CALIBRATION_PACK_v0.1"
if (-not (Test-Path $packDir)) { throw "Generated calibration pack directory missing." }

Copy-Item $packDir (Join-Path $Stage "CALIBRATION_PACK") -Recurse -Force
Copy-Item $Template (Join-Path $Stage "WORK\PHYSICAL_RESULTS_WORKING.csv") -Force

$files = @(
  "START_HAP_PHYSICAL.cmd",
  "PHYSICAL_WORKBENCH_MENU.ps1",
  "RUN_PHYSICAL_CAMPAIGN.ps1",
  "RECORD_PHYSICAL_RESULT.ps1",
  "NEXT_CALIBRATION_TEST.ps1",
  "BUILD_NEXT_PRINT_QUEUE.ps1",
  "BUILD_PHYSICAL_DASHBOARD.ps1",
  "REFRESH_PHYSICAL_WORKBENCH.ps1",
  "CHECK_PHYSICAL_PROGRESS.ps1",
  "SEAL_PHYSICAL_PROFILE.ps1",
  "BUILD_PHYSICAL_PILOT.ps1",
  "BUILD_NATIVE_CONNECTOR_PILOT.ps1",
  "SAVE_PHYSICAL_CHECKPOINT.ps1",
  "RESTORE_PHYSICAL_CHECKPOINT.ps1"
)

foreach ($name in $files) {
  $src = Join-Path $Root $name
  if (-not (Test-Path $src)) { throw "Workbench file missing: $src" }
  Copy-Item $src (Join-Path $Stage $name) -Force
}

$cadDir = Join-Path $Stage "cad"
New-Item -ItemType Directory -Force -Path $cadDir | Out-Null
foreach ($name in @(
  "HAP_MASTER_v0.1.scad",
  "DONOR_NATIVE_CONNECTOR_v0.1.scad"
)) {
  $src = Join-Path $Root ("cad\" + $name)
  if (-not (Test-Path $src)) { throw "Workbench CAD file missing: $src" }
  Copy-Item $src (Join-Path $cadDir $name) -Force
}

$toolsDir = Join-Path $Stage "tools"
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
Copy-Item (Join-Path $Root "tools\STL_COMPONENT_AUDIT.py") $toolsDir -Force

$calDir = Join-Path $Stage "calibration"
New-Item -ItemType Directory -Force -Path $calDir | Out-Null
foreach ($name in @(
  "PHYSICAL_RESULTS_TEMPLATE_v0.1.csv",
  "CALIBRATION_CAMPAIGN_v0.1.md",
  "CALIBRATION_PLATE_PLAN_v0.1.csv",
  "KOBRA_S1_CALIBRATION_PROFILE_v0.1.md"
)) {
  Copy-Item (Join-Path $Root ("calibration\" + $name)) (Join-Path $calDir $name) -Force
}

$quick = @"
# HAP Physical Workbench v0.1

## Start

Double-click:

    START_HAP_PHYSICAL.cmd

or run:

    PowerShell -ExecutionPolicy Bypass -File .\RUN_PHYSICAL_CAMPAIGN.ps1 -ArchivePath "C:\Path\To\lego-umbau.zip" -WorkDir ".\WORK"

## Normal loop

1. Print only the next recommended calibration STL.
2. Test it against the real mating part.
3. Record the result with RECORD_PHYSICAL_RESULT.ps1.
4. Re-run RUN_PHYSICAL_CAMPAIGN.ps1.
5. Use BUILD_NEXT_PRINT_QUEUE.ps1 when you want a folder containing only the next required STL files.
6. Use BUILD_PHYSICAL_DASHBOARD.ps1 for a human-readable progress dashboard.
7. Use SAVE_PHYSICAL_CHECKPOINT.ps1 before major changes.

The workbench never auto-passes a physical test.
"@
Set-Content -Encoding UTF8 -Path (Join-Path $Stage "00_READ_ME_FIRST.md") -Value $quick

$queueArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", (Join-Path $Stage "BUILD_NEXT_PRINT_QUEUE.ps1"),
  "-CalibrationPackDir", (Join-Path $Stage "CALIBRATION_PACK"),
  "-ResultsCsv", (Join-Path $Stage "WORK\PHYSICAL_RESULTS_WORKING.csv"),
  "-OutputDir", (Join-Path $Stage "WORK\NEXT_PRINT_QUEUE")
)
& $PowerShellExe @queueArgs
if ($LASTEXITCODE -ne 0) { throw "Initial next-print queue build failed." }

$dashArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", (Join-Path $Stage "BUILD_PHYSICAL_DASHBOARD.ps1"),
  "-CalibrationResultsCsv", (Join-Path $Stage "WORK\PHYSICAL_RESULTS_WORKING.csv"),
  "-OutputDir", (Join-Path $Stage "WORK\DASHBOARD")
)
& $PowerShellExe @dashArgs
if ($LASTEXITCODE -ne 0) { throw "Initial dashboard build failed." }

$manifest = foreach ($file in (Get-ChildItem $Stage -Recurse -File | Sort-Object FullName)) {
  $relative = $file.FullName.Substring($StageResolved.Length).TrimStart([char[]]"\/")
  [pscustomobject]@{
    relative_path = $relative
    size_bytes = $file.Length
    sha256 = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant()
  }
}
$manifestPath = Join-Path $Stage "WORKBENCH_MANIFEST.csv"
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestPath

$zipPath = Join-Path $OutputDir "HAP_PHYSICAL_WORKBENCH_v0.1.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $zipPath

$zipHash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()
"$zipHash  HAP_PHYSICAL_WORKBENCH_v0.1.zip" |
  Set-Content -Encoding ASCII -Path ($zipPath + ".sha256")

Write-Host ""
Write-Host "PASS: HAP physical workbench generated" -ForegroundColor Green
Write-Host "Files: $($manifest.Count)"
Write-Host "ZIP: $zipPath"
Write-Host "SHA256: $zipHash"
Write-Host "Reality: operator tooling ready; physical evidence still required" -ForegroundColor Yellow
