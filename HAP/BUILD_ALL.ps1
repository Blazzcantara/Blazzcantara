# Hybrid Adapter Pack v0.1 - one-click STL build
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

function Build-Part(
  [string]$Name,
  [string]$Part,
  [double]$LegoScale=1.0,
  [double]$GtFlat=29.78,
  [double]$CoreClearance=0.30,
  [double]$OffsetX=0.0,
  [double]$OffsetY=0.0,
  [double]$TileRotation=0.0
) {
  $dst = Join-Path $Out ($Name + ".stl")
  Write-Host "Building $Name ..." -ForegroundColor Cyan

  $args = @(
    "-o", $dst,
    "-D", "PART=`"$Part`"",
    "-D", "LEGO_SCALE=$LegoScale",
    "-D", "GT_MALE_FLAT=$GtFlat",
    "-D", "CORE_CLEARANCE=$CoreClearance",
    "-D", "OFFSET_X=$OffsetX",
    "-D", "OFFSET_Y=$OffsetY",
    "-D", "TILE_ROTATION=$TileRotation",
    $Cad
  )

  & $OpenSCAD @args

  if ($LASTEXITCODE -ne 0) { throw "OpenSCAD failed for $Name" }
  if (-not (Test-Path $dst)) { throw "Missing output: $dst" }
  if ((Get-Item $dst).Length -le 100) { throw "Suspiciously small STL: $dst" }
}

Build-Part "CAL_LEGO_2x2_scale_0.996" "LEGO_CLUTCH_2x2" 0.996
Build-Part "CAL_LEGO_2x2_scale_0.998" "LEGO_CLUTCH_2x2" 0.998
Build-Part "CAL_LEGO_2x2_scale_1.000" "LEGO_CLUTCH_2x2" 1.000
Build-Part "CAL_LEGO_2x2_scale_1.002" "LEGO_CLUTCH_2x2" 1.002
Build-Part "CAL_LEGO_2x2_scale_1.004" "LEGO_CLUTCH_2x2" 1.004

Build-Part "CAL_GT_male_29.60" "GT_MALE_TEST" 1.000 29.60
Build-Part "CAL_GT_male_29.70" "GT_MALE_TEST" 1.000 29.70
Build-Part "CAL_GT_male_29.78" "GT_MALE_TEST" 1.000 29.78
Build-Part "CAL_GT_male_29.86" "GT_MALE_TEST" 1.000 29.86
Build-Part "CAL_GT_male_29.96" "GT_MALE_TEST" 1.000 29.96

Build-Part "HAP_LG2x2_to_GT_nominal_v0.1" "LG2x2_GT"
Build-Part "HAP_LG4x4_to_GT_nominal_v0.1" "LG4x4_GT"

Build-Part "HAP_FULL_HEX_6x6_socket_0.20_v0.1" "FULL_HEX_6x6" 1.000 29.78 0.20
Build-Part "HAP_FULL_HEX_6x6_socket_0.30_v0.1" "FULL_HEX_6x6" 1.000 29.78 0.30
Build-Part "HAP_FULL_HEX_6x6_socket_0.40_v0.1" "FULL_HEX_6x6" 1.000 29.78 0.40

Build-Part "HAP_GT_CORE_nominal_v0.1" "GT_CORE"
Build-Part "HAP_GT_CORE_BLANK_v0.1" "GT_CORE_BLANK"

Build-Part "HAP_FULL_HEX_OFFSET_Xp4_v0.1" "FULL_HEX_OFFSET" 1.000 29.78 0.30 4.0 0.0 0.0
Build-Part "HAP_FULL_HEX_OFFSET_Xm4_v0.1" "FULL_HEX_OFFSET" 1.000 29.78 0.30 -4.0 0.0 0.0
Build-Part "HAP_FULL_HEX_OFFSET_Xp8_v0.1" "FULL_HEX_OFFSET" 1.000 29.78 0.30 8.0 0.0 0.0
Build-Part "HAP_FULL_HEX_OFFSET_Yp4_v0.1" "FULL_HEX_OFFSET" 1.000 29.78 0.30 0.0 4.0 0.0
Build-Part "HAP_FULL_HEX_ROT30_v0.1" "FULL_HEX_OFFSET" 1.000 29.78 0.30 0.0 0.0 30.0
Build-Part "HAP_LG4x4_GT_DIRECT_OFFSET_Xp4_v0.1" "LG4x4_GT_OFFSET_DIRECT" 1.000 29.78 0.30 4.0 0.0 0.0

Build-Part "HAP_SKY_CORE_2x4_v0.1" "SKY_CORE_2x4" 1.000 29.78 0.30
Build-Part "HAP_SKY_CORE_4x4_v0.1" "SKY_CORE_4x4" 1.000 29.78 0.30
Build-Part "HAP_SKY_CORE_4x6_v0.1" "SKY_CORE_4x6" 1.000 29.78 0.30

Build-Part "HAP_BRIDGE_DUAL_CORE_8x4_S32_v0.1" "BRIDGE_DUAL_CORE_8x4" 1.000 29.78 0.30
Build-Part "HAP_BRIDGE_DUAL_CORE_10x4_S40_v0.1" "BRIDGE_DUAL_CORE_10x4" 1.000 29.78 0.30
Build-Part "HAP_BRIDGE_DUAL_GT_8x4_S32_v0.1" "BRIDGE_DUAL_GT_8x4" 1.000 29.78 0.30

$Count = (Get-ChildItem $Out -Filter "*.stl").Count
if ($Count -ne 29) {
  throw "Expected 29 STL outputs, found $Count"
}

$Zip = Join-Path $Root "HAP_v0.1_SKY_BRIDGE_STRUCTURAL.zip"
if (Test-Path $Zip) { Remove-Item $Zip -Force }

$PackageItems = @(
  (Join-Path $Out "*"),
  (Join-Path $Root "README.md"),
  (Join-Path $Root "INTERFACE_SSOT_v0.1.md"),
  (Join-Path $Root "PHYSICAL_TEST_MATRIX_v0.1.md"),
  (Join-Path $Root "STRUCTURAL_TEST_MATRIX_v0.1.md"),
  (Join-Path $Root "LICENSE.md"),
  (Join-Path $Root "cad\HAP_MASTER_v0.1.scad")
)
Compress-Archive -Path $PackageItems -DestinationPath $Zip

Write-Host ""
Write-Host "PASS: build complete" -ForegroundColor Green
Write-Host "STLs: $Count"
Write-Host "ZIP : $Zip"
Write-Host "Reality gate: PHYSICAL VALIDATION STILL REQUIRED" -ForegroundColor Yellow
