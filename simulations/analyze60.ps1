# Exposure analysis of the 60-min ritual run (arad_ritual60).
# Same assumptions as analyze.ps1: breathing 0.75 m3/h; inhaled dose = breathing x integral(C dt);
# effect bands on inhaled THC (Spindle et al. 2018): <2 none | 2-5 threshold | 5-10 mild | 10-25 clear | >25 strong
# alpha-pinene odour threshold 18 ppb (Nagata 2003). THC source: 50 mg/min (2 g/min cannabis, 5% THC, 50% released).
param([string]$Chid = 'arad_ritual60')
Set-Location $PSScriptRoot

$breath = 0.75 / 3600.0
$thcRate = 50.0 / 60.0            # mg/s at full burn (30 s t^2 ramp)
$names = [ordered]@{
  P9 = 'Priest leaning over cannabis altar'; P10 = 'Priest leaning over frankincense altar';
  P12 = 'Priest on stair 2 between altars';  P11 = 'Priest kneeling before altars';
  P1 = 'Priest standing before altars';      P2 = 'Inside the cella';
  P3 = 'Hall centre (standing)';             P4 = 'S bench (seated)';  P5 = 'W bench (seated)';
  P6 = 'N end of hall';                      P7 = 'Hall doorway';      P8 = 'Court, 3 m from door' }

function Band([double]$mg) {
  if ($mg -lt 2) { 'none expected' } elseif ($mg -lt 5) { 'threshold' } elseif ($mg -lt 10) { 'mild' }
  elseif ($mg -lt 25) { 'clear' } else { 'strong' }
}

$lines = Get-Content "${Chid}_devc.csv"
$hdr = $lines[1].Split(',') | ForEach-Object { $_.Trim().Trim('"') }
$col = @{}; for ($i = 0; $i -lt $hdr.Count; $i++) { $col[$hdr[$i]] = $i }
$rows = foreach ($l in $lines[2..($lines.Count-1)]) { ,($l.Split(',') | ForEach-Object { [double]$_ }) }
$tEnd = $rows[-1][0]
$win = [math]::Min(600.0, $tEnd / 2)          # averaging window: last 10 min

$out = New-Object System.Collections.Generic.List[object]
foreach ($p in $names.Keys) {
  $ci = $col["${p}_THC"]; if ($null -eq $ci) { continue }
  $cum = 0.0; $at = @{ 600 = $null; 1800 = $null; 3600 = $null }; $tx = @{ 2 = $null; 5 = $null; 10 = $null; 25 = $null }
  $peak = 0.0; $s = 0.0; $n = 0
  for ($k = 1; $k -lt $rows.Count; $k++) {
    $tk = $rows[$k][0]
    $cum += 0.5 * ($rows[$k][$ci] + $rows[$k-1][$ci]) * ($tk - $rows[$k-1][0]) * $breath
    foreach ($m in @(600, 1800, 3600)) { if ($null -eq $at[$m] -and $tk -ge $m - 1e-6) { $at[$m] = $cum } }
    foreach ($m in @(2, 5, 10, 25)) { if ($null -eq $tx[$m] -and $cum -ge $m) { $tx[$m] = $tk / 60.0 } }
    $peak = [math]::Max($peak, $rows[$k][$ci])
    if ($tk -ge $tEnd - $win) { $s += $rows[$k][$ci]; $n++ }
  }
  $pinC = $col["${p}_PIN"]
  $pin = if ($null -ne $pinC) { ($rows | Where-Object { $_[0] -ge $tEnd - $win } | ForEach-Object { $_[$pinC] } | Measure-Object -Average).Average } else { $null }
  $fmt = { param($v) if ($null -eq $v) { '-' } else { [math]::Round($v, 1) } }
  $out.Add([pscustomobject]@{
    Receptor = "$p $($names[$p])"
    'THC last 10 min (mg/m3)' = [math]::Round($s / [math]::Max($n, 1), 2)
    'THC peak (mg/m3)' = [math]::Round($peak, 2)
    'Dose 10 min (mg)' = & $fmt $at[600]
    'Dose 30 min (mg)' = & $fmt $at[1800]
    'Dose 60 min (mg)' = [math]::Round($cum, 1)
    'Effect at end' = Band $cum
    'min to 2 mg' = & $fmt $tx[2]
    'min to 5 mg' = & $fmt $tx[5]
    'min to 10 mg' = & $fmt $tx[10]
    'Pinene (ppb)' = $(if ($null -ne $pin) { [math]::Round($pin, 0) } else { '' })
    'x odour thr.' = $(if ($null -ne $pin) { [math]::Round($pin / 18.0, 0) } else { '' })
  })
}

$last = $rows[-1]
$emitted = $thcRate * ($tEnd - 20)
$held = $last[$col['THC_in_hall']] + $last[$col['THC_in_cella']]
"[{0}] t_end = {1:0} s ({2:0.0} min)" -f $Chid, $tEnd, ($tEnd / 60)
"  THC emitted ~{0:0} mg; held in hall+cella {1:0} mg ({2:0}%); door air exchange (last 10 min) {3:0.000} m3/s" -f `
   $emitted, $held, (100 * $held / $emitted), (($rows | Where-Object { $_[0] -ge $tEnd - $win } | ForEach-Object { -$_[$col['Air_in_door']] } | Measure-Object -Average).Average)
foreach ($v in 'P1_VIS','P2_VIS','P3_VIS','P9_VIS') {
  "  min visibility {0}: {1:0.0} m" -f $v, (($rows | ForEach-Object { $_[$col[$v]] } | Measure-Object -Minimum).Minimum)
}
foreach ($v in 'P9_T','P10_T','T_above_S_altar','T_above_N_altar','T_ceiling_hall','T_cella') {
  "  {0}: {1:0.0} C (end)" -f $v, $last[$col[$v]]
}
foreach ($v in 'P2_INC','P3_INC','P9_INC','P10_INC') {
  "  incensole acetate {0}: {1:0.000} mg/m3 (last 10 min mean)" -f $v, (($rows | Where-Object { $_[0] -ge $tEnd - $win } | ForEach-Object { $_[$col[$v]] } | Measure-Object -Average).Average)
}
$out | Export-Csv "${Chid}_exposure.csv" -NoTypeInformation -Encoding UTF8
$out | Format-Table -AutoSize | Out-String -Width 260
