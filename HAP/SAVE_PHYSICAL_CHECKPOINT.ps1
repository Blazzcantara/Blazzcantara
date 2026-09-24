param(
  [Parameter(Mandatory=$true)]
  [string]$WorkDir,

  [string]$CheckpointDir = ".\HAP\physical_checkpoints"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $WorkDir)) {
  throw "Work directory not found: $WorkDir"
}

New-Item -ItemType Directory -Force -Path $CheckpointDir | Out-Null

$stamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
$stage = Join-Path $CheckpointDir ("checkpoint_" + $stamp)
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$WorkResolved = (Resolve-Path $WorkDir).Path
$StageResolved = (Resolve-Path $stage).Path

$patterns = @(
  "PHYSICAL_RESULTS_WORKING.csv",
  "PHYSICAL_PROFILE_v0.1.json",
  "PHYSICAL_PROFILE_v0.1.json.sha256",
  "PILOT_RESULTS_WORKING.csv",
  "PILOT_PROMOTION_RECEIPT_v0.1.json",
  "PILOT_PROMOTION_RECEIPT_v0.1.json.sha256",
  "STRUCTURAL_RESULTS_WORKING.csv",
  "STRUCTURAL_SEAL_RECEIPT_v0.1.json",
  "STRUCTURAL_SEAL_RECEIPT_v0.1.json.sha256",
  "SHOW_RESULTS_WORKING.csv",
  "SHOW_PROMOTION_RECEIPT_v0.1.json",
  "SHOW_PROMOTION_RECEIPT_v0.1.json.sha256"
)

$copied = @()
foreach ($pattern in $patterns) {
  $matches = @(Get-ChildItem $WorkDir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue)
  foreach ($file in $matches) {
    $relative = $file.FullName.Substring($WorkResolved.Length).TrimStart([char[]]"\/")
    $dst = Join-Path $stage $relative
    $parent = Split-Path -Parent $dst
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item $file.FullName $dst -Force
    $copied += Get-Item $dst
  }
}

if ($copied.Count -eq 0) {
  Remove-Item $stage -Recurse -Force
  throw "No physical campaign state files were found under $WorkDir"
}

$manifest = foreach ($file in ($copied | Sort-Object FullName)) {
  $relative = $file.FullName.Substring($StageResolved.Length).TrimStart([char[]]"\/")
  [pscustomobject]@{
    relative_path = $relative
    size_bytes = $file.Length
    sha256 = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant()
  }
}

$manifestPath = Join-Path $stage "CHECKPOINT_MANIFEST.csv"
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestPath

$meta = [ordered]@{
  checkpoint_version = "0.1"
  created_utc = [DateTime]::UtcNow.ToString("o")
  source_work_dir = $WorkResolved
  file_count = $manifest.Count
  manifest_sha256 = (Get-FileHash -Algorithm SHA256 $manifestPath).Hash.ToLowerInvariant()
}

$metaPath = Join-Path $stage "CHECKPOINT_META.json"
$meta | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -Path $metaPath

$zipPath = $stage + ".zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath

$zipHash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()
"$zipHash  $([System.IO.Path]::GetFileName($zipPath))" |
  Set-Content -Encoding ASCII -Path ($zipPath + ".sha256")

Write-Host "PASS: physical campaign checkpoint saved" -ForegroundColor Green
Write-Host "Files: $($manifest.Count)"
Write-Host "ZIP: $zipPath"
Write-Host "SHA256: $zipHash"
