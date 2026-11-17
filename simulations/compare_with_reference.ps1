# Compares the inhaled THC doses of a new set of runs with the reference results of the paper.
# Run after analyze.ps1 (10-min runs -> exposure_summary.csv) and analyze60.ps1 (60-min runs -> <case>_exposure.csv).
# Large-eddy simulation is sensitive to hardware, compiler and MPI partitioning, so doses are not expected to match to
# the last digit; differences of a few percent are of the order of run-to-run variability reported in the paper.
param([double]$TolerancePct = 15.0, [string]$ReferenceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'reference_results'))
Set-Location $PSScriptRoot
$ref = $ReferenceDir
$rows = New-Object System.Collections.Generic.List[object]
function Add-Row($case, $pos, [double]$new, [double]$old) {
  $d = if ([math]::Abs($old) -gt 0.05) { 100 * ($new - $old) / $old } else { 0 }
  $rows.Add([pscustomobject]@{ Case = $case; Position = $pos; 'Reference (mg)' = $old; 'New (mg)' = $new; 'Diff (%)' = [math]::Round($d, 1)
                               Check = $(if ([math]::Abs($new - $old) -le 0.1 -or [math]::Abs($d) -le $TolerancePct) { 'ok' } else { 'CHECK' }) })
}
# 10-minute runs (Table 3)
if (Test-Path exposure_summary.csv) {
  $o = Import-Csv (Join-Path $ref 'exposure_summary.csv'); $n = Import-Csv exposure_summary.csv
  foreach ($r in $n) { $m = $o | Where-Object { $_.Scenario -eq $r.Scenario -and $_.Receptor -eq $r.Receptor }
    if ($m) { Add-Row $r.Scenario $r.Receptor ([double]$r.'Inhaled THC 10 min (mg)') ([double]$m.'Inhaled THC 10 min (mg)') } }
}
# 60-minute runs (Figure 4, altar-height comparison)
foreach ($f in Get-ChildItem -Filter '*_exposure.csv') {
  $rf = Join-Path $ref $f.Name; if (-not (Test-Path $rf)) { continue }
  $o = Import-Csv $rf; $n = Import-Csv $f.FullName
  foreach ($r in $n) { $m = $o | Where-Object { $_.Receptor -eq $r.Receptor }
    if ($m) { Add-Row ($f.Name -replace '_exposure.csv') $r.Receptor ([double]$r.'Dose 60 min (mg)') ([double]$m.'Dose 60 min (mg)') } }
}
if ($rows.Count -eq 0) { 'Nothing to compare: run analyze.ps1 / analyze60.ps1 on new results first.'; return }
$rows | Format-Table -AutoSize | Out-String -Width 220
"{0} of {1} doses within {2}% (or 0.1 mg) of the reference" -f ($rows | Where-Object Check -eq 'ok').Count, $rows.Count, $TolerancePct
