param(
  [Parameter(Mandatory=$true)]
  [string]$ArchivePath,

  [string]$OutputDir = ".\\HAP\\donor_batch_out",

  [string[]]$DonorIds = @(),

  [switch]$DryRun
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
$RegistryPath = Join-Path $Root "donors\\DONOR_REGISTRY_v0.1.csv"
$RecipePath = Join-Path $Root "donors\\DONOR_RECIPES_v0.1.csv"
$SingleRunner = Join-Path $Root "BUILD_DONOR_CONVERSION.ps1"

if (-not (Test-Path $ArchivePath)) { throw "Archive not found: $ArchivePath" }
if (-not (Test-Path $RegistryPath)) { throw "Registry not found: $RegistryPath" }
if (-not (Test-Path $RecipePath)) { throw "Recipes not found: $RecipePath" }
if (-not (Test-Path $SingleRunner)) { throw "Single donor runner not found: $SingleRunner" }

$registry = Import-Csv $RegistryPath
$recipes = Import-Csv $RecipePath

$ready = foreach ($row in $registry) {
  if ($row.conversion_state -ne "READY_FOR_PRIVATE_CONVERSION") { continue }
  if ($row.license_state -ne "CC_ATTRIBUTION") { continue }
  if ($DonorIds.Count -gt 0 -and $DonorIds -notcontains $row.donor_id) { continue }

  $recipe = $recipes | Where-Object { $_.donor_id -eq $row.donor_id } | Select-Object -First 1
  if (-not $recipe) { throw "Missing recipe for $($row.donor_id)" }
  if ($recipe.recipe_state -eq "HOLD_LICENSE" -or $recipe.mount_style -eq "BLOCKED") { continue }

  [pscustomobject]@{
    donor = $row
    recipe = $recipe
  }
}

if (-not $ready) { throw "No conversion-ready donor IDs selected." }

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

if (-not $DryRun) {
  # Clear stale deterministic batch outputs so a subset run cannot accidentally
  # package files left by an earlier broader conversion.
  Write-Host "Clear stale deterministic batch outputs ..." -ForegroundColor DarkGray
  Get-ChildItem $OutputDir -File -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -like "HAP_CONVERTED_*" -or
      $_.Name -like "DONOR_BATCH_*" -or
      $_.Name -eq "SHA256SUMS.txt" -or
      $_.Name -eq "HAP_DONOR_BATCH_v0.1.zip"
    } |
    Remove-Item -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $ArchivePath))

$preflight = @()
try {
  foreach ($item in $ready) {
    $row = $item.donor
    $wanted = $row.source_path.Replace("\\","/")
    $entry = $zip.Entries | Where-Object { $_.FullName.Replace("\\","/") -eq $wanted } | Select-Object -First 1

    $status = if ($entry) { "FOUND" } else { "MISSING" }
    $preflight += [pscustomobject]@{
      donor_id = $row.donor_id
      source_path = $row.source_path
      archive_entry = $status
      license_state = $row.license_state
      recipe_state = $item.recipe.recipe_state
      mount_style = $item.recipe.mount_style
      risk_class = $item.recipe.risk_class
      rolling_test_order = [int]$item.recipe.rolling_test_order
    }
  }
}
finally {
  $zip.Dispose()
}

$missing = $preflight | Where-Object { $_.archive_entry -ne "FOUND" }
if ($missing) {
  $missing | Format-Table -AutoSize
  throw "Batch preflight failed: one or more registered donor paths are missing from the archive."
}

$preflightPath = Join-Path $OutputDir "DONOR_BATCH_PREFLIGHT.csv"
$preflight | Sort-Object rolling_test_order | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $preflightPath

if ($DryRun) {
  Write-Host "DRYRUN PASS: $($preflight.Count) donors found and eligible." -ForegroundColor Green
  Write-Host "Preflight: $preflightPath"
  exit 0
}

$results = @()

