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

$StageResolved = (Resolve-Path $Stage).Path

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

$uniqueHashes = @($manifest.sha256 | Sort-Object -Unique)
if ($uniqueHashes.Count -ne 47) {
  $duplicates = $manifest |
    Group-Object sha256 |
    Where-Object { $_.Count -gt 1 } |
    ForEach-Object {
      [pscustomobject]@{
        sha256 = $_.Name
        files = ($_.Group.file -join "; ")
      }
    }

  $detail = ($duplicates | ForEach-Object { "$($_.sha256): $($_.files)" }) -join " | "
  throw "Duplicate STL payloads detected. Expected 47 unique SHA-256 values. $detail"
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
    throw "Unexpected category count for ${category}: expected $($expectedCounts[$category]), found $actual."
  }
}

$manifestPath = Join-Path $Stage "STL_MANIFEST.csv"
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestPath

$shaPath = Join-Path $Stage "SHA256SUMS.txt"
$hashLines = Get-ChildItem $Stage -Recurse -Filter "*.stl" -File |
  Sort-Object FullName |
  ForEach-Object {
    $relative = $_.FullName.Substring($StageResolved.Length).TrimStart([char[]]"\/")
    $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    "$hash  $relative"
  }
$hashLines | Set-Content -Encoding ASCII -Path $shaPath

$sumLines = @(Get-Content $shaPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($sumLines.Count -ne 47) {
  throw "SHA256SUMS expected 47 entries, found $($sumLines.Count)."
}

foreach ($line in $sumLines) {
  $parts = $line -split "  ", 2
  if ($parts.Count -ne 2 -or $parts[0] -notmatch "^[0-9a-fA-F]{64}$") {
    throw "Malformed digital SHA256SUMS line: $line"
  }

  $expected = $parts[0].ToLowerInvariant()
  $relative = $parts[1]
  $target = Join-Path $StageResolved $relative

  if (-not (Test-Path $target)) {
    throw "Digital SHA256SUMS references missing STL: $relative"
  }

  $actual = (Get-FileHash -Algorithm SHA256 $target).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    throw "Digital SHA256SUMS mismatch: $relative"
  }
}
Write-Host "Digital SHA256SUMS self-verification PASS" -ForegroundColor Green

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
  unique_stl_sha256 = 47
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

# Verify the exact ZIP distribution after a clean re-extraction.
$verifyDir = Join-Path $OutputDir "_HAP_DIGITAL_VERIFY"
if (Test-Path $verifyDir) { Remove-Item $verifyDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null

Expand-Archive -Path $zipPath -DestinationPath $verifyDir -Force

$verifyStls = @(Get-ChildItem $verifyDir -Recurse -Filter "*.stl" -File)
if ($verifyStls.Count -ne 47) {
  throw "Digital ZIP round-trip expected 47 STL files, found $($verifyStls.Count)."
}

$verifySums = Join-Path $verifyDir "SHA256SUMS.txt"
if (-not (Test-Path $verifySums)) {
  throw "Digital ZIP round-trip is missing SHA256SUMS.txt."
}

$verifiedEntries = 0
foreach ($line in (Get-Content $verifySums | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
  $parts = $line -split "  ", 2
  if ($parts.Count -ne 2 -or $parts[0] -notmatch "^[0-9a-fA-F]{64}$") {
    throw "Digital ZIP round-trip found malformed checksum line: $line"
  }

  $expected = $parts[0].ToLowerInvariant()
  $relative = $parts[1]
  $target = Join-Path $verifyDir $relative

  if (-not (Test-Path $target)) {
    throw "Digital ZIP round-trip references missing STL: $relative"
  }

  $actual = (Get-FileHash -Algorithm SHA256 $target).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    throw "Digital ZIP round-trip hash mismatch: $relative"
  }

  $verifiedEntries++
}

if ($verifiedEntries -ne 47) {
  throw "Digital ZIP round-trip expected 47 verified checksum entries, found $verifiedEntries."
}

Remove-Item $verifyDir -Recurse -Force

Write-Host ""
Write-Host "PASS: digital STL set generated" -ForegroundColor Green
Write-Host "STLs: 47"
Write-Host "ZIP : $zipPath"
Write-Host "SHA256: $zipHash"
Write-Host "Reality: DIGITAL_GEOMETRY_PASS_PHYSICAL_PENDING" -ForegroundColor Yellow
