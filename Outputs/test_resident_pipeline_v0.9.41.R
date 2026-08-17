# test_resident_pipeline_v0.9.41.R
# Regression tests for Resident Pipeline v0.9.41.

repo_root <- function() {
  base <- normalizePath(getwd(), mustWork = FALSE)
  candidates <- unique(c(base, file.path(base, "Outputs"), file.path(base, ".."),
    file.path(base, "..", "Outputs")))
  for (dir in candidates) {
    if (file.exists(file.path(dir, "resident_pipeline_v0.9.41.R")) ||
        file.exists(file.path(dir, "Outputs", "resident_pipeline_v0.9.41.R"))) {
      if (basename(dir) == "Outputs") return(normalizePath(dirname(dir), mustWork = FALSE))
      return(normalizePath(dir, mustWork = FALSE))
    }
  }
  parent <- dirname(base)
  while (!identical(parent, base)) {
    if (file.exists(file.path(parent, "resident_pipeline_v0.9.41.R")) ||
        file.exists(file.path(parent, "Outputs", "resident_pipeline_v0.9.41.R"))) {
      return(normalizePath(parent, mustWork = FALSE))
    }
    base <- parent
    parent <- dirname(base)
  }
  normalizePath(getwd(), mustWork = FALSE)
}
if (!identical(normalizePath(getwd(), mustWork = FALSE), repo_root())) {
  setwd(repo_root())
}

options(resident_pipeline.autostart = FALSE)
options(resident.option7.state_maxit = 1L)
options(resident.table.output_dir = file.path("Outputs", "test_v0.9.41"))
dir.create(getOption("resident.table.output_dir"), recursive = TRUE, showWarnings = FALSE)
resident_load_output <- capture.output(source(file.path("Outputs", "resident_pipeline_v0.9.41.R")))

fail <- function(msg) stop(msg, call. = FALSE)
check <- function(ok, msg) if (!isTRUE(ok)) fail(msg)

make_history <- function() {
  m <- matrix(c(
    1,0,1,0,0,
    0,1,1,0,1,
    0,0,0,1,0,
    1,1,0,0,0
  ), nrow = 4, byrow = TRUE)
  rownames(m) <- paste0("ID_", seq_len(nrow(m)))
  colnames(m) <- paste0("Occ_", seq_len(ncol(m)))
  m
}

make_analysis <- function(occ) {
  history <- make_history()
  list(
    data_type = "empirical",
    observed = history,
    occasions = occ,
    encounter_data = list(history = history, occasions = occ, source = "test"),
    run_output_dir = file.path("Outputs", "test_v0.9.41")
  )
}

cat("Test 1: version loaded\n")
check(identical(resident_active_version(), "v0.9.41"), "Active version is not v0.9.41")

check(length(resident_load_output) == 1L, paste("Standalone load should print exactly one line, got", length(resident_load_output)))
check(any(grepl("v0.9.41 loaded as standalone", resident_load_output, fixed = TRUE)), "Standalone load message was not printed")
check(!any(grepl("v0.9.28|v0.9.29|v0.9.30|v0.9.31|v0.9.33|v0.9.34|v0.9.35|v0.9.36", resident_load_output)), "Standalone load still printed older dependency load messages")
check(isTRUE(resident_pipeline_is_standalone()), "resident_pipeline_is_standalone() did not confirm standalone source")
standalone_source <- readLines(file.path("Outputs", "resident_pipeline_v0.9.41.R"), warn = FALSE)
check(!any(grepl("source_resident_dependency\\s*\\(", standalone_source)), "Standalone file still defines/calls source_resident_dependency")
check(!any(grepl("source\\s*\\(.*resident_pipeline_v0\\.9\\.", standalone_source)), "Standalone file still contains source() calls to older Resident pipeline files")

forbidden_phrase <- paste0("Plain", "-", "language")
check(!any(grepl(forbidden_phrase, readLines(file.path("Outputs", "resident_pipeline_v0.9.41.R"), warn = FALSE), fixed = TRUE)), "Pipeline source still contains the removed wording")


cat("Test 1A: Option 1 examples and templates are available before file selection\n")
template_dir <- file.path(tempdir(), "resident_import_templates_v0923")
example_out <- capture.output(examples <- show_import_format_examples())
check(any(grepl("Program MARK-style", example_out)), "Import examples did not show Program MARK format")
check(any(grepl("SOCPROG-style", example_out)), "Import examples did not show SOCPROG format")
check(any(grepl("Wide CSV", example_out)), "Import examples did not show WIDE_CSV format")
check(any(grepl("Original MARK", example_out)), "Import examples did not show MARK_INP format")
templates <- write_import_templates(output_dir = template_dir)
check(nrow(templates) == 5L, "write_import_templates did not return all template paths")
check(all(file.exists(templates$path)), "One or more import template files were not created")

cat("Test 1B: pre-import validation rejects invalid files with correction guidance\n")
bad_file <- file.path(tempdir(), "resident_bad_import_v0923.csv")
writeLines(c("animal,when", "A,2020-01-01"), bad_file)
bad_validation <- validate_import_file_before_analysis(bad_file, "SOCPROG")
check(!isTRUE(bad_validation$ok), "Invalid SOCPROG file passed pre-import validation")
check(is.data.frame(bad_validation$problems) && all(c("problem", "correction") %in% names(bad_validation$problems)), "Invalid import did not return problem/correction guidance")

cat("Test 1C: pre-import validation auto-detects Program MARK files\n")
mark_file <- file.path(tempdir(), "resident_mark_import_v0923.txt")
writeLines(c(
  "# dates: 2022-01-01 2022-01-08 2022-01-15 2022-01-22",
  "id encounter_history frequency",
  "Dolphin_001 1001 1",
  "Dolphin_002 0100 1",
  "Dolphin_003 0011 1"
), mark_file)
mark_validation <- validate_import_file_before_analysis(mark_file, "AUTO")
check(isTRUE(mark_validation$ok), "Valid Program MARK file failed pre-import validation")
check(identical(mark_validation$detected_format, "PROGRAM_MARK"), "AUTO did not detect Program MARK format")
check(!is.null(mark_validation$imported$history), "Pre-import validation did not build canonical history for a valid file")

cat("Test 1D: Option 1 import confirms real dates and stores canonical analysis data\n")
provider_import <- local({ vals <- c("3", mark_file, "1"); i <- 0L; function(prompt = "") { i <<- i + 1L; vals[min(i, length(vals))] } })
import_out <- capture.output(analysis_import <- run_interactive_analysis_workflow(input_provider = provider_import, post_run_menu = FALSE))
check(any(grepl("Pre-import file validation", import_out)), "Option 1 did not print pre-import validation")
check(any(grepl("Detected format: PROGRAM_MARK", import_out)), "Option 1 did not report detected Program MARK format")
check(!is.null(analysis_import$data$history), "Option 1 analysis object does not contain imported history")
check(!is.null(analysis_import$data$occasions), "Option 1 analysis object does not contain imported occasions")
check(isTRUE(attr(analysis_import$data$occasions, "real_dates_confirmed")), "Option 1 did not store confirmed real-date metadata")
summary_import <- analysis_capture_data_summary(analysis_import)
check(identical(summary_import$date_status[1], "observed_survey_dates_confirmed"), "Confirmed imported dates were not propagated to later capture summaries")

