# Builds the sensitivity scenarios from arad_incense.fds (baseline: hall 3.0 m, cella 2.6 m).
#   arad_low     : hall ceiling 2.4 m, cella = low niche 1.8 m, hall door 2.2 m
#   arad_high    : hall ceiling 4.5 m (1.5 x span, Solomon MT ratio), cella 3.0 m
#   arad_canonly : baseline geometry, only the cannabis altar burns (effect of adding frankincense)
# Each scenario runs on 3 MPI processes so two can run side by side.

$base = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'arad_incense.fds'))

function Edit([string]$t, [string]$lineKey, [string]$from, [string]$to) {
    # replace $from with $to only on lines containing $lineKey (all literal)
    if ($from -eq $to) { return $t }
    $rx = '(?m)^(.*' + [regex]::Escape($lineKey) + '.*)$'
    $n = 0
    $r = [regex]::Replace($t, $rx, { param($m) $script:n++; $m.Value.Replace($from, $to) })
    if ($r -eq $t) { throw "no change for key '$lineKey' ($from -> $to)" }
    return $r
}

function Remap([string]$t) {
    # 3 MPI processes; meshes listed so MPI_PROCESS is non-decreasing
    $lines = $t -split "`r?`n"
    $mesh = @{}
    foreach ($l in $lines) { if ($l -match "^&MESH ID='(\w+)'") { $mesh[$Matches[1]] = $l } }
    $order = 'Hall_S:0','Cella:0','Court_W:0','Hall_C:1','Court_E:1','Hall_N1:2','Hall_N2:2'
    $block = foreach ($o in $order) { $id, $p = $o.Split(':'); $mesh[$id] -replace 'MPI_PROCESS=\d', "MPI_PROCESS=$p" }
    $out = New-Object System.Collections.Generic.List[string]
    $done = $false
    foreach ($l in $lines) {
        if ($l -match '^&MESH') { if (-not $done) { $block | ForEach-Object { $out.Add($_) }; $done = $true } }
        else { $out.Add($l) }
    }
    return ($out -join "`r`n")
}

function Heights([string]$t, [string]$H, [int]$nz, [string]$cella, [string]$open, [string]$door, [string]$p2z, [string]$ceilDev) {
    foreach ($m in 'Hall_S','Hall_C','Cella','Hall_N1','Hall_N2') {
        $t = Edit $t "ID='$m'" ',30, XB' ",$nz, XB"
        $t = Edit $t "ID='$m'" '0.0,3.0, MPI' "0.0,$H, MPI"
    }
    foreach ($w in 'Hall_W_brick','Hall_E_brick','Hall_S_brick','Hall_N_brick') { $t = Edit $t "ID='$w'" '1.0,3.0' "1.0,$H" }
    foreach ($w in 'Cella_W','Cella_S','Cella_N') { $t = Edit $t "ID='$w'," '0.0,3.0' "0.0,$H" }
    $t = Edit $t "ID='Cella_roof'" '2.6,3.0' "$cella,$H"
    $t = Edit $t 'hall door 1.3' '0.0,2.6' "0.0,$door"
    $t = Edit $t 'cella opening' '0.0,2.5' "0.0,$open"
    $t = Edit $t "ID='P2_THC'" '1.85' $p2z
    $t = Edit $t "ID='P2_PIN'" '1.85' $p2z
    $t = Edit $t "ID='T_ceiling_hall'" '5.7,6.05,2.9' "5.7,6.05,$ceilDev"
    $t = Edit $t "ID='THC_in_hall'" '0.0,3.0' "0.0,$H"
    $t = Edit $t "ID='THC_in_cella'" '0.0,2.6' "0.0,$cella"
    foreach ($d in 'THC_out_door','Air_out_door','Air_in_door') { $t = Edit $t "ID='$d'" '0.0,2.6' "0.0,$door" }
    return $t
}

function Save([string]$t, [string]$chid, [string]$title) {
    $t = Edit $t '&HEAD' "CHID='arad_incense'" "CHID='$chid'"
    $t = [regex]::Replace($t, "TITLE='[^']*'", "TITLE='$title'")
    $t = Remap $t
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot "$chid.fds"), $t, [Text.Encoding]::ASCII)
    "$chid.fds written"
}

# low: hall 2.4, cella = niche 1.8 m above hall floor (opening = full niche height), door 2.2
$low = Heights $base '2.4' 24 '1.8' '1.8' '2.2' '1.50' '2.3'
Save $low 'arad_low' 'Arad shrine - LOW: hall ceiling 2.4 m, cella niche 1.8 m, 10 min ritual'

# high: hall 4.5, cella 3.0; court mesh raised to 5.0 m
$high = Heights $base '4.4' 44 '3.0' '2.5' '2.6' '1.85' '4.3'   # 4.4 m (not 4.5) to align with the 0.2 m court grid
foreach ($m in 'Court_W','Court_E') {
    $high = Edit $high "ID='$m'" '20,62,20' '20,62,25'
    $high = Edit $high "ID='$m'" '0.0,4.0, MPI' '0.0,5.0, MPI'
}
$high = Edit $high "ID='Court_sky'" '4.0,4.0' '5.0,5.0'
$high = Edit $high "ID='Court_east'" '0.0,4.0' '0.0,5.0'
Save $high 'arad_high' 'Arad shrine - HIGH: hall ceiling 4.4 m, cella 3.0 m, 10 min ritual'

# baseline itself, re-partitioned to 3 MPI processes (written last, after the others are built from it)
$baseOut = $base

# cannabis only: baseline geometry, frankincense altar not lit
$can = Edit $base "SURF_ID='FRANK_FAT' /" '&VENT' 'not lit: VENT'
Save $can 'arad_canonly' 'Arad shrine - CANNABIS ONLY (frankincense altar not lit), hall 3.0 m'

Save $baseOut 'arad_incense' 'Arad shrine Str. X - BASE: hall ceiling 3.0 m, cella 2.6 m, cannabis + frankincense, 10 min ritual, calm air'
