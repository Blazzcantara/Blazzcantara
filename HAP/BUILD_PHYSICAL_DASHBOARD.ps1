param(
  [Parameter(Mandatory=$true)]
  [string]$CalibrationResultsCsv,

  [string]$PilotResultsCsv = "",
  [string]$StructuralResultsCsv = "",
  [string]$ShowResultsCsv = "",
  [string]$OutputDir = ".\HAP\physical_dashboard"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CalibrationResultsCsv)) {
  throw "Calibration results CSV not found: $CalibrationResultsCsv"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$cal = @(Import-Csv $CalibrationResultsCsv)
$gates = @("LEGO_CLUTCH","GT_MALE","CORE_CLEARANCE","TECHNIC_HOLE","NATIVE_CONNECTOR")

$gateRows = foreach ($gate in $gates) {
  $rows = @($cal | Where-Object { $_.gate -eq $gate })
  $tested = @($rows | Where-Object { $_.result -in @("PASS","FAIL") })
  $winner = @($rows | Where-Object { $_.result -eq "PASS" -and $_.tested_real -eq "YES" })

  [pscustomobject]@{
    gate = $gate
    tested = $tested.Count
    total = $rows.Count
    state = if ($winner.Count -eq 1) { "PASS" } elseif ($tested.Count -eq 0) { "NOT_STARTED" } else { "IN_PROGRESS" }
    winner = if ($winner.Count -eq 1) { $winner[0].candidate_id } else { "" }
  }
}

function Get-TableState {
  param(
    [string]$Path,
    [string]$Name
  )

  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
    return [pscustomobject]@{
      name = $Name
      state = "NOT_AVAILABLE"
      pass_count = 0
      total = 0
    }
  }

  $rows = @(Import-Csv $Path)
  $passes = @($rows | Where-Object { $_.result -eq "PASS" -and $_.tested_real -eq "YES" })

  [pscustomobject]@{
    name = $Name
    state = if ($rows.Count -gt 0 -and $passes.Count -eq $rows.Count) { "PASS" }
      elseif ($passes.Count -eq 0) { "NOT_STARTED" }
      else { "IN_PROGRESS" }
    pass_count = $passes.Count
    total = $rows.Count
  }
}

$pilotState = Get-TableState -Path $PilotResultsCsv -Name "Pilot"
$structuralState = Get-TableState -Path $StructuralResultsCsv -Name "Structural"
$showState = Get-TableState -Path $ShowResultsCsv -Name "Show"

$calPass = @($gateRows | Where-Object { $_.state -eq "PASS" }).Count
$overall = if ($calPass -lt 5) {
  "CALIBRATION"
}
elseif ($pilotState.state -ne "PASS") {
  "FIRST_PILOT"
}
elseif ($structuralState.state -ne "PASS") {
  "STRUCTURAL"
}
elseif ($showState.state -ne "PASS") {
  "ADVANCED_SHOW"
}
else {
  "READY_FOR_FINAL_RELEASE"
}

$blockers = @()

foreach ($row in $gateRows) {
  if ($row.state -ne "PASS") {
    $blockers += "Interface gate not sealed: $($row.gate)"
  }
}

if ($calPass -eq 5 -and $pilotState.state -ne "PASS") {
  $blockers += "Straight / Curve / S-Curve pilot not physically passed"
}
if ($pilotState.state -eq "PASS" -and $structuralState.state -ne "PASS") {
  $blockers += "Structural physical matrix not fully passed"
}
if ($pilotState.state -eq "PASS" -and $showState.state -ne "PASS") {
  $blockers += "Advanced show-module promotion not fully passed"
}

$generated = [DateTime]::UtcNow.ToString("o")

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# HAP Physical Operator Dashboard")
[void]$md.AppendLine("")
[void]$md.AppendLine("Generated UTC: $generated")
[void]$md.AppendLine("")
[void]$md.AppendLine("Overall stage: **$overall**")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Interface gates")
[void]$md.AppendLine("")
[void]$md.AppendLine("| Gate | Tested | Total | State | Winner |")
[void]$md.AppendLine("|---|---:|---:|---|---|")
foreach ($row in $gateRows) {
  [void]$md.AppendLine("| $($row.gate) | $($row.tested) | $($row.total) | $($row.state) | $($row.winner) |")
}

