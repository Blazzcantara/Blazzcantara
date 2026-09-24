param(
  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [string]$OutputDir = ".\HAP\calibration_out"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildAll = Join-Path $Root "BUILD_ALL.ps1"
$NativeBuilder = Join-Path $Root "BUILD_NATIVE_CONNECTOR_PILOT.ps1"
$CoreOut = Join-Path $Root "out"
$NativeOut = Join-Path $OutputDir "_native_tmp"
$Stage = Join-Path $OutputDir "HAP_PHYSICAL_CALIBRATION_PACK_v0.1"

if (-not (Test-Path $ArchivePath)) { throw "Archive not found: $ArchivePath" }
if (-not (Test-Path $BuildAll)) { throw "BUILD_ALL.ps1 not found." }
if (-not (Test-Path $NativeBuilder)) { throw "BUILD_NATIVE_CONNECTOR_PILOT.ps1 not found." }

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
if (Test-Path $NativeOut) { Remove-Item $NativeOut -Recurse -Force }

New-Item -ItemType Directory -Force -Path $Stage | Out-Null

foreach ($dir in @(
  "01_LEGO",
  "02_GT_MALE",
  "03_CORE",
  "04_TECHNIC",
  "05_NATIVE"
)) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Stage $dir) | Out-Null
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $BuildAll
if ($LASTEXITCODE -ne 0) { throw "Base HAP build failed." }

$nativeArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $NativeBuilder,
  "-ArchivePath", $ArchivePath,
  "-OutputDir", $NativeOut,
  "-Modes", "CONNECTOR_ONLY"
)
& powershell @nativeArgs
if ($LASTEXITCODE -ne 0) { throw "Native connector calibration build failed." }

$copyPlan = @(
  @{ Pattern = "CAL_LEGO_2x2_delta_*.stl"; Dir = "01_LEGO" },
  @{ Pattern = "CAL_GT_male_*.stl"; Dir = "02_GT_MALE" },
  @{ Pattern = "CAL_CORE_SOCKET_*.stl"; Dir = "03_CORE" },
  @{ Pattern = "HAP_GT_CORE_nominal_v0.1.stl"; Dir = "03_CORE" },
  @{ Pattern = "CAL_TECHNIC_HOLE_*.stl"; Dir = "04_TECHNIC" }
)

foreach ($item in $copyPlan) {
  $destination = Join-Path $Stage $item.Dir
  Get-ChildItem $CoreOut -Filter $item.Pattern -File |
    ForEach-Object { Copy-Item $_.FullName -Destination $destination }
}

Get-ChildItem $NativeOut -Filter "HAP_NATIVE_CONNECTOR_ONLY_*.stl" -File |
  ForEach-Object { Copy-Item $_.FullName -Destination (Join-Path $Stage "05_NATIVE") }

foreach ($supportFile in @(
  "calibration\PHYSICAL_RESULTS_TEMPLATE_v0.1.csv",
  "calibration\CALIBRATION_CAMPAIGN_v0.1.md",
  "calibration\CALIBRATION_PLATE_PLAN_v0.1.csv",
  "calibration\KOBRA_S1_CALIBRATION_PROFILE_v0.1.md",
  "INTERFACE_SSOT_v0.1.md",
  "RECORD_PHYSICAL_RESULT.ps1",
  "NEXT_CALIBRATION_TEST.ps1",
  "CHECK_PHYSICAL_PROGRESS.ps1"
)) {
  $src = Join-Path $Root $supportFile
  if (-not (Test-Path $src)) { throw "Calibration support file missing: $src" }
  Copy-Item $src -Destination $Stage
}

$stls = @(Get-ChildItem $Stage -Recurse -Filter "*.stl" -File)
if ($stls.Count -ne 23) {
  throw "Expected 23 calibration STLs, found $($stls.Count)."
}

$manifest = foreach ($file in ($stls | Sort-Object FullName)) {
  $relative = $file.FullName.Substring($Stage.Length).TrimStart([char[]]"\/")

  $category = if ($file.Name -like "CAL_LEGO*") {
    "LEGO_CLUTCH"
  }
  elseif ($file.Name -like "CAL_GT*") {
    "GT_MALE"
  }
  elseif ($file.Name -like "CAL_CORE*") {
    "CORE_CLEARANCE"
  }
  elseif ($file.Name -eq "HAP_GT_CORE_nominal_v0.1.stl") {
    "CORE_REFERENCE"
  }
  elseif ($file.Name -like "CAL_TECHNIC*") {
    "TECHNIC_HOLE"
  }
  elseif ($file.Name -like "HAP_NATIVE_CONNECTOR_ONLY*") {
    "NATIVE_CONNECTOR"
  }
  else {
    "UNKNOWN"
  }

  [pscustomobject]@{
    file = $file.Name
    relative_path = $relative
    category = $category
    size_bytes = $file.Length
    sha256 = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant()
    reality_state = "READY_TO_PRINT_NOT_VALIDATED"
  }
}

$manifestPath = Join-Path $Stage "CALIBRATION_PACK_MANIFEST.csv"
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestPath

$quickStart = @"
# HAP Physical Calibration Pack v0.1 — Quick Start

1. Read KOBRA_S1_CALIBRATION_PROFILE_v0.1.md.
2. Start with the nominal candidate in each numbered folder.
3. Use RECORD_PHYSICAL_RESULT.ps1 immediately after each real fit test.
4. Run NEXT_CALIBRATION_TEST.ps1 to determine whether a tighter or looser candidate is needed.
5. Run CHECK_PHYSICAL_PROGRESS.ps1 when you think all five interface gates have winners.

The package contains 23 possible calibration STLs, but you usually do not need to print all of them.
The adaptive workflow starts with five active candidates plus one reusable HAP core reference.

Reality state: READY_TO_PRINT / NOT PHYSICALLY VALIDATED
"@
Set-Content -Encoding UTF8 -Path (Join-Path $Stage "00_QUICK_START.md") -Value $quickStart

$zipPath = Join-Path $OutputDir "HAP_PHYSICAL_CALIBRATION_PACK_v0.1.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $zipPath

$zipHash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()

Write-Host ""
Write-Host "PASS: physical calibration pack generated" -ForegroundColor Green
Write-Host "STLs  : $($stls.Count)"
Write-Host "Stages: 5"
Write-Host "ZIP   : $zipPath"
Write-Host "SHA256: $zipHash"
Write-Host "State : READY_TO_PRINT / NOT PHYSICALLY VALIDATED" -ForegroundColor Yellow