summary_out <- capture.output(print_capture_data_summary(summary_import))
check(any(grepl("Sampling dates and time span", summary_out)), "Wide capture summary did not print as a grouped list")
check(any(grepl("Dataset size and capture frequency", summary_out)), "Capture summary list did not include dataset-size section")
check(!any(grepl("initial_sampling_date[[:space:]]*\\|", summary_out)), "Capture summary still printed as a wide pipe table")

cat("Test 1E: import menu can show examples and then return to format selection\n")
provider_menu <- local({ vals <- c("4", "3"); i <- 0L; function(prompt = "") { i <<- i + 1L; vals[min(i, length(vals))] } })
menu_out <- capture.output(fmt_after_examples <- prompt_import_choice(input_provider = provider_menu))
check(identical(fmt_after_examples, "AUTO"), "Import menu did not continue after examples/templates")
check(any(grepl("Template files written", menu_out)), "Import menu did not write templates when examples were requested")

cat("Test 1F: supplied MARK, SOCPROG, wide CSV, and MARK .inp examples import correctly\n")
input_dir <- "/Users/eduardomorteo/Documents/Codex/Resident/residency_MARK_SOCPROG_inputs"
if (dir.exists(input_dir)) {
  import_expectations <- data.frame(
    file = c(
      "DrMorteo_2007_2009_encounter_history_wide.csv",
      "DraTara_2014_2016_encounter_history_wide.csv",
      "DrMorteo_2007_2009_PROGRAM_MARK_encounter_history.txt",
      "DraTara_2014_2016_PROGRAM_MARK_encounter_history.txt",
      "DrMorteo_2007_2009_SOCPROG_sightings_long_format.txt",
      "DraTara_2014_2016_SOCPROG_sightings_long_format.txt"
    ),
    format = c("WIDE_CSV", "WIDE_CSV", "PROGRAM_MARK", "PROGRAM_MARK", "SOCPROG", "SOCPROG"),
    n_ids = c(206L, 455L, 206L, 455L, 206L, 455L),
    n_occ = c(29L, 36L, 29L, 36L, 29L, 36L),
    total_caps = c(881L, 2473L, 881L, 2473L, 881L, 2473L),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(import_expectations))) {
    row <- import_expectations[i, ]
    validation <- validate_import_file_before_analysis(file.path(input_dir, row$file), "AUTO")
    check(isTRUE(validation$ok), paste("Valid supplied file did not import:", row$file))
    check(identical(validation$detected_format, row$format), paste("Wrong detected format for", row$file))
    h <- validation$imported$history
    check(nrow(h) == row$n_ids, paste("Wrong individual count for", row$file))
    check(ncol(h) == row$n_occ, paste("Wrong occasion count for", row$file))
    check(sum(h) == row$total_caps, paste("Wrong total detections for", row$file))
  }
  for (f in c("Summer_17.inp", "Winter_18.inp")) {
    validation <- validate_import_file_before_analysis(file.path(input_dir, f), "AUTO")
    check(isTRUE(validation$ok), paste("Valid MARK .inp file did not import:", f))
    check(identical(validation$detected_format, "MARK_INP"), paste("Wrong detected format for", f))
    check(any(grepl("synthetic dates", validation$warnings, ignore.case = TRUE)), paste("MARK .inp import did not warn about synthetic dates:", f))
  }
  for (f in c("MANIFEST_MARK_SOCPROG.csv", "conversion_summary.csv", "conversion_issues_and_assumptions.csv")) {
    validation <- validate_import_file_before_analysis(file.path(input_dir, f), "AUTO")
    check(!isTRUE(validation$ok), paste("Metadata file should not be accepted as encounter data:", f))
    check(identical(validation$detected_format, "METADATA"), paste("Metadata file was not recognized as metadata:", f))
  }
  xlsx_validation <- validate_import_file_before_analysis(file.path(input_dir, "17S_18W_Sightings.xlsx"), "AUTO")
  check(isTRUE(xlsx_validation$ok), "Excel workbook did not import with readxl or the base-R fallback reader")
  check(identical(xlsx_validation$detected_format, "EXCEL"), "Excel file was not detected as EXCEL")
  check(nrow(xlsx_validation$imported$history) == 271L, "Excel import produced the wrong individual count")
  check(ncol(xlsx_validation$imported$history) == 31L, "Excel import produced the wrong occasion count")
  check(sum(xlsx_validation$imported$history) == 478L, "Excel import produced the wrong total detection count")
  check(length(xlsx_validation$imported$metadata$combined_sheets) == 2L, "Excel import did not combine the two sighting worksheets")
} else {
  cat("Supplied input directory not found; skipping file-specific import tests.\n")
}

cat("Test 1G: import menu supports explicit wide CSV, MARK .inp, and Excel choices\n")
check(identical(normalize_import_choice("5"), "WIDE_CSV"), "Menu choice 5 does not select WIDE_CSV")
check(identical(normalize_import_choice("6"), "MARK_INP"), "Menu choice 6 does not select MARK_INP")
check(identical(normalize_import_choice("7"), "EXCEL"), "Menu choice 7 does not select EXCEL")

cat("Test 1H: guided analysis import stores data in both current and compatibility locations\n")
if (dir.exists(input_dir)) {
  guided_cases <- data.frame(
    menu_choice = c("3", "5", "1", "2", "6", "7"),
    file = c(
      "DrMorteo_2007_2009_encounter_history_wide.csv",
      "DrMorteo_2007_2009_encounter_history_wide.csv",
      "DrMorteo_2007_2009_PROGRAM_MARK_encounter_history.txt",
      "DrMorteo_2007_2009_SOCPROG_sightings_long_format.txt",
      "Summer_17.inp",
      "17S_18W_Sightings.xlsx"
    ),
    expected_format = c("WIDE_CSV", "WIDE_CSV", "PROGRAM_MARK", "SOCPROG", "MARK_INP", "EXCEL"),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(guided_cases))) {
    case <- guided_cases[i, ]
    full_path <- file.path(input_dir, case$file)
    provider <- local({
      vals <- c(case$menu_choice, full_path, "1")
      j <- 0L
      function(prompt = "") {
        j <<- j + 1L
        vals[min(j, length(vals))]
      }
    })
    guided <- capture.output(analysis_guided <- run_interactive_analysis_workflow(input_provider = provider, post_run_menu = FALSE))
    check(is.list(analysis_guided), paste("Guided import did not return an analysis object for", case$file))
    check(!is.null(analysis_guided$data$history), paste("Guided import did not store analysis$data$history for", case$file))
    check(!is.null(analysis_guided$observed), paste("Guided import did not expose compatibility alias analysis$observed for", case$file))
    check(!is.null(analysis_guided$occasions), paste("Guided import did not expose compatibility alias analysis$occasions for", case$file))
    check(!is.null(analysis_guided$encounter_data$history), paste("Guided import did not expose compatibility alias analysis$encounter_data$history for", case$file))
    check(identical(dim(analysis_guided$observed), dim(analysis_guided$data$history)), paste("Compatibility observed dimensions differ from data$history for", case$file))
    check(identical(as.matrix(analysis_guided$observed), as.matrix(analysis_guided$data$history)), paste("Compatibility observed values differ from data$history for", case$file))
    check(identical(analysis_guided$source_format, case$expected_format), paste("Wrong source_format alias for", case$file))
    exported_table <- safe_capture_recapture_table_from_analysis(analysis_guided)
    check(nrow(exported_table) == nrow(analysis_guided$data$history), paste("Capture-recapture table row count failed after guided import for", case$file))
    check(ncol(exported_table) == ncol(analysis_guided$data$history) + 1L, paste("Capture-recapture table column count failed after guided import for", case$file))
    check(any(grepl("Capture data summary", guided)), paste("Guided import did not print the capture-data summary for", case$file))
  }
}

