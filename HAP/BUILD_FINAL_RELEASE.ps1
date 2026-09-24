param(
  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [Parameter(Mandatory=$true)]
  [string]$PhysicalProfileJson,

  [Parameter(Mandatory=$true)]
  [string]$PilotReceiptJson,

  [Parameter(Mandatory=$true)]
  [string]$StructuralReceiptJson,

  [Parameter(Mandatory=$true)]
  [string]$ShowReceiptJson,

  [string]$OutputDir = ".\HAP\final_release_out"
)

$ErrorActionPreference = "Stop"

$PowerShellExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
  (Get-Command pwsh).Source
}
elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
  (Get-Command powershell).Source
}
else {
  throw "PowerShell executable not found."
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cad = Join-Path $Root "cad\HAP_MASTER_v0.1.scad"
$NativeCad = Join-Path $Root "cad\DONOR_NATIVE_CONNECTOR_v0.1.scad"
$NativeBuilder = Join-Path $Root "BUILD_NATIVE_CONNECTOR_PILOT.ps1"
$InterfaceSsot = Join-Path $Root "INTERFACE_SSOT_v0.1.md"
$FinalAudit = Join-Path $Root "FINAL_RELEASE_AUDIT.ps1"
$RegistryPath = Join-Path $Root "donors\DONOR_REGISTRY_v0.1.csv"

foreach ($required in @(
  $ArchivePath,
  $PhysicalProfileJson,
  $PilotReceiptJson,
  $StructuralReceiptJson,
  $ShowReceiptJson,
  $Cad,
  $NativeCad,
  $NativeBuilder,
  $InterfaceSsot,
  $FinalAudit,
  $RegistryPath
)) {
  if (-not (Test-Path $required)) { throw "Required file not found: $required" }
}

$profile = Get-Content -Raw $PhysicalProfileJson | ConvertFrom-Json
$pilot = Get-Content -Raw $PilotReceiptJson | ConvertFrom-Json
$structural = Get-Content -Raw $StructuralReceiptJson | ConvertFrom-Json
$show = Get-Content -Raw $ShowReceiptJson | ConvertFrom-Json

if ($profile.reality_state -ne "INTERFACE_VALUES_PHYSICALLY_SELECTED_PENDING_SYSTEM_PILOT") {
  throw "Physical profile is not release-eligible: $($profile.reality_state)"
}

$sourceChecks = [ordered]@{
  hap_master_sha256 = $Cad
  native_connector_cad_sha256 = $NativeCad
  native_connector_builder_sha256 = $NativeBuilder
  interface_ssot_sha256 = $InterfaceSsot
}
foreach ($entry in $sourceChecks.GetEnumerator()) {
  $expected = $profile.source_lock.($entry.Key)
  $actual = (Get-FileHash -Algorithm SHA256 $entry.Value).Hash.ToLowerInvariant()
  if ([string]::IsNullOrWhiteSpace($expected) -or $actual -ne $expected) {
    throw "Final release source lock mismatch: $($entry.Key)"
  }
}
if ($pilot.reality_state -ne "PHYSICAL_PILOT_PASS") {
  throw "Pilot receipt is not release-eligible: $($pilot.reality_state)"
}
if ($structural.reality_state -ne "STRUCTURAL_PHYSICAL_PASS") {
  throw "Structural receipt is not release-eligible: $($structural.reality_state)"
}
if ($show.reality_state -ne "SHOW_MODULES_PHYSICAL_PASS") {
  throw "Show-module receipt is not release-eligible: $($show.reality_state)"
}

$profileHash = (Get-FileHash -Algorithm SHA256 $PhysicalProfileJson).Hash.ToLowerInvariant()
$pilotHash = (Get-FileHash -Algorithm SHA256 $PilotReceiptJson).Hash.ToLowerInvariant()

if ($pilot.physical_profile_sha256 -ne $profileHash) {
  throw "Pilot receipt does not reference the supplied physical profile."
}
if ($structural.physical_profile_sha256 -ne $profileHash) {
  throw "Structural receipt does not reference the supplied physical profile."
}
if ($show.physical_profile_sha256 -ne $profileHash) {
  throw "Show receipt does not reference the supplied physical profile."
}
if ($show.pilot_receipt_sha256 -ne $pilotHash) {
  throw "Show receipt does not reference the supplied pilot receipt."
}

$legoDelta = [double]$profile.selected.LEGO_CLUTCH.value
$gtMale = [double]$profile.selected.GT_MALE.value
$coreClearance = [double]$profile.selected.CORE_CLEARANCE.value
$technicHole = [double]$profile.selected.TECHNIC_HOLE.value
$nativeScale = [double]$profile.selected.NATIVE_CONNECTOR.value

$candidates = @(
  "openscad.com",
  "openscad.exe",
  "C:\Program Files\OpenSCAD\openscad.com",
  "C:\Program Files\OpenSCAD\openscad.exe"
)

$OpenSCAD = $null
foreach ($candidate in $candidates) {
  try {
    if (Test-Path $candidate) { $OpenSCAD = $candidate; break }
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $OpenSCAD = $cmd.Source; break }
  } catch {}
}
if (-not $OpenSCAD) { throw "OpenSCAD not found." }

