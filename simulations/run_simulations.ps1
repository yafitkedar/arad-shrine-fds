# Runs the FDS simulations of the paper (Windows, FDS 6.11.0 installed with the official NIST installer).
# Each case is run with as many MPI processes as its input file defines (3 for the 10-min runs, 7 for the 60-min runs).
# Cases run one after another; a case whose .out file already reports "FDS completed successfully" is skipped (use -Force to rerun).
#
#   .\run_simulations.ps1                              # all ten runs of the paper (Table 2)
#   .\run_simulations.ps1 -Cases arad_low,arad_incense # selected runs
#   .\run_simulations.ps1 -Cases arad_shrine_X         # 30-s geometry run used for Figure 1
param(
  [string[]]$Cases = @('arad_low', 'arad_incense', 'arad_high', 'arad_canonly',
                       'arad_ritual60', 'arad_ritual60_low', 'arad_r60_swap', 'arad_r60_low_swap',
                       'arad_r60_eqhi', 'arad_r60_low_eqhi'),
  [string]$FdsBin = 'C:\Program Files\firemodels\FDS6\bin',
  [switch]$Force
)
Set-Location $PSScriptRoot
$fds = Join-Path $FdsBin 'fds.exe'; $mpiexec = Join-Path $FdsBin 'mpi\mpiexec.exe'
if (-not (Test-Path $fds)) { throw "fds.exe not found in '$FdsBin'. Install FDS 6.11.0 (environment\install_fds_windows.ps1) or pass -FdsBin." }
$env:I_MPI_ROOT = Join-Path $FdsBin 'mpi'; $env:PATH = "$env:I_MPI_ROOT;$FdsBin;$env:PATH"; $env:OMP_NUM_THREADS = '1'

foreach ($c in $Cases) {
  if (-not (Test-Path "$c.fds")) { Write-Warning "$c.fds not found - skipped"; continue }
  if (-not $Force -and (Test-Path "$c.out") -and (Select-String -Path "$c.out" -Pattern 'FDS completed successfully' -Quiet)) { "$c : already completed - skipped"; continue }
  $n = 1 + (Select-String -Path "$c.fds" -Pattern 'MPI_PROCESS=(\d+)' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
  $t = Get-Date
  "$(Get-Date -f 'yyyy-MM-dd HH:mm') $c : starting on $n MPI processes"
  $p = Start-Process -FilePath $mpiexec -ArgumentList "-localonly -n $n `"$fds`" $c.fds" -RedirectStandardError "run_$c.log" -RedirectStandardOutput "run_${c}_stdout.log" -NoNewWindow -PassThru
  $p.WaitForExit()
  $ok = Select-String -Path "$c.out" -Pattern 'FDS completed successfully' -Quiet -ErrorAction SilentlyContinue
  "$(Get-Date -f 'yyyy-MM-dd HH:mm') $c : $(if ($ok) { 'completed' } else { 'FAILED - see run_' + $c + '.log and ' + $c + '.out' }) ($((Get-Date) - $t))"
  $rev = (Select-String -Path "$c.out" -Pattern 'Revision\s+:\s+(\S+)' -ErrorAction SilentlyContinue | Select-Object -First 1).Matches.Groups[1].Value
  if ($rev -and $rev -notlike 'FDS-6.11.0-*') { Write-Warning "$c was run with $rev; the reference results were produced with FDS-6.11.0-0-g369a20b-release" }
}