cat("Test 2: generated 2020 dates are hidden\n")
occ_default <- data.frame(occasion = 1:5, date = as.Date("2020-01-01") + 0:4)
s_default <- capture_data_summary(make_history(), occ_default)
check(is.na(s_default$initial_sampling_date[1]), "Generated start date was displayed")
check(is.na(s_default$final_sampling_date[1]), "Generated end date was displayed")
check(identical(s_default$date_status[1], "generated_or_synthetic_dates_hidden_not_field_dates"), "Generated dates were not flagged correctly")

cat("Test 3: unconfirmed real-looking dates are hidden\n")
occ_unconfirmed <- data.frame(occasion = 1:5, date = as.Date("2023-03-02") + c(0, 8, 21, 35, 60))
s_unconfirmed <- capture_data_summary(make_history(), occ_unconfirmed)
check(is.na(s_unconfirmed$initial_sampling_date[1]), "Unconfirmed start date was displayed")
check(identical(s_unconfirmed$date_status[1], "unconfirmed_dates_hidden_until_confirmed"), "Unconfirmed dates were not flagged correctly")

cat("Test 4: confirmed user-supplied dates are displayed\n")
attr(occ_unconfirmed, "real_dates_confirmed") <- TRUE
s_confirmed <- capture_data_summary(make_history(), occ_unconfirmed)
check(!is.na(s_confirmed$initial_sampling_date[1]), "Confirmed start date was hidden")
check(identical(s_confirmed$date_status[1], "observed_survey_dates_confirmed"), "Confirmed dates were not flagged correctly")

cat("Test 5: option 2 hides generated dates in printed summary\n")
analysis <- make_analysis(occ_default)
out2 <- capture.output(res2 <- handle_post_simulation_menu_choice("2", analysis))
check(!any(grepl("2020-01-01|2020-01-05", out2)), "Option 2 printed generated dates")
check(any(grepl("generated_or_synthetic_dates_hi|No confirmed real survey dates|does not display generated", out2)), "Option 2 did not print generated-date warning")

cat("Test 6: option 1 works after option 2 and does not recurse\n")
analysis_after_2 <- res2$analysis
out1 <- capture.output(res1 <- handle_post_simulation_menu_choice("1", analysis_after_2))
check(any(grepl("Capture-recapture table", out1)), "Option 1 did not print the capture-recapture table")
check(any(grepl("individual_id", out1)), "Option 1 did not include individual identifiers")

cat("Test 7: option 3 discovery summary works and does not recurse\n")
out3 <- capture.output(res3 <- handle_post_simulation_menu_choice("3", analysis))
check(any(grepl("Discovery", out3)), "Option 3 did not print discovery summary output")
check(any(grepl("cumulative|new individuals|first time", out3, ignore.case = TRUE)), "Option 3 did not explain discovery summary")


cat("Test 7A: option 4 prints and stores the model-assumption and detection audit\n")
out4_audit <- capture.output(res4_audit <- handle_post_simulation_menu_choice("4", analysis))
check(any(grepl("Model-assumption and detection review", out4_audit)), "Option 4 did not print the model-assumption and detection review")
check(any(grepl("Assumption-by-assumption audit", out4_audit)), "Option 4 did not print the assumption audit")
check(any(grepl("Candidate population-parameter models ranked", out4_audit)), "Option 4 did not print ranked candidate model guidance")
check(any(grepl("Recommended models to consider next", out4_audit)), "Option 4 did not print the recommended-model summary")
check(any(grepl("model_menu_option_for_option_22", out4_audit)), "Option 4 did not identify the menu option number to use in Option 22")
check(any(grepl("Numbering note", out4_audit)), "Option 4 did not explain whether list numbers are ranks or menu options")
check(any(grepl("Suitability rank", out4_audit)), "Option 4 did not label suitability ranks explicitly")
check(!any(grepl(forbidden_phrase, out4_audit, fixed = TRUE)), "Option 4 still prints the removed wording")
check(!is.null(res4_audit$analysis$model_assumption_audit), "Option 4 did not store model_assumption_audit")
check(!is.null(res4_audit$analysis$model_assumption_recommendation), "Option 4 did not store model_assumption_recommendation")
check(!is.null(res4_audit$analysis$model_assumption_recommended_models), "Option 4 did not store model_assumption_recommended_models")
check("model_menu_option_for_option_22" %in% names(res4_audit$analysis$model_assumption_recommended_models), "Recommended-model summary does not expose Option 22 menu numbers")
check("suitability_rank" %in% names(res4_audit$analysis$model_assumption_recommendation), "Ranked recommendation table does not store suitability_rank")
check(any(grepl("possible_bias_if_weak", names(res4_audit$analysis$model_assumption_audit))), "Option 4 audit does not store bias explanations")

