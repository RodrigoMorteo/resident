# Resident Pipeline v0.9.41 Mandatory Pre-Delivery Checklist

Before delivering a new version:

1. Read `Outputs/Check-commits/error_solution_ledger_v0.9.41.md`.
2. Read `Outputs/Check-commits/functionality_test_registry_v0.9.41.csv`.
3. Run the regression suite from the project root: `Rscript -e 'options(resident_pipeline.autostart = FALSE); source("Outputs/resident_pipeline_v0.9.41.R"); source("Outputs/test_resident_pipeline_v0.9.41.R")'`.
4. Confirm standalone loading: one current-version load message and no `source()` calls to older Resident pipeline files.
5. Confirm Option 22 prints a guided fitting wizard, data-readiness snapshot, grouped selectable models, implementation-status labels, comparable-likelihood groups, and CJS exclusion.
6. Confirm Option 22 still stores `analysis$abundance_fit`, `analysis$fitted_model`, `analysis$model_fit`, and `analysis$model_results`.
7. Confirm Option 23 retrieves every Option 22 fitted/stored model.
8. Confirm Options 1-14, 15-20, and 21 remain unaffected.
9. If any unrelated option changes behavior, revert the fix and narrow the implementation.
