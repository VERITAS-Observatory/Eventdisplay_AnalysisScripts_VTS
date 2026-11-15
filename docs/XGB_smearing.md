# XGB stereo IRF variants

Use a variant tag to keep multiple MC smearing experiments separate. For example,
with an absolute path to a YAML file understood by Eventdisplay-ML:

```bash
export XGB_VARIANT=smear05
export XGB_SMEARING_CONFIG=/absolute/path/smear05.yaml
./scripts/IRF.production.sh CARE_202404 ANAXGBANGRES V6_2023_2024w 61 0
./scripts/IRF.production.sh CARE_202404 EFFECTIVEAREAS V6_2023_2024w 61 0
./scripts/IRF.production.sh CARE_202404 COMBINEEFFECTIVEAREAS V6_2023_2024w 61 0
```

Use XGB cuts for the effective-area stages. The tag may contain letters, digits,
underscores and hyphens, beginning with a letter or digit. The YAML is copied to
`XGBVariants/<tag>/` in the epoch production directory, and later use of that tag
must match its recorded configuration. Sidecars use the suffix
`xgb_stereo_<tag>`; partial and combined IRFs also include the tag. Existing
variant outputs are not overwritten. Failed jobs can leave logs or locks that
must be examined and removed before retrying. Wait for each stage's jobs to
finish before starting the next.

For an augmented model, run `TRAINXGBANGRES` with its own variant and YAML;
the models are written to `TrainXGBStereoAnalysis_variants/<tag>/<zenith>/`.
To use that model in a separate inference variant, set `XGB_MODEL_ROOT` to the
absolute path of the training variant directory (the directory containing the
zenith-bin subdirectories) before running `ANAXGBANGRES`. If unset, the standard
`DispXGBs` models are used. Model and configuration hashes are printed in job
logs. Variants currently support RecID 0 and the separate XGB and effective-area
stages; `ANATABLESEFFAREAS` does not support them. Remove these environment
variables to run without a variant.