$Release = Join-Path $OutputDir "HAP_FINAL_v1.0.0"
$NativeTemp = Join-Path $OutputDir "_native_final"

if (Test-Path $Release) { Remove-Item $Release -Recurse -Force }
if (Test-Path $NativeTemp) { Remove-Item $NativeTemp -Recurse -Force }

$dirs = @(
  "00_RELEASE",
  "01_CORE_ADAPTERS",
  "02_STRUCTURAL",
  "03_NATIVE_CONNECTOR",
  "04_SHOW_MODULES",
  "05_FALLBACK_DONOR_MOUNTS",
  "06_EVIDENCE",
  "07_DOCUMENTATION"
)

foreach ($dir in $dirs) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Release $dir) | Out-Null
}
New-Item -ItemType Directory -Force -Path $NativeTemp | Out-Null

$ReleaseResolved = (Resolve-Path $Release).Path

function Build-FinalPart {
  param(
    [string]$RelativeDir,
    [string]$Name,
    [string]$Part,
    [double]$OffsetX = 0.0,
    [double]$OffsetY = 0.0,
    [double]$Rotation = 0.0
  )

  $dst = Join-Path (Join-Path $Release $RelativeDir) ($Name + ".stl")
  $partDefine = 'PART="' + $Part + '"'

  $args = @(
    "-o", $dst,
    "-D", $partDefine,
    "-D", "LEGO_CLUTCH_DELTA=$legoDelta",
    "-D", "GT_MALE_FLAT=$gtMale",
    "-D", "CORE_CLEARANCE=$coreClearance",
    "-D", "TECHNIC_HOLE_D=$technicHole",
    "-D", "OFFSET_X=$OffsetX",
    "-D", "OFFSET_Y=$OffsetY",
    "-D", "TILE_ROTATION=$Rotation",
    $Cad
  )

  Write-Host "Building $Name ..." -ForegroundColor Cyan
  & $OpenSCAD @args

  if ($LASTEXITCODE -ne 0) { throw "OpenSCAD failed for $Name" }
  if (-not (Test-Path $dst)) { throw "Missing output: $dst" }
  if ((Get-Item $dst).Length -le 100) { throw "Suspiciously small output: $dst" }
}

Build-FinalPart "01_CORE_ADAPTERS" "HAP_LG2x2_to_GT_v1.0.0" "LG2x2_GT"
Build-FinalPart "01_CORE_ADAPTERS" "HAP_LG4x4_to_GT_v1.0.0" "LG4x4_GT"
Build-FinalPart "01_CORE_ADAPTERS" "HAP_FULL_HEX_6x6_v1.0.0" "FULL_HEX_6x6"
Build-FinalPart "01_CORE_ADAPTERS" "HAP_GT_CORE_v1.0.0" "GT_CORE"
Build-FinalPart "01_CORE_ADAPTERS" "HAP_GT_CORE_BLANK_v1.0.0" "GT_CORE_BLANK"
Build-FinalPart "01_CORE_ADAPTERS" "HAP_FULL_HEX_OFFSET_Xp4_v1.0.0" "FULL_HEX_OFFSET" 4.0 0.0 0.0
Build-FinalPart "01_CORE_ADAPTERS" "HAP_FULL_HEX_OFFSET_Xm4_v1.0.0" "FULL_HEX_OFFSET" -4.0 0.0 0.0
Build-FinalPart "01_CORE_ADAPTERS" "HAP_FULL_HEX_OFFSET_Xp8_v1.0.0" "FULL_HEX_OFFSET" 8.0 0.0 0.0
Build-FinalPart "01_CORE_ADAPTERS" "HAP_FULL_HEX_OFFSET_Yp4_v1.0.0" "FULL_HEX_OFFSET" 0.0 4.0 0.0
Build-FinalPart "01_CORE_ADAPTERS" "HAP_FULL_HEX_ROT30_v1.0.0" "FULL_HEX_OFFSET" 0.0 0.0 30.0
Build-FinalPart "01_CORE_ADAPTERS" "HAP_LG4x4_GT_DIRECT_OFFSET_Xp4_v1.0.0" "LG4x4_GT_OFFSET_DIRECT" 4.0 0.0 0.0

