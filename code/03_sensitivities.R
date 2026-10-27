# Sensitivities (Tables S5, S7, S9, S10, S13; Figure S3) and analytical checks (Tables S11, S12).

# Transition shape (Table S7, Figure S3): same 2025 and 2050 intensities, different timing.
u <- (YEARS - T0) / TT
shapes <- list("Front-loaded" = ci_g[1] - (ci_g[1] - tail(ci_g, 1)) * u^0.5,
               "Linear"       = ci_g[1] - (ci_g[1] - tail(ci_g, 1)) * u,
               "Back-loaded"  = ci_g[1] - (ci_g[1] - tail(ci_g, 1)) * u^2)
lambda <- function(s) 1 / (1 + exp(-LOGISTIC_K * (s - (LOGISTIC_INFLECTION_YEAR - T0) / TT)))
p_log <- (lambda(u) - lambda(0)) / (lambda(1) - lambda(0))
shapes[["Logistic"]] <- ci_g[1] - (ci_g[1] - tail(ci_g, 1)) * p_log
for (nm in names(shapes))
  variant(paste0("Shape:", nm), nm, g$Dtot_IP_global, g$e_IP_global, shapes[[nm]], family = "Shape")

# Legacy energy scale (Table S5): changes the Australian energy scale only.
variant("Australia:Legacy-scale", "Legacy energy-scale sensitivity", d_bitre,
        ei_corr * (LEGACY_ENERGY_PJ / AU_ENERGY_PROXY_PJ), ci_a, scale = "Australia", family = "Legacy energy-scale")

# Passenger mass (Table S13). Globally, re-harmonizing demand and energy intensity together leaves
# emissions exactly unchanged, so the global rows equal the central case. Australian variants keep
# the 135.251 PJ start-year proxy.
source_Q_global <- gl_all$Dtot_IP_global * gl_all$e_IP_global
for (omega in c(0.08, 0.10)) {
  d_g_all <- gl_all$Df_IP_global + 1000 * omega * gl_all$Dp_IP_global
  ei_g_omega <- source_Q_global / d_g_all
  d_bit_omega <- bit$Freight_billion_tonne_km + omega * bit$Passenger_RPK_billion
  ei_au_omega <- AU_ENERGY_PROXY_PJ / d_bit_omega[1] * ei_g_omega / ei_g_omega[1]
  variant(paste0("Australia:Mass", omega * 1000), paste0("Passenger mass ", omega * 1000, " kg"),
          d_bit_omega, ei_au_omega, ci_a, scale = "Australia", family = "Passenger mass")
}

# Lifecycle endpoint savings and observed-share starting point (Table S9).
for (r in c(0.7, 0.8, 0.9)) {
  ci_lc <- ci_g[1] - (ci_g[1] - (1 - r) * CI_FOSSIL) * p_ref
  variant(paste0("Lifecycle:", r), paste0(round(100 * r), "% endpoint saving"),
          g$Dtot_IP_global, g$e_IP_global, ci_lc, family = "Lifecycle endpoint")
}
ci_obs <- CI_FOSSIL * (1 - 0.006) - (CI_FOSSIL * (1 - 0.006) - tail(ci_g, 1)) * p_ref
variant("Start-proxy:0.006", "0.6% start proxy", g$Dtot_IP_global, g$e_IP_global, ci_obs, family = "Start proxy")

# Half-pace partial delay (Table S10).
variant("Global:Demand-IP", "Demand-IP", g$Dtot_IP_global, g$e_IP_global, ci_g,
        family = "Partial delay", mode = "Partial delay")

# ---------------------------------------------------------------------------
# Closed-form benchmark (Table S11) and boundary checks (Table S12)
# ---------------------------------------------------------------------------
bench_ci <- seq(1, 0, length.out = length(YEARS))
bench_base <- sum(bench_ci)
analytical <- do.call(rbind, lapply(0:(TT - 1), function(d) {
  cu <- ci_catchup(bench_ci, d); nc <- ci_no_catchup(bench_ci, d)
  cu_num <- sum(cu) - bench_base; nc_num <- sum(nc) - bench_base
  cu_an <- d / 2; nc_an <- d - d * (d - 1) / (2 * TT)
  data.frame(Delay = d, Catchup_analytic = cu_an, Catchup_numeric = cu_num,
             Catchup_abs_error = abs(cu_num - cu_an),
             No_catchup_analytic = nc_an, No_catchup_numeric = nc_num,
             No_catchup_abs_error = abs(nc_num - nc_an),
             Endpoint_error = abs(tail(cu, 1) - tail(bench_ci, 1)), Required_pace_ratio = TT / (TT - d))
}))
boundary <- data.frame(
  Check = c("d = 0 catch-up penalty is zero", "d = 0 no-catch-up penalty is zero",
            "d = 0 required pace is one", "d = 24 catch-up reaches endpoint",
            "d = 24 required pace is 25", "d = 25 catch-up is undefined",
            "Catch-up penalty is monotonic for d = 0...24",
            "No-catch-up penalty is monotonic for d = 0...25"),
  Pass = c(abs(analytical$Catchup_numeric[1]) < 1e-12,
           abs(analytical$No_catchup_numeric[1]) < 1e-12,
           abs(analytical$Required_pace_ratio[1] - 1) < 1e-12,
           abs(tail(ci_catchup(bench_ci, 24), 1)) < 1e-12,
           abs(TT / (TT - 24) - 25) < 1e-12,
           all(is.na(ci_catchup(bench_ci, 25))),
           all(diff(analytical$Catchup_numeric) >= -1e-12),
           all(diff(vapply(0:TT, function(d) sum(ci_no_catchup(bench_ci, d)) - bench_base, numeric(1))) >= -1e-12)))
