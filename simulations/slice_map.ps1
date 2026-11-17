# Draws an FDS slice (all meshes of one slice group) at a given time as a PNG with a fixed colour scale.
# Reads the binary .sf files directly (Fortran unformatted: 4-byte record markers).
#   -Case arad_ritual60_low -Group 5 -Time 3590 -Plane z   (z = plan view, y = E-W section)
param([string]$Case, [int]$Group, [double]$Time, [ValidateSet('z','y')][string]$Plane,
      [double]$Vmax = 15.0, [double]$Scale = 1.0e6, [string]$Unit = 'mg/m3',
      [string]$Title = '', [string]$Out, [double[]]$Win, [double]$Cut, [string[]]$Mask = @(), [string[]]$Marks = @(), [double]$S = 1.0)   # Cut = slice position (z or y), for drawing walls   # Win = xmin,xmax,ymin,ymax (plan) or xmin,xmax,zmin,zmax (section)
Set-Location $PSScriptRoot
Add-Type -AssemblyName System.Drawing

# --- meshes from the .fds (order = smokeview mesh numbers) ---
$meshes = @()
foreach ($l in Get-Content "$Case.fds") {
  if ($l -match "^&MESH .*IJK=\s*(\d+),\s*(\d+),\s*(\d+),\s*XB=\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)") {
    $m = $Matches; $meshes += [pscustomobject]@{ I=[int]$m[1]; J=[int]$m[2]; K=[int]$m[3];
      x0=[double]$m[4]; x1=[double]$m[5]; y0=[double]$m[6]; y1=[double]$m[7]; z0=[double]$m[8]; z1=[double]$m[9] } }
}
# --- obstructions (walls etc.) ---
$obst = @()
foreach ($l in Get-Content "$Case.fds") {
  if ($l -match "^&OBST .*XB=\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)") {
    $obst += ,([double[]]@($Matches[1],$Matches[2],$Matches[3],$Matches[4],$Matches[5],$Matches[6], [double]($l -match "PERMIT_HOLE=\.FALSE\."))) }
}
# --- holes (cut through walls) ---
$holes = @()
foreach ($l in Get-Content "$Case.fds") {
  if ($l -match "^&HOLE .*XB=\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)") {
    $holes += ,([double[]]@($Matches[1],$Matches[2],$Matches[3],$Matches[4],$Matches[5],$Matches[6])) }
}
# --- slice files of this group from the .smv ---
$smv = Get-Content "$Case.smv"; $files = @()
for ($i = 0; $i -lt $smv.Count; $i++) {
  if ($smv[$i] -match '^\s*SLCF\s+(\d+).*!\s+(\d+)' -and [int]$Matches[2] -eq $Group) { $files += [pscustomobject]@{ mesh=[int]$Matches[1]; file=$smv[$i+1].Trim() } }
}

function Read-Rec([IO.BinaryReader]$br) { $n = $br.ReadInt32(); $b = $br.ReadBytes($n); [void]$br.ReadInt32(); return ,$b }
function Read-Frame([string]$f, [double]$t) {
  $br = New-Object IO.BinaryReader([IO.File]::OpenRead((Join-Path $PSScriptRoot $f)))
  try {
    1..3 | ForEach-Object { [void](Read-Rec $br) }
    $hb = Read-Rec $br; $ix = 0..5 | ForEach-Object { [BitConverter]::ToInt32($hb, 4 * $_) }
    $best = $null; $bestDt = 1e9
    while ($br.BaseStream.Position -lt $br.BaseStream.Length) {
      $tb = Read-Rec $br; $tt = [BitConverter]::ToSingle($tb, 0)
      $db = Read-Rec $br
      $dt = [math]::Abs($tt - $t); if ($dt -lt $bestDt) { $bestDt = $dt; $best = $db; $bestT = $tt } elseif ($tt -gt $t) { break }
    }
    $n = $best.Length / 4; $vals = New-Object float[] $n; [Buffer]::BlockCopy($best, 0, $vals, 0, $best.Length)
    return [pscustomobject]@{ idx = $ix; vals = $vals; t = $bestT }
  } finally { $br.Close() }
}

