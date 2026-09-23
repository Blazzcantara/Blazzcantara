param(
  [Parameter(Mandatory=$true)]
  [string]$ResultsCsv,

  [ValidateSet("ALL","LEGO_CLUTCH","GT_MALE","CORE_CLEARANCE","TECHNIC_HOLE","NATIVE_CONNECTOR")]
  [string]$Gate = "ALL"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ResultsCsv)) { throw "Results CSV not found: $ResultsCsv" }

$rows = @(Import-Csv $ResultsCsv)
if (-not $rows) { throw "Results CSV is empty." }

$definitions = @{
  "LEGO_CLUTCH" = [ordered]@{
    candidates = @("LEGO_D_m0.08","LEGO_D_m0.04","LEGO_D_0.00","LEGO_D_p0.04","LEGO_D_p0.08")
    start = "LEGO_D_0.00"
    larger_means = "TIGHTER"
    files = @{
      "LEGO_D_m0.08" = "01_LEGO\CAL_LEGO_2x2_delta_m0.08.stl"
      "LEGO_D_m0.04" = "01_LEGO\CAL_LEGO_2x2_delta_m0.04.stl"
      "LEGO_D_0.00" = "01_LEGO\CAL_LEGO_2x2_delta_0.00.stl"
      "LEGO_D_p0.04" = "01_LEGO\CAL_LEGO_2x2_delta_p0.04.stl"
      "LEGO_D_p0.08" = "01_LEGO\CAL_LEGO_2x2_delta_p0.08.stl"
    }
  }
  "GT_MALE" = [ordered]@{
    candidates = @("GT_29.60","GT_29.70","GT_29.78","GT_29.86","GT_29.96")
    start = "GT_29.78"
    larger_means = "TIGHTER"
    files = @{
      "GT_29.60" = "02_GT_MALE\CAL_GT_male_29.60.stl"
      "GT_29.70" = "02_GT_MALE\CAL_GT_male_29.70.stl"
      "GT_29.78" = "02_GT_MALE\CAL_GT_male_29.78.stl"
      "GT_29.86" = "02_GT_MALE\CAL_GT_male_29.86.stl"
      "GT_29.96" = "02_GT_MALE\CAL_GT_male_29.96.stl"
    }
  }
  "CORE_CLEARANCE" = [ordered]@{
    candidates = @("CORE_0.20","CORE_0.30","CORE_0.40")
    start = "CORE_0.30"
    larger_means = "LOOSER"
    files = @{
      "CORE_0.20" = "03_CORE\CAL_CORE_SOCKET_0.20_v0.1.stl"
      "CORE_0.30" = "03_CORE\CAL_CORE_SOCKET_0.30_v0.1.stl"
      "CORE_0.40" = "03_CORE\CAL_CORE_SOCKET_0.40_v0.1.stl"
    }
  }
  "TECHNIC_HOLE" = [ordered]@{
    candidates = @("TECHNIC_4.80","TECHNIC_4.90","TECHNIC_5.00","TECHNIC_5.10")
    start = "TECHNIC_4.90"
    larger_means = "LOOSER"
    files = @{
      "TECHNIC_4.80" = "04_TECHNIC\CAL_TECHNIC_HOLE_4.80_v0.1.stl"
      "TECHNIC_4.90" = "04_TECHNIC\CAL_TECHNIC_HOLE_4.90_v0.1.stl"
      "TECHNIC_5.00" = "04_TECHNIC\CAL_TECHNIC_HOLE_5.00_v0.1.stl"
      "TECHNIC_5.10" = "04_TECHNIC\CAL_TECHNIC_HOLE_5.10_v0.1.stl"
    }
  }
  "NATIVE_CONNECTOR" = [ordered]@{
    candidates = @("NATIVE_0.996","NATIVE_0.998","NATIVE_1.000","NATIVE_1.002","NATIVE_1.004")
    start = "NATIVE_1.000"
    larger_means = "TIGHTER"
    files = @{
      "NATIVE_0.996" = "05_NATIVE\HAP_NATIVE_CONNECTOR_ONLY_scale_0.996_v0.1.stl"
      "NATIVE_0.998" = "05_NATIVE\HAP_NATIVE_CONNECTOR_ONLY_scale_0.998_v0.1.stl"
      "NATIVE_1.000" = "05_NATIVE\HAP_NATIVE_CONNECTOR_ONLY_scale_1.000_v0.1.stl"
      "NATIVE_1.002" = "05_NATIVE\HAP_NATIVE_CONNECTOR_ONLY_scale_1.002_v0.1.stl"
      "NATIVE_1.004" = "05_NATIVE\HAP_NATIVE_CONNECTOR_ONLY_scale_1.004_v0.1.stl"
    }
  }
}

