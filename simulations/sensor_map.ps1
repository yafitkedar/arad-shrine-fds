# Plan of the shrine (from arad_ritual60.fds) with the 12 receptor positions, plus a legend with heights.
param([double]$S = 1.0, [string]$Out = 'smv_img\fig_sensor_positions.png')   # S = output scale (vector redraw)
Set-Location $PSScriptRoot
Add-Type -AssemblyName System.Drawing
$fds = Get-Content arad_ritual60.fds
$x0 = 1.6; $x1 = 13.2; $y0 = 0.0; $y1 = 12.8; $ppm = 62.0
$padL = 40; $padT = 70; $legW = 470
$W = [int](($x1 - $x0) * $ppm) + $padL + $legW; $H = [int](($y1 - $y0) * $ppm) + $padT + 60
$bmp = New-Object Drawing.Bitmap ([int]($W * $S)), ([int]($H * $S)); $g = [Drawing.Graphics]::FromImage($bmp); $g.ScaleTransform($S, $S)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'; $g.Clear([Drawing.Color]::White)
function PX([double]$x) { $padL + ($x - $x0) * $ppm }
function PY([double]$y) { $padT + ($y1 - $y) * $ppm }
function Rect($b, [double]$a, [double]$bb, [double]$c, [double]$d) { $g.FillRectangle($b, [float](PX $a), [float](PY $d), [float](($bb - $a) * $ppm), [float](($d - $c) * $ppm)) }

$colWall = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(150, 132, 104))
$colFort = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(205, 196, 180))
$colBench = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(222, 214, 196))
$colAltarS = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(214, 120, 40))
$colAltarN = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(235, 190, 50))
$colStone = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(200, 190, 165))
$colMass = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(168, 52, 40))
$floor = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(248, 244, 236))
Rect $floor 1.8 13.0 0.2 12.6; Rect ([Drawing.Brushes]::White) 1.6 3.6 0.0 4.8; Rect ([Drawing.Brushes]::White) 1.6 3.6 7.2 12.8

foreach ($l in $fds) {
  if ($l -match "^&OBST ID='(\w+)'.*XB=\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)") {
    $id = $Matches[1]; $v = 2..7 | ForEach-Object { [double]$Matches[$_] }
    if ($id -match 'brick') { continue }
    $b = if ($id -match 'Fortress') { $colFort } elseif ($id -match 'Bench|Installation|Plaster') { $colBench }
         elseif ($id -match 'Altar_S') { $colAltarS } elseif ($id -match 'Altar_N') { $colAltarN }
         elseif ($id -match 'Massebah') { $colMass } elseif ($id -match 'Stair|Cella_floor|Platform') { $colStone } else { $colWall }
    Rect $b $v[0] $v[1] $v[2] $v[3]
  }
}
# openings (holes) cut through walls
foreach ($l in $fds) { if ($l -match "^&HOLE XB=\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)") { $v = 1..4 | ForEach-Object { [double]$Matches[$_] }
  if ($v[0] -lt 4.3) { Rect $colStone $v[0] $v[1] $v[2] $v[3]; Rect $colAltarN 3.9 4.2 6.3 6.6; Rect $colAltarS 4.0 4.2 5.5 5.7 } else { Rect $floor $v[0] $v[1] $v[2] $v[3] } } }

$fT = New-Object Drawing.Font('Segoe UI', 15, [Drawing.FontStyle]::Bold); $fS = New-Object Drawing.Font('Segoe UI', 10.5)
$fM = New-Object Drawing.Font('Segoe UI', 9, [Drawing.FontStyle]::Bold); $fL = New-Object Drawing.Font('Segoe UI', 10)
$ink = [Drawing.Brushes]::Black; $grey = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(90, 90, 90))
$g.DrawString('Receptor positions (breathing height) in the Stratum X model', $fT, $ink, 12, 10)
$g.DrawString('Plan view, north up. Hall ceiling and roof not shown.', $fS, $grey, 14, 38)

# area labels
$fA = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Italic)
$g.DrawString('cella', $fA, $grey, [float](PX 2.05), [float](PY 5.45))
$g.DrawString('main hall', $fA, $grey, [float](PX 5.0), [float](PY 12.2))
$g.DrawString('courtyard', $fA, $grey, [float](PX 9.6), [float](PY 8.4))
$g.DrawString('storage', $fA, $grey, [float](PX 9.6), [float](PY 11.4))
$g.DrawString('door', $fA, $grey, [float](PX 7.3), [float](PY 5.1))