# --- colour map (viridis-like anchors) ---
$anch = @(@(68,1,84), @(59,82,139), @(33,145,140), @(94,201,98), @(253,231,37))
function Col([double]$v) {
  $f = [math]::Max([double]0.0, [math]::Min([double]1.0, [double]($v / $Vmax))) * ($anch.Count - 1); $a = [math]::Floor($f); $b = [math]::Min($a + 1, $anch.Count - 1); $w = $f - $a
  $c = 0..2 | ForEach-Object { [int]($anch[$a][$_] * (1 - $w) + $anch[$b][$_] * $w) }
  [Drawing.Color]::FromArgb($c[0], $c[1], $c[2])
}

$wx0, $wx1, $wv0, $wv1 = $Win
$ppm = 64.0                                         # pixels per metre
$padL = 50; $padT = 70; $padB = 60; $barW = 150
$W = [int](($wx1 - $wx0) * $ppm) + $padL + $barW; $H = [int](($wv1 - $wv0) * $ppm) + $padT + $padB
$bmp = New-Object Drawing.Bitmap ([int]($W * $S)), ([int]($H * $S)); $g = [Drawing.Graphics]::FromImage($bmp); $g.ScaleTransform($S, $S); $g.TextRenderingHint = 'AntiAliasGridFit'   # S = output scale (vector redraw, not resampling)
$g.SmoothingMode = 'AntiAlias'; $g.Clear([Drawing.Color]::White)
function PX([double]$x) { $padL + ($x - $wx0) * $ppm }
function PV([double]$v) { $padT + ($wv1 - $v) * $ppm }   # vertical axis: north (plan) or up (section)

$tShown = $null
foreach ($sf in $files) {
  $m = $meshes[$sf.mesh - 1]; $fr = Read-Frame $sf.file $Time; $tShown = $fr.t
  $dx = ($m.x1 - $m.x0) / $m.I; $dy = ($m.y1 - $m.y0) / $m.J; $dz = ($m.z1 - $m.z0) / $m.K
  $i1, $i2, $j1, $j2, $k1, $k2 = $fr.idx
  $ni = $i2 - $i1 + 1; $nj = $j2 - $j1 + 1; $nk = $k2 - $k1 + 1; $p = 0
  for ($k = $k1; $k -le $k2; $k++) { for ($j = $j1; $j -le $j2; $j++) { for ($i = $i1; $i -le $i2; $i++) {
    $v = $fr.vals[$p] * $Scale; $p++
    $x = $m.x0 + $i * $dx
    if ($Plane -eq 'z') { $hv = $m.y0 + $j * $dy; $hw = $dy } else { $hv = $m.z0 + $k * $dz; $hw = $dz }
    $br = New-Object Drawing.SolidBrush (Col $v)
    $g.FillRectangle($br, [float](PX ($x - $dx / 2)), [float](PV ($hv + $hw / 2)), [float]($dx * $ppm + 1), [float]($hw * $ppm + 1)); $br.Dispose()
  } } }
}

# --- blank areas outside the building (isolated air pockets between mesh edge and walls) ---
$wb = [Drawing.Brushes]::White
foreach ($mk in $Mask) { $r = $mk.Split(',') | ForEach-Object { [double]$_ }; $g.FillRectangle($wb, [float](PX $r[0]), [float](PV $r[3]), [float](($r[1]-$r[0])*$ppm), [float](($r[3]-$r[2])*$ppm)) }
# --- walls cut by the plane, minus holes ---
$wall = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(150, 132, 104))
$air = New-Object Drawing.SolidBrush ([Drawing.Color]::White)
$rg = New-Object Drawing.Region (New-Object Drawing.Rectangle 0, 0, $W, $H)
foreach ($hl in $holes) {
  if ($Plane -eq 'z' -and $hl[4] -le $Cut -and $hl[5] -ge $Cut) { $rg.Exclude((New-Object Drawing.RectangleF ([float](PX $hl[0])), ([float](PV $hl[3])), ([float](($hl[1]-$hl[0])*$ppm)), ([float](($hl[3]-$hl[2])*$ppm)))) }
  if ($Plane -eq 'y' -and $hl[2] -le $Cut -and $hl[3] -ge $Cut) { $rg.Exclude((New-Object Drawing.RectangleF ([float](PX $hl[0])), ([float](PV $hl[5])), ([float](($hl[1]-$hl[0])*$ppm)), ([float](($hl[5]-$hl[4])*$ppm)))) }
}
foreach ($o in $obst) { if ($o[6] -gt 0) { $g.ResetClip() } else { $g.Clip = $rg }
  if ($Plane -eq 'z') { if ($o[4] -le $Cut -and $o[5] -ge $Cut) { $g.FillRectangle($wall, [float](PX $o[0]), [float](PV $o[3]), [float](($o[1]-$o[0])*$ppm), [float](($o[3]-$o[2])*$ppm)) } }
  else { if ($o[2] -le $Cut -and $o[3] -ge $Cut) { $g.FillRectangle($wall, [float](PX $o[0]), [float](PV $o[5]), [float](($o[1]-$o[0])*$ppm), [float](($o[5]-$o[4])*$ppm)) } }
}
# holes re-open the walls they cut (data under them was drawn first, so redraw nothing: just outline them)
$hp = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(150, 132, 104)), 1
foreach ($hl in $holes) {
  if ($Plane -eq 'z' -and $hl[4] -le $Cut -and $hl[5] -ge $Cut) { $g.DrawRectangle($hp, [float](PX $hl[0]), [float](PV $hl[3]), [float](($hl[1]-$hl[0])*$ppm), [float](($hl[3]-$hl[2])*$ppm)) }
}
$wall.Dispose(); $air.Dispose()

