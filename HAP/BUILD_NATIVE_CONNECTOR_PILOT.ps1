param(
  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [string]$OutputDir = ".\HAP\native_connector_out",

  [double[]]$Scales = @(0.996,0.998,1.000,1.002,1.004),

  [ValidateSet("CONNECTOR_ONLY","CORE_BRIDGE")]
  [string[]]$Modes = @("CONNECTOR_ONLY","CORE_BRIDGE")
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Builder = Join-Path $Root "cad\DONOR_NATIVE_CONNECTOR_v0.1.scad"
$AuditTool = Join-Path $Root "tools\STL_COMPONENT_AUDIT.py"

$ConnectorPath = "Gravitrax Tiles Variations Collection - 4538769 - part 3 of 3/files/hex-connectorNOT-NEEDED-spare.stl"
$ConnectorSha256 = "31818bf1c329a458ef9a1a74e477bc0e0d5e2403e64700c77ec5f798962fd4c1"

if (-not (Test-Path $ArchivePath)) { throw "Archive not found: $ArchivePath" }
if (-not (Test-Path $Builder)) { throw "Builder not found: $Builder" }
if (-not (Test-Path $AuditTool)) { throw "Audit tool not found: $AuditTool" }

$candidates = @(
  "openscad.com",
  "openscad.exe",
  "openscad",
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
if (-not $Python) { throw "Python 3 not found; required for the STL geometry audit." }

Add-Type -AssemblyName System.IO.Compression.FileSystem

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("hap-native-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

try {
  $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $ArchivePath))
  try {
    $entry = $zip.Entries |
      Where-Object { $_.FullName.Replace("\","/") -eq $ConnectorPath } |
      Select-Object -First 1

    if (-not $entry) {
      throw "Native connector source not found in archive: $ConnectorPath"
    }

    $sourceFile = Join-Path $tempRoot "hex-connectorNOT-NEEDED-spare.stl"
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$sourceFile,$true)
  }
  finally {
    $zip.Dispose()
  }

  $actualHash = (Get-FileHash -Algorithm SHA256 $sourceFile).Hash.ToLowerInvariant()
  if ($actualHash -ne $ConnectorSha256) {
    throw "Connector SHA256 mismatch. Expected $ConnectorSha256, got $actualHash"
  }

  $sourceSafe = (Resolve-Path $sourceFile).Path.Replace("\","/")
  $manifest = @()

  foreach ($scale in $Scales) {
    $scaleTag = $scale.ToString("0.000",[System.Globalization.CultureInfo]::InvariantCulture)

    foreach ($mode in $Modes) {
      $name = "HAP_NATIVE_${mode}_scale_${scaleTag}_v0.1"
      $dst = Join-Path $OutputDir ($name + ".stl")
      $auditJson = Join-Path $OutputDir ($name + "_GEOMETRY.json")

      $scaleValue = $scale.ToString(
        "0.000",
        [System.Globalization.CultureInfo]::InvariantCulture
      )

      $args = @(
        "-o", $dst,
        "-D", "DONOR_FILE=`"$sourceSafe`"",
        "-D", "MODE=`"$mode`"",
        "-D", "CONNECTOR_SCALE=$scaleValue",
        $Builder
      )

      Write-Host "Building $name ..." -ForegroundColor Cyan
      & $OpenSCAD @args

      if ($LASTEXITCODE -ne 0) { throw "OpenSCAD failed for $name" }
      if (-not (Test-Path $dst)) { throw "Missing output: $dst" }
      if ((Get-Item $dst).Length -le 100) { throw "Suspiciously small STL: $dst" }

      $auditArgs = @()
      $auditArgs += $PythonPrefix
      $auditArgs += @(
        $AuditTool,
        $dst,
        "--json-out", $auditJson,
        "--expect-components", "1",
        "--expect-positive-shells", "1",
        "--require-watertight",
        "--require-no-degenerate"
      )
      & $Python @auditArgs

      if ($LASTEXITCODE -ne 0) {
        throw "Geometry audit failed for $name"
      }

      $manifest += [pscustomobject]@{
        file = [System.IO.Path]::GetFileName($dst)
        mode = $mode
        connector_scale = $scaleValue
        output_sha256 = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
        output_size_bytes = (Get-Item $dst).Length
        geometry_report = [System.IO.Path]::GetFileName($auditJson)
        reality_state = "GENERATED_GEOMETRY_PASS_NOT_PHYSICALLY_VALIDATED"
      }
    }
  }

  $manifestCsv = Join-Path $OutputDir "NATIVE_CONNECTOR_MANIFEST.csv"
  $manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestCsv

  $sourceReceipt = @"
HAP native connector source receipt
===================================
Source archive: user-supplied lego-umbau.zip
Source path: $ConnectorPath
Source SHA256: $actualHash
Author identified by bundled README: ImShogun
Bundled license text: Creative Commons - Attribution
License version: not specified in bundled LICENSE.txt
Original source mesh redistributed in this output: NO
Reality state: GENERATED / NOT PHYSICALLY VALIDATED
"@
  $receiptPath = Join-Path $OutputDir "SOURCE_RECEIPT.txt"
  Set-Content -Encoding UTF8 -Path $receiptPath -Value $sourceReceipt

  $shaPath = Join-Path $OutputDir "SHA256SUMS.txt"
  $hashLines = Get-ChildItem $OutputDir -File |
    Where-Object { $_.Name -notin @("SHA256SUMS.txt","HAP_NATIVE_CONNECTOR_PILOT_v0.1.zip") } |
    Sort-Object Name |
    ForEach-Object {
      $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
      "$hash  $($_.Name)"
    }
  $hashLines | Set-Content -Encoding ASCII -Path $shaPath

  $zipOut = Join-Path $OutputDir "HAP_NATIVE_CONNECTOR_PILOT_v0.1.zip"
  if (Test-Path $zipOut) { Remove-Item $zipOut -Force }

  $package = Get-ChildItem $OutputDir -File |
    Where-Object { $_.FullName -ne $zipOut } |
    Select-Object -ExpandProperty FullName

  Compress-Archive -Path $package -DestinationPath $zipOut

  Write-Host ""
  Write-Host "PASS: native connector pilot generated" -ForegroundColor Green
  Write-Host "STLs  : $($manifest.Count)"
  Write-Host "ZIP   : $zipOut"
  Write-Host "Gate  : physical connector fit still required" -ForegroundColor Yellow
}
finally {
  if (Test-Path $tempRoot) {
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
