param(
  [Parameter(Mandatory=$true)]
  [string]$ProfileJson,

  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [string]$OutputDir = ".\HAP\physical_pilot_out"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cad = Join-Path $Root "cad\HAP_MASTER_v0.1.scad"
$NativeCad = Join-Path $Root "cad\DONOR_NATIVE_CONNECTOR_v0.1.scad"
$NativeBuilder = Join-Path $Root "BUILD_NATIVE_CONNECTOR_PILOT.ps1"
$InterfaceSsot = Join-Path $Root "INTERFACE_SSOT_v0.1.md"
$AuditTool = Join-Path $Root "tools\STL_COMPONENT_AUDIT.py"

foreach ($required in @(
  $ProfileJson,
  ($ProfileJson + ".sha256"),
  $ArchivePath,
  $Cad,
  $NativeCad,
  $NativeBuilder,
  $InterfaceSsot,
  $AuditTool
)) {
  if (-not (Test-Path $required)) {
    throw "Required pilot source/evidence file not found: $required"
  }
}

# Verify the physical-profile sidecar before trusting profile content.
$profileHash = (Get-FileHash -Algorithm SHA256 $ProfileJson).Hash.ToLowerInvariant()
$sidecarLine = (Get-Content ($ProfileJson + ".sha256") |
  Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
  Select-Object -First 1)

if ($sidecarLine -notmatch '^([0-9a-fA-F]{64})  (.+)$') {
  throw "Malformed physical-profile SHA-256 sidecar."
}
$sidecarHash = $Matches[1].ToLowerInvariant()
$sidecarName = $Matches[2]
if ($sidecarName -ne [System.IO.Path]::GetFileName($ProfileJson)) {
  throw "Physical-profile sidecar filename mismatch."
}
if ($sidecarHash -ne $profileHash) {
  throw "Physical-profile SHA-256 sidecar mismatch."
}

$profile = Get-Content -Raw -Path $ProfileJson | ConvertFrom-Json
if ($profile.reality_state -ne "INTERFACE_VALUES_PHYSICALLY_SELECTED_PENDING_SYSTEM_PILOT") {
  throw "Profile is not a real physically selected interface profile. State: $($profile.reality_state)"
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
    throw "Physical profile source lock mismatch: $($entry.Key)"
  }
}

$legoDelta = [double]$profile.selected.LEGO_CLUTCH.value
$gtMale = [double]$profile.selected.GT_MALE.value
$coreClearance = [double]$profile.selected.CORE_CLEARANCE.value
$technicHole = [double]$profile.selected.TECHNIC_HOLE.value
$nativeScale = [double]$profile.selected.NATIVE_CONNECTOR.value

# Revalidate selected values even though the profile is source-locked.
$allowedLego = @(-0.08,-0.04,0.00,0.04,0.08)
$allowedGt = @(29.60,29.70,29.78,29.86,29.96)
$allowedCore = @(0.20,0.30,0.40)
$allowedTechnic = @(4.80,4.90,5.00,5.10)
$allowedNative = @(0.996,0.998,1.000,1.002,1.004)

if ($allowedLego -notcontains $legoDelta) { throw "Selected LEGO clutch value is not allowed." }
if ($allowedGt -notcontains $gtMale) { throw "Selected GT male value is not allowed." }
if ($allowedCore -notcontains $coreClearance) { throw "Selected core clearance is not allowed." }
if ($allowedTechnic -notcontains $technicHole) { throw "Selected Technic hole is not allowed." }
if ($allowedNative -notcontains $nativeScale) { throw "Selected native connector scale is not allowed." }

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
$PythonPrefix = @()
foreach ($candidate in @("python","python3","py")) {
  $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
  if ($cmd) {
    $Python = $cmd.Source
    if ($candidate -eq "py") { $PythonPrefix = @("-3") }
    break
  }
}
if (-not $Python) { throw "Python 3 not found." }

$Stage = Join-Path $OutputDir "HAP_PHYSICAL_PILOT_READY_v0.1"
$NativeOut = Join-Path $OutputDir "_native_selected"
$AuditOut = Join-Path $Stage "AUDIT"

foreach ($path in @($Stage,$NativeOut)) {
  if (Test-Path $path) { Remove-Item $path -Recurse -Force }
}
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
New-Item -ItemType Directory -Force -Path $NativeOut | Out-Null
New-Item -ItemType Directory -Force -Path $AuditOut | Out-Null

function Audit-PilotStl([string]$Path) {
  $json = Join-Path $AuditOut (([System.IO.Path]::GetFileNameWithoutExtension($Path)) + ".json")
  $args = @()
  $args += $PythonPrefix
  $args += @(
    $AuditTool,
    $Path,
    "--json-out", $json,
    "--expect-positive-shells", "1",
    "--require-watertight",
    "--require-no-degenerate"
  )
  & $Python @args
  if ($LASTEXITCODE -ne 0) {
    throw "Pilot STL geometry audit failed: $Path"
  }
}

