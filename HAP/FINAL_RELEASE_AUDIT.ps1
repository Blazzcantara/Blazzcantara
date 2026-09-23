param(
  [Parameter(Mandatory=$true)]
  [string]$ReleaseDir,

  [string]$OutputJson = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ReleaseDir)) { throw "Release directory not found: $ReleaseDir" }
$ReleaseDir = (Resolve-Path $ReleaseDir).Path

if (-not $OutputJson) {
  $OutputJson = Join-Path $ReleaseDir "00_RELEASE\FINAL_AUDIT_RECEIPT.json"
}

$requiredDirs = @(
  "00_RELEASE",
  "01_CORE_ADAPTERS",
  "02_STRUCTURAL",
  "03_NATIVE_CONNECTOR",
  "04_SHOW_MODULES",
  "05_FALLBACK_DONOR_MOUNTS",
  "06_EVIDENCE",
  "07_DOCUMENTATION"
)

foreach ($dir in $requiredDirs) {
  if (-not (Test-Path (Join-Path $ReleaseDir $dir))) {
    throw "Missing required release directory: $dir"
  }
}

$profilePath = Join-Path $ReleaseDir "06_EVIDENCE\PHYSICAL_PROFILE_v0.1.json"
$pilotPath = Join-Path $ReleaseDir "06_EVIDENCE\PILOT_PROMOTION_RECEIPT_v0.1.json"
$structuralPath = Join-Path $ReleaseDir "06_EVIDENCE\STRUCTURAL_SEAL_RECEIPT_v0.1.json"
$showPath = Join-Path $ReleaseDir "06_EVIDENCE\SHOW_PROMOTION_RECEIPT_v0.1.json"

foreach ($path in @($profilePath,$pilotPath,$structuralPath,$showPath)) {
  if (-not (Test-Path $path)) { throw "Missing required evidence file: $path" }
}

$profile = Get-Content -Raw $profilePath | ConvertFrom-Json
$pilot = Get-Content -Raw $pilotPath | ConvertFrom-Json
$structural = Get-Content -Raw $structuralPath | ConvertFrom-Json
$show = Get-Content -Raw $showPath | ConvertFrom-Json

if ($profile.reality_state -ne "INTERFACE_VALUES_PHYSICALLY_SELECTED_PENDING_SYSTEM_PILOT") {
  throw "Physical profile state is not release-eligible: $($profile.reality_state)"
}
if ($pilot.reality_state -ne "PHYSICAL_PILOT_PASS") {
  throw "Pilot receipt state is not release-eligible: $($pilot.reality_state)"
}
if ($structural.reality_state -ne "STRUCTURAL_PHYSICAL_PASS") {
  throw "Structural receipt state is not release-eligible: $($structural.reality_state)"
}
if ($show.reality_state -ne "SHOW_MODULES_PHYSICAL_PASS") {
  throw "Show receipt state is not release-eligible: $($show.reality_state)"
}

$stls = @(Get-ChildItem $ReleaseDir -Recurse -Filter "*.stl" -File)
if ($stls.Count -ne 38) {
  throw "Expected 38 final STL files, found $($stls.Count)."
}

$forbidden = @(
  "CAL_",
  "SMOKE",
  "SYNTHETIC",
  "UNTESTED",
  "CI_FIXTURE"
)

foreach ($file in Get-ChildItem $ReleaseDir -Recurse -File) {
  foreach ($token in $forbidden) {
    if ($file.Name.ToUpperInvariant().Contains($token)) {
      throw "Forbidden non-production file in final release: $($file.FullName)"
    }
  }
}

$manifestPath = Join-Path $ReleaseDir "00_RELEASE\FINAL_MANIFEST.csv"
if (-not (Test-Path $manifestPath)) { throw "FINAL_MANIFEST.csv missing." }

$manifest = @(Import-Csv $manifestPath)
if ($manifest.Count -ne 38) {
  throw "Expected 38 manifest rows, found $($manifest.Count)."
}

foreach ($row in $manifest) {
  $path = Join-Path $ReleaseDir $row.relative_path
  if (-not (Test-Path $path)) { throw "Manifest file missing: $($row.relative_path)" }

  $actual = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
  if ($actual -ne $row.sha256.ToLowerInvariant()) {
    throw "Manifest hash mismatch: $($row.relative_path)"
  }
}

$shaPath = Join-Path $ReleaseDir "00_RELEASE\SHA256SUMS.txt"
if (-not (Test-Path $shaPath)) { throw "SHA256SUMS.txt missing." }

$receipt = [ordered]@{
  receipt_version = "1.0"
  reality_state = "FINAL_AUDIT_PASS"
  generated_utc = [DateTime]::UtcNow.ToString("o")
  final_stl_count = $stls.Count
  manifest_rows = $manifest.Count
  evidence_states = [ordered]@{
    physical_profile = $profile.reality_state
    pilot = $pilot.reality_state
    structural = $structural.reality_state
    show_modules = $show.reality_state
  }
}

$parent = Split-Path -Parent $OutputJson
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

$receipt | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -Path $OutputJson

Write-Host "PASS: final release audit" -ForegroundColor Green
Write-Host "Final STLs: $($stls.Count)"
Write-Host "Receipt: $OutputJson"
