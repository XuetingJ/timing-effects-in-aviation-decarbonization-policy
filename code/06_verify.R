# Internal consistency checks, then comparison of this run with the shipped results/ files.
checks <- list()
check <- function(id, ok) checks[[id]] <<- data.frame(check = id, pass = isTRUE(all(ok, na.rm = FALSE)))
z <- metrics$summary; aout <- metrics$annual

q0 <- subset(aout, reference_id == "Australia:BITRE-AES-proxy" & delay == 0 & response == "Catch-up" & year == 2025)
check("AES_2025_proxy", abs(q0$energy_PJ_per_year - AU_ENERGY_PROXY_PJ) < 1e-12)
check("Australian_start_CI", q0$CI == AU_START_CI)
check("row_counts", nrow(z) == 636 & nrow(aout) == 16302 & sum(z$feasible) == 627)
check("energy_equivalent_bounds", aout$low_carbon_energy_equivalent_PJ_per_year >= -1e-10 &
        aout$low_carbon_energy_equivalent_PJ_per_year <= aout$energy_PJ_per_year + 1e-10)
check("44_PJ_per_Mt", max(abs(aout$low_carbon_energy_equivalent_PJ_per_year - 44 * aout$low_carbon_fuel_mass_equivalent_Mt_per_year)) < 1e-10)
check("catchup_endpoint", abs(subset(z, response == "Catch-up" & feasible)$endpoint_gap) < 1e-10)
check("own_baseline_identity", abs(with(subset(z, feasible), penalty_pct_own_baseline - 100 * penalty / baseline)) < 1e-10)
check("penalty_identity", abs(with(subset(z, feasible), penalty - (delayed - baseline))) < 1e-10)
check("d0_penalty", abs(subset(z, delay == 0)$penalty) < 1e-10)
check("d0_share_undefined", is.na(subset(z, delay == 0)$avoided_penalty_share))
check("d25_catchup_undefined", !subset(z, response == "Catch-up" & delay == 25)$feasible)
check("analytical_errors", max(analytical[, c("Catchup_abs_error", "No_catchup_abs_error", "Endpoint_error")]) < 1e-13)
check("boundary_checks", boundary$Pass)
check("logistic_endpoints_monotone", abs(p_log[1]) < 1e-14 && abs(tail(p_log, 1) - 1) < 1e-14 && all(diff(p_log) >= 0))
for (d in MARKERS) for (resp in c("No catch-up", "Catch-up")) {
  x <- subset(aout, mode == "Partial delay" & delay == d & response == resp)
  check(paste0("partial_clock_", d, "_", resp), x$reference_clock[x$year == 2025 + d] == 2025 + d / 2 && all(diff(x$reference_clock) >= 0))
}
for (id in unique(z$reference_id)) {
  zz <- subset(z, reference_id == id & mode == "Full pause" & feasible)
  for (resp in unique(zz$response)) {
    x <- zz[zz$response == resp, ]; x <- x[order(x$delay), ]
    check(paste0("monotone_penalty_", id, "_", resp), diff(x$penalty) >= -1e-10)
  }
}
for (r in c(0.7, 0.8, 0.9)) {
  lc <- subset(z, reference_id == paste0("Lifecycle:", r) & delay %in% MARKERS)
  ratio <- (ci_g[1] - (1 - r) * CI_FOSSIL) / (ci_g[1] - tail(ci_g, 1))
  expected <- mapply(function(d, resp) subset(z, reference_id == "Global:Demand-IP" & mode == "Full pause" & delay == d & response == resp)$penalty,
                     lc$delay, lc$response)
  check(paste0("lifecycle_amplitude_", r), abs(lc$penalty - expected * ratio) < 1e-10)
}
check("review_strict_pace", review_gates$pace_trigger == (review_gates$required_pace > 1.25))
check("review_2030_equality_not_triggered", !review_gates$pace_trigger[review_gates$year == 2030])
check("review_strict_overshoot", review_gates$NC_overshoot_trigger == (review_gates$overshoot_NC_pct > 5))

# Fresh run versus shipped results (relative tolerance 1e-12).
same_csv <- function(f) {
  a <- read.csv(file.path(project_dir, "results", f), check.names = FALSE)
  b <- read.csv(file.path(out_dir, f), check.names = FALSE)
  if (!identical(dim(a), dim(b)) || !identical(names(a), names(b))) return(FALSE)
  for (k in names(a)) {
    if (is.numeric(a[[k]])) {
      if (!identical(is.na(a[[k]]), is.na(b[[k]]))) return(FALSE)
      ok <- !is.na(a[[k]])
      if (any(abs(a[[k]][ok] - b[[k]][ok]) > 1e-12 * pmax(1, abs(a[[k]][ok])))) return(FALSE)
    } else if (!identical(as.character(a[[k]]), as.character(b[[k]]))) return(FALSE)
  }
  TRUE
}
# Every reference file is required: a missing file fails the check instead of being skipped.
for (f in c("diagnostics.csv", "annual_results.csv", "headline_values.csv")) {
  present <- file.exists(file.path(project_dir, "results", f)) && file.exists(file.path(out_dir, f))
  if (!present) message("Missing required file for comparison: ", f)
  check(paste0("matches_results_", f), present && same_csv(f))
}

# Every model-based table CSV must have been written (Table 4 is descriptive and has none).
expected_tables <- c("Table2_inputs.csv", "Table3_diagnostics.csv", "TableS1_pathway_configurations.csv",
  "TableS2_global_delay_grid.csv", "TableS3_australia_delay_grid.csv", "TableS4_australia_demand_sensitivity.csv",
  "TableS5_legacy_energy_scale.csv", "TableS6_headline_results.csv", "TableS7_transition_shape.csv",
  "TableS8_global_OFAT.csv", "TableS9_endpoint_start_sensitivity.csv", "TableS10_partial_delay.csv",
  "TableS11_analytical_verification.csv", "TableS12_boundary_checks.csv", "TableS13_passenger_mass.csv",
  "TableS14_review_gates.csv")
missing_tables <- expected_tables[!file.exists(file.path(table_dir, expected_tables))]
if (length(missing_tables)) message("Missing table CSVs: ", paste(missing_tables, collapse = ", "))
check("table_csvs_written", length(missing_tables) == 0)

ch <- do.call(rbind, checks); rownames(ch) <- NULL
write.csv(ch, file.path(check_dir, "checks.csv"), row.names = FALSE)
capture.output(sessionInfo(), file = file.path(check_dir, "sessionInfo.txt"))
if (any(!ch$pass)) stop("Verification failed; see output/checks/checks.csv")
message("All ", nrow(ch), " checks passed")
