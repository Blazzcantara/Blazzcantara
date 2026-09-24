param(
  [Parameter(Mandatory=$true)]
  [string]$ResultsCsv,

  [string]$OutputJson = ".\HAP\calibration\PHYSICAL_PROFILE_v0.1.json",

  [switch]$AllowSyntheticCiFixture
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ResultsCsv)) {
  throw "Results CSV not found: $ResultsCsv"
}

$rows = Import-Csv $ResultsCsv
if (-not $rows) {
  throw "Results CSV is empty."
}

$requiredColumns = @(
  "gate","candidate_id","parameter","value","unit",
  "result","tested_real","force_rating","wobble_rating","notes",
  "fit_direction","tested_utc"
)

foreach ($column in $requiredColumns) {
  if (-not ($rows[0].PSObject.Properties.Name -contains $column)) {
    throw "Missing required CSV column: $column"
  }
}

$allowed = @{
  "LEGO_CLUTCH" = @("-0.08","-0.04","0.00","0.04","0.08")
  "GT_MALE" = @("29.60","29.70","29.78","29.86","29.96")
  "CORE_CLEARANCE" = @("0.20","0.30","0.40")
  "TECHNIC_HOLE" = @("4.80","4.90","5.00","5.10")
  "NATIVE_CONNECTOR" = @("0.996","0.998","1.000","1.002","1.004")
}

$gateOrder = @(
  "LEGO_CLUTCH",
  "GT_MALE",
  "CORE_CLEARANCE",
  "TECHNIC_HOLE",
  "NATIVE_CONNECTOR"
)

$selected = [ordered]@{}

foreach ($gate in $gateOrder) {
  $gateRows = @($rows | Where-Object { $_.gate -eq $gate })
  if ($gateRows.Count -ne $allowed[$gate].Count) {
    throw "Gate $gate has $($gateRows.Count) rows; expected $($allowed[$gate].Count)."
  }

  foreach ($row in $gateRows) {
    if ($allowed[$gate] -notcontains $row.value) {
      throw "Unexpected value '$($row.value)' in gate $gate."
    }

    if ($row.result -notin @("PASS","FAIL","UNTESTED")) {
      throw "Invalid result '$($row.result)' in gate $gate."
    }

    if ($row.tested_real -notin @("YES","NO")) {
      throw "Invalid tested_real '$($row.tested_real)' in gate $gate."
    }
  }

  $winner = @($gateRows | Where-Object { $_.result -eq "PASS" })

  if ($winner.Count -ne 1) {
    throw "Gate $gate requires exactly one PASS; found $($winner.Count)."
  }

  $winner = $winner[0]

  if (-not $AllowSyntheticCiFixture) {
    if ($winner.tested_real -ne "YES") {
      throw "Gate $gate winner is not marked tested_real=YES."
    }

    if ([string]::IsNullOrWhiteSpace($winner.notes)) {
      throw "Gate $gate winner requires a physical-test note."
    }

    if ($winner.fit_direction -ne "GOOD") {
      throw "Gate $gate winner must use fit_direction=GOOD."
    }

    $force = 0
    $wobble = 0
    if (-not [int]::TryParse($winner.force_rating,[ref]$force) -or $force -lt 1 -or $force -gt 5) {
      throw "Gate $gate winner requires force_rating 1-5."
    }
    if (-not [int]::TryParse($winner.wobble_rating,[ref]$wobble) -or $wobble -lt 1 -or $wobble -gt 5) {
      throw "Gate $gate winner requires wobble_rating 1-5."
    }

    $testedUtc = [DateTime]::MinValue
    if (
      [string]::IsNullOrWhiteSpace($winner.tested_utc) -or
      -not [DateTime]::TryParse($winner.tested_utc,[ref]$testedUtc)
    ) {
      throw "Gate $gate winner requires a valid tested_utc timestamp."
    }
  }

  $selected[$gate] = [ordered]@{
    candidate_id = $winner.candidate_id
    parameter = $winner.parameter
    value = [double]::Parse(
      $winner.value,
      [System.Globalization.CultureInfo]::InvariantCulture
    )
    unit = $winner.unit
    tested_real = $winner.tested_real
    force_rating = $winner.force_rating
    wobble_rating = $winner.wobble_rating
    notes = $winner.notes
    fit_direction = $winner.fit_direction
    tested_utc = $winner.tested_utc
  }
}

$sourceHash = (Get-FileHash -Algorithm SHA256 $ResultsCsv).Hash.ToLowerInvariant()

$state = if ($AllowSyntheticCiFixture) {
  "SYNTHETIC_CI_ONLY_DO_NOT_USE_FOR_PRINTING"
}
else {
  "INTERFACE_VALUES_PHYSICALLY_SELECTED_PENDING_SYSTEM_PILOT"
}

$profile = [ordered]@{
  profile_version = "0.1"
  reality_state = $state
  generated_utc = [DateTime]::UtcNow.ToString("o")
  source_results_sha256 = $sourceHash
  selected = $selected
}

$parent = Split-Path -Parent $OutputJson
if ($parent) {
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

$profile | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -Path $OutputJson

$profileHash = (Get-FileHash -Algorithm SHA256 $OutputJson).Hash.ToLowerInvariant()
$shaPath = $OutputJson + ".sha256"
"$profileHash  $([System.IO.Path]::GetFileName($OutputJson))" |
  Set-Content -Encoding ASCII -Path $shaPath

Write-Host ""
Write-Host "PASS: calibration profile generated" -ForegroundColor Green
Write-Host "State  : $state"
Write-Host "Profile: $OutputJson"
Write-Host "SHA256 : $profileHash"

if ($AllowSyntheticCiFixture) {
  Write-Host "WARNING: synthetic CI fixture; not valid for real printing." -ForegroundColor Yellow
}
