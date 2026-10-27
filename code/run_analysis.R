# Reproduce every numerical result in the paper and Supplementary Material.
#
#   Rscript code/run_analysis.R          (run from the package root; base R only)
#
# Results are written to output/. The shipped results/ folder is never modified;
# the final step checks that the fresh run matches it.

args <- commandArgs(trailingOnly = FALSE)
hit <- grep("^--file=", args, value = TRUE)
code_dir <- if (length(hit)) {
  dirname(normalizePath(sub("^--file=", "", hit[1])))
} else if (file.exists("run_analysis.R")) {
  normalizePath(".")
} else {
  normalizePath("code")
}
project_dir <- dirname(code_dir)
input_dir   <- file.path(project_dir, "data")
out_dir     <- file.path(project_dir, "output")
table_dir   <- file.path(out_dir, "tables")
check_dir   <- file.path(out_dir, "checks")
for (d in c(out_dir, table_dir, check_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
options(stringsAsFactors = FALSE)

old_wd <- setwd(code_dir)
on.exit(setwd(old_wd), add = TRUE)

source("parameters.R")
source("01_functions.R")      # delay clocks, metric capture, CSV writer
source("02_core_model.R")     # global and Australian delay grids (d = 0...25)
source("03_sensitivities.R")  # shape, energy-scale, passenger-mass, endpoint, start, partial delay; S11-S12 checks
metrics <- finalize_metrics() # marginal penalties, avoided shares; writes annual_results.csv and diagnostics.csv
source("04_review_gates.R")   # Figure 6 / Table S14 review gates
source("05_export_tables.R")  # full-precision CSV for every table; headline_values.csv
source("06_verify.R")         # internal identities and comparison with results/

message("Done. Outputs in ", out_dir)
