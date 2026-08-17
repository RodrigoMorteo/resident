# Resident Pipeline v0.9.41
## Synopsis
The Resident Pipeline is a standalone, interactive R-based tool for the analysis of animal capture-recapture data. It is designed for researchers in ecology and wildlife biology to import, summarize, and model encounter histories to estimate population parameters. The pipeline focuses on assessing population abundance, residency patterns, and site fidelity using a variety of established and modern statistical methods.

The tool features an interactive menu-driven workflow, guiding the user from data import and validation through to model fitting, diagnostics, and result exportation.

# Features
- **Interactive Workflow:** A menu-based system guides users through the analysis steps.
- **Flexible Data Import:** Supports multiple common formats from wildlife ecology, including:
  - Program MARK (`.txt`)
  - SOCPROG (long format `.txt`/.`csv`)
  - Wide CSV capture histories
  - Original Program MARK (`.inp`)
  - Microsoft Excel (`.xlsx`) workbooks
* **Data Summarization:** Provides comprehensive summaries of capture data, discovery rates, and data readiness for modeling.
- **Residency & Site-Fidelity:** Implements a suite of literature-based classifiers (e.g., Huesca et al. 2024, Balmer, Díaz, etc.) to categorize individuals.
- **Abundance Modeling**:
  - Guided model selection wizard (Option 22) to help choose appropriate models based on data characteristics.
  - Fits a variety of closed-capture models (M0, Mt, Mb, Mh), Huggins models, and robust-design models.
  - Includes descriptive richness estimators like Chao1 and Chao2.
- **Model-Based State Estimation:** Fits state-space models to estimate individual residency states (e.g., Resident, Transient).
- **Diagnostics & Comparison:**
  - Audits data against key model assumptions (e.g., population closure).
  - Compares model-based residency states against literature-based classifications.
- **Visualization:** Generates plots for discovery curves, Chao estimates, and residency category proportions.
- **Reproducibility:** Standalone script and detailed configuration reports to ensure analyses are reproducible.

## System Requirements
- **R:** A recent version of R is required.
- **R Packages:**
  - `TMB`: Required for fitting custom statistical models. This package requires a C++ compiler.
  - `readxl` (optional): Recommended for importing data from Microsoft Excel files. If not installed, a base-R fallback is used for simple .xlsx files.
- **C++ Compiler:** TMB compiles C++ code on the fly, so a working C++ compiler (like g++ on Linux or the tools provided by Rtools on Windows) must be installed and accessible to R.

## Installation and Setup
1. **Clone the repository or download the files**.
2. **Set the R working directory** to the project's root folder.
3. **Compile the TMB C++ model**: The pipeline uses a C++ backend for efficient model fitting. Compile it from within R:
```R
# Make sure your R session has a working C++ compiler configured
install.packages("TMB") # If not already installed
TMB::compile("Outputs/resident_tmb_v0.9.41.cpp")
dyn.load(TMB::dynlib("Outputs/resident_tmb_v0.9.41"))
```

4. **Install Optional Dependencies** (recommended):
```R
install.packages("readxl")
```
## How to Use
Load and run the pipeline interactively in R:

```R
# Set your working directory to the folder containing the pipeline files
# setwd("/path/to/your/project")

# Load the pipeline with the interactive menu
options(resident_pipeline.autostart = TRUE)
source("Outputs/resident_pipeline_v0.9.41.R")
```

This will load the pipeline and present an interactive menu in the R console. You can then select options to import data, run summaries, fit models, and export results. The pipeline guides you through the process, starting with data import (Option 1).

### Linux Setup
On Ubuntu or Debian systems, install the R runtime and the C++ toolchain required by the TMB model backend:

```bash
sudo apt-get update
sudo apt-get install -y build-essential g++ gcc r-base r-base-dev
```

If you want to import Excel workbooks, install the system libraries often required by R packages such as `readxl`:

```bash
sudo apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev
```

Then install the R packages needed by the pipeline:

```bash
Rscript -e 'install.packages(c("TMB", "readxl"), repos = "https://cloud.r-project.org/")'
```

Once the packages are installed, compile the TMB model from the project root folder:

```bash
Rscript -e 'TMB::compile("Outputs/resident_tmb_v0.9.41.cpp"); dyn.load(TMB::dynlib("Outputs/resident_tmb_v0.9.41"))'
```

This is the standard Linux setup needed before running the pipeline.

