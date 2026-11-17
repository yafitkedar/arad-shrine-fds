# Installs the exact FDS/Smokeview release used for the paper (FDS 6.11.0, Smokeview 6.11.0) on Windows 10/11 x64.
# Downloads the official NIST installer from GitHub (182 MB), checks its SHA-256 against the value published with the
# release, and starts it. Accept the default install folder (C:\Program Files\firemodels) so the run scripts find FDS.
#
#   powershell -ExecutionPolicy Bypass -File environment\install_fds_windows.ps1
#   powershell -ExecutionPolicy Bypass -File environment\install_fds_windows.ps1 -Installer D:\FDS-6.11.0_SMV-6.11.0_win.exe
param([string]$Installer = '')
$ErrorActionPreference = 'Stop'
$url    = 'https://github.com/firemodels/fds/releases/download/FDS-6.11.0/FDS-6.11.0_SMV-6.11.0_win.exe'
$sha256 = 'b42281eb73b92a948fe21e80b22089da99c50574103d17c4d4ff609290a0ddb2'

if (-not $Installer) {
  $Installer = Join-Path $env:TEMP 'FDS-6.11.0_SMV-6.11.0_win.exe'
  if (-not (Test-Path $Installer)) {
    "Downloading $url ..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object Net.WebClient).DownloadFile($url, $Installer)
  }
}
$h = (Get-FileHash $Installer -Algorithm SHA256).Hash.ToLower()
if ($h -ne $sha256) { throw "SHA-256 mismatch for $Installer`n  expected $sha256`n  got      $h" }
"Installer verified (SHA-256 $h). Starting it - follow the prompts and keep the default install folder."
Start-Process -FilePath $Installer -Wait

$fds = 'C:\Program Files\firemodels\FDS6\bin\fds.exe'
if (Test-Path $fds) {
  $env:PATH = "C:\Program Files\firemodels\FDS6\bin\mpi;C:\Program Files\firemodels\FDS6\bin;$env:PATH"
  $v = & $fds -version 2>&1 | Out-String
  if ($v -match 'FDS-6\.11\.0-0-g369a20b-release') { 'FDS 6.11.0 (FDS-6.11.0-0-g369a20b-release) is installed.' }
  else { Write-Warning "Unexpected FDS version:`n$v" }
} else { Write-Warning "fds.exe not found at $fds - if you installed elsewhere, pass -FdsBin to simulations\run_simulations.ps1" }
