param(
  [string]$OutDir = ".\HAP\out",
  [string]$AuditDir = ".\HAP\geometry_audit",
  [string]$OutputDir = ".\HAP\digital_release"
)

$ErrorActionPreference = "Stop"

foreach ($required in @($OutDir,$AuditDir)) {
  if (-not (Test-Path $required)) {
    throw "Required directory not found: $required"
  }
}

$stls = @(Get-ChildItem $OutDir -Filter "*.stl" -File | Sort-Object Name)
if ($stls.Count -ne 47) {
  throw "Expected exactly 47 generated STL files, found $($stls.Count)."
}

$Stage = Join-Path $OutputDir "HAP_DIGITAL_STL_SET_v0.1"
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }

$dirs = @(
  "01_CALIBRATION",
  "02_CORE_ADAPTERS",
  "03_STRUCTURAL",
  "04_DONOR_MOUNTS",
  "05_AUDIT"
)
foreach ($dir in $dirs) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Stage $dir) | Out-Null
}

function Get-Category([string]$Name) {
  if ($Name -like "CAL_*") {
    return "01_CALIBRATION"
  }

  if (
    $Name -like "HAP_SKY_*" -or
    $Name -like "HAP_BRIDGE_*" -or
    $Name -like "HAP_DUAL_FOOT_*" -or
    $Name -like "HAP_CROSS_OUTRIGGER_*" -or
    $Name -like "HAP_TECHNIC_SIDE_*"
  ) {
    return "03_STRUCTURAL"
  }

  if ($Name -like "HAP_DONOR_*") {
    return "04_DONOR_MOUNTS"
  }

  return "02_CORE_ADAPTERS"
}

$manifest = @()

foreach ($file in $stls) {
  $auditPath = Join-Path $AuditDir ($file.BaseName + ".json")
  if (-not (Test-Path $auditPath)) {
    throw "Geometry audit missing for $($file.Name): $auditPath"
  }

  $audit = Get-Content -Raw $auditPath | ConvertFrom-Json

  if ($audit.positive_shells -ne 1) {
    throw "$($file.Name): expected exactly one positive solid shell, found $($audit.positive_shells)."
  }
  if (-not $audit.watertight_edge_test) {
    throw "$($file.Name): mesh is not watertight."
  }
  if ($audit.degenerate_triangle_count -ne 0) {
    throw "$($file.Name): contains $($audit.degenerate_triangle_count) degenerate triangles."
  }

  $category = Get-Category $file.Name
  $dst = Join-Path (Join-Path $Stage $category) $file.Name
  Copy-Item $file.FullName $dst -Force

  $manifest += [pscustomobject]@{
    file = $file.Name
    category = $category
    size_bytes = $file.Length
    sha256 = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant()
    triangles = $audit.triangles
    surface_shells = $audit.surface_shells
    positive_shells = $audit.positive_shells
    negative_shells = $audit.negative_shells
    watertight = $audit.watertight_edge_test
    degenerate_triangles = $audit.degenerate_triangle_count
    bbox_x_mm = $audit.bbox_extent_mm[0]
    bbox_y_mm = $audit.bbox_extent_mm[1]
    bbox_z_mm = $audit.bbox_extent_mm[2]
    net_signed_volume_mm3 = $audit.net_signed_volume_mm3
    reality_state = "DIGITAL_GEOMETRY_PASS_PHYSICAL_PENDING"
  }

  Copy-Item $auditPath (Join-Path $Stage "05_AUDIT") -Force
}

$categoryCounts = $manifest | Group-Object category | Sort-Object Name

$expectedCounts = @{
  "01_CALIBRATION" = 17
  "02_CORE_ADAPTERS" = 13
  "03_STRUCTURAL" = 11
  "04_DONOR_MOUNTS" = 6
}

foreach ($category in $expectedCounts.Keys) {
  $actual = @($manifest | Where-Object { $_.category -eq $category }).Count
  if ($actual -ne $expectedCounts[$category]) {
    throw "Unexpected category count for $category: expected $($expectedCounts[$category]), found $actual."
  }
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

$status = @"
# HAP Digital STL Set v0.1

Reality state: DIGITAL_GEOMETRY_PASS_PHYSICAL_PENDING

This package contains all 47 currently generated HAP STL files after the
automated geometry gate.

Digital gate requirements for every STL:
- exactly one positive printable solid body;
- watertight edge topology;
- zero degenerate triangles;
- unique SHA-256 entry in STL_MANIFEST.csv.

Folder counts:
- 01_CALIBRATION: 17
- 02_CORE_ADAPTERS: 13
- 03_STRUCTURAL: 11
- 04_DONOR_MOUNTS: 6
- total: 47

Important:
These are the finished DIGITAL candidate STL files.
They are not yet the physically sealed HAP FINAL v1.0.0 production release.
Interface fit, structural behavior and marble rolling still require the real
physical gates already defined in the project.

The final production release intentionally contains a smaller selected set after
physical calibration and promotion.
"@
Set-Content -Encoding UTF8 -Path (Join-Path $Stage "00_STATUS_README.md") -Value $status

$summary = [ordered]@{
  set_version = "0.1"
  reality_state = "DIGITAL_GEOMETRY_PASS_PHYSICAL_PENDING"
  generated_utc = [DateTime]::UtcNow.ToString("o")
  total_stl = $manifest.Count
  calibration = 17
  core_adapters = 13
  structural = 11
  donor_mounts = 6
  all_positive_shells_one = $true
  all_watertight = $true
  all_zero_degenerate = $true
}
$summary | ConvertTo-Json -Depth 5 |
  Set-Content -Encoding UTF8 -Path (Join-Path $Stage "DIGITAL_AUDIT_SUMMARY.json")

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$zipPath = Join-Path $OutputDir "HAP_DIGITAL_STL_SET_v0.1.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $zipPath

$zipHash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()
"$zipHash  HAP_DIGITAL_STL_SET_v0.1.zip" |
  Set-Content -Encoding ASCII -Path ($zipPath + ".sha256")

Write-Host ""
Write-Host "PASS: digital STL set generated" -ForegroundColor Green
Write-Host "STLs: 47"
Write-Host "ZIP : $zipPath"
Write-Host "SHA256: $zipHash"
Write-Host "Reality: DIGITAL_GEOMETRY_PASS_PHYSICAL_PENDING" -ForegroundColor Yellow