cat("Test 7AB: option 5 computes and stores literature-based residency classifications\n")
out4 <- capture.output(res4 <- handle_post_simulation_menu_choice("5", res4_audit$analysis))
check(any(grepl("Literature-based residency and site-fidelity classifications", out4)), "Option 5 did not identify literature-based classifications")
check(any(grepl("Individual literature-based classification overview", out4)), "Option 5 did not print the compact classification overview")
check(any(grepl("primary[[:space:]]*classifier", out4, ignore.case = TRUE)), "Option 5 overview did not show the primary classifier column")
check(any(grepl("Recommended primary rule:", out4)), "Option 5 result_note did not explain which literature rule was used")
check(any(grepl("Detailed classifications for first", out4)), "Option 5 did not print the readable per-individual detail list")
check(any(grepl("Full classification table saved to", out4)), "Option 5 did not export the full wide classification table")
check(!any(grepl("diaz_category[[:space:]]*\\|", out4)), "Option 5 still prints the wide literature-classification table in the console")
check(!any(grepl("No individual residency-classification table is stored", out4)), "Option 5 still reports missing classification instead of computing it")
check(!is.null(res4$analysis$individual_residency_classification), "Option 5 did not store individual_residency_classification")
check(!is.null(res4$analysis$literature_residency_classification), "Option 5 did not store literature_residency_classification")
check("primary_classifier" %in% names(res4$analysis$literature_residency_classification), "Option 5 did not store the primary_classifier column")
check("primary_classifier_reason" %in% names(res4$analysis$literature_residency_classification), "Option 5 did not store the primary_classifier_reason column")
check("primary_classifier_confidence" %in% names(res4$analysis$literature_residency_classification), "Option 5 did not store the primary_classifier_confidence column")
check(!is.null(res4$analysis$primary_classifier_recommendation), "Option 5 did not store the primary-classifier recommendation object")
check(!is.null(res4$analysis$primary_classifier_scores), "Option 5 did not store primary-classifier scores")
check(any(res4$analysis$literature_residency_classification$primary_classifier %in% literature_classifier_labels()), "Option 5 stored an unexpected primary classifier label")
check(identical(literature_classifier_metadata()$category_type[literature_classifier_metadata()$classifier == "Balmer"], "numeric frequency classes"), "Balmer metadata does not identify numeric frequency classes")
check(identical(format_literature_category_label(c(1, 10, 11, 2, 3), "balmer_category"), c("01", "10", "11", "02", "03")), "Balmer category labels are not zero-padded correctly")
balmer_sort_test <- data.frame(balmer_category = c(1, 10, 11, 2, 3), stringsAsFactors = FALSE)
balmer_summary_test <- literature_classifier_summary_long(balmer_sort_test)
check(identical(balmer_summary_test$category, c("01", "02", "03", "10", "11")), "Balmer summary categories are not sorted in natural zero-padded order")
check(!identical(res4$analysis$primary_classifier_recommendation$reason, "No scored classifier was available; fixed fallback order was used."), "Option 5 used fixed fallback instead of Huesca-style scoring when classifier scores were available")
check(!is.null(res4$analysis$residency_category_proportions), "Option 5 did not store category proportions for later options")
check(!is.null(res4$analysis$literature_residency_classification_full_csv), "Option 5 did not store the full classification CSV path")
check(file.exists(res4$analysis$literature_residency_classification_full_csv), "Option 5 full classification CSV path does not exist")
check("classifier_basis" %in% names(res4$analysis$individual_residency_classification), "Option 5 did not label the classification basis")

cat("Test 7AA: option 14 plots residency and site-fidelity classifications separately without implying unsupported true site fidelity\n")
pdf(NULL)
tryCatch({
  out12 <- capture.output(res12 <- handle_post_simulation_menu_choice("14", res4$analysis))
}, finally = try(dev.off(), silent = TRUE))
check(any(grepl("Residency and site-fidelity literature/model category proportion plots", out12, fixed = TRUE)), "Option 14 did not print the residency/site-fidelity literature-classification plot heading")
check(!any(grepl("Horizontal bars avoid crowded category labels", out12, fixed = TRUE)), "Option 14 still prints the old horizontal-bars subtitle")
check(any(grepl("Panels identify the published classifier", out12)), "Option 14 did not explain that panels identify classifiers")
check(any(grepl("Names for categories follow those from Huesca et al. (2024)", out12, fixed = TRUE)), "Option 14 did not print the Huesca category-name note")
check(!is.null(res12$analysis$category_proportion_plot_data), "Option 14 did not store plot data")
check(all(c("indicator_family", "indicator_family_label", "category_axis_label", "category_type_label", "classifier") %in% names(res12$analysis$category_proportion_plot_data)), "Option 14 plot data is missing required columns")
check(all(c("residency", "sighting_frequency_proxy") %in% unique(res12$analysis$category_proportion_plot_data$indicator_family)), "Option 14 did not separate residency and sighting-frequency/site-use proxy classifications")
check(!"site_fidelity" %in% unique(res12$analysis$category_proportion_plot_data$indicator_family), "Option 14 still mislabels proxy classifications as site_fidelity")
check(!any(grepl("Site-fidelity and sighting-frequency indicators", out12, fixed = TRUE)), "Option 14 still prints the misleading old site-fidelity/frequency label")
check(any(grepl("No true site-fidelity index is plotted", out12)), "Option 14 did not explain why no true site-fidelity index is shown")
check(all(c("residency", "sighting_frequency_proxy") %in% names(res12$analysis$category_proportion_plot_png)), "Option 14 did not save residency and proxy plot families")
check(all(file.exists(res12$analysis$category_proportion_plot_png)), "One or more Option 14 PNG files were not saved")
check(file.exists(res12$analysis$category_proportion_plot_data_csv), "Option 14 plot-data CSV was not saved")

cat("Test 7AAA: option 14 keeps separated active plots and survives tiny graphics devices\n")
check(!any(grepl("Literature-classification plot preview", out12)), "Option 14 used the v0.9.34 preview instead of separated family plots")
small_plot_file_14 <- file.path(tempdir(), "resident_small_option14.png")
grDevices::png(small_plot_file_14, width = 60, height = 45)
tryCatch({
  out14_small <- capture.output(res14_small <- handle_post_simulation_menu_choice("14", res4$analysis))
}, finally = try(grDevices::dev.off(), silent = TRUE))
check(length(res14_small$analysis$category_proportion_plot_png) >= 1L, "Option 14 did not store saved PNG paths after tiny graphics-device fallback")
check(all(file.exists(res14_small$analysis$category_proportion_plot_png)), "Option 14 saved PNG paths do not exist after tiny graphics-device fallback")

cat("Test 7B: option 6 now shows the residency/site-fidelity summary\n")
out5_summary <- capture.output(res5_summary <- handle_post_simulation_menu_choice("6", res4$analysis))
check(any(grepl("Residency/site-fidelity class summary", out5_summary)), "Option 6 did not display the residency/site-fidelity class summary")
check(any(grepl("Balmer note: Balmer categories are numerical", out5_summary)), "Option 6 did not explain that Balmer categories are numerical")
check(any(grepl("Zero padding", out5_summary)), "Option 6 did not explain why Balmer labels are zero-padded")
check(any(grepl("Dinis", out5_summary)) && any(grepl("Moller", out5_summary)) && any(grepl("Balmer", out5_summary)), "Option 6 did not expose multiple site-fidelity/residency classifiers")
check(!any(grepl("primary_literat", out5_summary)), "Option 6 still exposes the truncated primary_literature classifier label")
check(!is.null(res5_summary$analysis$literature_classifier_summary), "Option 6 did not store the all-classifier summary")
check("classifier" %in% names(res5_summary$analysis$literature_classifier_summary), "Option 6 summary does not store readable classifier names")
check("assessment_type" %in% names(res5_summary$analysis$literature_classifier_summary), "Option 6 summary does not store assessment type")
check(!is.null(res5_summary$analysis$literature_classifier_summary_full_csv), "Option 6 did not store the all-classifier summary CSV path")
check(file.exists(res5_summary$analysis$literature_classifier_summary_full_csv), "Option 6 all-classifier summary CSV path does not exist")
check(!any(grepl("No fitted model-based residency-state result", out5_summary)), "Option 6 still routes to model-based results")

