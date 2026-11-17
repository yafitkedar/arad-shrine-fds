# Dot plot of the 60-min inhaled THC dose by position, 3.0 m vs 2.4 m ceiling (paper Figure 4).
# Reads the *_exposure.csv tables written by analyze60.ps1. S = output scale (vector redraw).
param([double]$S = 2.0, [string]$Out = 'smv_img\fig_dose_60min.png')
Set-Location $PSScriptRoot
Add-Type -AssemblyName System.Drawing

function Doses([string]$csv) { $h = @{}; Import-Csv $csv | ForEach-Object { $h[($_.Receptor -split ' ')[0]] = [double]$_.'Dose 60 min (mg)' }; $h }
$base = Doses 'arad_ritual60_exposure.csv'; $low = Doses 'arad_ritual60_low_exposure.csv'
$labels = [ordered]@{ P12 = 'Priest in cella opening'; P2 = 'Inside the cella'; P4 = 'S bench (seated)'; P5 = 'W bench (seated)'
  P1 = 'Priest standing before altars'; P3 = 'Hall centre'; P6 = 'N end of hall'; P7 = 'Doorway'
  P9 = 'Leaning over cannabis altar'; P10 = 'Leaning over frankincense altar'; P11 = 'Kneeling before altars' }   # courtyard (P8, 0 mg) omitted
$rows = $labels.Keys | Sort-Object { -$low[$_] }

$W = 1344; $rowH = 53; $padT = 120; $plotL = 440; $plotR = $W - 54; $xMax = 16.0
$H = $padT + $rowH * $rows.Count + 110
$bmp = New-Object Drawing.Bitmap ([int]($W * $S)), ([int]($H * $S)); $g = [Drawing.Graphics]::FromImage($bmp); $g.ScaleTransform($S, $S)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.Clear([Drawing.Color]::White)
function PX([double]$v) { $plotL + ($plotR - $plotL) * $v / $xMax }

$ink = [Drawing.Brushes]::Black; $grey = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(90, 90, 90))
$fL = New-Object Drawing.Font('Segoe UI', 14); $fS = New-Object Drawing.Font('Segoe UI', 12.5); $fV = New-Object Drawing.Font('Segoe UI', 12.5)
$cBase = [Drawing.Color]::FromArgb(196, 194, 182); $cLow = [Drawing.Color]::FromArgb(39, 116, 214)
$bBase = New-Object Drawing.SolidBrush $cBase; $bLow = New-Object Drawing.SolidBrush $cLow

# legend
$g.FillEllipse($bBase, 34, 40, 17, 17); $g.DrawString('3.0 m ceiling', $fS, $ink, 58, 36)
$g.FillEllipse($bLow, 228, 40, 17, 17); $g.DrawString('2.4 m ceiling, cella niche 1.8 m', $fS, $ink, 252, 36)

# effect thresholds
$top = $padT - 10; $bot = $padT + $rowH * $rows.Count
$dash = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(120, 120, 120)), 1.3; $dash.DashStyle = 'Dash'
foreach ($t in @(@(2, '2 mg threshold'), @(5, '5 mg mild'), @(10, '10 mg clear'))) {
  $x = PX $t[0]; $g.DrawLine($dash, [float]$x, [float]$top, [float]$x, [float]$bot); $g.DrawString($t[1], $fS, $grey, [float]($x + 4), [float]($top - 28)) }

# rows
$track = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(228, 228, 228)), 5
$fmt = New-Object Drawing.StringFormat; $fmt.Alignment = 'Far'
$i = 0
foreach ($p in $rows) {
  $y = $padT + $rowH * $i + $rowH / 2; $xb = PX $base[$p]; $xl = PX $low[$p]
  $g.DrawString($labels[$p], $fL, $ink, (New-Object Drawing.RectangleF 0, ([float]($y - 14)), ([float]($plotL - 16)), 30), $fmt)
  $g.DrawLine($track, [float][math]::Min($xb, $xl), [float]$y, [float][math]::Max($xb, $xl), [float]$y)
  $g.FillEllipse($bBase, [float]($xb - 8), [float]($y - 8), 16, 16); $g.FillEllipse($bLow, [float]($xl - 10), [float]($y - 10), 20, 20)
  $vs = '{0:0.0}' -f $low[$p]; $sz = $g.MeasureString($vs, $fV); $g.FillRectangle([Drawing.Brushes]::White, [float]($xl + 14), [float]($y - 11), $sz.Width - 4, $sz.Height - 4)
  $g.DrawString($vs, $fV, $ink, [float]($xl + 14), [float]($y - 12)); $i++
}

# axis
$ax = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(150, 150, 140)), 1.3
$g.DrawLine($ax, [float]$plotL, [float]$bot, [float]$plotR, [float]$bot)
$fc = New-Object Drawing.StringFormat; $fc.Alignment = 'Center'
foreach ($v in 0, 4, 8, 12, 16) { $g.DrawString("$v", $fS, $grey, [float](PX $v), [float]($bot + 10), $fc) }
$g.DrawString('Inhaled THC (mg), breathing rate 0.75 m' + [char]0x00B3 + '/h', $fS, $grey, (New-Object Drawing.RectangleF 0, ([float]($bot + 42)), ([float]$plotR), 30), $fmt)

$bmp.SetResolution(96 * $S, 96 * $S); $bmp.Save((Join-Path $PSScriptRoot $Out), [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
"$Out  $([int]($W * $S)) x $([int]($H * $S))"
