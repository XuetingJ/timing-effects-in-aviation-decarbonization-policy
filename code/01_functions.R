# Shared definitions: time window, delay operators, metric capture and CSV output.

T0 <- 2025L
TF <- 2050L
TT <- TF - T0                      # 25 transition intervals
YEARS <- T0:TF                     # 26 annual observations
OMEGA <- 0.09                      # tonne-km equivalent per passenger-km
MARKERS <- c(3L, 5L, 10L)          # delays reported in the main text

annual_store <- list(); summary_store <- list(); references <- list()

# Write a CSV with numbers at 15 significant digits; only text columns are quoted.
emit <- function(x, name, dir = out_dir) {
  y <- x
  text_cols <- which(vapply(y, function(v) is.character(v) || is.factor(v), logical(1)))
  for (k in names(y)) if (is.numeric(y[[k]]))
    y[[k]] <- ifelse(is.na(y[[k]]), NA_character_, sprintf("%.15g", y[[k]]))
  write.table(y, file.path(dir, name), sep = ",", row.names = FALSE, col.names = TRUE,
              quote = if (length(text_cols)) text_cols else FALSE, na = "", fileEncoding = "UTF-8")
}

# ---------------------------------------------------------------------------
# Delay operators
# ---------------------------------------------------------------------------

# No catch-up: hold CI at its 2025 value for d intervals, then resume the
# reference pathway shifted by d years. Reaches only reference stage T-d by 2050.
ci_no_catchup <- function(ci_ref, d) {
  vapply(YEARS, function(t) ci_ref[[max(T0, t - d) - T0 + 1L]], numeric(1))
}

# Catch-up: hold CI during the delay, then compress the remaining period onto the
# full reference transition so the 2050 endpoint is recovered. Mapped years are
# generally non-integer: linear interpolation between annual reference nodes.
# Undefined for d >= T.
ci_catchup <- function(ci_ref, d) {
  if (d >= TT) return(rep(NA_real_, length(YEARS)))
  scale <- TT / (TT - d)
  vapply(YEARS, function(t) {
    if (t <= T0 + d) return(ci_ref[[1L]])
    mapped <- min(T0 + (t - T0 - d) * scale, TF)
    lo <- floor(mapped)
    hi <- min(lo + 1, TF)
    frac <- mapped - lo
    ci_ref[[lo - T0 + 1L]] * (1 - frac) + ci_ref[[hi - T0 + 1L]] * frac
  }, numeric(1))
}

interp_nodes <- function(ci, tau) {
  lo <- floor(tau); hi <- pmin(lo + 1, TF); f <- tau - lo
  ci[lo - T0 + 1] * (1 - f) + ci[hi - T0 + 1] * f
}

# Reference clock: the reference-pathway year reached in each calendar year.
clock <- function(d, response, mode = "Full pause") {
  if (response == "Catch-up" && d >= TT) return(rep(NA_real_, length(YEARS)))
  if (mode == "Partial delay") {
    td <- T0 + d / 2
    return(ifelse(YEARS <= T0 + d, T0 + 0.5 * (YEARS - T0),
                  if (response == "Catch-up") td + (TF - td) * (YEARS - T0 - d) / (TT - d) else td + YEARS - T0 - d))
  }
  if (response == "No catch-up") return(pmax(T0, YEARS - d))
  ifelse(YEARS <= T0 + d, T0, pmin(T0 + (YEARS - T0 - d) * (TT / (TT - d)), TF))
}

