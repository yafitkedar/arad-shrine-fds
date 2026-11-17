# Smoke dispersal in the Judahite shrine of Arad: FDS simulations

Input files, scripts and reference results for the paper

> **Architecture, Smoke and Altered States of Consciousness: Modelling Cannabis and Frankincense Exposure in the Judahite Shrine of Arad (8th-century BCE)**
> Yafit Kedar, Gil Kedar. Submitted to the *Journal of Archaeological Science*.

The repository lets a reader re-run the ten Fire Dynamics Simulator (FDS) simulations of the paper, recompute the inhaled THC doses, compare them with the published values and rebuild the figures.

## Contents

```
arad-shrine-fds/
├── README.md
├── environment/
│   ├── install_fds_windows.ps1    downloads and verifies the FDS 6.11.0 installer (Windows)
│   └── Dockerfile                 Linux image with FDS 6.11.0 and PowerShell 7
├── simulations/                   run everything from this folder (FDS writes its output here)
│   ├── arad_*.fds                 FDS input files (the ten runs of Table 2, plus arad_shrine_X)
│   ├── run_simulations.ps1/.sh    runs the cases with the right number of MPI processes
│   ├── analyze.ps1                10-min runs  -> exposure_summary.csv          (Table 3)
│   ├── analyze60.ps1              60-min runs  -> <case>_exposure.csv           (Figure 4, altar heights)
│   ├── compare_with_reference.ps1 compares new doses with reference_results/
│   ├── make_figures.ps1           rebuilds Figures 1-6 (uses the four scripts below)
│   ├── slice_map.ps1              THC slice maps (Figures 5-6)
│   ├── sensor_map.ps1             receptor plan (Figure 3)
│   ├── dose_chart.ps1             dose chart (Figure 4)
│   ├── arad_shrine_X.ini, arad_ritual60.ini   Smokeview view settings for Figures 1-2
│   └── make_scenarios.ps1         provenance only: how the 10-min variants were derived (see note below)
├── reference_results/             output of the runs used in the paper
│   ├── <case>_devc.csv            receptor time series (all devices, every 2 s)
│   ├── <case>_hrr.csv             heat release and mass-flow summary
│   ├── <case>.out                 FDS log of each run (version, mesh, timing)
│   ├── exposure_summary.csv       analysis of the 10-min runs
│   └── <case>_exposure.csv        analysis of the 60-min runs
└── paper_figures/                 Figures 1-6 as submitted
```

## The simulations

| Paper run (Table 2) | Input file | Hall / cella ceiling | Cannabis | Frankincense | Altar heights cannabis / frankincense | Duration | MPI processes | Wall time* |
|---|---|---|---|---|---|---|---|---|
| 1 | `arad_low.fds` | 2.4 m / 1.8 m niche | 5 g per 10 min | lit | 40 / 50 cm | 10 min | 3 | 1.9 h |
| 2 | `arad_incense.fds` | 3.0 / 2.6 m (baseline) | 5 g per 10 min | lit | 40 / 50 cm | 10 min | 3 | 2.1 h |
| 3 | `arad_high.fds` | 4.4 / 3.0 m | 5 g per 10 min | lit | 40 / 50 cm | 10 min | 3 | 3.1 h |
| 4 | `arad_canonly.fds` | 3.0 / 2.6 m | 5 g per 10 min | not lit | 40 / 50 cm | 10 min | 3 | 2.3 h |
| 5 | `arad_ritual60.fds` | 3.0 / 2.6 m | 20 g per 10 min | lit | 40 / 50 cm | 60 min | 7 | 15.4 h |
| 6 | `arad_ritual60_low.fds` | 2.4 m / 1.8 m niche | 20 g per 10 min | lit | 40 / 50 cm | 60 min | 7 | 8.6 h |
| 7 | `arad_r60_swap.fds` | 3.0 / 2.6 m | 20 g per 10 min | lit | 50 / 40 cm | 60 min | 7 | 9.6 h |
| 8 | `arad_r60_low_swap.fds` | 2.4 m / 1.8 m niche | 20 g per 10 min | lit | 50 / 40 cm | 60 min | 7 | 8.5 h |
| 9 | `arad_r60_eqhi.fds` | 3.0 / 2.6 m | 20 g per 10 min | lit | 50 / 50 cm | 60 min | 7 | 11.2 h |
| 10 | `arad_r60_low_eqhi.fds` | 2.4 m / 1.8 m niche | 20 g per 10 min | lit | 50 / 50 cm | 60 min | 7 | 8.6 h |
| (Figure 1) | `arad_shrine_X.fds` | geometry run of the Stratum X reconstruction | | | | 30 s | 5 | 8 min |