$pts = @(
 @('P1', 4.65, 6.05, 1.55, 'Priest standing before the altars'),
 @('P2', 3.0, 6.05, 1.85, 'Inside the cella (1.50 m in the 2.4 m model)'),
 @('P3', 5.7, 6.05, 1.55, 'Hall centre, standing'),
 @('P4', 5.7, 1.5, 1.2, 'South bench, seated'),
 @('P5', 4.5, 3.0, 1.2, 'West bench, seated'),
 @('P6', 5.7, 10.5, 1.55, 'North end of hall, standing'),
 @('P7', 7.7, 5.9, 1.55, 'Doorway'),
 @('P8', 11.0, 5.9, 1.55, 'Courtyard, 3 m from the door'),
 @('P9', 4.425, 5.625, 1.0, 'Leaning over the cannabis altar'),
 @('P10', 4.425, 6.475, 1.1, 'Leaning over the frankincense altar'),
 @('P11', 4.775, 6.025, 0.95, 'Kneeling before the altars'),
 @('P12', 4.05, 6.05, 1.75, 'Standing on stair 2, in the cella opening'))
# label offsets to avoid overlap near the altars
$off = @{ P1 = @(6, -26); P2 = @(-12, -24); P3 = @(10, -9); P9 = @(14, 8); P10 = @(14, -26); P11 = @(10, 6); P12 = @(-34, -24) }
$mp = New-Object Drawing.Pen ([Drawing.Color]::White), 1.5
foreach ($p in $pts) {
  $px = PX $p[1]; $py = PY $p[2]; $col = if ([double]$p[3] -lt 1.3) { [Drawing.Color]::FromArgb(40, 90, 200) } else { [Drawing.Color]::FromArgb(20, 20, 20) }
  $br = New-Object Drawing.SolidBrush $col
  $g.FillEllipse($br, [float]($px - 5), [float]($py - 5), 10, 10); $g.DrawEllipse($mp, [float]($px - 5), [float]($py - 5), 10, 10)
  $o = if ($off.ContainsKey($p[0])) { $off[$p[0]] } else { @(9, -9) }
  $sz = $g.MeasureString($p[0], $fM)
  $g.FillRectangle((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(215, 255, 255, 255))), [float]($px + $o[0]), [float]($py + $o[1]), $sz.Width, $sz.Height)
  $g.DrawString($p[0], $fM, $br, [float]($px + $o[0]), [float]($py + $o[1]))
}
# legend
$lx = $W - $legW + 20; $ly = $padT
$g.DrawString('Position (height above floor)', (New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)), $ink, $lx, $ly); $ly += 28
foreach ($p in $pts) { $g.DrawString(("{0}  {1}  ({2:0.00} m)" -f $p[0], $p[4], [double]$p[3]), $fL, $ink, $lx, $ly); $ly += 21 }
$ly += 14
$items = @(@($colAltarS, 'Cannabis altar (S), 40 cm'), @($colAltarN, 'Frankincense altar (N), 52 cm'), @($colMass, 'Massebah'), @($colStone, 'Stairs, cella floor, platform'), @($colBench, 'Benches'), @($colWall, 'Walls'))
foreach ($it in $items) { $g.FillRectangle($it[0], $lx, $ly + 3, 16, 12); $g.DrawString($it[1], $fL, $ink, $lx + 24, $ly); $ly += 21 }
$ly += 10
$g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(20, 20, 20))), $lx, $ly + 4, 10, 10); $g.DrawString('standing height', $fL, $ink, $lx + 18, $ly); $ly += 21
$g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(40, 90, 200))), $lx, $ly + 4, 10, 10); $g.DrawString('seated, kneeling or leaning', $fL, $ink, $lx + 18, $ly)
# scale + north
$sb = New-Object Drawing.Pen ([Drawing.Color]::Black), 3; $g.DrawLine($sb, $padL, $H - 28, $padL + 2 * $ppm, $H - 28); $g.DrawString('2 m', $fL, $ink, $padL + 2 * $ppm + 6, $H - 38)
$g.DrawString('N (up)', (New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)), $ink, $padL + 2 * $ppm + 60, $H - 40)
$bmp.SetResolution(96 * $S, 96 * $S); $bmp.Save((Join-Path $PSScriptRoot $Out), [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose(); 'saved'