Build-FinalPart "02_STRUCTURAL" "HAP_SKY_CORE_2x4_v1.0.0" "SKY_CORE_2x4"
Build-FinalPart "02_STRUCTURAL" "HAP_SKY_CORE_4x4_v1.0.0" "SKY_CORE_4x4"
Build-FinalPart "02_STRUCTURAL" "HAP_SKY_CORE_4x6_v1.0.0" "SKY_CORE_4x6"
Build-FinalPart "02_STRUCTURAL" "HAP_BRIDGE_DUAL_CORE_8x4_S32_v1.0.0" "BRIDGE_DUAL_CORE_8x4"
Build-FinalPart "02_STRUCTURAL" "HAP_BRIDGE_DUAL_CORE_10x4_S40_v1.0.0" "BRIDGE_DUAL_CORE_10x4"
Build-FinalPart "02_STRUCTURAL" "HAP_BRIDGE_DUAL_GT_8x4_S32_v1.0.0" "BRIDGE_DUAL_GT_8x4"
Build-FinalPart "02_STRUCTURAL" "HAP_TECHNIC_SIDE_CORE_3H_v1.0.0" "TECHNIC_SIDE_CORE_3H"
Build-FinalPart "02_STRUCTURAL" "HAP_TECHNIC_SIDE_CORE_5H_v1.0.0" "TECHNIC_SIDE_CORE_5H"
Build-FinalPart "02_STRUCTURAL" "HAP_DUAL_FOOT_CORE_S32_v1.0.0" "DUAL_FOOT_CORE_S32"
Build-FinalPart "02_STRUCTURAL" "HAP_DUAL_FOOT_CORE_S40_v1.0.0" "DUAL_FOOT_CORE_S40"
Build-FinalPart "02_STRUCTURAL" "HAP_CROSS_OUTRIGGER_CORE_S40_v1.0.0" "CROSS_OUTRIGGER_CORE_S40"

Build-FinalPart "05_FALLBACK_DONOR_MOUNTS" "HAP_DONOR_PAD_HEX_v1.0.0" "DONOR_PAD_HEX"
Build-FinalPart "05_FALLBACK_DONOR_MOUNTS" "HAP_DONOR_PAD_RECT_v1.0.0" "DONOR_PAD_RECT"
Build-FinalPart "05_FALLBACK_DONOR_MOUNTS" "HAP_DONOR_CORE_MOUNT_v1.0.0" "DONOR_CORE_MOUNT"
Build-FinalPart "05_FALLBACK_DONOR_MOUNTS" "HAP_DONOR_UNDERBODY_HEX_v1.0.0" "DONOR_UNDERBODY_HEX"
Build-FinalPart "05_FALLBACK_DONOR_MOUNTS" "HAP_DONOR_UNDERBODY_HEX_REINFORCED_v1.0.0" "DONOR_UNDERBODY_HEX_REINFORCED"
Build-FinalPart "05_FALLBACK_DONOR_MOUNTS" "HAP_DONOR_UNDERBODY_RECT_v1.0.0" "DONOR_UNDERBODY_RECT"

foreach ($nativeMode in @("CONNECTOR_ONLY","CORE_BRIDGE")) {
  $nativeArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $NativeBuilder,
    "-ArchivePath", $ArchivePath,
    "-OutputDir", $NativeTemp,
    "-Scales", $nativeScale,
    "-Modes", $nativeMode
  )
  & $PowerShellExe @nativeArgs
  if ($LASTEXITCODE -ne 0) { throw "Native final build failed for $nativeMode." }
}

