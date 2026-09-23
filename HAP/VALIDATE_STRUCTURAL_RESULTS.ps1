param(
  [Parameter(Mandatory=$true)]
  [string]$ResultsCsv,

  [Parameter(Mandatory=$true)]
  [string]$PhysicalProfileJson,

  [string]$OutputJson = ".\HAP\structural\STRUCTURAL_SEAL_RECEIPT_v0.1.json",

  [switch]$AllowSyntheticCiFixture
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ResultsCsv)) { throw "Structural results CSV not found: $ResultsCsv" }
if (-not (Test-Path $PhysicalProfileJson)) { throw "Physical profile not found: $PhysicalProfileJson" }

$profile = Get-Content -Raw -Path $PhysicalProfileJson | ConvertFrom-Json
$rows = @(Import-Csv $ResultsCsv)

$requiredIds = @(
  "STRUCT-SKY2x4",
  "STRUCT-SKY4x4",
  "STRUCT-SKY4x6",
  "STRUCT-BRIDGE32",
  "STRUCT-BRIDGE40",
  "STRUCT-BRIDGE-GT32",
  "STRUCT-FOOT32",
  "STRUCT-FOOT40",
  "STRUCT-OUT40",
  "STRUCT-TECH3H",
  "STRUCT-TECH5H"
)

if ($rows.Count -ne $requiredIds.Count) {
  throw "Expected 11 structural rows, found $($rows.Count)."
}

$ids = @($rows | ForEach-Object { $_.module_id })
if (@($ids | Sort-Object) -join "|" -ne @($requiredIds | Sort-Object) -join "|") {
  throw "Structural module IDs do not match the required gate set."
}

if (-not $AllowSyntheticCiFixture) {
  if ($profile.reality_state -ne "INTERFACE_VALUES_PHYSICALLY_SELECTED_PENDING_SYSTEM_PILOT") {
    throw "Physical profile is not a real selected profile. State: $($profile.reality_state)"
  }
}

foreach ($row in $rows) {
  foreach ($field in @(
    "vertical_load_pass",
    "lateral_rigidity_pass",
    "twist_pass",
    "crack_free"
  )) {
    if ($row.$field -ne "PASS") {
      throw "$($row.module_id) failed $field."
    }
  }

  if ($row.result -ne "PASS") {
    throw "$($row.module_id) result is not PASS."
  }

  if (-not $AllowSyntheticCiFixture -and $row.tested_real -ne "YES") {
    throw "$($row.module_id) is not marked tested_real=YES."
  }

  if (-not $AllowSyntheticCiFixture -and [string]::IsNullOrWhiteSpace($row.notes)) {
    throw "$($row.module_id) requires a physical-test note."
  }
}

$profileHash = (Get-FileHash -Algorithm SHA256 $PhysicalProfileJson).Hash.ToLowerInvariant()
$resultsHash = (Get-FileHash -Algorithm SHA256 $ResultsCsv).Hash.ToLowerInvariant()

$state = if ($AllowSyntheticCiFixture) {
  "SYNTHETIC_CI_STRUCTURAL_PASS_DO_NOT_PROMOTE"
}
else {
  "STRUCTURAL_PHYSICAL_PASS"
}

$receipt = [ordered]@{
  receipt_version = "0.1"
  reality_state = $state
  generated_utc = [DateTime]::UtcNow.ToString("o")
  physical_profile_sha256 = $profileHash
  structural_results_sha256 = $resultsHash
  modules = @($rows | ForEach-Object {
    [ordered]@{
      module_id = $_.module_id
      module_name = $_.module_name
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

Write-Host "PASS: structural seal receipt generated" -ForegroundColor Green
Write-Host "State: $state"
Write-Host "Receipt: $OutputJson"