foreach ($item in ($ready | Sort-Object { [int]$_.recipe.rolling_test_order })) {
  $id = $item.donor.donor_id

  Write-Host ""
  Write-Host "=== Converting $id ===" -ForegroundColor Cyan

  $singleArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $SingleRunner,
    "-ArchivePath", $ArchivePath,
    "-DonorId", $id,
    "-OutputDir", $OutputDir,
    "-Mode", "FUSED"
  )
  & $PowerShellExe @singleArgs

  if ($LASTEXITCODE -ne 0) {
    throw "Conversion failed for $id"
  }

  $stl = Join-Path $OutputDir ("HAP_CONVERTED_" + $id + "_v0.1.stl")
  $receipt = Join-Path $OutputDir ("HAP_CONVERTED_" + $id + "_v0.1_ATTRIBUTION.txt")
  $evidence = Join-Path $OutputDir ("HAP_CONVERTED_" + $id + "_v0.1_EVIDENCE.json")
  $geometry = Join-Path $OutputDir ("HAP_CONVERTED_" + $id + "_v0.1_GEOMETRY.json")

  foreach ($required in @($stl,$receipt,$evidence,$geometry)) {
    if (-not (Test-Path $required)) { throw "Required batch output missing: $required" }
  }

  $results += [pscustomobject]@{
    donor_id = $id
    output_file = (Split-Path -Leaf $stl)
    output_sha256 = (Get-FileHash -Algorithm SHA256 $stl).Hash.ToLowerInvariant()
    output_size_bytes = (Get-Item $stl).Length
    attribution_file = (Split-Path -Leaf $receipt)
    evidence_file = (Split-Path -Leaf $evidence)
    geometry_file = (Split-Path -Leaf $geometry)
    mount_style = $item.recipe.mount_style
    risk_class = $item.recipe.risk_class
    rolling_test_order = [int]$item.recipe.rolling_test_order
    reality_state = "GENERATED_NOT_PHYSICALLY_VALIDATED"
  }
}

$manifestCsv = Join-Path $OutputDir "DONOR_BATCH_MANIFEST.csv"
$results | Sort-Object rolling_test_order | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestCsv

$manifestJson = Join-Path $OutputDir "DONOR_BATCH_MANIFEST.json"
$results | Sort-Object rolling_test_order | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -Path $manifestJson

$shaPath = Join-Path $OutputDir "SHA256SUMS.txt"
$hashLines = Get-ChildItem $OutputDir -File |
  Where-Object { $_.Name -notin @("SHA256SUMS.txt","HAP_DONOR_BATCH_v0.1.zip") } |
  Sort-Object Name |
  ForEach-Object {
    $h = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    "$h  $($_.Name)"
  }
$hashLines | Set-Content -Encoding ASCII -Path $shaPath

$summary = @"
# HAP Donor Batch Summary v0.1

Status: GENERATED / NOT PHYSICALLY VALIDATED

Converted donors: $($results.Count)

All items passed:
- archive path preflight
- donor registry gate
- license gate
- recipe gate
- exact source SHA-256 verification
- OpenSCAD conversion
- output existence check
- attribution receipt generation
- per-item evidence generation
- per-item STL geometry audit
- output SHA-256 manifest generation

Physical fit and rolling regression remain mandatory.
"@
$summaryPath = Join-Path $OutputDir "DONOR_BATCH_SUMMARY.md"
Set-Content -Encoding UTF8 -Path $summaryPath -Value $summary

$zipPath = Join-Path $OutputDir "HAP_DONOR_BATCH_v0.1.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$package = Get-ChildItem $OutputDir -File | Where-Object { $_.FullName -ne $zipPath } | Select-Object -ExpandProperty FullName
Compress-Archive -Path $package -DestinationPath $zipPath

Write-Host ""
Write-Host "PASS: donor batch completed" -ForegroundColor Green
Write-Host "Converted: $($results.Count)"
Write-Host "Manifest : $manifestCsv"
Write-Host "SHA256   : $shaPath"
Write-Host "ZIP      : $zipPath"
Write-Host "Reality  : GENERATED / NOT PHYSICALLY VALIDATED" -ForegroundColor Yellow
