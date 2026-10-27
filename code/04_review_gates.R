# Five-year review-gate diagnostics (Figure 6, Table S14). Illustrative signals; no policy optimization.
z <- metrics$summary; annual <- metrics$annual
review <- subset(annual, reference_id == "Global:Demand-IP" & mode == "Full pause" & delay == 5)
review$overshoot <- review$cumulative_emissions - review$cumulative_reference
review$overshoot_pct <- 100 * review$overshoot / review$cumulative_reference
review$overshoot_trigger <- review$overshoot_pct > 5

first_crossing <- do.call(rbind, lapply(c("No catch-up", "Catch-up"), function(resp) {
  x <- subset(review, response == resp); cross <- x$year[x$overshoot_trigger]
  data.frame(response = resp, first_crossing_year = if (length(cross)) min(cross) else NA_integer_)
}))

gates <- list()
for (gate in c(2030, 2035, 2040)) {
  nc <- subset(review, response == "No catch-up" & year == gate)
  cu <- subset(review, response == "Catch-up" & year == gate)
  # Recovery starts from the no-catch-up history at the gate and restores the 2050 endpoint.
  tau_nc <- gate - 5; pace <- (TF - tau_nc) / (TF - gate)
  tau <- ifelse(YEARS <= gate, pmax(T0, YEARS - 5), tau_nc + (TF - tau_nc) * (YEARS - gate) / (TF - gate))
  ci <- interp_nodes(ci_g, tau); Q <- g$Dtot_IP_global * g$e_IP_global / 1000
  M <- Q * (1 - ci / CI_FOSSIL) / LHV_MJ_KG; Mr <- Q * (1 - ci_g / CI_FOSSIL) / LHV_MJ_KG
  dm <- c(NA, diff(M)); dr <- c(NA, diff(Mr)); ix <- YEARS > gate
  pk <- max(dm[ix]); pr <- max(dr[ix])
  flags <- c(if (nc$overshoot_pct > 5) "Overshoot", if (pace > 1.25) "Pace")
  gates[[as.character(gate)]] <- data.frame(
    year = gate, overshoot_CU_Gt = cu$overshoot, overshoot_CU_pct = cu$overshoot_pct,
    overshoot_NC_Gt = nc$overshoot, overshoot_NC_pct = nc$overshoot_pct,
    required_pace = pace, required_pace_faster_pct = 100 * (pace - 1),
    review_peak_Mt_per_year = pk, reference_peak_remaining_Mt_per_year = pr, peak_extra_Mt_per_year = pk - pr,
    review_peak_year = min(YEARS[ix][dm[ix] == pk]), review_peak_years = paste(YEARS[ix][dm[ix] == pk], collapse = ";"),
    NC_overshoot_trigger = nc$overshoot_pct > 5, CU_overshoot_trigger = cu$overshoot_pct > 5,
    pace_trigger = pace > 1.25, trigger = if (length(flags)) paste(flags, collapse = " + ") else "None")
}
review_gates <- do.call(rbind, gates); rownames(review_gates) <- NULL
