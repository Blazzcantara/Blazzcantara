# Hybrid Adapter Pack v0.1 - one-click STL build
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cad = Join-Path $Root "cad\HAP_MASTER_v0.1.scad"
$Out = Join-Path $Root "out"
$SmokeOut = Join-Path $Root "smoke_out"
$Converter = Join-Path $Root "cad\DONOR_CONVERTER_v0.1.scad"
$NativeConverter = Join-Path $Root "cad\DONOR_NATIVE_CONNECTOR_v0.1.scad"
$SmokeFixture = Join-Path $Root "cad\DONOR_SMOKE_FIXTURE.scad"
$AuditTool = Join-Path $Root "tools\STL_COMPONENT_AUDIT.py"
$GeometryAudit = Join-Path $Root "geometry_audit"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
New-Item -ItemType Directory -Force -Path $SmokeOut | Out-Null
if (Test-Path $GeometryAudit) { Remove-Item $GeometryAudit -Recurse -Force }
New-Item -ItemType Directory -Force -Path $GeometryAudit | Out-Null

# Remove stale STL outputs before counting. Re-running the local build must not
# inherit files from an older HAP revision.
Write-Host "Remove stale STL outputs ..." -ForegroundColor DarkGray
Get-ChildItem $Out -Filter "*.stl" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem $SmokeOut -Filter "*.stl" -File -ErrorAction SilentlyContinue | Remove-Item -Force

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

$Python = $null
$PythonPrefix = @()
foreach ($candidate in @("python","python3","py")) {
  $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
  if ($cmd) {
    $Python = $cmd.Source
    if ($candidate -eq "py") { $PythonPrefix = @("-3") }
    break
  }
}
if (-not $Python) {
  throw "Python 3 not found. It is required for the full STL geometry audit."
}
if (-not (Test-Path $AuditTool)) {
  throw "STL geometry audit tool missing: $AuditTool"
}

function Build-Part(
  [string]$Name,
  [string]$Part,
  [double]$LegoScale=1.0,
  [double]$GtFlat=29.78,
  [double]$CoreClearance=0.30,
  [double]$OffsetX=0.0,
  [double]$OffsetY=0.0,
  [double]$TileRotation=0.0,
  [double]$TechnicHole=4.90,
  [double]$LegoClutchDelta=0.00
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
    "-D", "TECHNIC_HOLE_D=$TechnicHole",
    "-D", "LEGO_CLUTCH_DELTA=$LegoClutchDelta",
    $Cad
  )

  & $OpenSCAD @args

  if ($LASTEXITCODE -ne 0) { throw "OpenSCAD failed for $Name" }
  if (-not (Test-Path $dst)) { throw "Missing output: $dst" }
  if ((Get-Item $dst).Length -le 100) { throw "Suspiciously small STL: $dst" }
}

Build-Part "CAL_LEGO_2x2_delta_m0.08" "LEGO_CLUTCH_2x2" -LegoClutchDelta -0.08
Build-Part "CAL_LEGO_2x2_delta_m0.04" "LEGO_CLUTCH_2x2" -LegoClutchDelta -0.04
Build-Part "CAL_LEGO_2x2_delta_0.00" "LEGO_CLUTCH_2x2" -LegoClutchDelta 0.00
Build-Part "CAL_LEGO_2x2_delta_p0.04" "LEGO_CLUTCH_2x2" -LegoClutchDelta 0.04
Build-Part "CAL_LEGO_2x2_delta_p0.08" "LEGO_CLUTCH_2x2" -LegoClutchDelta 0.08

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

Build-Part "CAL_CORE_SOCKET_0.20_v0.1" "CORE_SOCKET_COUPON" 1.000 29.78 0.20
Build-Part "CAL_CORE_SOCKET_0.30_v0.1" "CORE_SOCKET_COUPON" 1.000 29.78 0.30
Build-Part "CAL_CORE_SOCKET_0.40_v0.1" "CORE_SOCKET_COUPON" 1.000 29.78 0.40

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

