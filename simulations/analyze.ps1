# Exposure analysis of the Arad incense runs.
# For each scenario and receptor: THC concentration, inhaled THC dose (10 min), time to reach
# effect thresholds, alpha-pinene vs odour threshold, visibility.
#
# Assumptions (stated in the report):
#   breathing rate 0.75 m3/h (standing / light ritual activity; ICRP rest 0.54, light work ~1.5)
#   inhaled THC dose = breathing rate x time-integral of THC concentration at nose height
#   effect bands on inhaled dose (mg), anchored to Spindle et al. 2018 (10 mg THC inhaled
#   -> discriminable effects, modest impairment; 25 mg -> pronounced effects, infrequent users):
#     < 2 none expected | 2-5 threshold (naive users) | 5-10 mild | 10-25 clear | > 25 strong
#   alpha-pinene odour threshold 18 ppb (Nagata 2003)
param([string[]]$Cases = @('arad_low','arad_incense','arad_high','arad_canonly'))
Set-Location $PSScriptRoot

$breath = 0.75 / 3600.0      # m3/s
$names = [ordered]@{
  P1 = 'Priest at the altars'; P2 = 'Inside the cella'; P3 = 'Hall centre (standing)';
  P4 = 'S bench (seated)';     P5 = 'W bench (seated)'; P6 = 'N end of hall';
  P7 = 'Hall doorway';         P8 = 'Court, 3 m from door' }
$label = @{ arad_low='LOW 2.4 m / niche 1.8'; arad_incense='BASE 3.0 m'; arad_high='HIGH 4.4 m'; arad_canonly='BASE, cannabis only' }

function Band([double]$mg) {
  if ($mg -lt 2) { 'none expected' } elseif ($mg -lt 5) { 'threshold' } elseif ($mg -lt 10) { 'mild' }
  elseif ($mg -lt 25) { 'clear' } else { 'strong' }
}

function Read-Devc([string]$chid) {
  $f = "${chid}_devc.csv"
  if (-not (Test-Path $f)) { return $null }
  $lines = Get-Content $f
  $hdr = $lines[1].Split(',') | ForEach-Object { $_.Trim().Trim('"') }
  $rows = foreach ($l in $lines[2..($lines.Count-1)]) { ,($l.Split(',') | ForEach-Object { [double]$_ }) }
  return @{ hdr = $hdr; rows = $rows }
}

$summary = New-Object System.Collections.Generic.List[object]
foreach ($c in $Cases) {
  $d = Read-Devc $c
  if (-not $d) { "[$c] no results yet"; continue }
  $col = @{}; for ($i = 0; $i -lt $d.hdr.Count; $i++) { $col[$d.hdr[$i]] = $i }
  $t = $d.rows | ForEach-Object { $_[0] }
  $tEnd = $t[-1]
  foreach ($p in $names.Keys) {
    $ci = $col["${p}_THC"]; if ($null -eq $ci) { continue }
    $cum = 0.0; $t2 = $null; $t5 = $null; $peak = 0.0; $sum5 = 0.0; $n5 = 0
    for ($k = 1; $k -lt $d.rows.Count; $k++) {
      $dt = $d.rows[$k][0] - $d.rows[$k-1][0]
      $cAvg = 0.5 * ($d.rows[$k][$ci] + $d.rows[$k-1][$ci])          # mg/m3
      $cum += $cAvg * $dt * $breath                                   # mg inhaled
      if ($null -eq $t2 -and $cum -ge 2) { $t2 = $d.rows[$k][0] }
      if ($null -eq $t5 -and $cum -ge 5) { $t5 = $d.rows[$k][0] }
      $peak = [math]::Max($peak, $d.rows[$k][$ci])
      if ($d.rows[$k][0] -ge $tEnd - 300) { $sum5 += $d.rows[$k][$ci]; $n5++ }
    }
    $pin = $col["${p}_PIN"]
    $pinMean = if ($null -ne $pin) { ($d.rows | Where-Object { $_[0] -ge $tEnd - 300 } | ForEach-Object { $_[$pin] } | Measure-Object -Average).Average } else { $null }
    $summary.Add([pscustomobject]@{
      Scenario = $label[$c]; Receptor = "$p $($names[$p])"
      'THC mean last 5 min (mg/m3)' = [math]::Round($sum5 / [math]::Max($n5,1), 3)
      'THC peak (mg/m3)' = [math]::Round($peak, 3)
      'Inhaled THC 10 min (mg)' = [math]::Round($cum, 2)
      'Effect band' = Band $cum
      'Cannabis for 2 mg (g/10 min)' = $(if ($cum -gt 1e-6) { [math]::Round(5.0 * 2.0 / $cum, 0) } else { 'n/a' })
      't to 2 mg (s)' = $(if ($t2) { [int]$t2 } else { '-' })
      't to 5 mg (s)' = $(if ($t5) { [int]$t5 } else { '-' })
      'Pinene mean (ppb)' = $(if ($null -ne $pinMean) { [math]::Round($pinMean, 0) } else { '' })
      'x odour threshold' = $(if ($null -ne $pinMean) { [math]::Round($pinMean / 18.0, 1) } else { '' })
    })
  }
  # whole-shrine indicators
  $last = $d.rows[-1]
  $vis = foreach ($v in 'P1_VIS','P3_VIS') { if ($col[$v]) { "$v=" + [math]::Round(($d.rows | Where-Object { $_[0] -ge $tEnd - 300 } | ForEach-Object { $_[$col[$v]] } | Measure-Object -Minimum).Minimum, 1) + 'm' } }
  $airIn = ($d.rows | Where-Object { $_[0] -ge $tEnd - 300 } | ForEach-Object { -$_[$col['Air_in_door']] } | Measure-Object -Average).Average
  $emitted = 12.5 / 60.0 * ($tEnd - 15)     # mg THC emitted (approx., 30 s ramp)
  "[{0}] t_end={1:0}s  THC held in hall+cella={2:0.0} mg of ~{3:0} mg emitted ({4:0}%)  air exchange via door={5:0.000} m3/s  min visibility (last 5 min): {6}  T ceiling={7:0.0}C" -f `
     $label[$c], $tEnd, ($last[$col['THC_in_hall']] + $last[$col['THC_in_cella']]), $emitted,
     (100 * ($last[$col['THC_in_hall']] + $last[$col['THC_in_cella']]) / $emitted), $airIn, ($vis -join ' '), $last[$col['T_ceiling_hall']]
}
$summary | Export-Csv exposure_summary.csv -NoTypeInformation -Encoding UTF8
$summary | Format-Table -AutoSize | Out-String -Width 250
