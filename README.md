# Eventdisplay Analysis Scripts for VERITAS

[![DOI](https://zenodo.org/badge/307321978.svg)](https://zenodo.org/badge/latestdoi/307321978)
[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/blob/main/LICENSE)
[![CI](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/actions/workflows/CI.yml/badge.svg)](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/actions/workflows/CI.yml)

## Overview

Run scripts for the analysis of VERITAS data. Requires the installation or availability of a container of the [Eventdisplay package](https://github.com/VERITAS-Observatory/EventDisplay_v4).

Scripts are optimized for the DESY computing environment using HTCondor batch systems and apptainers.

## Usage

Expected environmental variables:

- `$EVNDISPSYS` - pointing to Eventdisplay installation ([here](https://github.com/VERITAS-Observatory/EventDisplay_v4))
- `$EVNDISPSCRIPT` - pointing to the `./scripts` directory of this repository ([here](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/tree/main/scripts))
- `$VERITAS_ANALYSIS_TYPE` (recommended) - indicating the reconstruction methods applied; e.g., AP\_DISP, NN\_DISP.

Additional environmental variables useful especially for running on a batch system can be found in [./scripts/set_environment.sh](./scripts/set_environment.sh).

Submission commands for a range of different batch systems can be found in [submissionCommands.dat](./scripts/submissionCommands.dat). Modify according to your local needs.

## Download of database data from the VERITAS database

Scripts are provided to download run-wise information from the VERITAS database, see [./scripts/db_scripts/README.md](./scripts/db_scripts/README.md).

## Production of instrument response functions (IRFs)

Instrument response functions (IRFs) are provided for each release of Eventdisplay.
The following instructions are intended for use by the IRF processing team.

### Adding a new IRF Epochs

VERITAS IRFs are divided into epochs (summer/winter; throughput epochs; stages of the instrument like V4, V5, V6).
Epochs are defined in [ParameterFiles/VERITAS.Epochs.runparameter](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/ParameterFiles/VERITAS.Epochs.runparameter) and should be aligned with the effort to derive calibration throughput corrections (see [internal VERITAS wiki page](https://veritas.sao.arizona.edu/wiki/Flux_Calibration_/_Energy_scale_2020)).

Throughput corrections are defined in [ParameterFiles/ThroughputCorrection.runparameter](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/ParameterFiles/ThroughputCorrection.runparameter).

Analysis scripts require a list of all V6 summer and winter periods, which are listed in [IRF_EPOCHS_WINTER.dat](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/IRF_EPOCHS_WINTER.dat) and [IRF_EPOCHS_SUMMER.dat](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/IRF_EPOCHS_SUMMER.dat).
UV Filter IRF periods are defined in [IRF_EPOCHS_obsfilter.dat](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/IRF_EPOCHS_obsfilter.dat).
No changes to the analysis scripts are required, with the exception of the update of the help message (list of epochs) in [./IRF.production.sh](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/blob/main/scripts/IRF.production.sh).

Adding a new epoch usually requires to re-run the mscw data analysis steps with the updated lookup tables and dispBDTs, as these IRFs changed. This step also updates the IRF flag in the mscw files.

### MC Analysis - evndisp stage

This is the stage requiring most computing resources and usually takes several days. MC simulation files are required in the directory structure outlined in [./scripts/IRF.production.sh](./scripts/IRF.production.sh).

Run for all analysis types (`AP`, `NN`) the following steps:

```bash
./IRF.generalproduction.sh CARE_RedHV_Feb2024 EVNDISP
./IRF.generalproduction.sh CARE_24_20 EVNDISP
```

Results are stored in `$VERITAS_IRFPRODUCTION_DIR/v491/AP/CARE_24_20/V6_2022_2023w_ATM61_gamma/`. For DESY productions, the evndisp files should be moved to `$VERITAS_IRFPRODUCTION_DIR/v4N/AP/CARE_24_20/V6_2022_2023w_ATM61_gamma/`.

### MC Analysis - Lookup table filling

Look up table filling per bin:

```bash
./IRF.generalproduction.sh CARE_24_20 MAKETABLES
```

following by combining the tables with

```bash
./IRF.generalproduction.sh CARE_24_20 COMBINETABLES
```

Tables need to be moved from `$VERITAS_IRFPRODUCTION_DIR/v491/${VERITAS_ANALYSIS_TYPE:0:2}/Tables` to `$VERITAS_EVNDISP_AUX_DIR/Tables`.

### MC Analysis - DispBDT Angular Reconstruction training

```bash
./IRF.generalproduction.sh CARE_24_20 TRAINMVANGRES
```

Files are copied and zipped to `$VERITAS_EVNDISP_AUX_DIR/DispBDTs` by:

```bash
cd $VERITAS_EVNDISP_AUX_DIR/DispBDTs
./copy_DispBDT.sh
```

(take care for any errors printed to the screen)

### BDT Training

#### Preparation

Generate background training events using:

```bash
./IRF.selectRunsForGammaHadronSeparationTraining.sh <major epoch> <source mscw directory> <target mscw directory> <TMVA run parameter file (full path)>
```

Use e.g. `$VERITAS_DATA_DIR/processed_data_v491/AP/mscw/` for the source directory, which contains processed mscw files from observations.

This script links mscw files from the archive to a target directory sorted by epoch and zenith bins (read from TMVA run parameter file).

#### Training

(only for regular HV)

- use `TRAINTMVA` in `./IRF.generalproduction.sh`, which calls script `IRF.trainTMVAforGammaHadronSeparation.sh`
- copy TMVA BDT files to `$VERITAS_EVNDISP_AUX_DIR/GammaHadronBDTs` using `$VERITAS_EVNDISP_AUX_DIR/GammaHadronBDTs/copy_GammaHadron_V6_BDTs.sh` (XML files are not zipped)

Requires as input

- `TMVA.runparameter` file
- mscw files from observations (see above) for background events
- mscw files from simulations for signal events

#### Cut optimization

Cut optimization requires signal rates (from simulations) and background rates (from data).
The `$EVNDISPSYS"/bin/calculateCrabRateFromMC` tool is used to calculate rates after pre-selection cuts (note: set `CALCULATERATEFILES="TRUE"` in `$EVNDISPSCRIPTS/helper_scripts/IRF.optimizeTMVAforGammaHadronSeparation_sub.sh`).

1. Generate effective ares for *pre-selection cuts* using `PRESELECTEFFECTIVEAREAS`.
2. Generate background anasum files for *pre-selection cuts*. Use `$EVNDISPSCRIPTS/IRF.anasumforTMVAOptimisation.sh` to submit the corresponding jobs (use the same runs for background rate calculation as used for BDT training).

### Effective area generation

(to be added)

## Notes

In version v483 and earlier, these scripts were part of the Eventdisplay package and in the scripts/VTS directory (e.g., [v483 script](https://github.com/VERITAS-Observatory/EventDisplay_v4/tree/v483/scripts/VTS)).

## Support

For any questions, contact Gernot Maier
