param(
  [string]$OutputDir = ".\HAP\lego_structural_out",
  [double]$LegoClutchDelta = 0.00,
  [double]$LegoStudDelta = 0.00
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cad = Join-Path $Root "cad\LEGO_STRUCTURAL_MASTER_v0.1.scad"
$AuditTool = Join-Path $Root "tools\STL_COMPONENT_AUDIT.py"

foreach ($required in @($Cad,$AuditTool)) {
  if (-not (Test-Path $required)) {
    throw "Required file not found: $required"
  }
}

$OpenSCAD = $null
foreach ($candidate in @(
  "openscad.com",
  "openscad.exe",
  "openscad",
  "C:\Program Files\OpenSCAD\openscad.com",
  "C:\Program Files\OpenSCAD\openscad.exe"
)) {
  try {
    if (Test-Path $candidate) { $OpenSCAD = $candidate; break }
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $OpenSCAD = $cmd.Source; break }
  } catch {}
}
if (-not $OpenSCAD) { throw "OpenSCAD not found." }

$Python = $null
foreach ($candidate in @("python","python3","py")) {
  $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
  if ($cmd) { $Python = $cmd.Source; break }
}
if (-not $Python) { throw "Python not found." }

if ($LegoClutchDelta -lt -0.20 -or $LegoClutchDelta -gt 0.20) {
  throw "LegoClutchDelta outside safe range [-0.20, +0.20]."
}
if ($LegoStudDelta -lt -0.20 -or $LegoStudDelta -gt 0.20) {
  throw "LegoStudDelta outside safe range [-0.20, +0.20]."
}

$BuildRoot = Join-Path $OutputDir "_build"
$AuditRoot = Join-Path $OutputDir "_audit"
$Stage = Join-Path $OutputDir "HAP_LEGO_STRUCTURAL_PACK_v0.1"

foreach ($path in @($BuildRoot,$AuditRoot,$Stage)) {
  if (Test-Path $path) { Remove-Item $path -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $path | Out-Null
}

$categories = [ordered]@{
  "01_BRICKS" = @(
    @{ Name="HAP_LEGO_BRICK_2x2_H1_v0.1"; Part="BRICK_2x2_H1" },
    @{ Name="HAP_LEGO_BRICK_2x4_H1_v0.1"; Part="BRICK_2x4_H1" },
    @{ Name="HAP_LEGO_BRICK_2x6_H1_v0.1"; Part="BRICK_2x6_H1" },
    @{ Name="HAP_LEGO_BRICK_2x8_H1_v0.1"; Part="BRICK_2x8_H1" },
    @{ Name="HAP_LEGO_BRICK_4x4_H1_v0.1"; Part="BRICK_4x4_H1" }
  )
  "02_PLATES" = @(
    @{ Name="HAP_LEGO_PLATE_2x2_v0.1"; Part="PLATE_2x2" },
    @{ Name="HAP_LEGO_PLATE_2x4_v0.1"; Part="PLATE_2x4" },
    @{ Name="HAP_LEGO_PLATE_4x4_v0.1"; Part="PLATE_4x4" },
    @{ Name="HAP_LEGO_PLATE_4x6_v0.1"; Part="PLATE_4x6" },
    @{ Name="HAP_LEGO_PLATE_6x6_v0.1"; Part="PLATE_6x6" },
    @{ Name="HAP_LEGO_PLATE_7x2_v0.1"; Part="PLATE_7x2" },
    @{ Name="HAP_LEGO_PLATE_7x7_v0.1"; Part="PLATE_7x7" },
    @{ Name="HAP_LEGO_PLATE_8x8_v0.1"; Part="PLATE_8x8" }
  )
  "03_RISERS" = @(
    @{ Name="HAP_LEGO_RISER_2x2_H2_v0.1"; Part="RISER_2x2_H2" },
    @{ Name="HAP_LEGO_RISER_2x2_H3_v0.1"; Part="RISER_2x2_H3" },
    @{ Name="HAP_LEGO_RISER_2x2_H5_v0.1"; Part="RISER_2x2_H5" },
    @{ Name="HAP_LEGO_RISER_2x4_H3_v0.1"; Part="RISER_2x4_H3" },
    @{ Name="HAP_LEGO_RISER_4x4_H3_v0.1"; Part="RISER_4x4_H3" }
  )
  "04_TOWERS" = @(
    @{ Name="HAP_LEGO_TOWER_2x2_H10_v0.1"; Part="TOWER_2x2_H10" },
    @{ Name="HAP_LEGO_TOWER_2x4_H10_v0.1"; Part="TOWER_2x4_H10" },
    @{ Name="HAP_LEGO_TOWER_4x4_H5_v0.1"; Part="TOWER_4x4_H5" }
  )
  "05_HAP_SUPPORTS" = @(
    @{ Name="HAP_LEGO_FOUNDATION_6x6_H1_v0.1"; Part="FOUNDATION_6x6_H1" },
    @{ Name="HAP_LEGO_FOUNDATION_7x7_H1_v0.1"; Part="FOUNDATION_7x7_H1" },
    @{ Name="HAP_LEGO_FOUNDATION_8x8_H1_v0.1"; Part="FOUNDATION_8x8_H1" },
    @{ Name="HAP_LEGO_BRIDGE_SUPPORT_2x6_H5_v0.1"; Part="BRIDGE_SUPPORT_2x6_H5" },
    @{ Name="HAP_LEGO_BRIDGE_SUPPORT_4x8_H3_v0.1"; Part="BRIDGE_SUPPORT_4x8_H3" },
    @{ Name="HAP_LEGO_BRIDGE_SUPPORT_10x4_H3_v0.1"; Part="BRIDGE_SUPPORT_10x4_H3" },
    @{ Name="HAP_LEGO_CROSS_SUPPORT_6x6_H3_v0.1"; Part="CROSS_SUPPORT_6x6_H3" },
    @{ Name="HAP_LEGO_PLATFORM_BLOCK_6x6_H2_v0.1"; Part="PLATFORM_BLOCK_6x6_H2" }
  )
}

foreach ($category in $categories.Keys) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Stage $category) | Out-Null
}