cat("Test 7C: option 7 fits and stores model-based residency-state results\n")
out6_model <- capture.output(res6_model <- handle_post_simulation_menu_choice("7", res4$analysis))
model_tab_7 <- safe_residency_result_table(res6_model$analysis)
check(any(grepl("Fitting diagnostic state-space residency model for Option 7", out6_model)), "Option 7 did not start the model-based state workflow")
check(any(grepl("Option 7 residency-state guide", out6_model, fixed = TRUE)), "Option 7 did not print the residency-state guide")
check(any(grepl("Option 21 evaluates which abundance", out6_model, fixed = TRUE)), "Option 7 did not distinguish itself from Option 21")
check(any(grepl("A high availability_probability can still occur with no detection", out6_model, fixed = TRUE)), "Option 7 did not explain availability_probability and missed detections")
check(any(grepl("Model-based residency-state results", out6_model)), "Option 7 did not print model-based residency-state results")
check(resident_valid_model_based_residency_table(model_tab_7), "Option 7 did not store a valid model-based residency-state table")
check(nrow(model_tab_7) == nrow(extract_history(res4$analysis)), "Option 7 model-based table does not have one row per individual")
check(!is.null(res6_model$analysis$residency_state_fit), "Option 7 did not store residency_state_fit")
check(!is.null(res6_model$analysis$state_space_fit), "Option 7 did not store state_space_fit")
check(!is.null(res6_model$analysis$model_based_residency_results), "Option 7 did not store model_based_residency_results")
check(!is.null(res6_model$analysis$residency_state_results), "Option 7 did not store residency_state_results")
check(all(c("id", "most_likely_state", "resident_probability", "availability_probability", "classification_confidence", "model_fit_note") %in% names(model_tab_7)), "Option 7 table is missing required readable model-state columns")
check(any(grepl("Diagnostic state classification", model_tab_7$model_fit_note)), "Option 7 did not label non-converged diagnostic state classifications")
check(any(grepl("Option 7 has fitted/stored", out6_model)), "Option 7 did not explain that results were fitted/stored")
status_only_analysis <- list(model_based_residency_status = data.frame(check = "model_based_residency_state_table", status = "available", detail = "status only", output_type = "backend_status", stringsAsFactors = FALSE))
check(is.null(safe_residency_result_table(status_only_analysis)), "safe_residency_result_table accepted a status table through partial name matching")
check(is.null(.safe_model_based_residency_table(status_only_analysis)), ".safe_model_based_residency_table accepted a status table through partial name matching")

cat("Test 7D: option 8 compares model-based states with literature classifications\n")
out8_compare <- capture.output(res8_compare <- handle_post_simulation_menu_choice("8", res6_model$analysis))
check(any(grepl("Model-vs-literature residency comparison", out8_compare)), "Option 8 did not print the model-vs-literature comparison")
check(!is.null(res8_compare$analysis$model_literature_comparison), "Option 8 did not store model_literature_comparison")
check(nrow(res8_compare$analysis$model_literature_comparison) == nrow(extract_history(res4$analysis)), "Option 8 comparison does not have one row per individual")
check(any(c("most_likely_state", "model_based_state") %in% names(res8_compare$analysis$model_literature_comparison)), "Option 8 comparison does not include model-based state information")
check(any(c("primary_classifier", "primary_literature_category", "chabanne_category", "moller_category") %in% names(res8_compare$analysis$model_literature_comparison)), "Option 8 comparison does not include literature-classification information")
check(any(grepl("Rows compare", out8_compare)), "Option 8 did not explain what the comparison rows mean")
out8_res <- capture.output(res8_res <- handle_post_simulation_menu_choice("9", res4$analysis))
check(any(grepl("Literature-classification category proportions", out8_res)), "Option 9 did not display literature-classification category proportions")
check(!is.null(res5_summary$analysis$residency_category_proportions), "Option 6 did not preserve category proportions")

cat("Test 7E: option 9 includes model-based state proportions after option 7\n")
out9_model <- capture.output(res9_model <- handle_post_simulation_menu_choice("9", res6_model$analysis))
check(any(grepl("Literature-classification category proportions", out9_model)), "Option 9 no longer displays literature-classification proportions")
check(any(grepl("Model-based residency-state proportions from Option 7", out9_model, fixed = TRUE)), "Option 9 did not display Option 7 model-based state proportions")
check(!is.null(res9_model$analysis$model_based_state_proportions), "Option 9 did not store model_based_state_proportions")
check(all(c("model_state", "number_of_individuals", "proportion", "classifier") %in% names(res9_model$analysis$model_based_state_proportions)), "Option 9 model-based proportions are missing required columns")

cat("Test 7F: option 14 includes model-based state plot data after option 7 and still works without it\n")
pdf(NULL)
tryCatch({
  out14_model <- capture.output(res14_model <- handle_post_simulation_menu_choice("14", res6_model$analysis))
}, finally = try(dev.off(), silent = TRUE))
check(any(grepl("Model-based states are labelled separately when Option 7 results are available", out14_model, fixed = TRUE)), "Option 14 did not explain model-based state plotting")
check(!is.null(res14_model$analysis$category_proportion_plot_data), "Option 14 did not store plot data after Option 7")
check("model_based_residency_state" %in% unique(res14_model$analysis$category_proportion_plot_data$indicator_family), "Option 14 plot data did not include Option 7 model-based states")
check(any(grepl("No model-based state plot was added", out12, fixed = TRUE)), "Option 14 without Option 7 did not explain that only literature classifications were plotted")


cat("Test 8: option 10 creates a configuration report path\n")
out10 <- capture.output(res10 <- handle_post_simulation_menu_choice("10", analysis))
check(any(grepl("Full configuration report path:", out10)), "Option 10 did not print a configuration path")
check(!any(grepl("No configuration report path is stored", out10)), "Option 10 still reports no stored configuration path")
check(file.exists(res10$analysis$configuration_report_path), "Option 10 did not create a report file")

cat("Test 9: option 11 computes discovery table before plotting\n")
pdf(NULL)
out11 <- tryCatch(capture.output(res11 <- handle_post_simulation_menu_choice("11", analysis)), finally = try(dev.off(), silent = TRUE))
check(any(grepl("Discovery", out11)), "Option 11 did not print discovery output")


cat("Test 9A: option 12 computes and stores Chao discovery curves on demand\n")
pdf(NULL)
tryCatch({
  out13 <- capture.output(res13 <- handle_post_simulation_menu_choice("12", analysis))
}, finally = try(dev.off(), silent = TRUE))
check(any(grepl("Chao discovery curves were computed on demand", out13)), "Option 12 did not compute Chao discovery curves on demand")
check(!any(grepl("Chao discovery or completeness outputs are not stored", out13)), "Option 12 still reports missing Chao outputs")
check(!is.null(res13$analysis$chao_discovery_curve_table), "Option 12 did not store chao_discovery_curve_table")
check(!is.null(res13$analysis$chao_estimates), "Option 12 did not store chao_estimates")
check(!is.null(res13$analysis$chao_diagnostics), "Option 12 did not store chao_diagnostics")
check(nrow(res13$analysis$chao_discovery_curve_table) == ncol(make_history()), "Option 12 Chao curve does not contain one row per occasion")
check(all(c("S_obs", "Chao1", "Chao2", "Chao1_completeness", "Chao2_completeness") %in% names(res13$analysis$chao_discovery_curve_table)), "Option 12 Chao curve is missing required columns")

