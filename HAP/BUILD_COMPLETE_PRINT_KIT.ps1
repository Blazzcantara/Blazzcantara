param(
  [string]$HapOutDir = ".\HAP\out",
  [string]$StructuralPackDir = ".\HAP\lego_structural_out\HAP_LEGO_STRUCTURAL_PACK_v0.1",
  [string]$NativeConnectorZip = "",
  [string]$OutputDir = ".\HAP\complete_print_out"
)

$ErrorActionPreference = "Stop"

foreach ($required in @($HapOutDir,$StructuralPackDir)) {
  if (-not (Test-Path $required)) {
    throw "Required directory not found: $required"
  }
}

$hapNames = @(
  "HAP_LG2x2_to_GT_nominal_v0.1.stl",
  "HAP_LG4x4_to_GT_nominal_v0.1.stl",
  "HAP_FULL_HEX_6x6_socket_0.30_v0.1.stl",
  "HAP_GT_CORE_nominal_v0.1.stl",
  "HAP_GT_CORE_BLANK_v0.1.stl",
  "HAP_FULL_HEX_OFFSET_Xp4_v0.1.stl",
  "HAP_FULL_HEX_OFFSET_Xm4_v0.1.stl",
  "HAP_FULL_HEX_OFFSET_Xp8_v0.1.stl",
  "HAP_FULL_HEX_OFFSET_Yp4_v0.1.stl",
  "HAP_FULL_HEX_ROT30_v0.1.stl",
  "HAP_LG4x4_GT_DIRECT_OFFSET_Xp4_v0.1.stl",
  "HAP_SKY_CORE_2x4_v0.1.stl",
  "HAP_SKY_CORE_4x4_v0.1.stl",
  "HAP_SKY_CORE_4x6_v0.1.stl",
  "HAP_BRIDGE_DUAL_CORE_8x4_S32_v0.1.stl",
  "HAP_BRIDGE_DUAL_CORE_10x4_S40_v0.1.stl",
  "HAP_BRIDGE_DUAL_GT_8x4_S32_v0.1.stl",
  "HAP_DUAL_FOOT_CORE_S32_v0.1.stl",
  "HAP_DUAL_FOOT_CORE_S40_v0.1.stl",
  "HAP_CROSS_OUTRIGGER_CORE_S40_v0.1.stl",
  "HAP_DONOR_PAD_HEX_v0.1.stl",
  "HAP_DONOR_PAD_RECT_v0.1.stl",
  "HAP_DONOR_CORE_MOUNT_v0.1.stl",
  "HAP_DONOR_UNDERBODY_HEX_v0.1.stl",
  "HAP_DONOR_UNDERBODY_HEX_REINFORCED_v0.1.stl",
  "HAP_DONOR_UNDERBODY_RECT_v0.1.stl"
)

if ($hapNames.Count -ne 26) {
  throw "Internal HAP direct-print list must contain exactly 26 non-Technic STL files."
}

$structuralStls = @(Get-ChildItem $StructuralPackDir -Recurse -Filter "*.stl" -File)
if ($structuralStls.Count -ne 29) {
  throw "Expected 29 LEGO structural STL files, found $($structuralStls.Count)."
}

$StageName = if ([string]::IsNullOrWhiteSpace($NativeConnectorZip)) {
  "HAP_COMPLETE_DIRECT_PRINT_NO_TECHNIC_NO_NATIVE_v0.2"
} else {
  "HAP_COMPLETE_DIRECT_PRINT_NO_TECHNIC_v0.2"
}

$Stage = Join-Path $OutputDir $StageName
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }

$hapDst = Join-Path $Stage "01_HAP_ADAPTERS_AND_SUPPORTS"
$structDst = Join-Path $Stage "02_LEGO_STRUCTURAL"
$nativeDst = Join-Path $Stage "03_NATIVE_CONNECTOR"

foreach ($dir in @($hapDst,$structDst)) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$manifest = @()