$manifest = @()

foreach ($category in $categories.Keys) {
  foreach ($entry in $categories[$category]) {
    $name = $entry.Name
    $part = $entry.Part
    $buildPath = Join-Path $BuildRoot ($name + ".stl")
    $auditPath = Join-Path $AuditRoot ($name + ".json")

    Write-Host "Building $name ..." -ForegroundColor Cyan

    $scadArgs = @(
      "-o", $buildPath,
      "-D", ('PART="' + $part + '"'),
      "-D", "LEGO_CLUTCH_DELTA=$LegoClutchDelta",
      "-D", "LEGO_STUD_DELTA=$LegoStudDelta",
      $Cad
    )

    & $OpenSCAD @scadArgs
    if ($LASTEXITCODE -ne 0) { throw "OpenSCAD failed for $name." }
    if (-not (Test-Path $buildPath)) { throw "Missing STL: $buildPath" }
    if ((Get-Item $buildPath).Length -le 100) { throw "Suspiciously small STL: $name" }

    $auditArgs = @(
      $AuditTool,
      $buildPath,
      "--json-out", $auditPath,
      "--expect-positive-shells", "1",
      "--require-watertight",
      "--require-no-degenerate"
    )
    & $Python @auditArgs

    if ($LASTEXITCODE -ne 0) { throw "Geometry audit failed for $name." }

    $audit = Get-Content -Raw $auditPath | ConvertFrom-Json
    $dst = Join-Path (Join-Path $Stage $category) ($name + ".stl")
    Copy-Item $buildPath $dst -Force

    $manifest += [pscustomobject]@{
      file = $name + ".stl"
      category = $category
      part_selector = $part
      size_bytes = (Get-Item $dst).Length
      sha256 = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
      triangles = $audit.triangles
      positive_shells = $audit.positive_shells
      watertight = $audit.watertight_edge_test
      degenerate_triangles = $audit.degenerate_triangle_count
      bbox_x_mm = $audit.bbox_extent_mm[0]
      bbox_y_mm = $audit.bbox_extent_mm[1]
      bbox_z_mm = $audit.bbox_extent_mm[2]
      lego_clutch_delta_mm = $LegoClutchDelta
      lego_stud_delta_mm = $LegoStudDelta
      reality_state = "DIGITAL_GEOMETRY_PASS_PHYSICAL_FIT_PENDING"
    }
  }
}

if ($manifest.Count -ne 29) {
  throw "Expected 29 structural STL files, found $($manifest.Count)."
}

$uniqueHashes = @($manifest.sha256 | Sort-Object -Unique)
if ($uniqueHashes.Count -ne 29) {
  throw "Structural pack contains duplicate STL payloads."
}

$manifestPath = Join-Path $Stage "STL_MANIFEST.csv"
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestPath

$shaPath = Join-Path $Stage "SHA256SUMS.txt"
$hashLines = Get-ChildItem $Stage -Recurse -Filter "*.stl" -File |
  Sort-Object FullName |
  ForEach-Object {
    $relative = $_.FullName.Substring($Stage.Length).TrimStart([char[]]"\/")
    $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    "$hash  $relative"
  }
$hashLines | Set-Content -Encoding ASCII -Path $shaPath

$readme = @"
# HAP LEGO Structural Pack v0.1

Reality state: DIGITAL_GEOMETRY_PASS / PHYSICAL_FIT_PENDING

