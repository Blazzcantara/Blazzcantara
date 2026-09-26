param(
  [string]$OutputDir = ".\\HAP\\starter_pack_out"
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cad = Join-Path $Root "cad\\HAP_MASTER_v0.1.scad"
$Out = Join-Path $OutputDir "HAP_LEGO_GRAVITRAX_STARTER_PACK_PROVISIONAL"
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$candidates=@(
  "openscad",
  "/usr/bin/openscad",
  "openscad.com",
  "openscad.exe",
  "C:\\Program Files\\OpenSCAD\\openscad.com",
  "C:\\Program Files\\OpenSCAD\\openscad.exe"
)
$OpenSCAD=$null
foreach($candidate in $candidates){
  try {
    if(Test-Path $candidate){$OpenSCAD=$candidate;break}
    $cmd=Get-Command $candidate -ErrorAction SilentlyContinue
    if($cmd){$OpenSCAD=$cmd.Source;break}
  } catch {}
}
if(-not $OpenSCAD){throw "OpenSCAD not found on PATH or in known Windows/Linux locations."}

$parts=[ordered]@{
 "HAP_LG2x2_to_GT_PROVISIONAL"="LG2x2_GT"
 "HAP_LG4x4_to_GT_PROVISIONAL"="LG4x4_GT"
 "HAP_GT_to_LG2x2_PROVISIONAL"="GT_LG2x2"
 "HAP_GT_to_LG4x4_PROVISIONAL"="GT_LG4x4"
 "HAP_LG4x4_to_GT_REINFORCED_PROVISIONAL"="LG4x4_GT_REINFORCED"
 "HAP_GT_to_LG4x4_REINFORCED_PROVISIONAL"="GT_LG4x4_REINFORCED"
 "HAP_LG4x4_to_GT_OFFSET_Xp4_PROVISIONAL"="LG4x4_GT_STARTER_OFFSET"
 "HAP_GT_to_LG4x4_OFFSET_Xp4_PROVISIONAL"="GT_LG4x4_STARTER_OFFSET"
}
foreach($kv in $parts.GetEnumerator()){
 $dst=Join-Path $Out ($kv.Key+".stl")
 & $OpenSCAD "-o" $dst "-D" ('PART="'+$kv.Value+'"') $Cad
 if($LASTEXITCODE -ne 0){throw "OpenSCAD failed: $($kv.Key)"}
 if(-not(Test-Path $dst)){throw "Missing STL: $dst"}
 if((Get-Item $dst).Length -le 100){throw "Suspicious STL: $dst"}
}
$stls=Get-ChildItem $Out -Filter *.stl
if($stls.Count -ne 8){throw "Expected 8 STL, got $($stls.Count)"}
$manifest=@{
 package="HAP LEGO <-> GraviTrax Starter Pack"
 reality_state="DIGITALLY_GENERATED_PROVISIONAL_FINAL"
 physical_validation=$false
 stl_count=8
 files=@($stls|Sort-Object Name|ForEach-Object{@{name=$_.Name;sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant();bytes=$_.Length}})
}
$manifest|ConvertTo-Json -Depth 5|Set-Content (Join-Path $Out "MANIFEST.json") -Encoding UTF8
@"
# HAP LEGO <-> GraviTrax Starter Pack

Reality state: DIGITALLY_GENERATED_PROVISIONAL_FINAL
Physical validation: NOT PERFORMED

Contains eight focused adapters for both directions:
- LEGO 2x2 -> GraviTrax
- LEGO 4x4 -> GraviTrax
- GraviTrax -> LEGO 2x2
- GraviTrax -> LEGO 4x4
- reinforced 4x4 variants in both directions
- +4 mm X offset 4x4 variants in both directions

These are production-oriented candidates, not calibration coupons.
"@|Set-Content (Join-Path $Out "README.md") -Encoding UTF8
Write-Host "PASS: 8-STL starter pack generated." -ForegroundColor Green
