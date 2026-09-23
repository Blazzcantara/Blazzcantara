param(
  [Parameter(Mandatory=$true)]
  [string]$ResultsCsv,

  [Parameter(Mandatory=$true)]
  [ValidateSet("LEGO_CLUTCH","GT_MALE","CORE_CLEARANCE","TECHNIC_HOLE","NATIVE_CONNECTOR")]
  [string]$Gate,

  [Parameter(Mandatory=$true)]
  [string]$CandidateId,

  [Parameter(Mandatory=$true)]
  [ValidateSet("PASS","FAIL")]
  [string]$Outcome,

  [Parameter(Mandatory=$true)]
  [ValidateSet("GOOD","TIGHT","LOOSE","NA")]
  [string]$FitDirection,

  [ValidateRange(1,5)]
  [int]$ForceRating = 3,

  [ValidateRange(1,5)]
  [int]$WobbleRating = 3,

  [string]$Notes = "",

  [switch]$TestedReal,

  [switch]$ReplaceWinner
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ResultsCsv)) {
  throw "Results CSV not found: $ResultsCsv"
}

$rows = @(Import-Csv $ResultsCsv)
if (-not $rows) { throw "Results CSV is empty." }

foreach ($name in @("fit_direction","tested_utc")) {
  if (-not ($rows[0].PSObject.Properties.Name -contains $name)) {
    foreach ($row in $rows) {
      Add-Member -InputObject $row -NotePropertyName $name -NotePropertyValue ""
    }
  }
}

$row = $rows | Where-Object {
  $_.gate -eq $Gate -and $_.candidate_id -eq $CandidateId
} | Select-Object -First 1

if (-not $row) {
  throw "Candidate '$CandidateId' was not found in gate '$Gate'."
}

if ($Outcome -eq "PASS") {
  if ($FitDirection -ne "GOOD") {
    throw "A PASS result must use FitDirection=GOOD."
  }

  if (-not $TestedReal) {
    throw "A PASS result requires -TestedReal."
  }

  if ([string]::IsNullOrWhiteSpace($Notes)) {
    throw "A PASS result requires a physical-test note."
  }

  $otherPass = @($rows | Where-Object {
    $_.gate -eq $Gate -and
    $_.candidate_id -ne $CandidateId -and
    $_.result -eq "PASS"
  })

  if ($otherPass.Count -gt 0 -and -not $ReplaceWinner) {
    throw "Gate $Gate already has a PASS winner. Use -ReplaceWinner to supersede it."
  }

  if ($ReplaceWinner) {
    foreach ($old in $otherPass) {
      $old.result = "FAIL"
      $old.fit_direction = "NA"
      $old.notes = (($old.notes + " [superseded by " + $CandidateId + "]").Trim())
    }
  }
}
else {
  if ($FitDirection -eq "GOOD") {
    throw "A FAIL result cannot use FitDirection=GOOD."
  }
}

$row.result = $Outcome
$row.tested_real = if ($TestedReal) { "YES" } else { "NO" }
$row.force_rating = $ForceRating.ToString()
$row.wobble_rating = $WobbleRating.ToString()
$row.notes = $Notes
$row.fit_direction = $FitDirection
$row.tested_utc = [DateTime]::UtcNow.ToString("o")

$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $ResultsCsv

Write-Host ""
Write-Host "Recorded physical calibration result" -ForegroundColor Green
Write-Host "Gate      : $Gate"
Write-Host "Candidate : $CandidateId"
Write-Host "Outcome   : $Outcome"
Write-Host "Direction : $FitDirection"
Write-Host "Real test : $($row.tested_real)"
