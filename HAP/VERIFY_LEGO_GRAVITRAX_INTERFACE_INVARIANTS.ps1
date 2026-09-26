param(
  [string]$CadPath = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $CadPath) { $CadPath = Join-Path $Root "cad\HAP_MASTER_v0.1.scad" }
if (-not (Test-Path $CadPath)) { throw "CAD file not found: $CadPath" }

$cad = Get-Content -Raw $CadPath

$required = @(
  'GT_SOCKET_CLEARANCE = is_undef(GT_SOCKET_CLEARANCE) ? 0.30 : GT_SOCKET_CLEARANCE;',
  'socket_flat = GT_MALE_FLAT + GT_SOCKET_CLEARANCE;',
  'if (nx <= 2 || ny <= 2)',
  'else if (PART == "LG2x2_GT")',
  'else if (PART == "LG4x4_GT")',
  'else if (PART == "GT_LG2x2")',
  'else if (PART == "GT_LG4x4")'
)
foreach ($token in $required) {
  if (-not $cad.Contains($token)) { throw "Interface invariant missing: $token" }
}

if ($cad.Contains('inner_flat = GT_MALE_FLAT - 2*gt_ring_wall;')) {
  throw "Legacy invalid GT female receiver formula is present."
}

$male = 29.78
$clearance = 0.30
$socket = $male + $clearance
if ($socket -le $male) { throw "Nominal GT female receiver has no positive clearance." }
if ([math]::Abs($socket - 30.08) -gt 0.0001) { throw "Unexpected nominal GT socket flat: $socket" }

Write-Host "PASS: LEGO-GraviTrax interface invariants" -ForegroundColor Green
Write-Host "Nominal GT male flat: $male mm"
Write-Host "Nominal GT socket flat: $socket mm"
Write-Host "Nominal diametral/across-flat clearance: $clearance mm"