\* Wall-clock times of the original runs on a laptop with an Intel Core i3-1315U (6 cores, 8 threads), Windows 11, FDS 6.11.0 with Intel MPI. The 10-min runs were executed two at a time. The full set takes about three days on such a machine and much less on a workstation.

All runs share the reconstruction of the Stratum X shrine (hall, cella, stairs, altars, benches, courtyard), a closed roof, calm air at 25 °C and passive tracer species for THC (`THC`), α-pinene (`PINENE`), incensole acetate (`INCENSOLE_AC`) and smoke particulate (`SMOKE_PM`). The source terms (heat release of the two altar fires and emission rates of each species) are defined on the `SURF` lines of each input file and explained in Section 3 and Table 1 of the paper. The 10-min runs use a 10 cm grid at the altars and record eight receptors (P1-P8); the 60-min runs use a 5 cm grid at the altars and twelve receptors (P1-P12). Receptor positions are shown in Figure 3 and listed in `sensor_map.ps1`.

**Output columns** (`<case>_devc.csv`): `Pn_THC`, `Pn_PIN`, `Pn_INC` are the mass concentrations (mg/m³) of THC, α-pinene and incensole acetate at receptor *n*; `Pn_VIS` is visibility (m); `T_*` are temperatures (°C); `THC_in_hall` and `THC_in_cella` are the THC mass (mg) held in each space; `THC_out_door`, `Air_in_door` and `Air_out_door` are flows through the hall door.

## Requirements

* **FDS 6.11.0 and Smokeview 6.11.0** (revision `FDS-6.11.0-0-g369a20b-release`), the release used for all reference results. FDS is free software from the US National Institute of Standards and Technology (NIST) and is not stored in this repository; the setup scripts install exactly this release from the official GitHub release and verify its checksum. Other FDS versions will run the inputs but may give slightly different numbers.
* **Windows 10 or 11 (x64)**, the platform of the original runs, with Windows PowerShell 5.1 (built in). All scripts were written and tested there.
* Or **Linux / Docker** for the simulations and the dose analysis (see below). The figure scripts need Windows.
* **At least 7 CPU cores** for the 60-min runs as set up (one MPI process per core; they also run on fewer cores, more slowly), about 8 GB RAM, and about **2.5 GB of free disk space** for the full output (slice files and restart dumps).

## Installation

### Windows (tested)

```powershell
powershell -ExecutionPolicy Bypass -File environment\install_fds_windows.ps1
```

The script downloads `FDS-6.11.0_SMV-6.11.0_win.exe` (182 MB) from https://github.com/firemodels/fds/releases/tag/FDS-6.11.0, checks its SHA-256 (`b42281eb73b92a948fe21e80b22089da99c50574103d17c4d4ff609290a0ddb2`), starts the installer and confirms the installed version. Keep the default install folder (`C:\Program Files\firemodels`). If you already have the installer, pass `-Installer <path>`.

### Linux / Docker

```bash
docker build -t arad-fds -f environment/Dockerfile .
docker run --rm -it -v "$PWD/simulations:/work/simulations" arad-fds
```

The image installs the official Linux bundle `FDS-6.11.0_SMV-6.11.0_lnx.sh` (checksum verified) and PowerShell 7 for the analysis scripts. On a Linux machine without Docker, run the official installer and `source ~/FDS/FDS6/bin/FDS6VARS.sh` before running the simulations. The reference results were produced on Windows; the Linux route has not been run by the authors.

## Running the simulations

From the `simulations` folder:

