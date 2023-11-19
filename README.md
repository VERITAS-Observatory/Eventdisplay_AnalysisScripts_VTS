# Eventdisplay Analysis Scripts for VERITAS

[![DOI](https://zenodo.org/badge/307321978.svg)](https://zenodo.org/badge/latestdoi/307321978)

Run scripts for VERITAS.

In version v483 and earlier, these scripts were part of the Eventdisplay package and in the scripts/VTS directory (e.g., [v483 script](https://github.com/VERITAS-Observatory/EventDisplay_v4/tree/v483/scripts/VTS)).

## Usage

Expected environmental variables:

- `$EVNDISPSYS` - pointing to Eventdisplay installation ([here](https://github.com/VERITAS-Observatory/EventDisplay_v4))
- `$EVNDISPSCRIPT` - pointing to the `./scripts` directory of this repository ([here](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/tree/main/scripts))
- `$VERITAS_ANALYSIS_TYPE` (recommended) - indicating the reconstruction methods applied; e.g., AP\_DISP, NN\_DISP.

Submission commands for a range of different batch systems can be found in [submissionCommands.dat](./scripts/submissionCommands.dat). Modify according to your local needs.

## Production of instrument response functions (IRFs)

Instrument response functions (IRFs) are provided for each release of Eventdisplay.
The following instructions are intended for use by the IRF processing team.

### BDT Training Preparation

Generate background training events using:

```bash
./IRF.selectRunsForBDTTraining.sh <major epoch> <source mscw directory> <target mscw directory> <TMVA run parameter file>
```

Use e.g. `$VERITAS_DATA_DIR/processed_data_v490/AP/mscw/` for the source directory.

This script links mscw files from the archive to a target directory sorted by epoch and zenith bins (read from TMVA run parameter file).

### BDT Training

- use `TRAINTMVA` in `./IRF.generalproduction.sh`.
- copy TMVA BDT files to `$VERITAS_EVNDISP_AUX_DIR/GammaHadronBDTs` using `$VERITAS_EVNDISP_AUX_DIR/GammaHadronBDTs/copy_GammaHadron_V6_BDTs.sh`.

### Optimize Cuts

Cut optimization requires signal rates (from simulations) and background rates (from data).
The `$EVNDISPSYS"/bin/calculateCrabRateFromMC` tool is used to calculate rates after pre-selection cuts (note: set `CALCULATERATEFILES="TRUE"` in `$EVNDISPSCRIPTS/helper_scripts/IRF.optimizeTMVAforGammaHadronSeparation_sub.sh`).

1. Generate effective ares for *pre-selection cuts* using `PRESELECTEFFECTIVEAREAS`.
2. Generate background anasum files for *pre-selection cuts*. Use `$EVNDISPSCRIPTS/IRF.anasumforTMVAOptimisation.sh` to submit the corresponding jobs (use the same runs for background rate calculation as used for BDT training).

### IRF generation
