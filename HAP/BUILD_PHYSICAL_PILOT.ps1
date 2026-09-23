param(
  [Parameter(Mandatory=$true)]
  [string]$ProfileJson,

  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [string]$OutputDir = ".\\HAP\\physical_pilot_out"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cad = Join-Path $Root "cad\\HAP_MASTER_v0.1.scad"
$NativeBuilder = Join-Path $Root "BUILD_NATIVE_CONNECTOR_PILOT.ps1"

if (-not (Test-Path $ProfileJson)) { throw "Profile not found: $ProfileJson" }
if (-not (Test-Path $ArchivePath)) { throw "Archive not found: $ArchivePath" }
if (-not (Test-Path $Cad)) { throw "HAP master CAD not found." }
if (-not (Test-Path $NativeBuilder)) { throw "Native connector builder not found." }

$profile = Get-Content -Raw -Path $ProfileJson | ConvertFrom-Json
if ($profile.reality_state -ne "INTERFACE_VALUES_PHYSICALLY_SELECTED_PENDING_SYSTEM_PILOT") {
  throw "Profile is not a real physically selected interface profile. State: $($profile.reality_state)"
}

$legoDelta = [double]$profile.selected.LEGO_CLUTCH.value
$gtMale = [double]$profile.selected.GT_MALE.value
$coreClearance = [double]$profile.selected.CORE_CLEARANCE.value
$technicHole = [double]$profile.selected.TECHNIC_HOLE.value
$nativeScale = [double]$profile.selected.NATIVE_CONNECTOR.value

$candidates = @(
  "openscad.com",
  "openscad.exe",
  "C:\\Program Files\\OpenSCAD\\openscad.com",
  "C:\\Program Files\\OpenSCAD\\openscad.exe"
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

$Stage = Join-Path $OutputDir "HAP_PHYSICAL_PILOT_READY_v0.1"
$NativeOut = Join-Path $OutputDir "_native_selected"
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
if (Test-Path $NativeOut) { Remove-Item $NativeOut -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
New-Item -ItemType Directory -Force -Path $NativeOut | Out-Null

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
}

Build-PilotPart "HAP_LG4x4_to_GT_SEALED_v0.1" "LG4x4_GT"
Build-PilotPart "HAP_FULL_HEX_6x6_SEALED_v0.1" "FULL_HEX_6x6"
Build-PilotPart "HAP_GT_CORE_SEALED_v0.1" "GT_CORE"
Build-PilotPart "HAP_SKY_CORE_4x4_SEALED_v0.1" "SKY_CORE_4x4"
Build-PilotPart "HAP_TECHNIC_SIDE_CORE_3H_SEALED_v0.1" "TECHNIC_SIDE_CORE_3H"

& $NativeBuilder -ArchivePath $ArchivePath -OutputDir $NativeOut -Scales @($nativeScale) -Modes @("CORE_BRIDGE")

if ($LASTEXITCODE -ne 0) { throw "Selected native connector bridge build failed." }

$scaleTag = $nativeScale.ToString(
  "0.000",
  [System.Globalization.CultureInfo]::InvariantCulture
)
$nativeFile = Join-Path $NativeOut ("HAP_NATIVE_CORE_BRIDGE_scale_" + $scaleTag + "_v0.1.stl")
if (-not (Test-Path $nativeFile)) { throw "Selected native bridge output missing: $nativeFile" }
Copy-Item $nativeFile -Destination (Join-Path $Stage "HAP_NATIVE_CORE_BRIDGE_SEALED_v0.1.stl")

Copy-Item $ProfileJson -Destination (Join-Path $Stage "PHYSICAL_PROFILE_v0.1.json")
if (Test-Path ($ProfileJson + ".sha256")) {
  Copy-Item ($ProfileJson + ".sha256") -Destination (Join-Path $Stage "PHYSICAL_PROFILE_v0.1.json.sha256")
}

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

First show-module pilot:
1. Straight
2. Large Curve
3. S-Curve

Print the native bridge three times or move one bridge between donor tiles.

This package is NOT a final physical release. It exists only after interface
selection and still requires static fit, structural checks and 10-run rolling
regression on each of the three pilot show modules.
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

Write-Host ""
Write-Host "PASS: sealed-value pilot package generated" -ForegroundColor Green
Write-Host "STLs : $($manifest.Count)"
Write-Host "ZIP  : $zipPath"
Write-Host "State: READY_FOR_PHYSICAL_SYSTEM_PILOT" -ForegroundColor Yellow