function Build-PilotPart(
  [string]$Name,
  [string]$Part
) {
  $dst = Join-Path $Stage ($Name + ".stl")
  $partDefine = 'PART="' + $Part + '"'

  $args = @(
    "-o", $dst,
    "-D", $partDefine,
    "-D", "LEGO_CLUTCH_DELTA=$legoDelta",
    "-D", "GT_MALE_FLAT=$gtMale",
    "-D", "CORE_CLEARANCE=$coreClearance",
    "-D", "TECHNIC_HOLE_D=$technicHole",
    $Cad
  )

  & $OpenSCAD @args
  if ($LASTEXITCODE -ne 0) { throw "OpenSCAD failed for $Name" }
  if (-not (Test-Path $dst)) { throw "Missing output: $dst" }
  if ((Get-Item $dst).Length -le 100) { throw "Suspiciously small output: $dst" }

  Audit-PilotStl $dst
}

Build-PilotPart "HAP_LG4x4_to_GT_SELECTED_v0.1" "LG4x4_GT"
Build-PilotPart "HAP_FULL_HEX_6x6_SELECTED_v0.1" "FULL_HEX_6x6"
Build-PilotPart "HAP_GT_CORE_SELECTED_v0.1" "GT_CORE"
Build-PilotPart "HAP_SKY_CORE_4x4_SELECTED_v0.1" "SKY_CORE_4x4"
Build-PilotPart "HAP_TECHNIC_SIDE_CORE_3H_SELECTED_v0.1" "TECHNIC_SIDE_CORE_3H"

& $NativeBuilder -ArchivePath $ArchivePath -OutputDir $NativeOut -Scales @($nativeScale) -Modes @("CORE_BRIDGE")
if ($LASTEXITCODE -ne 0) { throw "Selected native connector bridge build failed." }

$scaleTag = $nativeScale.ToString("0.000",[System.Globalization.CultureInfo]::InvariantCulture)
$nativeFile = Join-Path $NativeOut ("HAP_NATIVE_CORE_BRIDGE_scale_" + $scaleTag + "_v0.1.stl")
if (-not (Test-Path $nativeFile)) { throw "Selected native bridge output missing: $nativeFile" }

$selectedNative = Join-Path $Stage "HAP_NATIVE_CORE_BRIDGE_SELECTED_v0.1.stl"
Copy-Item $nativeFile -Destination $selectedNative
Audit-PilotStl $selectedNative

Copy-Item $ProfileJson -Destination (Join-Path $Stage "PHYSICAL_PROFILE_v0.1.json")
Copy-Item ($ProfileJson + ".sha256") -Destination (Join-Path $Stage "PHYSICAL_PROFILE_v0.1.json.sha256")

$readme = @"
# HAP Physical Pilot Ready v0.1

Reality state: READY_FOR_PHYSICAL_SYSTEM_PILOT

Selected interface values:
- LEGO_CLUTCH_DELTA: $legoDelta mm
- GT_MALE_FLAT: $gtMale mm
- CORE_CLEARANCE: $coreClearance mm
- TECHNIC_HOLE_D: $technicHole mm
- NATIVE_CONNECTOR scale: $scaleTag

Included production candidates:
- LG4x4 -> GT direct support
- Full Hex 6x6 carrier
- GT core
- Sky 4x4 core support
- Technic 3-hole side-core support
- Native donor connector -> HAP core bridge

The word SELECTED means the values were selected from real interface evidence.
It does NOT mean the complete HAP system is physically validated.

This package still requires static fit, structural checks and rolling regression
before any final physical release.
"@
Set-Content -Encoding UTF8 -Path (Join-Path $Stage "README_PHYSICAL_PILOT.md") -Value $readme

$manifest = foreach ($file in (Get-ChildItem $Stage -Filter "*.stl" -File | Sort-Object Name)) {
  [pscustomobject]@{
    file = $file.Name
    sha256 = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant()
    size_bytes = $file.Length
    reality_state = "READY_FOR_PHYSICAL_SYSTEM_PILOT"
  }
}
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $Stage "PILOT_MANIFEST.csv")

if ($manifest.Count -ne 6) {
  throw "Expected 6 physical pilot STLs, found $($manifest.Count)."
}

$zipPath = Join-Path $OutputDir "HAP_PHYSICAL_PILOT_READY_v0.1.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $zipPath

$zipHash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()
"$zipHash  $([System.IO.Path]::GetFileName($zipPath))" |
  Set-Content -Encoding ASCII -Path ($zipPath + ".sha256")

Write-Host ""
Write-Host "PASS: selected-value physical pilot package generated" -ForegroundColor Green
Write-Host "STLs : $($manifest.Count)"
Write-Host "ZIP  : $zipPath"
Write-Host "SHA256: $zipHash"
Write-Host "State: READY_FOR_PHYSICAL_SYSTEM_PILOT" -ForegroundColor Yellow
