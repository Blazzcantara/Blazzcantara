param(
  [Parameter(Mandatory=$true)]
  [string]$ResultsCsv
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ResultsCsv)) { throw "Results CSV not found: $ResultsCsv" }

$rows = Import-Csv $ResultsCsv
$gates = @(
  "LEGO_CLUTCH",
  "GT_MALE",
  "CORE_CLEARANCE",
  "TECHNIC_HOLE",
  "NATIVE_CONNECTOR"
)

$summary = @()

foreach ($gate in $gates) {
  $gateRows = @($rows | Where-Object { $_.gate -eq $gate })
  $tested = @($gateRows | Where-Object { $_.result -in @("PASS","FAIL") })
  $passes = @($gateRows | Where-Object { $_.result -eq "PASS" })
  $realPasses = @($passes | Where-Object { $_.tested_real -eq "YES" })

  $state = if ($realPasses.Count -eq 1 -and $passes.Count -eq 1) {
    "READY_TO_SEAL"
  }
  elseif ($passes.Count -gt 1) {
    "INVALID_MULTIPLE_PASS"
  }
  elseif ($passes.Count -eq 1 -and $realPasses.Count -eq 0) {
    "PASS_NOT_REAL_TESTED"
  }
  elseif ($tested.Count -eq $gateRows.Count -and $passes.Count -eq 0) {
    "NO_WINNER"
  }
  else {
    "IN_PROGRESS"
  }

  $summary += [pscustomobject]@{
    gate = $gate
    candidates = $gateRows.Count
    tested = $tested.Count
    pass_count = $passes.Count
    real_pass_count = $realPasses.Count
    state = $state
    winner = if ($passes.Count -eq 1) { $passes[0].candidate_id } else { "" }
  }
}

$summary | Format-Table -AutoSize

$allReady = @($summary | Where-Object { $_.state -eq "READY_TO_SEAL" }).Count -eq $gates.Count

if ($allReady) {
  Write-Host ""
  Write-Host "READY: all five physical interface gates have exactly one real winner." -ForegroundColor Green
  exit 0
}

Write-Host ""
Write-Host "HOLD: physical calibration is not complete yet." -ForegroundColor Yellow
exit 2
