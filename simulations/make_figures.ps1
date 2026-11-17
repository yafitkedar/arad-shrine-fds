# Rebuilds Figures 1-6 of the paper from the simulation output (Windows; Smokeview 6.11.0 for Figures 1-2).
# Requires: arad_shrine_X (Figure 1) and arad_ritual60 (Figures 2, 4, 6), arad_ritual60_low (Figures 4-6) run in this
# folder, and analyze60.ps1 run for arad_ritual60 and arad_ritual60_low (Figure 4). Output: figures\Figure_1.png ... Figure_6.png
param([string]$Smokeview = 'C:\Program Files\firemodels\SMV6\smokeview.exe')
Set-Location $PSScriptRoot
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force figures, figures\panels | Out-Null

# --- Figures 1-2: Smokeview views, rendered at 2x the 1400 x 820 window (RENDEROPTION multiplier 2 + RENDERDOUBLEONCE).
# The first render after loading a case is discarded (Smokeview's first frame can be incomplete).
function Render([string]$case, [string]$view, [string]$name) {
  if (-not (Test-Path "$case.smv")) { Write-Warning "$case.smv not found - run $case first; $name skipped"; return }
  $ini = Get-Content "$case.ini" -Raw
  [IO.File]::WriteAllText("$PWD\$case.ini", $ini.TrimEnd() + "`r`nRENDEROPTION`r`n 0 2 0`r`n")
  try {
    "RENDERDIR`r`n figures`r`nUNLOADALL`r`nXYZVIEW`r`n $view`r`nRENDERONCE`r`n panels\_discard`r`nXYZVIEW`r`n $view`r`nRENDERDOUBLEONCE`r`n $name`r`nEXIT" |
      Set-Content "make_$name.ssf" -Encoding ascii
    $p = Start-Process $Smokeview -ArgumentList "-script make_$name.ssf $case" -WorkingDirectory $PWD -PassThru
    if (-not $p.WaitForExit(600000)) { $p.Kill(); Write-Warning "$name : Smokeview timed out" }
  } finally { [IO.File]::WriteAllText("$PWD\$case.ini", $ini); Remove-Item "make_$name.ssf" -ErrorAction SilentlyContinue }
}
Render 'arad_shrine_X' '36.0 -16.0 22.0 -48.0 -32.0' 'Figure_1'   # reconstruction from the south-east
Render 'arad_ritual60' '7.1 5.7 2.3 -84.0 -22.0' 'Figure_2'       # cella opening from inside the hall

# --- Figure 3: receptor positions (drawn from arad_ritual60.fds)
& .\sensor_map.ps1 -S 2 -Out figures\Figure_3.png

# --- Figure 4: 60-min inhaled THC by position (from the *_exposure.csv tables of analyze60.ps1)
if ((Test-Path arad_ritual60_exposure.csv) -and (Test-Path arad_ritual60_low_exposure.csv)) { & .\dose_chart.ps1 -S 2 -Out figures\Figure_4.png }
else { Write-Warning 'Figure_4 skipped: run .\analyze60.ps1 -Chid arad_ritual60 and -Chid arad_ritual60_low first' }

# --- Figures 5-6: THC slices (mask = air pockets outside the building; marks = receptors)
$mask  = @('1.7,1.86,0,13', '1.7,3.62,0,4.85', '1.7,3.62,7.15,13', '1.7,13.1,12.55,13', '1.7,13.1,0,0.25', '12.9,13.2,0,13')
$marks = @('P1:4.65:6.05', 'P2:3.0:6.05', 'P3:5.7:6.05', 'P4:5.7:1.5', 'P5:4.5:3.0', 'P6:5.7:10.5', 'P7:7.7:5.9', 'P8:11.0:5.9')
$smask = @('1.7,1.86,0,5', '12.9,13.2,0,5', '1.7,8.62,2.36,2.5', '1.7,8.62,-0.1,0.04', '8.6,13.2,-0.1,0.04')
$smarks = @('P2:3.0:1.5', 'P12:4.05:1.75', 'P1:4.65:1.55', 'P3:5.7:1.55', 'P7:7.7:1.55', 'P8:11.0:1.55')
if (Test-Path arad_ritual60_low.smv) {
  foreach ($tt in 600, 1800, 3590) {
    & .\slice_map.ps1 -Case arad_ritual60_low -Group 2 -Time $tt -Plane y -Cut 6.05 -Win 1.8,13.0,0.0,4.0 -Mask $smask -Marks $smarks -S 3 `
      -Title "THC on the shrine axis (y = 6.05 m), 2.4 m ceiling, minute $([math]::Round($tt / 60))" -Out "figures\panels\section_low_t$tt.png" }
  & .\slice_map.ps1 -Case arad_ritual60_low -Group 5 -Time 3590 -Plane z -Cut 1.55 -Win 1.8,13.0,0.2,12.6 -Mask $mask -Marks $marks -S 1.5 `
    -Title 'THC at 1.55 m after 60 min: 2.4 m ceiling' -Out figures\panels\plan_low_t3590.png
}
if (Test-Path arad_ritual60.smv) {
  & .\slice_map.ps1 -Case arad_ritual60 -Group 5 -Time 3590 -Plane z -Cut 1.55 -Win 1.8,13.0,0.2,12.6 -Mask $mask -Marks $marks -S 1.5 `
    -Title 'THC at 1.55 m after 60 min: 3.0 m ceiling' -Out figures\panels\plan_base_t3590.png
}

function Stack([string[]]$files, [string]$out, [switch]$Horizontal) {
  if ($files | Where-Object { -not (Test-Path $_) }) { Write-Warning "$out skipped: missing panels"; return }
  $imgs = $files | ForEach-Object { [Drawing.Bitmap]::FromFile((Resolve-Path $_).Path) }
  if ($Horizontal) { $W = ($imgs | Measure-Object Width -Sum).Sum; $H = ($imgs | Measure-Object Height -Maximum).Maximum }
  else { $W = ($imgs | Measure-Object Width -Maximum).Maximum; $H = ($imgs | Measure-Object Height -Sum).Sum }
  $bmp = New-Object Drawing.Bitmap ([int]$W), ([int]$H); $g = [Drawing.Graphics]::FromImage($bmp); $g.Clear([Drawing.Color]::White); $o = 0
  foreach ($im in $imgs) { if ($Horizontal) { $g.DrawImage($im, $o, 0, $im.Width, $im.Height); $o += $im.Width } else { $g.DrawImage($im, 0, $o, $im.Width, $im.Height); $o += $im.Height } }
  $bmp.SetResolution(300, 300); $bmp.Save((Join-Path $PWD $out), [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose(); $imgs | ForEach-Object { $_.Dispose() }
  "$out  $W x $H"
}
Stack @('figures\panels\section_low_t600.png', 'figures\panels\section_low_t1800.png', 'figures\panels\section_low_t3590.png') 'figures\Figure_5.png'
Stack @('figures\panels\plan_base_t3590.png', 'figures\panels\plan_low_t3590.png') 'figures\Figure_6.png' -Horizontal
Get-ChildItem figures -Filter 'Figure_*.png' | Select-Object Name, Length
