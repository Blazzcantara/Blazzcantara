param(
  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [Parameter(Mandatory=$true)]
  [string]$DonorId,

  [string]$OutputDir = ".\HAP\donor_out",

  [ValidateSet("FUSED","MOUNT_ONLY","DONOR_ONLY")]
  [string]$Mode = "FUSED"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Registry = Join-Path $Root "donors\DONOR_REGISTRY_v0.1.csv"
$Converter = Join-Path $Root "cad\DONOR_CONVERTER_v0.1.scad"

if (-not (Test-Path $ArchivePath)) { throw "Archive not found: $ArchivePath" }
if (-not (Test-Path $Registry)) { throw "Registry not found: $Registry" }
if (-not (Test-Path $Converter)) { throw "Converter not found: $Converter" }

$row = Import-Csv $Registry | Where-Object { $_.donor_id -eq $DonorId } | Select-Object -First 1
if (-not $row) { throw "Unknown donor id: $DonorId" }

if ($row.conversion_state -eq "HOLD_LICENSE" -or $row.license_state -eq "LICENSE_UNCONFIRMED") {
  throw "Donor $DonorId is blocked by the license gate and cannot be converted by this script."
}

if ($row.license_state -ne "CC_ATTRIBUTION") {
  throw "Donor $DonorId is not in an approved conversion license state."
}

$mountStyle = switch ($row.preferred_mount) {
  "HEX_CORE_MOUNT" { "HEX" }
  "REINFORCED_HEX_CORE_MOUNT" { "HEX_REINFORCED" }
  default { throw "Unsupported preferred_mount: $($row.preferred_mount)" }
}

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
  throw "OpenSCAD not found. Install OpenSCAD first or run HAP\BUILD_ALL.ps1 once."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("hap-donor-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

try {
  $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $ArchivePath))
  try {
    $wanted = $row.source_path.Replace("\","/")
    $entry = $zip.Entries | Where-Object { $_.FullName.Replace("\","/") -eq $wanted } | Select-Object -First 1
    if (-not $entry) {
      throw "Registered donor path was not found inside the archive: $wanted"
    }

    $sourceFile = Join-Path $tempRoot ([System.IO.Path]::GetFileName($entry.FullName))
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$sourceFile,$true)
  }
  finally {
    $zip.Dispose()
  }

  $actualHash = (Get-FileHash -Algorithm SHA256 $sourceFile).Hash.ToLowerInvariant()
  $expectedHash = $row.sha256.ToLowerInvariant()

  if ($actualHash -ne $expectedHash) {
    throw "SHA256 mismatch for $DonorId. Expected $expectedHash, got $actualHash"
  }

  $safePath = (Resolve-Path $sourceFile).Path.Replace("\","/")
  $outFile = Join-Path $OutputDir ("HAP_CONVERTED_" + $DonorId + "_v0.1.stl")

  $args = @(
    "-o", $outFile,
    "-D", "DONOR_FILE=`"$safePath`"",
    "-D", "MOUNT_STYLE=`"$mountStyle`"",
    "-D", "MODE=`"$Mode`"",
    $Converter
  )

  Write-Host "Donor      : $DonorId" -ForegroundColor Cyan
  Write-Host "Source     : $($row.source_path)"
  Write-Host "SHA256     : $actualHash"
  Write-Host "Mount      : $mountStyle"
  Write-Host "Mode       : $Mode"

  & $OpenSCAD @args

  if ($LASTEXITCODE -ne 0) { throw "OpenSCAD conversion failed." }
  if (-not (Test-Path $outFile)) { throw "Output STL missing: $outFile" }
  if ((Get-Item $outFile).Length -le 100) { throw "Output STL is suspiciously small." }

  $attribution = @"
HAP donor conversion receipt
============================
Donor ID: $DonorId
Source path: $($row.source_path)
Source SHA256: $actualHash
License state: $($row.license_state)
Original collection: Gravitrax Tiles Variations Collection - 4538769
Author identified by bundled README: ImShogun
Bundled license description: Creative Commons - Attribution
License version: not established by the local archive audit
Conversion mode: $Mode
Mount style: $mountStyle
Reality state: GENERATED / NOT PHYSICALLY VALIDATED
"@

  $receipt = Join-Path $OutputDir ("HAP_CONVERTED_" + $DonorId + "_v0.1_ATTRIBUTION.txt")
  Set-Content -Path $receipt -Value $attribution -Encoding UTF8

  Write-Host ""
  Write-Host "PASS: donor conversion generated" -ForegroundColor Green
  Write-Host "STL     : $outFile"
  Write-Host "Receipt : $receipt"
}
finally {
  if (Test-Path $tempRoot) {
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