[void]$md.AppendLine("")
[void]$md.AppendLine("## Downstream physical gates")
[void]$md.AppendLine("")
[void]$md.AppendLine("| Gate | Passed | Total | State |")
[void]$md.AppendLine("|---|---:|---:|---|")
foreach ($state in @($pilotState,$structuralState,$showState)) {
  [void]$md.AppendLine("| $($state.name) | $($state.pass_count) | $($state.total) | $($state.state) |")
}

[void]$md.AppendLine("")
[void]$md.AppendLine("## Current blockers")
[void]$md.AppendLine("")
if ($blockers.Count -eq 0) {
  [void]$md.AppendLine("- none")
}
else {
  foreach ($item in $blockers) {
    [void]$md.AppendLine("- $item")
  }
}

$mdPath = Join-Path $OutputDir "HAP_PHYSICAL_DASHBOARD.md"
Set-Content -Encoding UTF8 -Path $mdPath -Value $md.ToString()

function HtmlEncode([string]$Text) {
  return [System.Net.WebUtility]::HtmlEncode($Text)
}

$gateHtml = ($gateRows | ForEach-Object {
  "<tr><td>$(HtmlEncode $_.gate)</td><td>$($_.tested)/$($_.total)</td><td>$(HtmlEncode $_.state)</td><td>$(HtmlEncode $_.winner)</td></tr>"
}) -join [Environment]::NewLine

$downHtml = (@($pilotState,$structuralState,$showState) | ForEach-Object {
  "<tr><td>$(HtmlEncode $_.name)</td><td>$($_.pass_count)/$($_.total)</td><td>$(HtmlEncode $_.state)</td></tr>"
}) -join [Environment]::NewLine

$blockerHtml = if ($blockers.Count -eq 0) {
  "<li>none</li>"
}
else {
  ($blockers | ForEach-Object { "<li>$(HtmlEncode $_)</li>" }) -join [Environment]::NewLine
}

$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>HAP Physical Operator Dashboard</title>
<style>
body { font-family: system-ui, sans-serif; max-width: 980px; margin: 32px auto; padding: 0 16px; }
h1 { margin-bottom: 4px; }
.status { padding: 12px 16px; border: 1px solid #999; border-radius: 8px; margin: 16px 0; }
table { width: 100%; border-collapse: collapse; margin-bottom: 24px; }
th, td { border: 1px solid #bbb; padding: 8px; text-align: left; }
th { background: #eee; }
code { background: #eee; padding: 2px 5px; }
</style>
</head>
<body>
<h1>HAP Physical Operator Dashboard</h1>
<p>Generated UTC: $(HtmlEncode $generated)</p>
<div class="status"><strong>Overall stage:</strong> $(HtmlEncode $overall)</div>
<h2>Interface gates</h2>
<table>
<thead><tr><th>Gate</th><th>Tested</th><th>State</th><th>Winner</th></tr></thead>
<tbody>
$gateHtml
</tbody>
</table>
<h2>Downstream physical gates</h2>
<table>
<thead><tr><th>Gate</th><th>Passed</th><th>State</th></tr></thead>
<tbody>
$downHtml
</tbody>
</table>
<h2>Current blockers</h2>
<ul>
$blockerHtml
</ul>
</body>
</html>
"@

$htmlPath = Join-Path $OutputDir "HAP_PHYSICAL_DASHBOARD.html"
Set-Content -Encoding UTF8 -Path $htmlPath -Value $html

$summary = [ordered]@{
  generated_utc = $generated
  overall_stage = $overall
  calibration_pass_count = $calPass
  calibration_gate_count = 5
  pilot = $pilotState
  structural = $structuralState
  show = $showState
  blockers = $blockers
}

$jsonPath = Join-Path $OutputDir "HAP_PHYSICAL_DASHBOARD.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -Path $jsonPath

Write-Host "PASS: physical dashboard generated" -ForegroundColor Green
Write-Host "Stage: $overall"
Write-Host "Markdown: $mdPath"
Write-Host "HTML: $htmlPath"
Write-Host "JSON: $jsonPath"
