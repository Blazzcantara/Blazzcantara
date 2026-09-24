param(
  [string]$WorkbenchDir = ".",
  [string]$ArchivePath = ""
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path $WorkbenchDir).Path
$Work = Join-Path $Root "WORK"
$ResultsCsv = Join-Path $Work "PHYSICAL_RESULTS_WORKING.csv"
$Recorder = Join-Path $Root "RECORD_PHYSICAL_RESULT.ps1"
$Refresh = Join-Path $Root "REFRESH_PHYSICAL_WORKBENCH.ps1"
$Campaign = Join-Path $Root "RUN_PHYSICAL_CAMPAIGN.ps1"
$Checkpoint = Join-Path $Root "SAVE_PHYSICAL_CHECKPOINT.ps1"
$Dashboard = Join-Path $Work "DASHBOARD\HAP_PHYSICAL_DASHBOARD.html"

$PowerShellExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
  (Get-Command pwsh).Source
}
elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
  (Get-Command powershell).Source
}
else {
  throw "PowerShell executable not found."
}

foreach ($required in @($ResultsCsv,$Recorder,$Refresh,$Campaign,$Checkpoint)) {
  if (-not (Test-Path $required)) {
    throw "Workbench file missing: $required"
  }
}

function Refresh-Workbench {
  & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Refresh -WorkbenchDir $Root
  if ($LASTEXITCODE -ne 0) {
    throw "Workbench refresh failed."
  }
}

function Resolve-Archive {
  if (-not [string]::IsNullOrWhiteSpace($script:ArchivePath) -and (Test-Path $script:ArchivePath)) {
    return $script:ArchivePath
  }

  $entered = Read-Host "Full path to lego-umbau.zip"
  if ([string]::IsNullOrWhiteSpace($entered) -or -not (Test-Path $entered)) {
    Write-Host "Archive not found." -ForegroundColor Red
    return $null
  }

  $script:ArchivePath = (Resolve-Path $entered).Path
  return $script:ArchivePath
}

function Record-PhysicalFit {
  $gates = @(
    "LEGO_CLUTCH",
    "GT_MALE",
    "CORE_CLEARANCE",
    "TECHNIC_HOLE",
    "NATIVE_CONNECTOR"
  )

  Write-Host ""
  Write-Host "Select interface gate:" -ForegroundColor Cyan
  for ($i=0; $i -lt $gates.Count; $i++) {
    Write-Host "$($i+1)) $($gates[$i])"
  }

  $gateSelection = Read-Host "Gate number"
  $gateIndex = 0
  if (-not [int]::TryParse($gateSelection,[ref]$gateIndex)) {
    Write-Host "Invalid gate selection." -ForegroundColor Red
    return
  }
  $gateIndex -= 1
  if ($gateIndex -lt 0 -or $gateIndex -ge $gates.Count) {
    Write-Host "Invalid gate selection." -ForegroundColor Red
    return
  }

  $gate = $gates[$gateIndex]
  $rows = @(Import-Csv $ResultsCsv | Where-Object { $_.gate -eq $gate })

  Write-Host ""
  Write-Host "Candidates for $gate" -ForegroundColor Cyan
  foreach ($row in $rows) {
    Write-Host ("- {0,-22} result={1,-8} value={2} {3}" -f $row.candidate_id,$row.result,$row.value,$row.unit)
  }

  $candidate = Read-Host "Candidate ID exactly as shown"
  if (-not ($rows | Where-Object { $_.candidate_id -eq $candidate })) {
    Write-Host "Unknown candidate ID for $gate." -ForegroundColor Red
    return
  }

  $outcome = (Read-Host "Outcome PASS or FAIL").ToUpperInvariant()
  if ($outcome -notin @("PASS","FAIL")) {
    Write-Host "Outcome must be PASS or FAIL." -ForegroundColor Red
    return
  }

  if ($outcome -eq "PASS") {
    $direction = "GOOD"
  }
  else {
    $direction = (Read-Host "Fit direction TIGHT, LOOSE or NA").ToUpperInvariant()
    if ($direction -notin @("TIGHT","LOOSE","NA")) {
      Write-Host "Invalid fit direction." -ForegroundColor Red
      return
    }
  }

  $forceText = Read-Host "Insertion/removal force 1-5"
  $wobbleText = Read-Host "Wobble 1-5 (1 = minimal)"
  $force = 0
  $wobble = 0

  if (-not [int]::TryParse($forceText,[ref]$force) -or $force -lt 1 -or $force -gt 5) {
    Write-Host "Force must be 1-5." -ForegroundColor Red
    return
  }
  if (-not [int]::TryParse($wobbleText,[ref]$wobble) -or $wobble -lt 1 -or $wobble -gt 5) {
    Write-Host "Wobble must be 1-5." -ForegroundColor Red
    return
  }

  $notes = Read-Host "Short physical-test note"
  if ($outcome -eq "PASS" -and [string]::IsNullOrWhiteSpace($notes)) {
    Write-Host "PASS requires a note." -ForegroundColor Red
    return
  }

  $args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $Recorder,
    "-ResultsCsv", $ResultsCsv,
    "-Gate", $gate,
    "-CandidateId", $candidate,
    "-Outcome", $outcome,
    "-FitDirection", $direction,
    "-ForceRating", $force,
    "-WobbleRating", $wobble,
    "-Notes", $notes,
    "-TestedReal"
  )

  & $PowerShellExe @args
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Result recorder rejected the entry." -ForegroundColor Red
    return
  }

  Refresh-Workbench
}

Refresh-Workbench

while ($true) {
  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Cyan
  Write-Host " HAP PHYSICAL WORKBENCH"
  Write-Host "============================================================"
  Write-Host "1) Refresh next-print queue + dashboard"
  Write-Host "2) Record a real physical fit result"
  Write-Host "3) Run campaign progress / auto-promote when ready"
  Write-Host "4) Save physical checkpoint"
  Write-Host "5) Open HTML dashboard"
  Write-Host "6) Exit"
  Write-Host ""

  $choice = Read-Host "Select 1-6"

  switch ($choice) {
    "1" {
      Refresh-Workbench
    }
    "2" {
      Record-PhysicalFit
    }
    "3" {
      $archive = Resolve-Archive
      if ($archive) {
        $args = @(
          "-NoProfile",
          "-ExecutionPolicy", "Bypass",
          "-File", $Campaign,
          "-ArchivePath", $archive,
          "-WorkDir", $Work,
          "-SkipPackBuild"
        )
        & $PowerShellExe @args
        if ($LASTEXITCODE -ne 0) {
          Write-Host "Campaign runner returned an error." -ForegroundColor Red
        }
        else {
          Refresh-Workbench
        }
      }
    }
    "4" {
      $checkpointDir = Join-Path $Work "CHECKPOINTS"
      & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Checkpoint -WorkDir $Work -CheckpointDir $checkpointDir
    }
    "5" {
      if (-not (Test-Path $Dashboard)) {
        Refresh-Workbench
      }

      if (Test-Path $Dashboard) {
        try {
          Start-Process $Dashboard
        }
        catch {
          Write-Host "Dashboard: $Dashboard"
        }
      }
    }
    "6" {
      break
    }
    default {
      Write-Host "Invalid selection." -ForegroundColor Yellow
    }
  }

  if ($choice -eq "6") { break }
}