# HAP-008 Technic hole calibration + side-core supports
Build-Part "CAL_TECHNIC_HOLE_4.80_v0.1" "TECHNIC_HOLE_COUPON_3" 1.000 29.78 0.30 0.0 0.0 0.0 4.80
Build-Part "CAL_TECHNIC_HOLE_4.90_v0.1" "TECHNIC_HOLE_COUPON_3" 1.000 29.78 0.30 0.0 0.0 0.0 4.90
Build-Part "CAL_TECHNIC_HOLE_5.00_v0.1" "TECHNIC_HOLE_COUPON_3" 1.000 29.78 0.30 0.0 0.0 0.0 5.00
Build-Part "CAL_TECHNIC_HOLE_5.10_v0.1" "TECHNIC_HOLE_COUPON_3" 1.000 29.78 0.30 0.0 0.0 0.0 5.10
Build-Part "HAP_TECHNIC_SIDE_CORE_3H_v0.1" "TECHNIC_SIDE_CORE_3H" 1.000 29.78 0.30 0.0 0.0 0.0 4.90
Build-Part "HAP_TECHNIC_SIDE_CORE_5H_v0.1" "TECHNIC_SIDE_CORE_5H" 1.000 29.78 0.30 0.0 0.0 0.0 4.90

# HAP-009 anti-twist/outrigger family
Build-Part "HAP_DUAL_FOOT_CORE_S32_v0.1" "DUAL_FOOT_CORE_S32"
Build-Part "HAP_DUAL_FOOT_CORE_S40_v0.1" "DUAL_FOOT_CORE_S40"
Build-Part "HAP_CROSS_OUTRIGGER_CORE_S40_v0.1" "CROSS_OUTRIGGER_CORE_S40"

# HAP-010 donor-conversion blanks
Build-Part "HAP_DONOR_PAD_HEX_v0.1" "DONOR_PAD_HEX"
Build-Part "HAP_DONOR_PAD_RECT_v0.1" "DONOR_PAD_RECT"
Build-Part "HAP_DONOR_CORE_MOUNT_v0.1" "DONOR_CORE_MOUNT"
Build-Part "HAP_DONOR_UNDERBODY_HEX_v0.1" "DONOR_UNDERBODY_HEX"
Build-Part "HAP_DONOR_UNDERBODY_HEX_REINFORCED_v0.1" "DONOR_UNDERBODY_HEX_REINFORCED"
Build-Part "HAP_DONOR_UNDERBODY_RECT_v0.1" "DONOR_UNDERBODY_RECT"

$Count = (Get-ChildItem $Out -Filter "*.stl").Count
if ($Count -ne 47) {
  throw "Expected 47 STL outputs, found $Count"
}

# Deep geometry gate for every generated HAP STL.
foreach ($Stl in (Get-ChildItem $Out -Filter "*.stl" -File | Sort-Object Name)) {
  $JsonOut = Join-Path $GeometryAudit ($Stl.BaseName + ".json")
  $AuditArgs = @()
  $AuditArgs += $PythonPrefix
  $AuditArgs += @(
    $AuditTool,
    $Stl.FullName,
    "--json-out", $JsonOut,
    "--expect-positive-shells", "1",
    "--require-watertight",
    "--require-no-degenerate"
  )

  & $Python @AuditArgs
  if ($LASTEXITCODE -ne 0) {
    throw "STL geometry audit failed: $($Stl.Name)"
  }
}

# HAP-016 synthetic donor-converter smoke test
$SyntheticDonor = Join-Path $SmokeOut "SYNTHETIC_DONOR.stl"
& $OpenSCAD -o $SyntheticDonor $SmokeFixture
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $SyntheticDonor)) {
  throw "Synthetic donor fixture build failed."
}

