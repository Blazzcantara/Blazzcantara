# Hybrid Adapter Pack v0.1 — one-click STL build
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cad = Join-Path $Root "cad\HAP_MASTER_v0.1.scad"
$Out = Join-Path $Root "out"
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$candidates = @(
  "openscad.com",
  "openscad.exe",
  "C:\Program Files\OpenSCAD\openscad.com",
  "C:\Program Files\OpenSCAD\openscad.exe"
)

$OpenSCAD = $null
foreach ($c in $candidates) {
  try {
    if (Test-Path $c) { $OpenSCAD = $c; break }
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) { $OpenSCAD = $cmd.Source; break }
  } catch {}
}

if (-not $OpenSCAD) {
  Write-Host "OpenSCAD not found. Trying winget installation..." -ForegroundColor Yellow
  winget install --id OpenSCAD.OpenSCAD -e --accept-source-agreements --accept-package-agreements
  $OpenSCAD = "C:\Program Files\OpenSCAD\openscad.com"
  if (-not (Test-Path $OpenSCAD)) { $OpenSCAD = "C:\Program Files\OpenSCAD\openscad.exe" }
}
if (-not (Test-Path $OpenSCAD) -and -not (Get-Command $OpenSCAD -ErrorAction SilentlyContinue)) {
  throw "OpenSCAD could not be located after installation."
}

function Build-Part([string]$Name,[string]$Part,[double]$LegoScale=1.0,[double]$GtFlat=29.78) {
  $dst = Join-Path $Out ($Name + ".stl")
  Write-Host "Building $Name ..." -ForegroundColor Cyan
  & $OpenSCAD -o $dst `
    -D "PART=`"$Part`"" `
    -D "LEGO_SCALE=$LegoScale" `
    -D "GT_MALE_FLAT=$GtFlat" `
    $Cad
  if ($LASTEXITCODE -ne 0) { throw "OpenSCAD failed for $Name" }
}

Build-Part "CAL_LEGO_2x2_scale_0.996" "LEGO_CLUTCH_2x2" 0.996 29.78
Build-Part "CAL_LEGO_2x2_scale_0.998" "LEGO_CLUTCH_2x2" 0.998 29.78
Build-Part "CAL_LEGO_2x2_scale_1.000" "LEGO_CLUTCH_2x2" 1.000 29.78
Build-Part "CAL_LEGO_2x2_scale_1.002" "LEGO_CLUTCH_2x2" 1.002 29.78
Build-Part "CAL_LEGO_2x2_scale_1.004" "LEGO_CLUTCH_2x2" 1.004 29.78

Build-Part "CAL_GT_male_29.60" "GT_MALE_TEST" 1.000 29.60
Build-Part "CAL_GT_male_29.70" "GT_MALE_TEST" 1.000 29.70
Build-Part "CAL_GT_male_29.78" "GT_MALE_TEST" 1.000 29.78
Build-Part "CAL_GT_male_29.86" "GT_MALE_TEST" 1.000 29.86
Build-Part "CAL_GT_male_29.96" "GT_MALE_TEST" 1.000 29.96

Build-Part "HAP_LG2x2_to_GT_nominal_v0.1" "LG2x2_GT" 1.000 29.78
Build-Part "HAP_LG4x4_to_GT_nominal_v0.1" "LG4x4_GT" 1.000 29.78

$Zip = Join-Path $Root "HAP_v0.1_CALIBRATION_AND_PROTOTYPES.zip"
if (Test-Path $Zip) { Remove-Item $Zip -Force }
Compress-Archive -Path (Join-Path $Out "*"), (Join-Path $Root "README.md"), (Join-Path $Root "cad\HAP_MASTER_v0.1.scad") -DestinationPath $Zip

Write-Host ""
Write-Host "PASS: build complete" -ForegroundColor Green
Write-Host "STLs: $Out"
Write-Host "ZIP : $Zip"