foreach ($name in $hapNames) {
  $src = Join-Path $HapOutDir $name
  if (-not (Test-Path $src)) { throw "HAP direct-print STL missing: $src" }

  $dst = Join-Path $hapDst $name
  Copy-Item $src $dst -Force

  $manifest += [pscustomobject]@{
    family = "HAP"
    relative_path = "01_HAP_ADAPTERS_AND_SUPPORTS/$name"
    size_bytes = (Get-Item $dst).Length
    sha256 = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
  }
}

foreach ($src in $structuralStls) {
  $relative = $src.FullName.Substring((Resolve-Path $StructuralPackDir).Path.Length).TrimStart([char[]]"\/")
  $dst = Join-Path $structDst $relative
  $parent = Split-Path -Parent $dst
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Copy-Item $src.FullName $dst -Force

  $manifest += [pscustomobject]@{
    family = "LEGO_STRUCTURAL"
    relative_path = ("02_LEGO_STRUCTURAL/" + $relative.Replace("\","/"))
    size_bytes = (Get-Item $dst).Length
    sha256 = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
  }
}

$nativeCount = 0
if (-not [string]::IsNullOrWhiteSpace($NativeConnectorZip)) {
  if (-not (Test-Path $NativeConnectorZip)) {
    throw "Native connector ZIP not found: $NativeConnectorZip"
  }

  $nativeTemp = Join-Path $OutputDir "_native_extract"
  if (Test-Path $nativeTemp) { Remove-Item $nativeTemp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $nativeTemp | Out-Null
  Expand-Archive -Path $NativeConnectorZip -DestinationPath $nativeTemp -Force

  $wanted = @(
    "HAP_NATIVE_CONNECTOR_ONLY_scale_1.000_v0.1.stl",
    "HAP_NATIVE_CORE_BRIDGE_scale_1.000_v0.1.stl"
  )

  $expectedNativeHashes = @{
    "HAP_NATIVE_CONNECTOR_ONLY_scale_1.000_v0.1.stl" = "0d716ce770dc0d3b06e35b5566e8509cbce381894ee811f1c49da86ec4fb7dfd"
    "HAP_NATIVE_CORE_BRIDGE_scale_1.000_v0.1.stl" = "991b4a94f8a5a73524626fb6d55bec7772f58f709f2518790c278d1c48dbffe4"
  }

  New-Item -ItemType Directory -Force -Path $nativeDst | Out-Null

  foreach ($name in $wanted) {
    $src = Get-ChildItem $nativeTemp -Recurse -File -Filter $name | Select-Object -First 1
    if (-not $src) { throw "Native STL missing from connector ZIP: $name" }

    $actualNativeHash = (Get-FileHash -Algorithm SHA256 $src.FullName).Hash.ToLowerInvariant()
    if ($actualNativeHash -ne $expectedNativeHashes[$name]) {
      throw "Native nominal STL hash mismatch for $name."
    }

    $dst = Join-Path $nativeDst $name
    Copy-Item $src.FullName $dst -Force
    $nativeCount++

    $manifest += [pscustomobject]@{
      family = "NATIVE_CONNECTOR"
      relative_path = "03_NATIVE_CONNECTOR/$name"
      size_bytes = (Get-Item $dst).Length
      sha256 = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
    }
  }

  Remove-Item $nativeTemp -Recurse -Force
}

$expectedTotal = 55 + $nativeCount
if ($manifest.Count -ne $expectedTotal) {
  throw "Complete print-kit manifest expected $expectedTotal STL rows, found $($manifest.Count)."
}

$manifestPath = Join-Path $Stage "STL_MANIFEST.csv"
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestPath

$recipes = @"
recipe,qty,file,purpose
BASIC_LOW,2,HAP_LEGO_BRICK_2x4_H1_v0.1.stl,normal structural height
BASIC_LOW,1,HAP_LG4x4_to_GT_nominal_v0.1.stl,direct GraviTrax support
RAISED_CORE,1,HAP_LEGO_RISER_2x2_H3_v0.1.stl,28.8 mm fast riser
RAISED_CORE,1,HAP_LEGO_PLATE_6x6_v0.1.stl,load-spreading top plate
RAISED_CORE,1,HAP_FULL_HEX_6x6_socket_0.30_v0.1.stl,HAP socket carrier
RAISED_CORE,1,HAP_GT_CORE_nominal_v0.1.stl,GraviTrax core
FIRST_PROOF,1,HAP_LEGO_BRICK_2x4_H1_v0.1.stl,normal-height proof structure
FIRST_PROOF,1,HAP_LEGO_PLATE_6x6_v0.1.stl,load-spreading proof plate
FIRST_PROOF,1,HAP_LG4x4_to_GT_nominal_v0.1.stl,direct GraviTrax proof adapter
TALL_STABLE,1,HAP_LEGO_TOWER_4x4_H5_v0.1.stl,stable medium-height tower
TALL_STABLE,1,HAP_LEGO_PLATE_6x6_v0.1.stl,wide top platform
TALL_STABLE,1,HAP_SKY_CORE_4x4_v0.1.stl,HAP core socket support
TALL_STABLE,1,HAP_GT_CORE_nominal_v0.1.stl,GraviTrax core
S32_BRIDGE,2,HAP_LEGO_BRIDGE_SUPPORT_4x8_H3_v0.1.stl,8x4 bridge piers
S32_BRIDGE,1,HAP_BRIDGE_DUAL_CORE_8x4_S32_v0.1.stl,dual HAP bridge carrier
S32_BRIDGE,2,HAP_GT_CORE_nominal_v0.1.stl,dual GraviTrax cores
S40_DUAL_FOOT,1,HAP_LEGO_PLATE_7x2_v0.1.stl,exact centered S40 stud field
S40_DUAL_FOOT,1,HAP_DUAL_FOOT_CORE_S40_v0.1.stl,S40 dual-foot HAP carrier
S40_CROSS,1,HAP_LEGO_FOUNDATION_7x7_H1_v0.1.stl,exact sturdy S40 cross base
S40_CROSS,1,HAP_CROSS_OUTRIGGER_CORE_S40_v0.1.stl,S40 cross-outrigger carrier
S40_BRIDGE,1,HAP_LEGO_BRIDGE_SUPPORT_10x4_H3_v0.1.stl,exact 10x4 bridge support
S40_BRIDGE,1,HAP_BRIDGE_DUAL_CORE_10x4_S40_v0.1.stl,10x4 S40 dual-core carrier
S40_BRIDGE,2,HAP_GT_CORE_nominal_v0.1.stl,dual GraviTrax cores
"@
Set-Content -Encoding UTF8 -Path (Join-Path $Stage "BUILD_RECIPES.csv") -Value $recipes

$orientationRows = @(
  [pscustomobject]@{ pattern="HAP_DONOR_CORE_MOUNT_v0.1.stl"; orientation="ROTATE_180_PAD_ON_BED_CORE_UP"; risk="ORIENTATION_REQUIRED" },
  [pscustomobject]@{ pattern="HAP_DONOR_UNDERBODY_HEX_v0.1.stl"; orientation="ROTATE_180_PAD_ON_BED_CORE_UP"; risk="ORIENTATION_REQUIRED" },
  [pscustomobject]@{ pattern="HAP_DONOR_UNDERBODY_HEX_REINFORCED_v0.1.stl"; orientation="ROTATE_180_PAD_ON_BED_CORE_UP"; risk="ORIENTATION_REQUIRED" },
  [pscustomobject]@{ pattern="HAP_DONOR_UNDERBODY_RECT_v0.1.stl"; orientation="ROTATE_180_PAD_ON_BED_CORE_UP"; risk="ORIENTATION_REQUIRED" },
  [pscustomobject]@{ pattern="HAP_LEGO_TOWER_2x2_H10_v0.1.stl"; orientation="STUDS_UP_OPEN_CAVITY_DOWN"; risk="HIGH_SLENDER_USE_BRIM" },
  [pscustomobject]@{ pattern="HAP_LEGO_TOWER_2x4_H10_v0.1.stl"; orientation="STUDS_UP_OPEN_CAVITY_DOWN"; risk="HIGH_SLENDER_USE_BRIM" }
)
$orientationRows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $Stage "PRINT_ORIENTATION_AND_RISK.csv")

$nativeState = if ($nativeCount -eq 2) { "INCLUDED_NOMINAL_1.000" } else { "NOT_INCLUDED_REQUIRES_PRIVATE_NATIVE_ZIP" }
$realityState = if ($nativeCount -eq 2) {
  "DIGITAL_COMPLETE_NO_TECHNIC_PHYSICAL_FIT_PENDING"
} else {
  "DIGITAL_CORE_COMPLETE_NO_TECHNIC_NATIVE_PENDING_PHYSICAL_FIT_PENDING"
}

$readme = @"
# HAP Complete Direct Print Kit v0.2

Reality state: $realityState

This kit combines:
- 26 non-Technic HAP adapter / carrier / donor-mount STL files
- 29 printable LEGO-compatible structural STL files
- native connector state: $nativeState

Total STL files: $expectedTotal

Architecture:
printable LEGO-compatible structure
    -> HAP adapter / carrier
    -> HAP core or direct GT interface
    -> GraviTrax

LEGO Technic is intentionally excluded and remains a separate package.

Nominal direct-print values:
- LEGO grid pitch: 8.00 mm
- LEGO clutch delta: 0.00 mm
- LEGO structural stud delta: 0.00 mm
- GT male flat: 29.78 mm
- HAP core clearance: 0.30 mm
- native connector scale: 1.000 when included

These files are digitally audited candidates. Physical fit remains nominal because
the separate fit-calibration campaign was intentionally skipped.

Print safety / usability:
- start with FIRST_PROOF from BUILD_RECIPES.csv before large-volume printing;
- the H10 2x2 / 2x4 towers are intentionally NOT first-proof parts; use a brim;
- donor core / underbody standalone STL files must be rotated 180 degrees so the broad donor pad is on the bed;
- use PRINT_ORIENTATION_AND_RISK.csv before slicing;
- do not scale STL files in the slicer.
"@
Set-Content -Encoding UTF8 -Path (Join-Path $Stage "00_START_HERE.md") -Value $readme

$hashLines = Get-ChildItem $Stage -Recurse -Filter "*.stl" -File |
  Sort-Object FullName |
  ForEach-Object {
    $relative = $_.FullName.Substring($Stage.Length).TrimStart([char[]]"\/").Replace("\","/")
    $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    "$hash  $relative"
  }
$hashLines | Set-Content -Encoding ASCII -Path (Join-Path $Stage "SHA256SUMS.txt")

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$zipPath = Join-Path $OutputDir ($StageName + ".zip")
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $zipPath

$verifyDir = Join-Path $OutputDir "_complete_verify"
if (Test-Path $verifyDir) { Remove-Item $verifyDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $verifyDir -Force

$verifyCount = @(Get-ChildItem $verifyDir -Recurse -Filter "*.stl" -File).Count
if ($verifyCount -ne $expectedTotal) {
  throw "ZIP round-trip expected $expectedTotal STL files, found $verifyCount."
}
Remove-Item $verifyDir -Recurse -Force

$zipHash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()
"$zipHash  $([System.IO.Path]::GetFileName($zipPath))" |
  Set-Content -Encoding ASCII -Path ($zipPath + ".sha256")

Write-Host "PASS: complete direct-print kit generated" -ForegroundColor Green
Write-Host "HAP STL       : 26"
Write-Host "Structural STL: 29"
Write-Host "Native STL    : $nativeCount"
Write-Host "Total STL     : $expectedTotal"
Write-Host "ZIP           : $zipPath"
Write-Host "SHA256        : $zipHash"
