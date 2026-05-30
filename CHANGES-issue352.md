# Bug-Fix Summary — EventDisplay Issue #352

Fixes applied to `Eventdisplay_AnalysisScripts_VTS` for bugs reported in
[VERITAS-Observatory/EventDisplay_v4#352](https://github.com/VERITAS-Observatory/EventDisplay_v4/issues/352).

---

## Analysis scripts (Section C)

### C1 — `ANALYSIS.anasum.sh`: job submission never executed
**File:** `scripts/ANALYSIS.anasum.sh`

`SUBC` was assigned the path to the helper script as a string instead of
executing it.  The submission command was therefore never built, so no jobs
were ever submitted.

```diff
-SUBC="$EVNDISPSCRIPTS/UTILITY.readSubmissionCommand.sh"
+SUBC=$("$EVNDISPSCRIPTS/UTILITY.readSubmissionCommand.sh")
 SUBC=$(eval "echo \"$SUBC\"")
```

---

### C2 — `ANALYSIS.mscw_energy_sub.sh`: wrong condition for RedHV DispBDT fallback
**File:** `scripts/helper_scripts/ANALYSIS.mscw_energy_sub.sh`

The `get_disp_dir()` function selected a 55° zenith-angle fallback training
directory for RedHV data only when `${SIMTYPE_RUN} == "CARE_RedHV"` (exact
match).  The function already uses `${HVSETTINGS}` for the base directory,
so the condition was changed to match that variable instead:

```diff
-elif [[ ${SIMTYPE_RUN} == "CARE_RedHV" ]]; then
+elif [[ ${HVSETTINGS} == "obsLowHV" ]]; then
```

---

### C5 — `ANALYSIS.mscw_energy_sub.sh`: missing `$` before `DISPBDT`
**File:** `scripts/helper_scripts/ANALYSIS.mscw_energy_sub.sh`

Log message printed the literal string `DISPBDT` instead of the variable
value:

```diff
-if [[ DISPBDT == "1" ]]; then
+if [[ $DISPBDT == "1" ]]; then
```

---

### C10 — `IRF.optimizeTMVAforGammaHadronSeparation.sh`: unsafe regex for `* ENERGYBINS`
**File:** `scripts/IRF.optimizeTMVAforGammaHadronSeparation.sh`

Runparameter files use `* ENERGYBINS` (literal asterisk).  The `*` without
escaping is undefined in POSIX BRE right after `^`:

```diff
-ENERGYBINS=$(grep "^* ENERGYBINS" …)
+ENERGYBINS=$(grep "^\* ENERGYBINS" …)
 …
-| sed 's/* ENERGYBINS 1//'
+| sed 's/\* ENERGYBINS//'
```

---

### C11 — `IRF.optimizeTMVAforGammaHadronSeparation.sh`: no `exit 1` on missing effective-area file
**File:** `scripts/IRF.optimizeTMVAforGammaHadronSeparation.sh`

The script printed an error and continued instead of stopping when the
effective-area file was missing:

```diff
 echo "ERROR: effective area file not found: ${EFFAREA}"
+exit 1
```

---

### C20 — `ANALYSIS.v2dl3.sh`: `LOGIDR` typo and undefined `$AFILE`
**File:** `scripts/ANALYSIS.v2dl3.sh`

Two distinct bugs:
1. `${LOGIDR}` (typo) → `${LOGDIR}` — the cleanup `rm -f` targeted the
   wrong (unexpanded/empty) directory.
2. `$AFILE` (undefined variable) → `$J` (the loop variable) — run IDs in
   log output were blank.

```diff
-rm -f ${LOGIDR}/x* 2>/dev/null
+rm -f ${LOGDIR}/x* 2>/dev/null
 …
-echo "RUN $AFILE JOBID $JOBID"
+echo "RUN $J JOBID $JOBID"
```

---

### C21 — `ANALYSIS.anasum_allcuts.sh`: fragile relative `./` invocations
**File:** `scripts/ANALYSIS.anasum_allcuts.sh`

The script invoked sibling scripts with `./ANALYSIS.…`, which fails unless
the user's working directory is the `scripts/` folder:

```diff
-./ANALYSIS.anasum_parallel_from_runlist.sh …
+$(dirname "$0")/ANALYSIS.anasum_parallel_from_runlist.sh …
 …
-./ANALYSIS.v2dl3.sh …
+$(dirname "$0")/ANALYSIS.v2dl3.sh …
```

---

## IRF production chain (Section D)

### D1+D2 — `IRF.production.sh`: redundant inner loops and wrong loop variable
**File:** `scripts/IRF.production.sh`

The TRAINTMVA/OPTIMIZETMVA block contained extra `for VX in $EPOCH` and
`for ATM in $ATMOS` loops nested *inside* the outer epoch/atmosphere loops,
causing N_epoch × N_atmo times more job submissions than intended.  After
removing the redundant inner loops, `${EPOCH:0:2}` (the full epoch list)
was replaced with `${VX:0:2}` (the correct loop variable):

```diff
-for VX in $EPOCH; do
-    for ATM in $ATMOS; do
-        for C in ${CUTTYPES[@]}; do
+for C in ${CUTTYPES[@]}; do
     …
-            grep "* sizesecondmax" … | grep ${EPOCH:0:2} …
+            grep "* sizesecondmax" … | grep ${VX:0:2} …
     …
-            if [[ ${EPOCH:0:2} == "V4" ]]; then
+            if [[ ${VX:0:2} == "V4" ]]; then
     …
-        done
-    done
-done
+done
```

---

### D3 — `IRF.mscw_energy_MC_sub.sh`: unquoted glob, can fail on spaces / special chars
**File:** `scripts/helper_scripts/IRF.mscw_energy_MC_sub.sh`

```diff
-MSCFILES=$(ls ${INDIR}/*[0-9].root 2>/dev/null)
+MSCFILES=$(ls "${INDIR}"/*[0-9].root 2>/dev/null)
```

---

### D4 — `IRF.generate_lookup_table_parts.sh` / `IRF.mscw_energy_MC.sh`: double `.sh` extension
**Files:** `scripts/IRF.generate_lookup_table_parts.sh`, `scripts/IRF.mscw_energy_MC.sh`

`FSCRIPT` is defined *with* the `.sh` suffix, but submission calls used
`$FSCRIPT.sh`, producing a nonexistent `….sh.sh` path:

```diff
 FSCRIPT="$LOGDIR/…name….sh"
-JOBID=`$SUBC $FSCRIPT.sh`
+JOBID=`$SUBC $FSCRIPT`
```
(Same change applied to all submission/execution branches: SGE, Condor,
GNU parallel, and simple.)

---

### D6 — `IRF.combine_lookup_table_parts.sh`: existence check on filename alone
**File:** `scripts/IRF.combine_lookup_table_parts.sh`

`$OFILE` is just a filename, not a path — the check always failed when the
current directory differed from `$ODIR`:

```diff
-if [[ -f $OFILE ]]; then
+if [[ -f "$ODIR/$OFILE" ]]; then
```

---

### D7 — `zstd` availability check used non-portable `which`
**Files:** `scripts/helper_scripts/IRF.mscw_energy_MC_sub.sh`,
`IRF.compress_evndisp_MC_sub.sh`, `IRF.evndisp_MC_sub.sh`,
`IRF.lookup_table_parallel_sub.sh`

`which zstd` returns exit 0 even when the command is absent on some
systems.  Replaced with POSIX-portable `command -v`:

```diff
-if which zstd &>/dev/null; then
+if command -v zstd &>/dev/null; then
```

---

### D9 — `IRF.optimizeTMVAforGammaHadronSeparation_sub.sh`: `rm` uses `MVADIR` before it is defined
**File:** `scripts/helper_scripts/IRF.optimizeTMVAforGammaHadronSeparation_sub.sh`

`rm -f ${MVADIR}/rates.log` appeared 11 lines *before* `MVADIR=…` was
assigned, so it silently operated on an empty path.  Moved to immediately
after the assignment:

```diff
-    rm -f ${MVADIR}/rates.log       # ← before MVADIR is set
 …
 MVADIR="$VERITAS_EVNDISP_AUX_DIR/…"
+rm -f "${MVADIR}/rates.log"         # ← now in the correct place
```

---

### D10 — `IRF.production.sh`: fragile `./IRF.` invocations
**File:** `scripts/IRF.production.sh`

Three calls used `./IRF.*.sh`, which fails when the script is launched from
outside the `scripts/` directory:

```diff
-./IRF.dispXGB.sh "stereo_analysis" …
+$(dirname "$0")/IRF.dispXGB.sh "stereo_analysis" …

-./IRF.dispXGB.sh "classification" …
+$(dirname "$0")/IRF.dispXGB.sh "classification" …

-./IRF.trainXGBforGammaHadronSeparationTraining.sh …
+$(dirname "$0")/IRF.trainXGBforGammaHadronSeparationTraining.sh …
```

---

### Bonus — `IRF.mscw_energy_MC_sub.sh`: RedHV 55° path was appended, not substituted
**File:** `scripts/helper_scripts/IRF.mscw_energy_MC_sub.sh`

Analogous to C2, for MC production: when zenith angle ≥ 58° and the
simulation type is `CARE_RedHV*`, the script should *replace* the `60deg`
or `65deg` training path with `55deg`, but instead it *appended* `/55deg/`
to the already-constructed path.  Fixed by restructuring the if/else to set
the path once for each case.

---

## XGB angular reconstruction (Section E)

### E3 — `IRF.trainXGBforAngularReconstructionBinned.sh`: hard-coded `RECID0`
**File:** `scripts/IRF.trainXGBforAngularReconstructionBinned.sh`

The input directory always pointed to `MSCW_RECID0_DISP` regardless of the
`RECID` argument (`$6`):

```diff
-INDIR="…/MSCW_RECID0_DISP"
+INDIR="…/MSCW_RECID${RECID}_DISP"
```

---

### E7 — `IRF.trainXGBforAngularReconstruction_sub.sh`: temp dir used undefined `$MSCW_FILE`
**File:** `scripts/helper_scripts/IRF.trainXGBforAngularReconstruction_sub.sh`

`MSCW_FILE` is never set in this script; `LLIST` (the input `.list` file)
is the actual variable.  The temp directory name was also not unique enough
for parallel runs:

```diff
-TEMPDIR=$TMPDIR/$(basename $MSCW_FILE .root)
+TEMPDIR=$TMPDIR/XGB-$(basename $LLIST .list)-$(uuidgen)
```

---

## Issues intentionally skipped

| Issue | Reason |
|-------|---------|
| C3 — FORCEDATMO injection | Requires understanding caller contract; no clear minimal fix |
| C4 — V4/V5 atmo normalisation | Design decision, not a clear bug |
| C6 — Positional parameter parsing | Refactor scope, not a minimal fix |
| C8, C9 — DBTEXT / DB query logic | Complex; risk of regressions |
| C12–C19 — Various design issues | Out of scope for minimal fix pass |
| D5 — Wrong positional arg | Appears already fixed (`$8` present) |
| E1, E2, E5, E6, E8–E11 | Design-level or require C++ changes |
