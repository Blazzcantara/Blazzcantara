param(
  [string]$AuditPath = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $AuditPath) { $AuditPath = Join-Path $Root "FINAL_RELEASE_AUDIT.ps1" }
if (-not (Test-Path $AuditPath)) { throw "Final audit script missing: $AuditPath" }

$TestRoot = Join-Path $Root "ci_final_audit_manifest_set"
$Release = Join-Path $TestRoot "HAP_FINAL_v1.0.0"
if (Test-Path $TestRoot) { Remove-Item $TestRoot -Recurse -Force }

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

$profilePath = Join-Path $Release "06_EVIDENCE/PHYSICAL_PROFILE_v0.1.json"
$pilotPath = Join-Path $Release "06_EVIDENCE/PILOT_PROMOTION_RECEIPT_v0.1.json"
$structuralPath = Join-Path $Release "06_EVIDENCE/STRUCTURAL_SEAL_RECEIPT_v0.1.json"
$showPath = Join-Path $Release "06_EVIDENCE/SHOW_PROMOTION_RECEIPT_v0.1.json"

[ordered]@{
  reality_state = "INTERFACE_VALUES_PHYSICALLY_SELECTED_PENDING_SYSTEM_PILOT"
} | ConvertTo-Json | Set-Content -Encoding UTF8 $profilePath

$profileHash = (Get-FileHash -Algorithm SHA256 $profilePath).Hash.ToLowerInvariant()

[ordered]@{
  reality_state = "PHYSICAL_PILOT_PASS"
  physical_profile_sha256 = $profileHash
} | ConvertTo-Json | Set-Content -Encoding UTF8 $pilotPath

$pilotHash = (Get-FileHash -Algorithm SHA256 $pilotPath).Hash.ToLowerInvariant()

[ordered]@{
  reality_state = "STRUCTURAL_PHYSICAL_PASS"
  physical_profile_sha256 = $profileHash
} | ConvertTo-Json | Set-Content -Encoding UTF8 $structuralPath

[ordered]@{
  reality_state = "SHOW_MODULES_PHYSICAL_PASS"
  physical_profile_sha256 = $profileHash
  pilot_receipt_sha256 = $pilotHash
} | ConvertTo-Json | Set-Content -Encoding UTF8 $showPath

$stlDir = Join-Path $Release "01_CORE_ADAPTERS"
$stls = @()
for ($i = 1; $i -le 38; $i++) {
  $path = Join-Path $stlDir ("REGRESSION_PART_{0:D2}.stl" -f $i)
  Set-Content -Encoding ASCII -Path $path -Value ("dummy regression STL {0:D2}" -f $i)
  $stls += Get-Item $path
}

function RelPath([System.IO.FileInfo]$File) {
  return ($File.FullName.Substring($Release.Length).TrimStart([char[]]"\/") -replace '\\','/')
}

$goodRows = @($stls | Sort-Object Name | ForEach-Object {
  [pscustomobject]@{
    relative_path = RelPath $_
    size_bytes = $_.Length
    sha256 = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    reality_state = "PHYSICAL_RELEASE_CANDIDATE"
  }
})

$manifestPath = Join-Path $Release "00_RELEASE/FINAL_MANIFEST.csv"
$badRows = @($goodRows[0..36]) + @($goodRows[0])
$badRows | Export-Csv -NoTypeInformation -Encoding UTF8 $manifestPath

$shaPath = Join-Path $Release "00_RELEASE/SHA256SUMS.txt"
@($stls | Sort-Object Name | ForEach-Object {
  $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
  "$hash  $(RelPath $_)"
}) | Set-Content -Encoding ASCII $shaPath

$rejected = $false
try {
  & $AuditPath -ReleaseDir $Release
} catch {
  $rejected = $true
  if ($_.Exception.Message -notmatch "duplicate STL paths|exact final STL set") {
    throw "Malformed-manifest regression failed for unexpected reason: $($_.Exception.Message)"
  }
}
if (-not $rejected) {
  throw "Final audit incorrectly accepted a 38-row manifest with a duplicate path and an omitted STL."
}
Write-Host "PASS: duplicate/omitted manifest fixture rejected." -ForegroundColor Green

$goodRows | Export-Csv -NoTypeInformation -Encoding UTF8 $manifestPath
& $AuditPath -ReleaseDir $Release

$receiptPath = Join-Path $Release "00_RELEASE/FINAL_AUDIT_RECEIPT.json"
if (-not (Test-Path $receiptPath)) { throw "Final audit receipt missing after positive fixture." }
$receipt = Get-Content -Raw $receiptPath | ConvertFrom-Json
if ($receipt.reality_state -ne "FINAL_AUDIT_PASS") {
  throw "Unexpected final audit receipt state: $($receipt.reality_state)"
}

Write-Host "PASS: exact 38-STL manifest fixture accepted." -ForegroundColor Green
Remove-Item $TestRoot -Recurse -Force
