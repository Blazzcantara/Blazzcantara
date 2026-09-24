param(
  [Parameter(Mandatory=$true)]
  [string]$CheckpointZip,

  [Parameter(Mandatory=$true)]
  [string]$RestoreDir,

  [switch]$Overwrite
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CheckpointZip)) {
  throw "Checkpoint ZIP not found: $CheckpointZip"
}

if ((Test-Path $RestoreDir) -and -not $Overwrite) {
  $existing = @(Get-ChildItem $RestoreDir -Force -ErrorAction SilentlyContinue)
  if ($existing.Count -gt 0) {
    throw "Restore directory is not empty. Use -Overwrite to restore into it."
  }
}

if (Test-Path $RestoreDir -and $Overwrite) {
  Remove-Item $RestoreDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $RestoreDir | Out-Null

Expand-Archive -Path $CheckpointZip -DestinationPath $RestoreDir -Force

$manifestPath = Join-Path $RestoreDir "CHECKPOINT_MANIFEST.csv"
$metaPath = Join-Path $RestoreDir "CHECKPOINT_META.json"

if (-not (Test-Path $manifestPath)) { throw "Checkpoint manifest missing after extraction." }
if (-not (Test-Path $metaPath)) { throw "Checkpoint metadata missing after extraction." }

$manifest = @(Import-Csv $manifestPath)
foreach ($row in $manifest) {
  $path = Join-Path $RestoreDir $row.relative_path
  if (-not (Test-Path $path)) {
    throw "Checkpoint file missing after extraction: $($row.relative_path)"
  }

  $actual = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
  if ($actual -ne $row.sha256.ToLowerInvariant()) {
    throw "Checkpoint hash mismatch: $($row.relative_path)"
  }
}

$meta = Get-Content -Raw $metaPath | ConvertFrom-Json
$manifestHash = (Get-FileHash -Algorithm SHA256 $manifestPath).Hash.ToLowerInvariant()
if ($manifestHash -ne $meta.manifest_sha256) {
  throw "Checkpoint manifest SHA-256 does not match metadata."
}

Write-Host "PASS: checkpoint restored and verified" -ForegroundColor Green
Write-Host "Files: $($manifest.Count)"
Write-Host "Restore directory: $RestoreDir"