$scaleTag = $nativeScale.ToString("0.000",[System.Globalization.CultureInfo]::InvariantCulture)
$nativeConnector = Join-Path $NativeTemp ("HAP_NATIVE_CONNECTOR_ONLY_scale_" + $scaleTag + "_v0.1.stl")
$nativeBridge = Join-Path $NativeTemp ("HAP_NATIVE_CORE_BRIDGE_scale_" + $scaleTag + "_v0.1.stl")

if (-not (Test-Path $nativeConnector)) { throw "Selected native connector output missing." }
if (-not (Test-Path $nativeBridge)) { throw "Selected native bridge output missing." }

Copy-Item $nativeConnector (Join-Path $Release "03_NATIVE_CONNECTOR\HAP_NATIVE_CONNECTOR_v1.0.0.stl")
Copy-Item $nativeBridge (Join-Path $Release "03_NATIVE_CONNECTOR\HAP_NATIVE_CORE_BRIDGE_v1.0.0.stl")

$registry = Import-Csv $RegistryPath
$showIds = @(
  "SHOW-ST01",
  "SHOW-CV01",
  "SHOW-SC01",
  "SHOW-X01",
  "SHOW-SP01",
  "SHOW-LP01",
  "SHOW-WP01",
  "SHOW-SOL01"
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $ArchivePath))

