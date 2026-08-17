# Resident Pipeline v0.9.41 Usage Notes

Load the current version from R from the project root:

```r
setwd("/path/to/your/project")
options(resident_pipeline.autostart = TRUE)
source("Outputs/resident_pipeline_v0.9.41.R")
```

For automated tests without the interactive startup menu from the project root:

```r
setwd("/path/to/your/project")
options(resident_pipeline.autostart = FALSE)
source("Outputs/resident_pipeline_v0.9.41.R")
source("Outputs/test_resident_pipeline_v0.9.41.R")
```

Important v0.9.41 behavior:

- Option 4 is now the model-assumption and detection review, placed immediately after the capture table, capture summary, and discovery summary.
- Option 4 now prints observed detection diagnostics, an assumption-by-assumption audit, likely bias if assumptions are weak, recommended actions, a short recommended-model summary, and candidate population-parameter models ranked by current data support.
- Option 4 separates suitability rank from the model menu option number. Use the column `model_menu_option_for_option_22` when fitting a recommended model in Option 22.
- Option 4 stores `analysis$detection_assumption_review`, `analysis$model_assumption_audit`, `analysis$model_assumption_recommendation`, and `analysis$model_assumption_recommended_models` for later inspection or export.
- Option 5 computes individual literature-based residency and site-fidelity classifications from the loaded encounter history.
- Option 5 selects `primary_classifier` using Huesca-style suitability scoring instead of a blind fixed priority order.
- The recommendation considers the classification goal, temporal support in the dataset, temporal gaps, and whether the classifier is better suited to residency or site-fidelity comparison.
- Option 5 shows `primary_classifier`, `primary_classifier_confidence`, and an interpretable `primary_classifier_reason` so the selected rule is explainable.
- The old fixed priority order remains only as a fallback when no scored classifier is available.
- Option 5 prints a compact overview table plus a readable per-individual detail list instead of flooding the R console with a very wide table.
- Option 5 automatically saves the complete wide classification table as a CSV file in `Outputs/` so no classifier columns are lost.
- Option 6 now shows a classifier-by-classifier residency/site-fidelity summary, because this result is available immediately after Option 5.
- Option 6 prints one readable block per literature rule and saves the complete long-format summary to `Outputs/literature_classifier_summary_full_*.csv`.
- Option 6 explicitly explains that Balmer categories are numerical sighting-frequency groups, not named resident/transient states.
- Balmer category labels are displayed and exported with zero padding, for example `01`, `02`, ..., `10`, so tables sort in natural numeric order.
- Option 7 now displays a fitted model-based residency-state table only when one truly exists. If none is stored, it prints an availability report explaining which fit is stored, why abundance/survival outputs are not individual residency-state classifications, and whether legacy state-model wrapper functions are present without a completed individual-state backend.
- Option 9 reuses the stored literature classification outputs for literature-classification category proportions.

- Options 11 to 13 are now grouped as discovery-curve plots: basic discovery, Chao discovery, and Chao sampling-completeness.
- Option 14 now plots residency and site-fidelity literature-classification category proportions as readable horizontal small multiples.
- Option 14 no longer labels frequency-based rules as true site-fidelity indices. A true site-fidelity plot is only shown when a spatial site-use index exists.
- Option 14 saves both the plot-data CSV and PNG image files to `Outputs/`, so the graph can be inspected outside the R plotting window.
- Option 14 plot legends now state: "Panels identify the published classifier. Names for categories follow those from Huesca et al. (2024)."
- Option 12 now computes Chao1/Chao2 discovery curves on demand, stores `analysis$chao_discovery_curve_table`, and sends the plot to the active R graphics device.
- Options 12 and 13 now use the same protected active-device pattern as Option 11: preserve/restore graphics settings, try the normal plot, try a simple fallback plot if the pane is too small, and export a JPG only if the active device cannot draw safely.
- Option 14 saves full-size PNG plots first, then draws only a protected active-device preview in RStudio. This prevents repeated multi-panel redraws from leaving RStudio in an invalid graphics state.
- Option 13 now computes Chao sampling-completeness curves on demand using the same stored Chao table.
- Option 20 now exports Chao estimates, Chao discovery-curve data, Chao discovery and completeness plots, and a interpretation summary text file.
- Chao outputs are descriptive richness/completeness indicators. They are not residency classifications and are not fitted mark-recapture abundance models.
- Export residency results exports the available literature-based individual classification table when no fitted model-state table exists.
- Current stable model-fitting outputs include abundance, Chao/discovery, and survival/detection summaries. These should not be interpreted as individual model-based residency-state classes unless a dedicated residency-state backend stores state probabilities or assigned states.
- Wide one-row summaries keep the v0.9.16 grouped-list display behavior.
- Option 1 keeps the v0.9.15 pre-import examples, templates, auto-detection, and dry-run validation.
- Option 1 now stores imported encounter histories in the current canonical location `analysis$data$history` and also exposes compatibility aliases `analysis$observed`, `analysis$occasions`, and `analysis$encounter_data$history`, so older examples and menu helpers can read the same imported data.
- Option 1 now imports the supplied MARK/SOCPROG example files directly: wide encounter-history CSV, Program MARK encounter-history TXT with companion dates, SOCPROG long sighting TXT/CSV, original MARK `.inp`, and Excel workbooks when `readxl` is installed.
- Metadata/audit files such as manifests, conversion summaries, and conversion-issue logs are recognized as documentation, not accepted as encounter-history data.
- Imported empirical dates are preserved exactly when present. Original MARK `.inp` files without a date companion receive synthetic dates for occasion order only and print a warning.
- The canonical TMB compile target remains `Outputs/resident_tmb.cpp`. The archived C++ file for this iteration is `Outputs/resident_tmb_v0.9.41.cpp`.

