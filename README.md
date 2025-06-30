# Eventdisplay Analysis Scripts for VERITAS

[![DOI](https://zenodo.org/badge/307321978.svg)](https://zenodo.org/badge/latestdoi/307321978)
[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/blob/main/LICENSE)
[![CI](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/actions/workflows/CI.yml/badge.svg)](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/actions/workflows/CI.yml)

## Overview

This repository contains scripts for analyzing VERITAS data and MC simulations.

These scripts are part of the Eventdisplay packages and require additionally the following items installed:

- binaries and libraries from the [Eventdisplay package](https://github.com/VERITAS-Observatory/EventDisplay_v4).
- Eventdisplay analysis files with configuration files, calibrations files, and instrument response functions. From [Eventdisplay_AnalysisFiles_VTS](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS).

The scripts are optimized for the DESY computing environment, utilizing HTCondor batch systems and apptainers.

## Usage

Set the following environment variables:

- `$EVNDISPSYS`: Path to the Eventdisplay installation ([Eventdisplay package](https://github.com/VERITAS-Observatory/EventDisplay_v4)).
- `$EVNDISPSCRIPT`: Path to the `./scripts` directory of this repository ([scripts directory](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/tree/main/scripts)).
- `$VERITAS_ANALYSIS_TYPE` (recommended): Indicates the reconstruction methods applied, e.g., `AP_DISP`, `NN_DISP`.

Additional environment variables, especially useful for batch systems, can be found in [./scripts/set_environment.sh](./scripts/set_environment.sh).

Submission commands for various batch systems are available in [submissionCommands.dat](./scripts/submissionCommands.dat). Modify these commands according to your local requirements.

## Downloading Data from the VERITAS Database

Scripts for downloading run-wise information from the VERITAS database are available in [./scripts/db_scripts/README.md](./scripts/db_scripts/README.md).

## Producing Instrument Response Functions (IRFs)

IRFs are provided for each Eventdisplay release. The following instructions are for the IRF processing team.

### Adding a New IRF Epoch

VERITAS IRFs are divided into epochs (e.g., summer/winter, throughput epochs, instrument stages like V4, V5, V6). Epochs are defined in [ParameterFiles/VERITAS.Epochs.runparameter](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/ParameterFiles/VERITAS.Epochs.runparameter) and should align with calibration throughput corrections (see [internal VERITAS wiki page](https://veritas.sao.arizona.edu/wiki/Flux_Calibration_/_Energy_scale_2020)).

Throughput corrections are defined in [ParameterFiles/ThroughputCorrection.runparameter](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/ParameterFiles/ThroughputCorrection.runparameter).

Analysis scripts require a list of all V6 summer and winter periods, which are listed in [IRF_EPOCHS_WINTER.dat](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/IRF_EPOCHS_WINTER.dat) and [IRF_EPOCHS_SUMMER.dat](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/IRF_EPOCHS_SUMMER.dat). UV Filter IRF periods are defined in [IRF_EPOCHS_obsfilter.dat](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/IRF_EPOCHS_obsfilter.dat). No changes to the analysis scripts are required, except for updating the help message (list of epochs) in [./IRF.production.sh](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/blob/main/scripts/IRF.production.sh).

Adding a new epoch usually requires re-running the mscw data analysis steps with updated lookup tables and dispBDTs, as these IRFs have changed. This step also updates the IRF flag in the mscw files.

### MC Analysis - evndisp Stage

This stage requires the most computing resources and usually takes several days. MC simulation files are required in the directory structure outlined in [./scripts/IRF.production.sh](./scripts/IRF.production.sh).

Run the following steps for all analysis types (`AP`, `NN`):

```bash
./IRF.generalproduction.sh CARE_RedHV_Feb2024 EVNDISP
./IRF.generalproduction.sh CARE_24_20 EVNDISP
```

Results are stored in `$VERITAS_IRFPRODUCTION_DIR/<eventdisplay version>/AP/CARE_24_20/V6_2022_2023w_ATM61_gamma/`. For DESY productions, the evndisp files should be moved to `$VERITAS_IRFPRODUCTION_DIR/v4N/AP/CARE_24_20/V6_2022_2023w_ATM61_gamma/`.

### MC Analysis - Lookup Table Filling

Fill lookup tables per bin:

```bash
./IRF.generalproduction.sh CARE_24_20 MAKETABLES
```

Then combine the tables with:

```bash
./IRF.generalproduction.sh CARE_24_20 COMBINETABLES
```

Move the tables from `$VERITAS_IRFPRODUCTION_DIR/<eventdisplay version>/${VERITAS_ANALYSIS_TYPE:0:2}/Tables` to `$VERITAS_EVNDISP_AUX_DIR/Tables`.

### MC Analysis - DispBDT Angular Reconstruction Training

```bash
./IRF.generalproduction.sh CARE_24_20 TRAINMVANGRES
```

Copy and zip the files to `$VERITAS_EVNDISP_AUX_DIR/DispBDTs`:

```bash
cd $VERITAS_EVNDISP_AUX_DIR/DispBDTs
./copy_DispBDT.sh
```

(take care of any errors printed to the screen)

### BDT Training

#### Preparation

Analyze data runs for the new period to the `mscw` stage using `./ANALYSIS.mscw_energy.sh`.

Select background runs for the BDT training.

```bash
./IRF.selectRunsForGammaHadronSeparationTraining.sh <major epoch> <source mscw directory> <target mscw directory> <TMVA run parameter file (full path)>
```

Use e.g. `$VERITAS_DATA_DIR/processed_data_v491/AP/mscw/` for the source directory, which contains processed mscw files from observations. Main purpose is to select runs with good data quality and runs obtained from observations of strong gamma-ray sources.

This script links mscw files from the archive to a target directory sorted by epoch and zenith bins (read from TMVA run parameter file).

#### Training

(only for regular HV)

- Use `TRAINTMVA` in `./IRF.generalproduction.sh`, which calls the script `IRF.trainTMVAforGammaHadronSeparation.sh`.
- Copy TMVA BDT files to `$VERITAS_EVNDISP_AUX_DIR/GammaHadronBDTs` using `$VERITAS_EVNDISP_AUX_DIR/GammaHadronBDTs/copy_GammaHadron_V6_BDTs.sh` (XML files are not zipped).

Requires as input:

- `TMVA.runparameter` file
- mscw files from observations (see above) for background events
- mscw files from simulations for signal events

#### Cut Optimization

Cut optimization requires signal rates (from simulations) and background rates (from data). The `$EVNDISPSYS/bin/calculateCrabRateFromMC` tool is used to calculate rates after pre-selection cuts (note: check that  `CALCULATERATEFILES="TRUE"` is set in `$EVNDISPSCRIPTS/helper_scripts/IRF.optimizeTMVAforGammaHadronSeparation_sub.sh`).

**Important: This script is not working in combination with the usage of apptainers.**

1. Generate effective areas for *pre-selection cuts* using `PRESELECTEFFECTIVEAREAS` with the usual two-step process of first generating effective areas per observational bin and then combine the effective areas. Move the combined files to `$VERITAS_EVNDISP_AUX_DIR/EffectiveAreas`.
2. Generate background anasum files for *pre-selection cuts*. Use `$EVNDISPSCRIPTS/ANALYSIS.anasum_allcuts.sh` with the `PRECUTS` option to submit the corresponding jobs (use the same runs for background rate calculation as used for BDT training). These files should be moved into e.g. `$VERITAS_IRFPRODUCTION_DIR/<eventdisplay version>/AP/BDTtraining/BackgroundRates/V6/NTel2-Moderate` (adjust epoch and cut directory name).

Cut values are extracted by the optimization tool and written e.g., to

```console
VERITAS_IRFPRODUCTION_DIR/<eventdisplay version>/AP/BDTtraining/BackgroundRates/V6/Optimize-NTel2-Moderate/
```

Copy and paste those values into the files defining the gamma/hadron separation cuts in `$VERITAS_EVNDISP_AUX_DIR/GammaHadronCuts`.

### Effective Area Generation

Effective area generation requires the MC-generated mscw files and well defined gamma/hadron cuts values in `$VERITAS_EVNDISP_AUX_DIR/GammaHadronCuts`.

```bash
./IRF.generalproduction.sh CARE_24_20 EFFECTIVEAREAS
```

This generates effective areas per bin in parameter spaces. To combine the effective areas for a single file per cut and epcoh, run:

```bash
./IRF.generalproduction.sh CARE_24_20 COMBINEEFFECTIVEAREAS
```

Move the generated effective areas files to `$VERITAS_EVNDISP_AUX_DIR/EffectiveAreas`.

## Support

For any questions, contact Gernot Maier

## License

Eventdisplay_AnalysisScripts_VTS is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file.
