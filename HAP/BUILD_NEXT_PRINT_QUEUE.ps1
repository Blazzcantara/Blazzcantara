param(
  [Parameter(Mandatory=$true)]
  [string]$CalibrationPackDir,

  [Parameter(Mandatory=$true)]
  [string]$ResultsCsv,

  [string]$OutputDir = ".\HAP\next_print_queue"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CalibrationPackDir)) { throw "Calibration pack directory not found: $CalibrationPackDir" }
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
    reference = "03_CORE\HAP_GT_CORE_nominal_v0.1.stl"
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

function Resolve-NextCandidate([string]$Gate) {
  $def = $definitions[$Gate]
  $gateRows = @($rows | Where-Object { $_.gate -eq $Gate })
  $realPass = @($gateRows | Where-Object { $_.result -eq "PASS" -and $_.tested_real -eq "YES" })

  if ($realPass.Count -eq 1) {
    return $null
  }

  $tested = @($gateRows | Where-Object { $_.result -in @("PASS","FAIL") })
  if ($tested.Count -eq 0) {
    return $def.start
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

  $ids = @($def.candidates)
  $index = [array]::IndexOf($ids,$last.candidate_id)
  $direction = $last.fit_direction

  $step = 0
  if ($direction -eq "TIGHT") {
    $step = if ($def.larger_means -eq "TIGHTER") { -1 } else { 1 }
  }
  elseif ($direction -eq "LOOSE") {
    $step = if ($def.larger_means -eq "TIGHTER") { 1 } else { -1 }
  }

  $testedIds = @($tested | ForEach-Object { $_.candidate_id })

  if ($index -ge 0 -and $step -ne 0) {
    $i = $index + $step
    while ($i -ge 0 -and $i -lt $ids.Count) {
      if ($testedIds -notcontains $ids[$i]) {
        return $ids[$i]
      }
      $i += $step
    }
  }

  foreach ($candidate in $ids) {
    if ($testedIds -notcontains $candidate) {
      return $candidate
    }
  }

  return $null
}

if (Test-Path $OutputDir) { Remove-Item $OutputDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$queue = @()
foreach ($gate in @("LEGO_CLUTCH","GT_MALE","CORE_CLEARANCE","TECHNIC_HOLE","NATIVE_CONNECTOR")) {
  $candidate = Resolve-NextCandidate $gate
  if (-not $candidate) { continue }

  $def = $definitions[$gate]
  $relative = $def.files[$candidate]
  $src = Join-Path $CalibrationPackDir $relative

  if (-not (Test-Path $src)) {
    throw "Required next-test STL missing: $src"
  }

  $dst = Join-Path $OutputDir ([System.IO.Path]::GetFileName($src))
  Copy-Item $src $dst

  $queue += [pscustomobject]@{
    gate = $gate
    candidate_id = $candidate
    source_relative_path = $relative
    queue_file = [System.IO.Path]::GetFileName($dst)
    sha256 = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
    reality_state = "NEXT_PHYSICAL_TEST"
  }

  if ($gate -eq "CORE_CLEARANCE" -and $def.Contains("reference")) {
    $coreRef = Join-Path $CalibrationPackDir $def.reference
    if (-not (Test-Path $coreRef)) { throw "Core reference missing: $coreRef" }

    $coreDst = Join-Path $OutputDir ([System.IO.Path]::GetFileName($coreRef))
    if (-not (Test-Path $coreDst)) {
      Copy-Item $coreRef $coreDst
    }
  }
}

$manifest = Join-Path $OutputDir "NEXT_PRINT_QUEUE.csv"
$queue | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifest

if ($queue.Count -eq 0) {
  $note = @"
# HAP Next Print Queue

No additional calibration STL is required.
All five physical interface gates already have a real PASS winner.

Next action: seal the physical profile and build the six-part system pilot.
"@
}
else {
  $note = @"
# HAP Next Print Queue

Print only the STL files in this folder.

Queued fit candidates: $($queue.Count)

For the HAP core gate the reusable nominal core reference is included when needed.

After each real fit test:
1. record PASS or FAIL with RECORD_PHYSICAL_RESULT.ps1;
2. include GOOD / TIGHT / LOOSE direction;
3. rebuild this queue.

Do not mark a fit PASS without a real physical test.
"@
}

Set-Content -Encoding UTF8 -Path (Join-Path $OutputDir "00_PRINT_THIS_NEXT.md") -Value $note

Write-Host ""
Write-Host "PASS: next physical print queue generated" -ForegroundColor Green
Write-Host "Queued fit candidates: $($queue.Count)"
Write-Host "Queue directory: $OutputDir"