> Note: the project now resolves paths relative to the repository root and is repo-path agnostic. The verification command can be run from the project root without changing directories:
>
> ```bash
> cd /path/to/your/project
> Rscript -e 'options(resident_pipeline.autostart = FALSE); source("Outputs/resident_pipeline_v0.9.41.R"); source("Outputs/test_resident_pipeline_v0.9.41.R")'
> ```
>
> This was fixed so the pipeline no longer depends on a specific working-directory layout.

## Example Workflow
1. Start the pipeline as shown above.
2. Choose **Option 1** to import data. You can select `AUTO` (Option 3) to let the pipeline detect your file format. Example data and template files are provided in the `input/` directory.
3. Choose **Option 2** to view the "Capture data summary".
4. Choose **Option 3** to view the "Discovery summary".
5. Choose **Option 22** to enter the "Select and fit abundance/population model" wizard. Follow the prompts to select and fit an appropriate model for your data.
6. Choose Option 23 to view the results of the fitted model.
7. Choose an option from the "Exports" section (e.g., **Option 15**) to save your results.
8. Choose "Finish" to exit the workflow.

## Input Data Formats
The pipeline automatically detects and imports several common formats. Use **Option 1** and choose `AUTO` for automatic detection.

* `PROGRAM_MARK`: Text file with `id` and `encounter_history` columns.
* `SOCPROG`: Long-format sighting file with `id` and `date` columns.
* `WIDE_CSV`: A matrix with an `id` column followed by 0/1 columns for each sampling occasion.
* `MARK_INP`: Original Program MARK `.inp` file format.
* `EXCEL`: A workbook with data in either `WIDE_CSV` or `SOCPROG` format.
For detailed specifications and examples, please refer to the templates generated by the pipeline (select Option 4 within the import menu) or the example files in `input/`.

## Testing
A comprehensive regression test suite is included to verify the pipeline's functionality. The project is repo-path agnostic, so the tests can be run from the repository root without adjusting the working directory.

```bash
cd /path/to/your/project
Rscript -e 'options(resident_pipeline.autostart = FALSE); source("Outputs/resident_pipeline_v0.9.41.R"); source("Outputs/test_resident_pipeline_v0.9.41.R")'
```

If you prefer to run the code in R directly:

```R
# Set the working directory to the project root
setwd("/path/to/your/project")

# Load the pipeline without the interactive menu
options(resident_pipeline.autostart = FALSE)
source("Outputs/resident_pipeline_v0.9.41.R")

# Run the test suite
source("Outputs/test_resident_pipeline_v0.9.41.R")
```

A successful run will print "All v0.9.41 regression tests passed." to the console.

> If the test script ever stops with `Required dependency not found: resident_pipeline_v0.9.41.R`, the fix is to ensure the project root is the current working directory or use the repo-root command above.

## Repository Hygiene
This repository is configured for a public Git hosting workflow while keeping local analysis artifacts out of version control.

The project ignores generated and machine-specific files such as:
- R session state (`.RData`, `.Rhistory`, `.Rproj.user`)
- compiled binaries and shared libraries (`.o`, `.so`, `.dll`, `.dylib`)
- temporary files and OS metadata (`.log`, `.tmp`, `.swp`, `.DS_Store`)
- generated run outputs like the local `outputs/` directory and test output folders under `Outputs/test_v0.9.41/`

The tracked source files remain in the repo, including the standalone pipeline script and tests in `Outputs/`.

## Scientific Context and Limitations
This pipeline is a powerful tool for population analysis but has limitations that users should understand. As of `v0.9.41`:

 * The implemented likelihoods are not yet full Program MARK-equivalent likelihoods for all model families.
 * Full Huggins conditional likelihoods, full robust-design likelihoods, and full Jolly-Seber/POPAN likelihoods are not yet implemented.
The interface labels the current outputs as "diagnostic" where appropriate so they are not mistaken for final, comparable likelihood inference.
Users should carefully review the model assumptions and diagnostic outputs to ensure the chosen models are appropriate for their data and research questions.

## How to Cite
If you use this software in your research, please cite it. We recommend citing both the software directly (using the Zenodo DOI) and any associated publications.

* **Software**: [Placeholder for Zenodo DOI badge]
* **Publication**: [Placeholder for publication citation once available]

## License
This project is licensed under the MIT License.

## Contributing
We welcome contributions and feedback from the community. Please feel free to open an issue on the GitHub repository to:

* Report a bug
* Suggest a new feature
* Ask a question about the software

