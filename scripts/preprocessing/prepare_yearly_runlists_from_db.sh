#!/bin/bash
# Generates a simple run list (one run per line) with quality cuts

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for y in $(seq 2012 2025); do
  "$script_dir/prepare_runlist_from_db.sh" "${y}-08-01" "$((y+1))-09-01" /afs/ifh.de/group/cta/scratch/maierg/EVNDISP/EVNDISP-400/GITHUB_Eventdisplay/EventDisplay_Preprocessing/processing/runlists_good_observation_runs/runs_not_processed.dat >| "runs_${y}_$((y+1)).txt"
done