function Get-NextForGate([string]$GateName) {
  $def = $definitions[$GateName]
  $gateRows = @($rows | Where-Object { $_.gate -eq $GateName })
  $pass = @($gateRows | Where-Object { $_.result -eq "PASS" -and $_.tested_real -eq "YES" })

  if ($pass.Count -eq 1) {
    return [pscustomobject]@{
      gate = $GateName
      state = "COMPLETE"
      candidate_id = $pass[0].candidate_id
      file = $def.files[$pass[0].candidate_id]
      reason = "Real physical PASS already recorded"
    }
  }

  $tested = @($gateRows | Where-Object { $_.result -in @("PASS","FAIL") })

  if ($tested.Count -eq 0) {
    return [pscustomobject]@{
      gate = $GateName
      state = "PRINT_NEXT"
      candidate_id = $def.start
      file = $def.files[$def.start]
      reason = "Start with nominal candidate"
    }
  }

  $last = $tested |
    Sort-Object {
      if ([string]::IsNullOrWhiteSpace($_.tested_utc)) {
        [DateTime]::MinValue
      }
      else {
        try { [DateTime]::Parse($_.tested_utc) } catch { [DateTime]::MinValue }
      }
    } -Descending |
    Select-Object -First 1

  if ($last.result -eq "PASS" -and $last.tested_real -ne "YES") {
    return [pscustomobject]@{
      gate = $GateName
      state = "RETEST_REAL"
      candidate_id = $last.candidate_id
      file = $def.files[$last.candidate_id]
      reason = "PASS exists but is not marked as a real physical test"
    }
  }

  $direction = $last.fit_direction
  $candidates = @($def.candidates)
  $index = [array]::IndexOf($candidates,$last.candidate_id)
  if ($index -lt 0) { throw "Candidate order missing for $($last.candidate_id)" }

  $step = 0
  if ($direction -eq "TIGHT") {
    $step = if ($def.larger_means -eq "TIGHTER") { -1 } else { 1 }
  }
  elseif ($direction -eq "LOOSE") {
    $step = if ($def.larger_means -eq "TIGHTER") { 1 } else { -1 }
  }

  $testedIds = @($tested | ForEach-Object { $_.candidate_id })

  if ($step -ne 0) {
    $i = $index + $step
    while ($i -ge 0 -and $i -lt $candidates.Count) {
      $candidate = $candidates[$i]
      if ($testedIds -notcontains $candidate) {
        return [pscustomobject]@{
          gate = $GateName
          state = "PRINT_NEXT"
          candidate_id = $candidate
          file = $def.files[$candidate]
          reason = "Previous candidate was $direction"
        }
      }
      $i += $step
    }
  }

  foreach ($candidate in $candidates) {
    if ($testedIds -notcontains $candidate) {
      return [pscustomobject]@{
        gate = $GateName
        state = "PRINT_NEXT"
        candidate_id = $candidate
        file = $def.files[$candidate]
        reason = "Fallback to next untested candidate"
      }
    }
  }

  return [pscustomobject]@{
    gate = $GateName
    state = "NO_WINNER"
    candidate_id = ""
    file = ""
    reason = "All candidates were tested without a real PASS"
  }
}

$targets = if ($Gate -eq "ALL") {
  @("LEGO_CLUTCH","GT_MALE","CORE_CLEARANCE","TECHNIC_HOLE","NATIVE_CONNECTOR")
}
else {
  @($Gate)
}

$result = @($targets | ForEach-Object { Get-NextForGate $_ })
$result | Format-Table -AutoSize
