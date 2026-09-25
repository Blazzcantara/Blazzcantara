$ErrorActionPreference="Stop"
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$Cad=Join-Path $Root "cad\\HAP_MASTER_v0.1.scad"
$content=Get-Content -Raw $Cad
$required=@("LG2x2_GT","LG4x4_GT","GT_LG2x2","GT_LG4x4","LG4x4_GT_REINFORCED","GT_LG4x4_REINFORCED","LG4x4_GT_STARTER_OFFSET","GT_LG4x4_STARTER_OFFSET")
foreach($part in $required){if($content -notmatch [regex]::Escape('PART == "'+$part+'"')){throw "Missing selector: $part"}}
foreach($module in @("lego_stud_top","gt_to_lego_adapter","lego_to_gt_reinforced")){if($content -notmatch ('module\s+'+[regex]::Escape($module)+'\s*\(')){throw "Missing module: $module"}}
Write-Host "PASS: starter-pack CAD selectors/modules present." -ForegroundColor Green