cat("Test 9B: option 13 computes and stores Chao completeness curves on demand\n")
pdf(NULL)
tryCatch({
  out14 <- capture.output(res14 <- handle_post_simulation_menu_choice("13", analysis))
}, finally = try(dev.off(), silent = TRUE))
check(any(grepl("Chao sampling-completeness curves were computed on demand", out14)), "Option 13 did not compute Chao completeness curves on demand")
check(!any(grepl("Chao discovery or completeness outputs are not stored", out14)), "Option 13 still reports missing Chao outputs")
check(!is.null(res14$analysis$chao_discovery_curve_table), "Option 13 did not store chao_discovery_curve_table")

cat("Test 9BA: options 12 and 13 keep normal plot behavior but survive tiny graphics devices\n")
check(!any(grepl("Plot cannot be displayed|could not safely render|graphics pane was too small", out13, ignore.case = TRUE)), "Option 12 used the fallback on a normal null PDF graphics device")
check(!any(grepl("Plot cannot be displayed|could not safely render|graphics pane was too small", out14, ignore.case = TRUE)), "Option 13 used the fallback on a normal null PDF graphics device")
small_plot_file_12 <- file.path(tempdir(), "resident_small_option12.png")
grDevices::png(small_plot_file_12, width = 60, height = 45)
tryCatch({
  out12_small <- capture.output(res12_small <- handle_post_simulation_menu_choice("12", analysis))
}, finally = try(grDevices::dev.off(), silent = TRUE))
check(any(grepl("Plot cannot be displayed|full-size Chao discovery|could not safely render|graphics pane was too small", out12_small, ignore.case = TRUE)), "Option 12 did not explain the tiny graphics-device fallback")
check(!is.null(res12_small$analysis$chao_plot_paths), "Option 12 did not store the exported fallback plot path")
check(any(file.exists(unname(res12_small$analysis$chao_plot_paths))), "Option 12 fallback plot file was not created")
small_plot_file_13 <- file.path(tempdir(), "resident_small_option13.png")
grDevices::png(small_plot_file_13, width = 60, height = 45)
tryCatch({
  out13_small <- capture.output(res13_small <- handle_post_simulation_menu_choice("13", analysis))
}, finally = try(grDevices::dev.off(), silent = TRUE))
check(any(grepl("Plot cannot be displayed|full-size Chao sampling|could not safely render|graphics pane was too small", out13_small, ignore.case = TRUE)), "Option 13 did not explain the tiny graphics-device fallback")
check(!is.null(res13_small$analysis$chao_plot_paths), "Option 13 did not store the exported fallback plot path")
check(any(file.exists(unname(res13_small$analysis$chao_plot_paths))), "Option 13 fallback plot file was not created")

cat("Test 9C: option 20 exports Chao plots and tables\n")
out20 <- capture.output(res20 <- handle_post_simulation_menu_choice("20", analysis))
check(any(grepl("Saved Chao outputs", out20)), "Option 20 did not report saved Chao outputs")
check(!is.null(res20$analysis$chao_plot_paths), "Option 20 did not store Chao output paths")
check(all(file.exists(res20$analysis$chao_plot_paths)), "One or more Chao export files do not exist")
cat("Test 10: option 21 does not recurse\n")
out21 <- capture.output(res21 <- handle_post_simulation_menu_choice("21", analysis))
check(any(grepl("Abundance model recommendation and learning guide", out21, fixed = TRUE)), "Option 21 did not print the teaching-guide title")
check(any(grepl("Data snapshot used for model screening", out21, fixed = TRUE)), "Option 21 did not print the data snapshot")
check(any(grepl("First recommended action", out21, fixed = TRUE)), "Option 21 did not print the first recommended action")
check(any(grepl("Assumption teaching checkpoints", out21, fixed = TRUE)), "Option 21 did not print the teaching checkpoints")
check(any(grepl("Complete model cards", out21, fixed = TRUE)), "Option 21 did not print model cards")
check(any(grepl("Next step", out21, fixed = TRUE)), "Option 21 did not print a next-step section")
check(!is.null(res21$analysis$option21_teaching_snapshot), "Option 21 did not store the teaching snapshot")
check(!is.null(res21$analysis$option21_next_step), "Option 21 did not store the next-step guidance")
check(any(grepl("What it estimates", out21)), "Option 21 did not explain what models estimate")
check(any(grepl("Main assumption/caution", out21)), "Option 21 did not print model assumptions or cautions")
check(any(grepl("Data diagnostics used for suitability", out21)), "Option 21 did not print data diagnostics for suitability")
check(any(grepl("Suitability for these data", out21)), "Option 21 did not print model suitability")
check(any(grepl("recommended|acceptable_with_caution|not_recommended|useful_baseline", out21)), "Option 21 did not use readable suitability classes")
check(any(grepl("Assumptions checked against data", out21)), "Option 21 did not explain assumptions checked against the data")
check(any(grepl("Recommendation", out21)), "Option 21 did not print model recommendations")

cat("Test 11: option 22 can return without fitting and does not recurse\n")
provider <- local({ vals <- c("0"); i <- 0L; function(prompt = "") { i <<- i + 1L; vals[min(i, length(vals))] } })
out22 <- capture.output(res22 <- handle_post_simulation_menu_choice("22", analysis, input_provider = provider))
check(any(grepl("Option 22: Select and fit abundance/population model", out22, fixed = TRUE)), "Option 22 did not print the guided fitting title")
check(any(grepl("Data readiness snapshot before fitting", out22, fixed = TRUE)), "Option 22 did not print the data-readiness snapshot")
check(any(grepl("Option 22 model status overview", out22, fixed = TRUE)), "Option 22 did not print the model status overview")
check(any(grepl("Grouped selectable abundance models", out22, fixed = TRUE)), "Option 22 did not show grouped selectable models")
check(any(grepl("CJS / Cormack-Jolly-Seber: not an abundance model", out22, fixed = TRUE)), "Option 22 did not state that CJS is not an abundance model")
check(any(grepl("functional_direct_likelihood|diagnostic_simplified|diagnostic_open_population_summary", out22)), "Option 22 did not show implementation-status labels")
check(!is.null(res22$analysis$option22_model_status), "Option 22 did not store the model-status table")
check(all(c("candidate_model", "model_group", "implementation_status", "comparable_likelihood_group", "student_caution") %in% names(res22$analysis$option22_model_status)), "Option 22 model-status table is missing required columns")
provider_cjs <- local({ vals <- c("CJS"); i <- 0L; function(prompt = "") { i <<- i + 1L; vals[min(i, length(vals))] } })
out22_cjs <- capture.output(res22_cjs <- handle_post_simulation_menu_choice("22", analysis, input_provider = provider_cjs))
check(any(grepl("not selectable in Option 22 because it is not an abundance model", out22_cjs, fixed = TRUE)), "Option 22 did not reject CJS as a non-abundance model")
check(identical(res22_cjs$analysis$last_fit_status$status, "not_abundance_model"), "Option 22 did not store not_abundance_model status for CJS")


cat("Test 12: non-recommended selected model explains assumptions before avoiding fit\n")
provider_bad <- local({ vals <- c("3", "0"); i <- 0L; function(prompt = "") { i <<- i + 1L; vals[min(i, length(vals))] } })
out_bad <- capture.output(res_bad <- handle_post_simulation_menu_choice("22", analysis, input_provider = provider_bad))
check(any(grepl("Selected model suitability before fitting", out_bad)), "Option 22 did not print selected-model suitability before fitting")
check(any(grepl("Assumptions not met or requiring caution", out_bad)), "Option 22 did not explain unmet assumptions for selected model")
check(any(grepl("not recommended|not_recommended|Warning", out_bad, ignore.case = TRUE)), "Option 22 did not warn for a non-recommended model")