try {
  foreach ($id in $showIds) {
    $row = $registry | Where-Object { $_.donor_id -eq $id } | Select-Object -First 1
    if (-not $row) { throw "Missing donor registry row: $id" }
    if ($row.license_state -ne "CC_ATTRIBUTION") { throw "Donor is not redistribution-eligible: $id" }
    if ($row.conversion_state -ne "READY_FOR_PRIVATE_CONVERSION") {
      throw "Donor is not in the final conversion-ready state: $id"
    }

    $wanted = $row.source_path.Replace("\","/")
    $entry = $zip.Entries | Where-Object { $_.FullName.Replace("\","/") -eq $wanted } | Select-Object -First 1
    if (-not $entry) { throw "Donor source missing from archive: $wanted" }

    $safeFamily = ($row.family -replace '[^A-Za-z0-9_-]','_')
    $dst = Join-Path $Release ("04_SHOW_MODULES\" + $id + "_" + $safeFamily + ".stl")
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$dst,$true)

    $actual = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
    if ($actual -ne $row.sha256.ToLowerInvariant()) {
      throw "Donor hash mismatch for $id"
    }
  }

  $licenseEntry = $zip.Entries |
    Where-Object { $_.FullName -like "Gravitrax Tiles Variations Collection - 4538769 -*LICENSE.txt" } |
    Select-Object -First 1

  $readmeEntry = $zip.Entries |
    Where-Object { $_.FullName -like "Gravitrax Tiles Variations Collection - 4538769 -*README.txt" } |
    Select-Object -First 1

  if (-not $licenseEntry) {
    throw "Approved donor family LICENSE.txt is missing from the source archive."
  }
  if (-not $readmeEntry) {
    throw "Approved donor family README.txt is missing from the source archive."
  }

  [System.IO.Compression.ZipFileExtensions]::ExtractToFile(
    $licenseEntry,
    (Join-Path $Release "07_DOCUMENTATION\DONOR_LICENSE_ORIGINAL.txt"),
    $true
  )

  [System.IO.Compression.ZipFileExtensions]::ExtractToFile(
    $readmeEntry,
    (Join-Path $Release "07_DOCUMENTATION\DONOR_README_ORIGINAL.txt"),
    $true
  )
}
finally {
  $zip.Dispose()
}

Copy-Item $PhysicalProfileJson (Join-Path $Release "06_EVIDENCE\PHYSICAL_PROFILE_v0.1.json")
Copy-Item $PilotReceiptJson (Join-Path $Release "06_EVIDENCE\PILOT_PROMOTION_RECEIPT_v0.1.json")
Copy-Item $StructuralReceiptJson (Join-Path $Release "06_EVIDENCE\STRUCTURAL_SEAL_RECEIPT_v0.1.json")
Copy-Item $ShowReceiptJson (Join-Path $Release "06_EVIDENCE\SHOW_PROMOTION_RECEIPT_v0.1.json")

$docs = @(
  "README.md",
  "INTERFACE_SSOT_v0.1.md",
  "LICENSE.md",
  "DONOR_CONVERSION_RULES_v0.1.md",
  "donors\DONOR_ATTRIBUTION_v0.1.md",
  "donors\NATIVE_CONNECTOR_SSOT_v0.1.md",
  "donors\PILOT_SHOW_MODULES_v0.1.md",
  "cad\HAP_MASTER_v0.1.scad",
  "cad\DONOR_NATIVE_CONNECTOR_v0.1.scad",
  "BUILD_NATIVE_CONNECTOR_PILOT.ps1"
)

foreach ($doc in $docs) {
  $src = Join-Path $Root $doc
  if (Test-Path $src) {
    $name = [System.IO.Path]::GetFileName($src)
    Copy-Item $src (Join-Path $Release ("07_DOCUMENTATION\" + $name))
  }
}

$releaseReadme = @"
# HAP FINAL v1.0.0

Reality state: PHYSICAL_RELEASE_CANDIDATE_PENDING_FINAL_AUDIT

This package was generated only after:
- five physical interface gates passed;
- Straight / Curve / S-Curve physical pilot passed;
- all 11 structural production parts passed;
- Crossing / Spiral / Loop / Whoopy / Solenoid show promotion passed.

Selected interface values:
- LEGO_CLUTCH_DELTA: $legoDelta mm
- GT_MALE_FLAT: $gtMale mm
- CORE_CLEARANCE: $coreClearance mm
- TECHNIC_HOLE_D: $technicHole mm
- NATIVE_CONNECTOR_SCALE: $scaleTag

STL layout:
- 01_CORE_ADAPTERS: 11 HAP production adapters
- 02_STRUCTURAL: 11 physically gated structural parts
- 03_NATIVE_CONNECTOR: 2 selected native connector parts
- 04_SHOW_MODULES: 8 physically promoted donor tiles
- 05_FALLBACK_DONOR_MOUNTS: 6 fallback mount parts

Expected final STL total: 38

Validation scope:
- Core adapters use the physically selected interfaces but are not claimed as individually printed variants.
- Structural parts require individual structural physical PASS.
- Native connector parts require interface selection plus the first system pilot.
- Show modules require their rolling physical PASS.
- Fallback donor mounts are included as digitally audited utility parts and are NOT claimed as donor-specific physical PASS.
"@
Set-Content -Encoding UTF8 -Path (Join-Path $Release "00_RELEASE\README_FINAL.md") -Value $releaseReadme

$stls = @(Get-ChildItem $Release -Recurse -Filter "*.stl" -File | Sort-Object FullName)
if ($stls.Count -ne 38) {
  throw "Expected 38 final STL files before audit, found $($stls.Count)."
}

$manifest = foreach ($file in $stls) {
  $relative = $file.FullName.Substring($ReleaseResolved.Length).TrimStart([char[]]"\/")
  $topDir = ($relative -split '[\\/]')[0]

  $validationScope = switch ($topDir) {
    "01_CORE_ADAPTERS" {
      "INTERFACE_PHYSICALLY_SELECTED_GEOMETRY_AUDITED"
    }
    "02_STRUCTURAL" {
      "STRUCTURAL_PHYSICAL_PASS"
    }
    "03_NATIVE_CONNECTOR" {
      "PHYSICAL_INTERFACE_AND_PILOT_PASS"
    }
    "04_SHOW_MODULES" {
      "ROLLING_PHYSICAL_PASS"
    }
    "05_FALLBACK_DONOR_MOUNTS" {
      "DIGITAL_GEOMETRY_PASS_FALLBACK_NOT_DONOR_SPECIFIC_PHYSICAL"
    }
    default {
      throw "Unexpected final STL directory while building manifest: $topDir"
    }
  }

  [pscustomobject]@{
    relative_path = $relative
    category = $topDir
    size_bytes = $file.Length
    sha256 = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant()
    validation_scope = $validationScope
  }
}
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $Release "00_RELEASE\FINAL_MANIFEST.csv")

$shaPath = Join-Path $Release "00_RELEASE\SHA256SUMS.txt"
$hashLines = Get-ChildItem $Release -Recurse -File |
  Where-Object { $_.FullName -ne $shaPath } |
  Sort-Object FullName |
  ForEach-Object {
    $rel = $_.FullName.Substring($Release.Length).TrimStart([char[]]"\/")
    $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    "$hash  $rel"
  }
$hashLines | Set-Content -Encoding ASCII -Path $shaPath

$auditArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $FinalAudit,
  "-ReleaseDir", $Release
)
& $PowerShellExe @auditArgs
if ($LASTEXITCODE -ne 0) { throw "Final release audit failed." }

$auditReceipt = Join-Path $Release "00_RELEASE\FINAL_AUDIT_RECEIPT.json"
$auditHash = (Get-FileHash -Algorithm SHA256 $auditReceipt).Hash.ToLowerInvariant()
$manifestHash = (Get-FileHash -Algorithm SHA256 (Join-Path $Release "00_RELEASE\FINAL_MANIFEST.csv")).Hash.ToLowerInvariant()
$profileReleaseHash = (Get-FileHash -Algorithm SHA256 (Join-Path $Release "06_EVIDENCE\PHYSICAL_PROFILE_v0.1.json")).Hash.ToLowerInvariant()

$seal = @"
HAP FINAL v1.0.0 RELEASE SEAL
=============================
Reality state: FINAL_AUDIT_PASS
Physical profile SHA256: $profileReleaseHash
HAP master CAD SHA256: $($profile.source_lock.hap_master_sha256)
Native connector CAD SHA256: $($profile.source_lock.native_connector_cad_sha256)
Native connector builder SHA256: $($profile.source_lock.native_connector_builder_sha256)
Interface SSOT SHA256: $($profile.source_lock.interface_ssot_sha256)
Final manifest SHA256: $manifestHash
Final audit receipt SHA256: $auditHash
Final STL count: 38
"@
Set-Content -Encoding ASCII -Path (Join-Path $Release "00_RELEASE\RELEASE_SEAL.txt") -Value $seal

# Final distribution sums are generated after the audit receipt and release seal
# exist. The checksum file excludes only itself, avoiding a circular hash.
$finalSumsPath = Join-Path $Release "00_RELEASE\SHA256SUMS_FINAL.txt"
$finalHashLines = Get-ChildItem $Release -Recurse -File |
  Where-Object { $_.FullName -ne $finalSumsPath } |
  Sort-Object FullName |
  ForEach-Object {
    $rel = $_.FullName.Substring($ReleaseResolved.Length).TrimStart([char[]]"\/")
    $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    "$hash  $rel"
  }
$finalHashLines | Set-Content -Encoding ASCII -Path $finalSumsPath

$zipPath = Join-Path $OutputDir "HAP_FINAL_v1.0.0.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $Release "*") -DestinationPath $zipPath

$zipHash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()
"$zipHash  HAP_FINAL_v1.0.0.zip" |
  Set-Content -Encoding ASCII -Path (Join-Path $OutputDir "HAP_FINAL_v1.0.0.zip.sha256")

# Distribution round-trip verification: re-extract the exact final ZIP and
# verify every final checksum plus the final STL count.
$verifyDir = Join-Path $OutputDir "_HAP_FINAL_VERIFY"
if (Test-Path $verifyDir) { Remove-Item $verifyDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $verifyDir -Force

$verifySums = Join-Path $verifyDir "00_RELEASE\SHA256SUMS_FINAL.txt"
if (-not (Test-Path $verifySums)) {
  throw "Round-trip verification failed: SHA256SUMS_FINAL.txt missing."
}

foreach ($line in (Get-Content $verifySums | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
  if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)
Write-Host "PASS: HAP FINAL v1.0.0 generated" -ForegroundColor Green
Write-Host "Final STLs: 38"
Write-Host "ZIP: $zipPath"
Write-Host "SHA256: $zipHash"
) {
    throw "Round-trip verification found malformed checksum line: $line"
  }

  $expected = $Matches[1].ToLowerInvariant()
  $relative = $Matches[2]
  $file = Join-Path $verifyDir $relative
  if (-not (Test-Path $file)) {
    throw "Round-trip verification missing file: $relative"
  }

  $actual = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    throw "Round-trip verification hash mismatch: $relative"
  }
}

$verifyStls = @(Get-ChildItem $verifyDir -Recurse -Filter "*.stl" -File)
if ($verifyStls.Count -ne 38) {
  throw "Round-trip verification expected 38 STL files, found $($verifyStls.Count)."
}

Remove-Item $verifyDir -Recurse -Force

Write-Host ""
Write-Host "PASS: HAP FINAL v1.0.0 generated" -ForegroundColor Green
Write-Host "Final STLs: 38"
Write-Host "ZIP: $zipPath"
Write-Host "SHA256: $zipHash"
