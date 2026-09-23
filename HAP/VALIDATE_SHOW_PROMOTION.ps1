param(
  [Parameter(Mandatory=$true)]
  [string]$ResultsCsv,

  [Parameter(Mandatory=$true)]
  [string]$PhysicalProfileJson,

  [Parameter(Mandatory=$true)]
  [string]$PilotReceiptJson,

  [string]$OutputJson = ".\HAP\show\SHOW_PROMOTION_RECEIPT_v0.1.json",

  [switch]$AllowSyntheticCiFixture
)

$ErrorActionPreference = "Stop"

foreach ($required in @($ResultsCsv,$PhysicalProfileJson,$PilotReceiptJson)) {
  if (-not (Test-Path $required)) { throw "Required file not found: $required" }
}

$profile = Get-Content -Raw -Path $PhysicalProfileJson | ConvertFrom-Json
$pilot = Get-Content -Raw -Path $PilotReceiptJson | ConvertFrom-Json
$rows = @(Import-Csv $ResultsCsv)

$requiredIds = @("SHOW-X01","SHOW-SP01","SHOW-LP01","SHOW-WP01","SHOW-SOL01")

if ($rows.Count -ne $requiredIds.Count) {
  throw "Expected 5 show-module rows, found $($rows.Count)."
}

$ids = @($rows | ForEach-Object { $_.module_id })
if (@($ids | Sort-Object) -join "|" -ne @($requiredIds | Sort-Object) -join "|") {
  throw "Show-module IDs do not match the required promotion set."
}

if (-not $AllowSyntheticCiFixture) {
  if ($profile.reality_state -ne "INTERFACE_VALUES_PHYSICALLY_SELECTED_PENDING_SYSTEM_PILOT") {
    throw "Physical profile is not real-selected."
  }
  if ($pilot.reality_state -ne "PHYSICAL_PILOT_PASS") {
    throw "Straight / Curve / S-Curve pilot is not physically passed."
  }
}

foreach ($row in $rows) {
  if ([int]$row.run_count -lt 10) { throw "$($row.module_id) requires at least 10 runs." }
  if ([int]$row.successful_runs -ne [int]$row.run_count) {
    throw "$($row.module_id) did not complete every recorded run."
  }

  foreach ($field in @("connector_fit","core_fit","lateral_rigidity","track_clearance")) {
    if ($row.$field -ne "PASS") { throw "$($row.module_id) failed $field." }
  }

  if ($row.result -ne "PASS") { throw "$($row.module_id) result is not PASS." }

  if (-not $AllowSyntheticCiFixture -and $row.tested_real -ne "YES") {
    throw "$($row.module_id) is not marked tested_real=YES."
  }

  if (-not $AllowSyntheticCiFixture -and [string]::IsNullOrWhiteSpace($row.notes)) {
    throw "$($row.module_id) requires a physical-test note."
  }
}

$profileHash = (Get-FileHash -Algorithm SHA256 $PhysicalProfileJson).Hash.ToLowerInvariant()
$pilotHash = (Get-FileHash -Algorithm SHA256 $PilotReceiptJson).Hash.ToLowerInvariant()
$resultsHash = (Get-FileHash -Algorithm SHA256 $ResultsCsv).Hash.ToLowerInvariant()

$state = if ($AllowSyntheticCiFixture) {
  "SYNTHETIC_CI_SHOW_PASS_DO_NOT_PROMOTE"
}
else {
  "SHOW_MODULES_PHYSICAL_PASS"
}

$receipt = [ordered]@{
  receipt_version = "0.1"
  reality_state = $state
  generated_utc = [DateTime]::UtcNow.ToString("o")
  physical_profile_sha256 = $profileHash
  pilot_receipt_sha256 = $pilotHash
  show_results_sha256 = $resultsHash
  modules = @($rows | ForEach-Object {
    [ordered]@{
      module_id = $_.module_id
      module_name = $_.module_name
      run_count = [int]$_.run_count
      successful_runs = [int]$_.successful_runs
      tested_real = $_.tested_real
      notes = $_.notes
    }
  })
}

$parent = Split-Path -Parent $OutputJson
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

$receipt | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -Path $OutputJson
$hash = (Get-FileHash -Algorithm SHA256 $OutputJson).Hash.ToLowerInvariant()
"$hash  $([System.IO.Path]::GetFileName($OutputJson))" |
  Set-Content -Encoding ASCII -Path ($OutputJson + ".sha256")

Write-Host "PASS: advanced show-module promotion receipt generated" -ForegroundColor Green
Write-Host "State: $state"
Write-Host "Receipt: $OutputJson"
