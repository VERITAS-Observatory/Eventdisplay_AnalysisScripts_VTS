# Eventdisplay Analysis Scripts for VERITAS

[![DOI](https://zenodo.org/badge/307321978.svg)](https://zenodo.org/badge/latestdoi/307321978)
[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/blob/main/LICENSE)
[![CI](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/actions/workflows/CI.yml/badge.svg)](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/actions/workflows/CI.yml)

This repository contains scripts for analyzing VERITAS observational data and Monte Carlo (MC) simulations.

The analysis scripts are part of the Eventdisplay package and additionally require the following to be installed:

- Binaries and libraries from the [Eventdisplay package](https://github.com/VERITAS-Observatory/EventDisplay_v4)
- Eventdisplay analysis files (configuration files, calibration files, and instrument response functions) from [Eventdisplay_AnalysisFiles_VTS](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS)
- Converter to DL3 format: [V2DL3](https://github.com/VERITAS-Observatory/V2DL3/)
- Optional: install [Eventdisplay-ML](https://github.com/Eventdisplay/Eventdisplay-ML) for machine-learning-based reconstruction methods

These scripts are optimized for the DESY computing environment and use HTCondor batch systems and Apptainer containers.

## Table of Contents

- [Eventdisplay Analysis Scripts for VERITAS](#eventdisplay-analysis-scripts-for-veritas)
  - [Table of Contents](#table-of-contents)
  - [Environment Variables](#environment-variables)
  - [Analysis Workflow](#analysis-workflow)
  - [Calibration (SPANALYSIS)](#calibration-spanalysis)
  - [Run Lists (RUNLIST)](#run-lists-runlist)
  - [Downloading Data from the VERITAS Database](#downloading-data-from-the-veritas-database)
  - [Instrument Response Functions Generation Workflow](#instrument-response-functions-generation-workflow)
    - [Adding a New IRF Epoch](#adding-a-new-irf-epoch)
    - [Monte Carlo (MC) Analysis - evndisp Stage](#monte-carlo-mc-analysis---evndisp-stage)
    - [Monte Carlo (MC) Analysis - Lookup Table Filling](#monte-carlo-mc-analysis---lookup-table-filling)
    - [Monte Carlo (MC) Analysis - DispBDT Angular Reconstruction Training](#monte-carlo-mc-analysis---dispbdt-angular-reconstruction-training)
    - [BDT Training](#bdt-training)
      - [Preparation](#preparation)
      - [Training](#training)
      - [Cut Optimization](#cut-optimization)
    - [Effective Area Generation](#effective-area-generation)
  - [Support](#support)
  - [License](#license)

## Environment Variables

Set the following environment variables before running the scripts:

| Variable | Description |
|---|---|
| `$EVNDISPSYS` | Path to the [Eventdisplay](https://github.com/VERITAS-Observatory/EventDisplay_v4) installation |
| `$EVNDISPSCRIPTS` | Path to the [`./scripts`](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/tree/main/scripts) directory of this repository |
| `$VERITAS_ANALYSIS_TYPE` | Reconstruction method, e.g., `AP_DISP` or `NN_DISP` (recommended) |
| `$V2DL3SYS` | Path to the [V2DL3](https://github.com/VERITAS-Observatory/V2DL3/) installation |
| `$VERITAS_DATA_DIR` | Path to the raw VBF data files |
| `$VERITAS_EVNDISP_AUX_DIR` | Path to auxiliary files (lookup tables, BDTs, effective areas, cuts) |
| `$VERITAS_PREPROCESSED_DATA_DIR` | Path to pre-processed data products |
| `$VERITAS_IRFPRODUCTION_DIR` | Path to the IRF production output directory |
| `$VERITAS_USER_DATA_DIR` | Path to user-specific data output |
| `$VERITAS_USER_LOG_DIR` | Path to log files |
| `$EVNDISP_ML_SYS` | Path to the [Eventdisplay-ML](https://github.com/Eventdisplay/Eventdisplay-ML) installation (optional) |
| `$EVNDISP_ML_ENV` | Name of the conda environment for Eventdisplay-ML (default: `eventdisplay_ml`) |

See [`./scripts/set_environment.sh`](./scripts/set_environment.sh) for a template with all variables configured for the DESY computing environment. Submission commands for various batch systems are available in [submissionCommands.dat](./scripts/submissionCommands.dat).

## Analysis Workflow

The standard VERITAS data analysis follows four sequential steps, each corresponding to a dedicated script:

```
Raw data (VBF)
     │
     ▼
ANALYSIS.evndisp.sh          # Image calibration and parameterization (Hillas parameters)
     │
     ▼
ANALYSIS.mscw_energy.sh      # Energy and direction reconstruction using lookup tables
     │
     ▼
ANALYSIS.anasum.sh           # High-level analysis: signal/background, spectra, light curves
     │
     ▼
ANALYSIS.v2dl3.sh            # Convert anasum output to FITS DL3 format (point-like and full-enclosure)
```

Run each script without arguments to print its full usage information. Example:

```bash
$EVNDISPSCRIPTS/ANALYSIS.evndisp.sh
```

Additional scripts cover combined anasum analyses (`ANALYSIS.anasum_combine.sh`, `ANALYSIS.anasum_parallel_from_runlist.sh`) and XGBoost-based direction reconstruction (`ANALYSIS.dispXGB.sh`).

## Calibration (SPANALYSIS)

Calibration must be run before the main analysis. The following special-purpose scripts handle calibration steps:

| Script | Description |
|---|---|
| `SPANALYSIS.evndisp_pedestal_events.sh` | Calculate pedestals (high and low gain) for a given run |
| `SPANALYSIS.evndisp_laser_run.sh` | Process a single laser/flasher calibration run |
| `SPANALYSIS.evndisp_laser_runs_from_runlist.sh` | Process laser/flasher runs for all runs in a run list |
| `SPANALYSIS.evndisp_laser_runs_from_calibfile.sh` | Process laser/flasher runs from a calibration file |
| `SPANALYSIS.evndisp_tzeros.sh` | Calculate timing zeros |
| `SPANALYSIS.lowgainped.sh` | Low-gain pedestal calculation |
| `SPANALYSIS.make_DST.sh` | Produce DST files from raw data |

## Run Lists (RUNLIST)

Run lists define which data runs enter the analysis. The following scripts help create and filter run lists:

| Script | Description |
|---|---|
| `RUNLIST.generate.sh` | Generate a run list for a given source with quality cuts |
| `RUNLIST.getRunListFromDB.sh` | Query the VERITAS database for run numbers |
| `RUNLIST.preprocessing.sh` | Generate a run list for preprocessing |
| `RUNLIST.findBackgroundRuns.sh` | Identify suitable background runs |
| `RUNLIST.whichRunsAreArrayEpoch.sh` | Filter runs by array epoch |
| `RUNLIST.whichRunsAreAtmosphere.sh` | Filter runs by atmosphere |
| `RUNLIST.whichRunsAreObservingMode.sh` | Filter runs by observing mode |
| `RUNLIST.whichRunsAreOnDisk.sh` | Check which runs are available on disk |
| `RUNLIST.whichRunsAreSource.sh` | Filter runs by source |
| `RUNLIST.whichRunsAreWobble.sh` | Filter runs by wobble offset |
| `RUNLIST.getObservatoryAzEl.sh` | Get azimuth/elevation from the database |
| `RUNLIST.findDBSourceCoordinates.sh` | Look up source coordinates in the database |
| `RUNLIST.findDBSourceNames.sh` | Look up source names in the database |

## Downloading Data from the VERITAS Database

Scripts for downloading run-wise information from the VERITAS database are available in [./scripts/db_scripts/README.md](./scripts/db_scripts/README.md).

## Instrument Response Functions Generation Workflow

Instrument Response Functions (IRFs) are provided for each Eventdisplay release. The following instructions are for the IRF processing team.

The IRF production pipeline combines MC simulations and observational data through several stages:

```
MC Simulations                        Observational Data
      │                                       │
      ▼                                       ▼
IRF.generalproduction.sh EVNDISP      ANALYSIS.mscw_energy.sh
(image parameterization)              (mscw files for BDT background training)
      │                                       │
      ▼                                       │
IRF.generalproduction.sh MAKETABLES           │
IRF.generalproduction.sh COMBINETABLES        │
(fill & combine lookup tables)                │
      │                                       │
      ▼                                       │
IRF.generalproduction.sh TRAINMVANGRES        │
(train DispBDTs for angular reconstruction)   │
      │                                       │
      └──────────────┬────────────────────────┘
                     │
                     ▼
             IRF.generalproduction.sh TRAINTMVA
             (gamma/hadron separation BDT training)
                     │
                     ▼
             IRF.generalproduction.sh OPTIMIZETMVA
             Cut Optimization
             (PRESELECTEFFECTIVEAREAS + ANALYSIS.anasum_allcuts.sh PRECUTS)
                     │
                     ▼
             IRF.generalproduction.sh EFFECTIVEAREAS
             IRF.generalproduction.sh COMBINEEFFECTIVEAREAS
             (generate & combine effective areas)
```

### Adding a New IRF Epoch

VERITAS IRFs are divided into epochs (e.g., summer/winter, throughput epochs, instrument stages like V4, V5, V6). Epochs are defined in [ParameterFiles/VERITAS.Epochs.runparameter](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/ParameterFiles/VERITAS.Epochs.runparameter) and should align with calibration throughput corrections (see [internal VERITAS wiki page](https://veritas.sao.arizona.edu/wiki/Flux_Calibration_/_Energy_scale_2020)).

Throughput corrections are defined in [ParameterFiles/ThroughputCorrection.runparameter](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/ParameterFiles/ThroughputCorrection.runparameter).

Analysis scripts require a list of all V6 summer and winter periods, which are listed in [IRF_EPOCHS_WINTER.dat](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/IRF_EPOCHS_WINTER.dat) and [IRF_EPOCHS_SUMMER.dat](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/IRF_EPOCHS_SUMMER.dat). UV Filter IRF periods are defined in [IRF_EPOCHS_obsfilter.dat](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisFiles_VTS/blob/main/IRF_EPOCHS_obsfilter.dat).

No changes to the analysis scripts are required, except for updating the help message that lists epochs in `./scripts/IRF.production.sh`.

Adding a new epoch usually requires re-running the mscw data-analysis steps with updated lookup tables and DispBDTs, as these IRFs have changed. This step also updates the IRF flag in the mscw files.

### Monte Carlo (MC) Analysis - evndisp Stage

This stage requires the most computing resources and typically takes several days. MC simulation files are required in the directory structure outlined in `./scripts/IRF.production.sh`.

Run the following steps for all analysis types (`AP`, `NN`):

```bash
./IRF.generalproduction.sh CARE_RedHV_Feb2024 EVNDISP
./IRF.generalproduction.sh CARE_24_20 EVNDISP
```

Results are stored in `$VERITAS_IRFPRODUCTION_DIR/<eventdisplay version>/AP/CARE_24_20/V6_2022_2023w_ATM61_gamma/`. For DESY productions, move the evndisp files to `$VERITAS_IRFPRODUCTION_DIR/v4N/AP/CARE_24_20/V6_2022_2023w_ATM61_gamma/`.

### Monte Carlo (MC) Analysis - Lookup Table Filling

Fill lookup tables per bin:

```bash
./IRF.generalproduction.sh CARE_24_20 MAKETABLES
```

Then combine the tables with:

```bash
./IRF.generalproduction.sh CARE_24_20 COMBINETABLES
```

Move the tables from `$VERITAS_IRFPRODUCTION_DIR/<eventdisplay version>/${VERITAS_ANALYSIS_TYPE:0:2}/Tables` to `$VERITAS_EVNDISP_AUX_DIR/Tables`.

### Monte Carlo (MC) Analysis - DispBDT Angular Reconstruction Training

```bash
./IRF.generalproduction.sh CARE_24_20 TRAINMVANGRES
```

Copy and compress the files to `$VERITAS_EVNDISP_AUX_DIR/DispBDTs`:

```bash
cd $VERITAS_EVNDISP_AUX_DIR/DispBDTs
./copy_DispBDT.sh
```

Watch for errors and address them as needed.

### BDT Training

#### Preparation

Analyze data runs for the new period to produce `mscw` files using `./ANALYSIS.mscw_energy.sh`.

Select background runs for the BDT training.

```bash
./IRF.selectRunsForGammaHadronSeparationTraining.sh <major epoch> <source mscw directory> <target mscw directory> <TMVA run parameter file (full path)>
```

For example, use `$VERITAS_PREPROCESSED_DATA_DIR/${VERITAS_ANALYSIS_TYPE:0:2}/mscw/` as the source directory, which contains processed `mscw` files from observations. The main purpose is to select runs with good data quality and from observations of strong gamma-ray sources.

This script links `mscw` files from the archive to a target directory sorted by epoch and zenith bins (as read from the TMVA run-parameter file).

#### Training

(only for regular HV)

- Use `TRAINTMVA` in `./IRF.generalproduction.sh`, which calls the script `IRF.trainTMVAforGammaHadronSeparation.sh`.
- Copy TMVA BDT files to `$VERITAS_EVNDISP_AUX_DIR/GammaHadronBDTs` using `$VERITAS_EVNDISP_AUX_DIR/GammaHadronBDTs/copy_GammaHadron_V6_BDTs.sh` (XML files are not zipped).

Requires as input:

- `TMVA.runparameter` file
- `mscw` files from observations (see above) for background events
- `mscw` files from simulations for signal events

#### Cut Optimization

Cut optimization requires signal rates (from simulations) and background rates (from data). The `$EVNDISPSYS/bin/calculateCrabRateFromMC` tool is used to calculate rates after pre-selection cuts (note: check that `CALCULATERATEFILES="TRUE"` is set in `$EVNDISPSCRIPTS/helper_scripts/IRF.optimizeTMVAforGammaHadronSeparation_sub.sh`).

**Important:** This step currently does not work with Apptainer.

1. Generate effective areas for *pre-selection cuts* using `PRESELECTEFFECTIVEAREAS` with the usual two-step process: first generate effective areas per observational bin and then combine them. Move the combined files to `$VERITAS_EVNDISP_AUX_DIR/EffectiveAreas`.
2. Generate background `anasum` files for *pre-selection cuts*. Use `$EVNDISPSCRIPTS/ANALYSIS.anasum_allcuts.sh` with the `PRECUTS` option to submit the corresponding jobs (use the same runs for background rate calculation as used for BDT training). Move these files into, e.g., `$VERITAS_IRFPRODUCTION_DIR/<eventdisplay version>/AP/BDTtraining/BackgroundRates/V6/NTel2-Moderate` (adjust epoch and cut directory name).

Cut values are extracted by the optimization tool and written, for example, to

```console
VERITAS_IRFPRODUCTION_DIR/<eventdisplay version>/AP/BDTtraining/BackgroundRates/V6/Optimize-NTel2-Moderate/
```

Copy and paste those values into the files defining the gamma/hadron separation cuts in `$VERITAS_EVNDISP_AUX_DIR/GammaHadronCuts`.

### Effective Area Generation

Effective-area generation requires the MC-generated `mscw` files and well-defined gamma/hadron cut values in `$VERITAS_EVNDISP_AUX_DIR/GammaHadronCuts`.

```bash
./IRF.generalproduction.sh CARE_24_20 EFFECTIVEAREAS
```

This generates effective areas per observational bin. To combine the effective areas into a single file per cut and epoch, run:

```bash
./IRF.generalproduction.sh CARE_24_20 COMBINEEFFECTIVEAREAS
```

Move the generated effective-area files to `$VERITAS_EVNDISP_AUX_DIR/EffectiveAreas`.

## Support

Open an [issue on GitHub](https://github.com/VERITAS-Observatory/Eventdisplay_AnalysisScripts_VTS/issues) for bug reports, questions, or feature requests.

## License

Eventdisplay_AnalysisScripts_VTS is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file.