cat("Test 13: selected direct models fit without node stack overflow\n")
provider_obs <- local({ vals <- c("1"); i <- 0L; function(prompt = "") { i <<- i + 1L; vals[min(i, length(vals))] } })
out_obs <- capture.output(res_obs <- handle_post_simulation_menu_choice("22", analysis, input_provider = provider_obs))
check(!any(grepl("node stack overflow", out_obs, ignore.case = TRUE)), "observed_only fit still produced node stack overflow")
check(!is.null(res_obs$analysis$abundance_fit), "observed_only did not store abundance_fit")
check(inherits(res_obs$analysis$abundance_fit, "resident_direct_abundance_fit"), "observed_only did not use direct abundance fitter")
check(any(grepl("Abundance estimates", out_obs)), "observed_only did not print abundance estimates")

provider_closed <- local({ vals <- c("3"); i <- 0L; function(prompt = "") { i <<- i + 1L; vals[min(i, length(vals))] } })
out_closed <- capture.output(res_closed <- handle_post_simulation_menu_choice("22", analysis, input_provider = provider_closed))
check(!any(grepl("node stack overflow", out_closed, ignore.case = TRUE)), "closed_M0 fit still produced node stack overflow")
check(!is.null(res_closed$analysis$abundance_fit), "closed_M0 did not store abundance_fit after user confirmed fitting")
check(inherits(res_closed$analysis$abundance_fit, "resident_direct_abundance_fit"), "closed_M0 did not use direct abundance fitter")

cat("Test 14: option 23 and 24 handle missing and fitted models\n")
analysis_no_fit <- make_analysis(occ_default)
out23_missing <- capture.output(handle_post_simulation_menu_choice("23", analysis_no_fit))
out24_missing <- capture.output(handle_post_simulation_menu_choice("24", analysis_no_fit))
check(any(grepl("Use option 22", out23_missing)), "Option 23 did not explain missing fit")
check(any(grepl("Use option 22", out24_missing)), "Option 24 did not explain missing fit")
out23_fit <- capture.output(handle_post_simulation_menu_choice("23", res_obs$analysis))
out24_fit <- capture.output(handle_post_simulation_menu_choice("24", res_obs$analysis))
check(any(grepl("Abundance estimates", out23_fit)), "Option 23 did not show fitted direct abundance estimates")
check(any(grepl("MARK-style parameter table", out24_fit)), "Option 24 did not show fitted direct parameter table")


cat("Test 15: Option 22 stores every implemented abundance model and option 23 retrieves it\n")
occ_fit <- occ_unconfirmed
attr(occ_fit, "real_dates_confirmed") <- TRUE
for (idx in seq_along(implemented_abundance_models())) {
  model <- implemented_abundance_models()[idx]
  temporal_answers <- c("2", "4", "1", "2", "1", "1", "1")
  vals <- if (requires_temporal_structure(model)) c(as.character(idx), temporal_answers) else as.character(idx)
  provider_model <- local({ values <- vals; i <- 0L; function(prompt = "") { i <<- i + 1L; values[min(i, length(values))] } })
  analysis_i <- make_analysis(occ_fit)
  out_fit <- capture.output(res_fit <- handle_post_simulation_menu_choice("22", analysis_i, input_provider = provider_model))
  check(!any(grepl("node stack overflow|evaluation nested too deeply", out_fit, ignore.case = TRUE)), paste("Option 22 recursion error for", model))
  check(!is.null(res_fit$analysis$abundance_fit), paste("Option 22 did not store abundance_fit for", model))
  check(identical(res_fit$analysis$last_fit_status$status, "fit_stored"), paste("last_fit_status was not fit_stored for", model))
  if (requires_temporal_structure(model)) {
    check(any(grepl("How should temporal structure be configured", out_fit)), paste("Temporal grouping prompt was not shown for", model))
    check(any(grepl("What are the primary periods", out_fit)), paste("Primary-period prompt was not shown for", model))
    check(any(grepl("What are the secondary periods", out_fit)), paste("Secondary-period prompt was not shown for", model))
    check(isTRUE(res_fit$analysis$temporal_structure$confirmed), paste("Temporal structure was not confirmed for", model))
  }
  out_retrieve <- capture.output(handle_post_simulation_menu_choice("23", res_fit$analysis))
  check(any(grepl("Abundance estimates", out_retrieve)), paste("Option 23 did not retrieve fitted result for", model))
  check(!any(grepl("No fitted abundance model", out_retrieve)), paste("Option 23 still reported missing fit for", model))
}

cat("Test 16: menu loop preserves fitted analysis object from option 22 to option 23\n")
provider_loop <- local({ vals <- c("22", "1", "23", "29"); i <- 0L; function(prompt = "") { i <<- i + 1L; vals[min(i, length(vals))] } })
out_loop <- capture.output(loop_analysis <- guided_analysis_next_step_menu(make_analysis(occ_fit), input_provider = provider_loop, max_steps = 4L))
check(any(grepl("Abundance estimates", out_loop)), "Menu loop did not display option 23 fitted results after option 22")
check(!is.null(loop_analysis$abundance_fit), "Menu loop return value did not preserve abundance_fit")

cat("Test 17: temporal gate prompts for non-abundance temporal model families\n")
for (model in c("markovian_state", "multistate", "state_space_robust_design", "CJS", "jolly_seber", "POPAN_like")) {
  provider_temporal <- local({ vals <- c("2", "4", "1", "2", "1", "1", "1"); i <- 0L; function(prompt = "") { i <<- i + 1L; vals[min(i, length(vals))] } })
  analysis_t <- make_analysis(occ_fit)
  out_temporal <- capture.output(gate <- temporal_model_gate(analysis = analysis_t, model = model, input_provider = provider_temporal, data_type = "empirical"))
  check(any(grepl("How should temporal structure be configured", out_temporal)), paste("Temporal grouping prompt missing for", model))
  check(any(grepl("What are the primary periods", out_temporal)), paste("Primary-period prompt missing for", model))
  check(any(grepl("What are the secondary periods", out_temporal)), paste("Secondary-period prompt missing for", model))
  check(isTRUE(gate$analysis$temporal_structure$confirmed), paste("Temporal structure not stored for", model))
}

cat("Test 18: active dispatchers preserve the final guided Option 22 implementation\n")
option22_body <- deparse(body(safe_select_and_fit_abundance_model))
check(any(grepl("resident_option22_print_prefit_wizard", option22_body, fixed = TRUE)), "safe_select_and_fit_abundance_model no longer exposes the guided Option 22 wizard")
check(any(grepl("direct_abundance_fit", option22_body, fixed = TRUE)), "safe_select_and_fit_abundance_model no longer calls the direct abundance fitter")
check(any(grepl("analysis$abundance_fit", option22_body, fixed = TRUE)), "safe_select_and_fit_abundance_model no longer stores analysis$abundance_fit")
check(any(grepl("analysis <- handled\\$analysis", deparse(body(guided_analysis_next_step_menu)))), "guided_analysis_next_step_menu does not persist returned analysis")
check(any(grepl("guided_analysis_next_step_menu", deparse(body(run_interactive_analysis_workflow))) & grepl("analysis <-", deparse(body(run_interactive_analysis_workflow)))), "run_interactive_analysis_workflow does not store returned menu analysis")