$SyntheticDonorSafe = (Resolve-Path $SyntheticDonor).Path.Replace("\","/")
foreach ($Style in @("HEX","HEX_REINFORCED","RECT")) {
  $SmokeFile = Join-Path $SmokeOut ("SMOKE_FUSED_" + $Style + ".stl")
  $SmokeArgs = @(
    "-o", $SmokeFile,
    "-D", "DONOR_FILE=`"$SyntheticDonorSafe`"",
    "-D", "MOUNT_STYLE=`"$Style`"",
    "-D", "MODE=`"FUSED`"",
    $Converter
  )
  & $OpenSCAD @SmokeArgs
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $SmokeFile)) {
    throw "Donor converter smoke test failed for $Style."
  }
  if ((Get-Item $SmokeFile).Length -le 100) {
    throw "Donor converter smoke output is suspiciously small for $Style."
  }
}

$SmokeCount = (Get-ChildItem $SmokeOut -Filter "*.stl").Count
if ($SmokeCount -ne 4) {
  throw "Expected 4 donor smoke STLs, found $SmokeCount"
}

$SmokeReport = Join-Path $Root "CI_DONOR_SMOKE_REPORT.txt"
@"
HAP Donor Converter Local Smoke Test
====================================
Synthetic donor: PASS
HEX: PASS
HEX_REINFORCED: PASS
RECT: PASS
Smoke STL count: $SmokeCount
Reality state: CI_GEOMETRY_PASS_ONLY
"@ | Set-Content -Encoding UTF8 -Path $SmokeReport

# Native connector synthetic smoke parity with CI.
$NativeSourceSafe = (Resolve-Path $SyntheticDonor).Path.Replace("\","/")
foreach ($Mode in @("CONNECTOR_ONLY","CORE_BRIDGE")) {
  $NativeSmoke = Join-Path $SmokeOut ("NATIVE_" + $Mode + ".stl")
  $NativeArgs = @(
    "-o", $NativeSmoke,
    "-D", "DONOR_FILE=`"$NativeSourceSafe`"",
    "-D", "MODE=`"$Mode`"",
    "-D", "CONNECTOR_SCALE=1.000",
    $NativeConverter
  )
  & $OpenSCAD @NativeArgs
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $NativeSmoke)) {
    throw "Native connector smoke test failed for $Mode."
  }

  $NativeAuditArgs = @()
  $NativeAuditArgs += $PythonPrefix
  $NativeAuditArgs += @(
    $AuditTool,
    $NativeSmoke,
    "--expect-positive-shells", "1",
    "--require-watertight",
    "--require-no-degenerate"
  )
  & $Python @NativeAuditArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Native connector geometry audit failed for $Mode."
  }
}

$Zip = Join-Path $Root "HAP_v0.1_PHYSICAL_WORKBENCH.zip"
if (Test-Path $Zip) { Remove-Item $Zip -Force }

# Current cumulative source + evidence package. Generated user work directories
# are intentionally excluded.
$PackageItems = @(
  (Join-Path $Out "*"),
  (Join-Path $GeometryAudit "*"),
  (Join-Path $Root "calibration"),
  (Join-Path $Root "ci"),
  (Join-Path $Root "donors"),
  (Join-Path $Root "pilot"),
  (Join-Path $Root "show"),
  (Join-Path $Root "structural"),
  (Join-Path $Root "tools"),
  (Join-Path $Root "cad"),
  (Join-Path $Root "*.ps1"),
  (Join-Path $Root "*.md"),
  (Join-Path $Root "*.cmd"),
  (Join-Path $Root "*.txt")
)
Compress-Archive -Path $PackageItems -DestinationPath $Zip

Write-Host ""
Write-Host "PASS: build complete" -ForegroundColor Green
Write-Host "STLs: $Count"
Write-Host "ZIP : $Zip"
Write-Host "Reality gate: PHYSICAL VALIDATION STILL REQUIRED" -ForegroundColor Yellow