```powershell
.\run_simulations.ps1                                   # all ten runs (Windows)
.\run_simulations.ps1 -Cases arad_low,arad_incense      # selected runs
.\run_simulations.ps1 -Cases arad_shrine_X              # geometry run for Figure 1
```

```bash
./run_simulations.sh                                    # all ten runs (Linux / Docker)
./run_simulations.sh arad_low                           # selected runs
```

Each case runs with the number of MPI processes its input file defines. Finished cases are skipped, so the script can be restarted after an interruption (`-Force` reruns them). A quick check of the installation is `arad_low` (about 2 hours on a laptop).

## Reproducing the results of the paper

```powershell
.\analyze.ps1                                           # 10-min runs: Table 3 and the frankincense comparison
foreach ($c in 'arad_ritual60','arad_ritual60_low','arad_r60_swap','arad_r60_low_swap','arad_r60_eqhi','arad_r60_low_eqhi') { .\analyze60.ps1 -Chid $c }
.\compare_with_reference.ps1                            # new doses vs reference_results
.\make_figures.ps1                                      # Figures 1-6 -> simulations\figures
```

| Paper item | Produced by | Where to look |
|---|---|---|
| Table 3 (inhaled THC, 10-min rite) | `analyze.ps1` | `exposure_summary.csv`, column `Inhaled THC 10 min (mg)` |
| Effect of the frankincense fire (door air exchange, THC retained) | `analyze.ps1` | console output, `BASE 3.0 m` vs `BASE, cannabis only` |
| Figure 4 and the 60-min doses in Section 4 | `analyze60.ps1` | `arad_ritual60(_low)_exposure.csv`, columns `Dose 60 min (mg)`, `min to 2/5/10 mg` |
| Altar-height comparison | `analyze60.ps1` | `arad_r60_*_exposure.csv` vs `arad_ritual60(_low)_exposure.csv` |
| α-pinene relative to odour threshold, incensole acetate, visibility | `analyze.ps1`, `analyze60.ps1` | `x odour thr.` columns and console output |
| Figures 1-6 | `make_figures.ps1` | `simulations\figures` |

Inhaled dose is computed as D = 0.75 m³/h × ∫ C<sub>THC</sub> dt at each receptor, and doses are classified into the effect bands of Section 3 (below 2 mg, 2-5, 5-10, 10-25 mg).

The analysis scripts can also be run on the reference output without re-running FDS: copy the `*_devc.csv` files from `reference_results` into `simulations` and run the commands above. This reproduces the published doses exactly.

### Expected agreement

Large-eddy simulation is sensitive to hardware, compiler, MPI library and processor count, so a re-run on another machine will not reproduce the reference time series to the last digit. `compare_with_reference.ps1` flags doses that differ from the reference by more than 15% (or 0.1 mg); differences of a few percent are of the order of the run-to-run variability discussed in the paper. Re-running the analysis on the reference output reproduces all 104 published doses exactly.

## Notes

* **Smokeview on Windows.** Figures 1 and 2 are rendered by Smokeview from a script. If Windows Smart App Control or an organisation's application-control policy blocks `smokeview.exe` from being started by a script, open the case in Smokeview by hand, set the view from the `XYZVIEW` values in `make_figures.ps1` and render it from Smokeview's Render menu.
* **`make_scenarios.ps1`** documents how the 10-min variants (`arad_low`, `arad_high`, `arad_canonly`) were derived from the baseline `arad_incense.fds`. It is not needed to reproduce the results, and running it overwrites those input files.
* The 60-min input files with altar-height variants write restart files every 5 minutes; to resume an interrupted run, add `RESTART=.TRUE.` to the `&MISC` line and run it again.

## Citation and licence

If you use these files, please cite the paper (reference to be added on publication) and FDS:
McGrattan, K., Hostikka, S., McDermott, R., Floyd, J., Vanella, M., Mueller, E., 2026. *Fire Dynamics Simulator User's Guide*, sixth ed. (FDS 6.11). NIST Special Publication 1019. https://doi.org/10.6028/NIST.SP.1019

Licence: FDS and Smokeview are developed by NIST and are not covered by this licence.

Contact: yafitkedar@mail.tau.ac.il