# --- receptor markers ---
$g.ResetClip()
$mf = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold); $mp = New-Object Drawing.Pen ([Drawing.Color]::White), 2
foreach ($mk in $Marks) { $q = $mk.Split(':'); $px = PX ([double]$q[1]); $pv = PV ([double]$q[2])
  $g.FillEllipse([Drawing.Brushes]::Black, [float]($px - 5), [float]($pv - 5), 10, 10); $g.DrawEllipse($mp, [float]($px - 5), [float]($pv - 5), 10, 10)
  $sz = $g.MeasureString($q[0], $mf); $g.FillRectangle((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(200, 255, 255, 255))), [float]($px + 7), [float]($pv - 9), $sz.Width, $sz.Height)
  $g.DrawString($q[0], $mf, [Drawing.Brushes]::Black, [float]($px + 7), [float]($pv - 9)) }
# --- frame, title, colour bar ---
$fT = New-Object Drawing.Font('Segoe UI', 15, [Drawing.FontStyle]::Bold); $fS = New-Object Drawing.Font('Segoe UI', 11); $fL = New-Object Drawing.Font('Segoe UI', 10)
$ink = [Drawing.Brushes]::Black; $grey = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(90, 90, 90))
$g.DrawString($Title, $fT, $ink, 12, 10)
$g.DrawString(("t = {0:0} s ({1:0.0} min)" -f $tShown, ($tShown / 60)), $fS, $grey, 14, 38)
$bx = $W - $barW + 30; $by0 = $padT; $by1 = $H - $padB
for ($y = $by0; $y -le $by1; $y++) { $v = $Vmax * ($by1 - $y) / ($by1 - $by0); $cb = New-Object Drawing.SolidBrush (Col $v); $g.FillRectangle($cb, [float]$bx, [float]($y - 0.5), [float]22, [float]1.6); $cb.Dispose() }
foreach ($q in 0..5) { $v = $Vmax * $q / 5; $yy = $by1 - ($by1 - $by0) * $q / 5; $g.DrawString(("{0:0.#}" -f $v), $fL, $ink, $bx + 28, $yy - 8) }
$g.DrawString("THC", $fS, $ink, $bx - 4, $by0 - 44); $g.DrawString($Unit, $fL, $grey, $bx - 4, $by0 - 24)
# scale bar 1 m
$sb = New-Object Drawing.Pen ([Drawing.Color]::Black), 3; $g.DrawLine($sb, $padL, $H - 25, $padL + $ppm, $H - 25); $g.DrawString('1 m', $fL, $ink, $padL + $ppm + 6, $H - 34)
$g.DrawString($(if ($Plane -eq 'z') { 'N up, E right' } else { 'looking north: W left, E right' }), $fL, $grey, $padL + $ppm + 60, $H - 34)
$bmp.SetResolution(96 * $S, 96 * $S); $bmp.Save((Join-Path $PSScriptRoot $Out), [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
"$Out  (t = $tShown s)"