cat("Test 19: every post-analysis menu option is directly handled without recursion\n")
menu <- post_simulation_menu_definition()
provider_all <- function(prompt = "") {
  if (grepl("abundance model", prompt, ignore.case = TRUE) || grepl("Enter abundance", prompt, ignore.case = TRUE)) return("0")
  ""
}
pdf(NULL)
tryCatch({
  for (opt in menu$option) {
    if (identical(menu$key[menu$option == opt], "finish")) next
    out <- tryCatch(capture.output(handle_post_simulation_menu_choice(as.character(opt), analysis, input_provider = provider_all)),
                    error = function(e) e)
    if (inherits(out, "error")) fail(paste("Menu option", opt, "failed:", conditionMessage(out)))
  }
}, finally = try(dev.off(), silent = TRUE))


cat("Test 20: wide one-row summaries use list display and ordinary tables remain tables\n")
wide_one <- data.frame(alpha_value = 1.23456, beta_value = 2, gamma_value = 3, delta_value = 4,
                       epsilon_value = 5, zeta_value = 6, eta_value = 7, theta_value = 8,
                       interpretation = "This is a long one-row summary that should be readable in the R console.", stringsAsFactors = FALSE)
wide_out <- capture.output(print_console_table(wide_one, title = "Wide test summary"))
check(any(grepl("Wide test summary", wide_out)), "Wide summary title was not printed")
check(any(grepl("Other details", wide_out)) || any(grepl("Interpretation", wide_out)), "Wide summary was not grouped as a list")
check(!any(grepl("alpha_value[[:space:]]*\\|", wide_out)), "Wide one-row summary still printed as a pipe table")
small_tab <- data.frame(model = c("A", "B"), estimate = c(1, 2), stringsAsFactors = FALSE)
small_out <- capture.output(print_console_table(small_tab, title = "Small model table"))
check(any(grepl("model", small_out)) && any(grepl("estimate", small_out)), "Ordinary small table did not print with table headers")


cat("Test 20A: Huesca-style primary classifier recommendation responds to goal and temporal support\n")
rec_residency <- recommend_primary_classifier(res4$analysis, res4$analysis$literature_residency_classification)
check(rec_residency$classifier %in% literature_classifier_labels(), "Recommended residency classifier is not a known literature classifier")
check(length(rec_residency$confidence) == 1 && rec_residency$confidence %in% c("high", "moderate", "low"), "Recommendation confidence is invalid")
analysis_sf <- res4$analysis; analysis_sf$classification_goal <- "site_fidelity"
rec_sf <- recommend_primary_classifier(analysis_sf, res4$analysis$literature_residency_classification)
check(rec_sf$classifier_column %in% c("moller_category", "balmer_category", "diaz_category", "quintana_general"), "Site-fidelity goal did not prioritize site-fidelity/frequency classifiers")
check(any(grepl("site-fidelity", rec_sf$reason, ignore.case = TRUE)), "Site-fidelity recommendation did not explain the goal match")

cat("Test 21: residency menu labels expose literature/site-fidelity flow before model-based output\n")
menu19 <- post_simulation_menu_definition()
check(identical(menu19$key[menu19$option == 4], "detection_review"), "Option 4 is not the model-assumption/detection review key")
check(any(grepl("model-assumption", menu19$label[menu19$option == 4], ignore.case = TRUE)), "Option 4 label does not describe model assumptions")
check(identical(menu19$key[menu19$option == 5], "individual_residency"), "Option 5 is not the literature classification key")
check(any(grepl("site-fidelity", menu19$label[menu19$option == 5], ignore.case = TRUE)), "Option 5 label does not expose site-fidelity classification")
check(identical(menu19$key[menu19$option == 6], "residency_summary"), "Option 6 is not the residency/site-fidelity summary key")
check(any(grepl("site-fidelity class summary", menu19$label[menu19$option == 6], ignore.case = TRUE)), "Option 6 label does not describe the residency/site-fidelity summary")
check(identical(menu19$key[menu19$option == 7], "model_residency"), "Option 7 is not the model-based residency key")
check(any(grepl("model-based", menu19$label[menu19$option == 7], ignore.case = TRUE)), "Option 7 label does not describe model-based output")
check(identical(menu19$key[menu19$option == 12], "plot_chao_discovery"), "Option 12 is not the Chao discovery plot key")
check(identical(menu19$key[menu19$option == 13], "plot_chao_completeness"), "Option 13 is not the Chao completeness plot key")
check(identical(menu19$key[menu19$option == 14], "plot_category"), "Option 14 is not the residency/site-fidelity category plot key")
check(any(grepl("residency and site-fidelity", menu19$label[menu19$option == 14], ignore.case = TRUE)), "Option 14 label does not describe residency and site-fidelity plots")
check(any(grepl("literature-classification", menu19$label[menu19$option == 14], ignore.case = TRUE)), "Option 14 label does not describe literature-classification plots")


cat("Test 22: export menu options 15-20 save all expected files in the run output folder\n")
export_analysis <- res4$analysis
export_dir <- file.path(tempdir(), "resident_export_menu_v096")
dir.create(export_dir, recursive = TRUE, showWarnings = FALSE)
export_analysis$run_output_dir <- export_dir
for (nm in list.files(export_dir, full.names = TRUE)) unlink(nm, recursive = TRUE)
provider_export <- function(prompt = "") ""
for (opt in 15:20) {
  out <- capture.output(res_export <- handle_post_simulation_menu_choice(as.character(opt), export_analysis, input_provider = provider_export))
  export_analysis <- res_export$analysis
  check(any(grepl("Saved", out)) || any(grepl("Saved literature", out)), paste("Export option", opt, "did not report saved output"))
}
expected_fixed <- c(
  "capture_recapture_table.csv",
  "capture_data_summary.csv",
  "discovery_summary.csv",
  "residency_classification_results.csv",
  "model_literature_comparison_status.txt",
  "literature_classifier_summary.csv",
  "literature_residency_classification_full.csv"
)
missing_fixed <- expected_fixed[!file.exists(file.path(export_dir, expected_fixed))]
check(length(missing_fixed) == 0L, paste("Missing export files:", paste(missing_fixed, collapse = ", ")))
chao_files <- list.files(export_dir, pattern = "^chao_.*\\.(csv|jpg|txt)$")
check(length(chao_files) >= 5L, paste("Option 20 did not export all Chao outputs; found", length(chao_files)))
check(!file.exists(file.path("Outputs", "capture_recapture_table.csv")) || normalizePath(dirname(file.path("Outputs", "capture_recapture_table.csv")), mustWork = FALSE) != normalizePath(export_dir, mustWork = FALSE), "Export test unexpectedly conflated root Outputs with run output folder")

cat("All v0.9.41 regression tests passed.\n")