Purpose:
A printable LEGO-compatible structural underbuild for HAP / GraviTrax.

Nominal interfaces:
- grid pitch: 8.00 mm
- plate height: 3.20 mm
- brick height: 9.60 mm
- top stud: 4.80 mm diameter x 1.80 mm
- clutch delta: $LegoClutchDelta mm
- stud delta: $LegoStudDelta mm

Contents:
- 5 standard bricks
- 8 plates
- 5 multi-brick risers
- 3 tall towers
- 8 HAP-oriented supports
- total: 29 STL

All 29 STL files passed:
- exactly one positive printable solid shell
- watertight edge topology
- zero degenerate triangles
- unique SHA-256 payload

These parts are nominal direct-print candidates. They are not official LEGO parts
and are not physically fit-sealed yet.
"@
Set-Content -Encoding UTF8 -Path (Join-Path $Stage "00_READ_ME_FIRST.md") -Value $readme

$starterNames = @(
  "HAP_LEGO_BRICK_2x2_H1_v0.1.stl",
  "HAP_LEGO_BRICK_2x4_H1_v0.1.stl",
  "HAP_LEGO_BRICK_2x8_H1_v0.1.stl",
  "HAP_LEGO_PLATE_4x4_v0.1.stl",
  "HAP_LEGO_PLATE_6x6_v0.1.stl",
  "HAP_LEGO_PLATE_7x2_v0.1.stl",
  "HAP_LEGO_PLATE_8x8_v0.1.stl",
  "HAP_LEGO_RISER_2x2_H2_v0.1.stl",
  "HAP_LEGO_RISER_2x2_H3_v0.1.stl",
  "HAP_LEGO_RISER_2x4_H3_v0.1.stl",
  "HAP_LEGO_TOWER_2x2_H10_v0.1.stl",
  "HAP_LEGO_FOUNDATION_6x6_H1_v0.1.stl",
  "HAP_LEGO_FOUNDATION_7x7_H1_v0.1.stl",
  "HAP_LEGO_BRIDGE_SUPPORT_4x8_H3_v0.1.stl",
  "HAP_LEGO_BRIDGE_SUPPORT_10x4_H3_v0.1.stl"
)

$starterDir = Join-Path $OutputDir "HAP_LEGO_STRUCTURAL_STARTER_v0.1"
if (Test-Path $starterDir) { Remove-Item $starterDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $starterDir | Out-Null

foreach ($name in $starterNames) {
  $src = Get-ChildItem $Stage -Recurse -File -Filter $name | Select-Object -First 1
  if (-not $src) { throw "Starter STL missing: $name" }
  Copy-Item $src.FullName (Join-Path $starterDir $name)
}

$starterNote = @"
# HAP LEGO Structural Starter v0.1

15 high-value structural parts selected from the full 29-part pack.

Recommended first use:
- BRICK 2x4 / 2x8 for normal height construction
- PLATE 6x6 / 8x8 for broad HAP bases
- PLATE 7x2 for exact S40 dual-foot alignment
- RISER 2x2 H2/H3 for fast GraviTrax height changes
- TOWER 2x2 H10 for tall support columns
- FOUNDATION 6x6 for wide single-support bases
- FOUNDATION 7x7 for exact S40 cross-outrigger alignment
- BRIDGE SUPPORT 4x8 H3 for elevated 8x4 bridge structures
- BRIDGE SUPPORT 10x4 H3 for exact 10x4 / S40 bridge support

Reality: nominal direct-print candidates; physical fit pending.
"@
Set-Content -Encoding UTF8 -Path (Join-Path $starterDir "00_START_HERE.md") -Value $starterNote

$fullZip = Join-Path $OutputDir "HAP_LEGO_STRUCTURAL_PACK_v0.1.zip"
$starterZip = Join-Path $OutputDir "HAP_LEGO_STRUCTURAL_STARTER_v0.1.zip"

foreach ($zip in @($fullZip,$starterZip)) {
  if (Test-Path $zip) { Remove-Item $zip -Force }
}

Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $fullZip
Compress-Archive -Path (Join-Path $starterDir "*") -DestinationPath $starterZip

foreach ($zip in @($fullZip,$starterZip)) {
  $hash = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
  "$hash  $([System.IO.Path]::GetFileName($zip))" |
    Set-Content -Encoding ASCII -Path ($zip + ".sha256")
}

Write-Host ""
Write-Host "PASS: HAP LEGO Structural Pack generated" -ForegroundColor Green
Write-Host "Full STLs   : 29"
Write-Host "Starter STLs: 15"
Write-Host "Full ZIP    : $fullZip"
Write-Host "Starter ZIP : $starterZip"
Write-Host "Reality     : DIGITAL_GEOMETRY_PASS / PHYSICAL_FIT_PENDING" -ForegroundColor Yellow