# ---------------------------------------------------------------------------
# Metric capture for one run (reference pathway x delay x response x mode)
# ---------------------------------------------------------------------------
capture_run <- function(id, scale, case, demand, ei, ref, ci, d, response, base, divisor,
                        mode = "Full pause", family = "Core") {
  rid <- paste(id, mode, d, response, sep = "|")
  Q <- demand * ei / if (scale == "Global") 1000 else 1          # energy, PJ/yr
  er <- demand * ei * ref / divisor
  unit <- if (scale == "Global") "Gt CO2" else "Mt CO2"
  pr <- if (d >= TT) NA_real_ else if (mode == "Partial delay") (TT - d / 2) / (TT - d) else TT / (TT - d)
  meta <- data.frame(reference_id = id, scale = scale, case = case, family = family, mode = mode,
                     delay = d, response = response, emissions_unit = unit, stringsAsFactors = FALSE)
  if (anyNA(ci)) {
    vals <- data.frame(baseline = base, delayed = NA_real_, penalty = NA_real_, penalty_pct_own_baseline = NA_real_,
                       endpoint_gap = NA_real_, endpoint_gap_pct_2025 = NA_real_, required_pace = pr,
                       required_pace_faster_pct = NA_real_, actual_postdelay_pace = NA_real_,
                       peak_supply_increment_Mt_per_year = NA_real_, reference_peak_Mt_per_year = NA_real_,
                       peak_extra_Mt_per_year = NA_real_, peak_year = NA_integer_, peak_years = NA_character_,
                       feasible = FALSE)
  } else {
    e <- demand * ei * ci / divisor
    M <- Q * (1 - ci / CI_FOSSIL) / LHV_MJ_KG; Mr <- Q * (1 - ref / CI_FOSSIL) / LHV_MJ_KG
    dm <- c(NA, diff(M)); dmr <- c(NA, diff(Mr))
    pk <- max(dm, na.rm = TRUE); pkr <- max(dmr, na.rm = TRUE); py <- YEARS[!is.na(dm) & dm == pk]
    pen <- sum(e) - base
    vals <- data.frame(baseline = base, delayed = sum(e), penalty = pen, penalty_pct_own_baseline = 100 * pen / base,
                       endpoint_gap = tail(e - er, 1), endpoint_gap_pct_2025 = 100 * tail(e - er, 1) / er[1],
                       required_pace = pr, required_pace_faster_pct = 100 * (pr - 1),
                       actual_postdelay_pace = if (response == "No catch-up") 1 else pr,
                       peak_supply_increment_Mt_per_year = pk, reference_peak_Mt_per_year = pkr,
                       peak_extra_Mt_per_year = pk - pkr, peak_year = min(py), peak_years = paste(py, collapse = ";"),
                       feasible = TRUE)
    annual_store[[rid]] <<- cbind(meta[rep(1, length(YEARS)), ], data.frame(
      year = YEARS, reference_clock = clock(d, response, mode), demand = demand, energy_intensity = ei,
      energy_PJ_per_year = Q, reference_CI = ref, CI = ci, reference_emissions = er, emissions = e,
      cumulative_reference = cumsum(er), cumulative_emissions = cumsum(e),
      low_carbon_energy_equivalent_PJ_per_year = M * LHV_MJ_KG,
      low_carbon_fuel_mass_equivalent_Mt_per_year = M, annual_supply_increment_Mt_per_year = dm,
      reference_supply_Mt_per_year = Mr, reference_supply_increment_Mt_per_year = dmr))
  }
  summary_store[[rid]] <<- cbind(meta, vals)
  references[[id]] <<- list(demand = demand, ei = ei, ci = ref, scale = scale, case = case, divisor = divisor)
  invisible(NULL)
}

# Full delay grid (d = 0...25, both responses) for a core reference pathway.
run_grid <- function(demand, ei, ci_ref, divisor, case, scale) {
  stopifnot(length(demand) == length(YEARS), length(ei) == length(YEARS), length(ci_ref) == length(YEARS))
  base <- sum(demand * ei * ci_ref / divisor)
  for (d in 0:TT) for (resp in c("No catch-up", "Catch-up")) {
    ci <- if (resp == "No catch-up") ci_no_catchup(ci_ref, d) else ci_catchup(ci_ref, d)
    capture_run(paste(scale, case, sep = ":"), scale, case, demand, ei, ci_ref, ci, d, resp, base, divisor)
  }
}

# Sensitivity variant: selected delays only.
variant <- function(id, case, demand, ei, ci, scale = "Global", family = "Shape", mode = "Full pause",
                    delays = c(0, 2, 3, 4, 5, 9, 10), responses = c("No catch-up", "Catch-up")) {
  div <- if (scale == "Global") 1e9 else 1e3
  base <- sum(demand * ei * ci / div)
  for (d in delays) for (resp in responses) {
    path <- if (mode == "Partial delay") interp_nodes(ci, clock(d, resp, mode))
            else if (resp == "Catch-up") ci_catchup(ci, d) else ci_no_catchup(ci, d)
    capture_run(id, scale, case, demand, ei, ci, path, d, resp, base, div, mode, family)
  }
}

# Marginal penalties and avoided-penalty shares; write the two main result files.
finalize_metrics <- function() {
  z <- do.call(rbind, summary_store); rownames(z) <- NULL
  z$marginal_penalty <- NA_real_; z$avoided_penalty_share <- NA_real_
  for (i in seq_len(nrow(z))) {
    q <- z[i, ]; same <- z$reference_id == q$reference_id & z$mode == q$mode
    prev <- which(same & z$delay == q$delay - 1 & z$response == q$response)
    if (q$delay > 0 && length(prev)) z$marginal_penalty[i] <- q$penalty - z$penalty[prev]
    nc <- which(same & z$delay == q$delay & z$response == "No catch-up")
    cu <- which(same & z$delay == q$delay & z$response == "Catch-up")
    if (q$delay > 0 && length(nc) && length(cu) && is.finite(z$penalty[nc]) && z$penalty[nc] != 0 && is.finite(z$penalty[cu]))
      z$avoided_penalty_share[i] <- 1 - z$penalty[cu] / z$penalty[nc]
  }
  z$avoided_penalty_pct <- 100 * z$avoided_penalty_share
  annual <- do.call(rbind, annual_store); rownames(annual) <- NULL
  emit(z, "diagnostics.csv")
  # Columns derivable from diagnostics.csv (case, family, unit) or by 44 x mass are omitted from the file.
  emit(annual[, setdiff(names(annual), c("case", "family", "emissions_unit",
                                         "low_carbon_energy_equivalent_PJ_per_year"))], "annual_results.csv")
  list(summary = z, annual = annual)
}