## What changed in v0.9.41

- Option 7 now fits/stores a model-based residency-state table using the state-space/robust-design backend instead of only reporting that no table exists.
- Option 8 now compares the stored model-based residency-state table with the literature-based residency/site-fidelity classifications.
- Model-result slots are read with exact matching so a status table cannot be mistaken for a residency-state result table.
- The file remains standalone and does not source older Resident pipeline versions.


## Supported empirical input files in v0.9.41

Use Option 1 and choose `3` for AUTO if you are unsure which format you have.

- `PROGRAM_MARK`: a text file with columns `id`, `encounter_history`, and optional `frequency`. Companion files named like `*_PROGRAM_MARK_occasion_dates.txt` are detected automatically.
- `SOCPROG`: a long sighting file with one row per sighting and required columns `id` and `date`. Duplicate detections of the same individual on the same date are collapsed to detected = 1.
- `WIDE_CSV`: a capture-recapture matrix with one `id` column and one 0/1 column per sampling occasion. Date headers such as `2020-01-05` are used as occasion dates.
- `MARK_INP`: original Program MARK compact rows such as `/*Dolphin_001*/100100 1;`. This works for detection histories, but real survey dates require a companion occasion-date file.
- `EXCEL`: a workbook containing either a WIDE_CSV-style worksheet or one or more SOCPROG-style sighting worksheets. If `readxl` is installed it is used; otherwise v0.9.41 uses a base-R fallback reader for simple `.xlsx` worksheets.

The supplied examples verified by the regression tests are:

- `DrMorteo_2007_2009_encounter_history_wide.csv`: 206 individuals, 29 occasions, 881 detections.
- `DraTara_2014_2016_encounter_history_wide.csv`: 455 individuals, 36 occasions, 2473 detections.
- `DrMorteo_2007_2009_PROGRAM_MARK_encounter_history.txt`: 206 individuals, 29 occasions, 881 detections.
- `DraTara_2014_2016_PROGRAM_MARK_encounter_history.txt`: 455 individuals, 36 occasions, 2473 detections.
- `DrMorteo_2007_2009_SOCPROG_sightings_long_format.txt`: 206 individuals, 29 occasions, 881 detections.
- `DraTara_2014_2016_SOCPROG_sightings_long_format.txt`: 455 individuals, 36 occasions, 2473 detections.
- `Summer_17.inp`: imports as MARK_INP with 230 rows and 121 occasions; dates are synthetic unless a companion date file is supplied.
- `Winter_18.inp`: imports as MARK_INP with 96 rows and 60 occasions; dates are synthetic unless a companion date file is supplied.
- `17S_18W_Sightings.xlsx`: imports as EXCEL by combining the two sighting worksheets into 271 individuals, 31 occasions, and 478 detections.

Files such as `MANIFEST_MARK_SOCPROG.csv`, `conversion_summary.csv`, and `conversion_issues_and_assumptions.csv` explain the conversion process and are intentionally rejected as direct analysis input.

## v0.9.41 Export Menu Notes

Version v0.9.41 makes Export menu Options 15-20 use the analysis run output folder consistently.

- Option 15 saves `capture_recapture_table.csv`.
- Option 16 saves `capture_data_summary.csv`.
- Option 17 saves `discovery_summary.csv`.
- Option 18 saves `residency_classification_results.csv`.
- Option 19 saves `model_literature_comparison.csv` when a model-based comparison exists. If no model-based residency-state table exists yet, it saves `model_literature_comparison_status.txt`, `literature_classifier_summary.csv`, and `literature_residency_classification_full.csv` instead.
- Option 20 saves Chao estimates, Chao discovery data, Chao plots, and a Chao summary text file in the same run folder.

This version does not change Options 1-5, and it intentionally does not change Options 6-7.

## v0.9.41 Standalone Notes

Version v0.9.41 is a standalone consolidated Resident Pipeline file. Sourcing it should print only one load message:

```r
Resident Pipeline v0.9.41 loaded as standalone.
```

It must not source older files such as v0.9.28, v0.9.35, or v0.9.36. You can verify this with:

```r
resident_active_version()
resident_pipeline_is_standalone()
resident_version_report()
```

Expected values:

```r
resident_active_version()       # "v0.9.41"
resident_pipeline_is_standalone() # TRUE
```

