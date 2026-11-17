#!/usr/bin/env bash
# Runs the FDS simulations of the paper on Linux (or in the Docker image built from environment/Dockerfile).
# Each case uses as many MPI processes as its input file defines (3 for the 10-min runs, 7 for the 60-min runs).
#
#   ./run_simulations.sh                          # all ten runs of the paper (Table 2)
#   ./run_simulations.sh arad_low arad_incense    # selected runs
#
# FDS must be on the PATH: source the environment script written by the FDS installer first, e.g.
#   source ~/FDS/FDS6/bin/FDS6VARS.sh
set -u
cd "$(dirname "$0")"
CASES=("$@")
if [ ${#CASES[@]} -eq 0 ]; then
  CASES=(arad_low arad_incense arad_high arad_canonly arad_ritual60 arad_ritual60_low
         arad_r60_swap arad_r60_low_swap arad_r60_eqhi arad_r60_low_eqhi)
fi
command -v fds >/dev/null || { echo "fds not on PATH - source FDS6VARS.sh first"; exit 1; }
export OMP_NUM_THREADS=1

for c in "${CASES[@]}"; do
  [ -f "$c.fds" ] || { echo "$c.fds not found - skipped"; continue; }
  if grep -q 'FDS completed successfully' "$c.out" 2>/dev/null; then echo "$c : already completed - skipped"; continue; fi
  n=$(( $(grep -o 'MPI_PROCESS=[0-9]*' "$c.fds" | cut -d= -f2 | sort -n | tail -1) + 1 ))
  echo "$(date '+%F %H:%M') $c : starting on $n MPI processes"
  mpiexec -n "$n" fds "$c.fds" > "run_${c}_stdout.log" 2> "run_$c.log"
  if grep -q 'FDS completed successfully' "$c.out" 2>/dev/null; then echo "$(date '+%F %H:%M') $c : completed"
  else echo "$(date '+%F %H:%M') $c : FAILED - see run_$c.log and $c.out"; fi
done
