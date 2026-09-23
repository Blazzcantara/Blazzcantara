param(
  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [string]$OutputDir = ".\\HAP\\calibration_out"
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

$patterns = @(
  "CAL_LEGO_2x2_delta_*.stl",
  "CAL_GT_male_*.stl",
  "CAL_CORE_SOCKET_*.stl",
  "HAP_GT_CORE_nominal_v0.1.stl",
  "CAL_TECHNIC_HOLE_*.stl"
)

foreach ($pattern in $patterns) {
  Get-ChildItem $CoreOut -Filter $pattern -File |
    ForEach-Object { Copy-Item $_.FullName -Destination $Stage }
}

Get-ChildItem $NativeOut -Filter "HAP_NATIVE_CONNECTOR_ONLY_*.stl" -File |
  ForEach-Object { Copy-Item $_.FullName -Destination $Stage }

Copy-Item (Join-Path $Root "calibration\\PHYSICAL_RESULTS_TEMPLATE_v0.1.csv") $Stage
Copy-Item (Join-Path $Root "calibration\\CALIBRATION_CAMPAIGN_v0.1.md") $Stage
Copy-Item (Join-Path $Root "INTERFACE_SSOT_v0.1.md") $Stage

$stls = @(Get-ChildItem $Stage -Filter "*.stl" -File)
if ($stls.Count -ne 23) {
  throw "Expected 23 calibration STLs, found $($stls.Count)."
}

$manifest = foreach ($file in ($stls | Sort-Object Name)) {
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
    category = $category
    size_bytes = $file.Length
    sha256 = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant()
    reality_state = "READY_TO_PRINT_NOT_VALIDATED"
  }
}

$manifestPath = Join-Path $Stage "CALIBRATION_PACK_MANIFEST.csv"
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestPath

$zipPath = Join-Path $OutputDir "HAP_PHYSICAL_CALIBRATION_PACK_v0.1.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $zipPath

$zipHash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()

Write-Host ""
Write-Host "PASS: physical calibration pack generated" -ForegroundColor Green
Write-Host "STLs  : $($stls.Count)"
Write-Host "ZIP   : $zipPath"
Write-Host "SHA256: $zipHash"
Write-Host "State : READY_TO_PRINT / NOT PHYSICALLY VALIDATED" -ForegroundColor Yellow
