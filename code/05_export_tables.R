# Full-precision CSV behind every model-based table, plus headline values quoted in the text.
# Rounding for presentation happens only in results/tables.xlsx.
tbl <- function(x, name) emit(x, name, dir = table_dir)
z <- metrics$summary
full <- subset(z, mode == "Full pause")
core_global <- subset(full, reference_id == "Global:Demand-IP")
core_au <- subset(full, reference_id == "Australia:BITRE-AES-proxy")

# Table 2: inputs and fixed parameters.
tbl(data.frame(
  parameter = c("Window", "Annual observations", "Australian energy proxy", "AES source period", "AES cell",
                "Model anchor year", "BITRE 2025 activity", "Australian starting CI", "Global EI shape",
                "Logistic inflection year", "Logistic k", "Lifecycle endpoint savings", "Observed-share start proxy",
                "Partial-delay pace", "Fuel mass-equivalent conversion", "Legacy energy scale (Table S5)"),
  value = c("2025-2050", "26", "135.251 PJ", "FY2023-24", "AUS!BA1831",
            "2025 (proxy, not observed calendar 2025)", "7.8762 billion tkme", "73.5 g CO2/MJ", "IP, normalized at 2025",
            "2038", "10", "0.7; 0.8; 0.9", "0.006", "0.5 x reference pace", "44 MJ/kg", "9.43 x 1000 / 70.21 PJ")),
  "Table2_inputs.csv")

# Table 3A-B: main-text diagnostics at 3, 5 and 10 years.
t3 <- list()
for (id in c("Global:Demand-IP", "Australia:BITRE-AES-proxy")) for (d in MARKERS) {
  nc <- subset(full, reference_id == id & delay == d & response == "No catch-up")
  cu <- subset(full, reference_id == id & delay == d & response == "Catch-up")
  k <- if (cu$scale == "Global") 1 else 1000
  t3[[length(t3) + 1L]] <- data.frame(
    scale = cu$scale, delay = d, emissions_unit = cu$emissions_unit, baseline = cu$baseline,
    No_catchup_penalty = nc$penalty, Catchup_penalty = cu$penalty,
    No_catchup_pct_own_baseline = nc$penalty_pct_own_baseline, Catchup_pct_own_baseline = cu$penalty_pct_own_baseline,
    avoided_penalty_share_pct = cu$avoided_penalty_pct, No_catchup_2050_gap_per_year = nc$endpoint_gap,
    required_pace_faster_pct = cu$required_pace_faster_pct,
    peak_supply_addition = cu$peak_supply_increment_Mt_per_year * k,
    reference_peak_supply_addition = cu$reference_peak_Mt_per_year * k,
    peak_supply_unit = if (k == 1) "Mt fuel equivalent/yr added over one-year step" else "kt fuel equivalent/yr added over one-year step",
    peak_year = cu$peak_year)
}
tbl(do.call(rbind, t3), "Table3_diagnostics.csv")

# Supplementary tables.
cfg <- data.frame(reference_id = names(references),
                  scale = vapply(references, function(x) x$scale, character(1)),
                  case = vapply(references, function(x) x$case, character(1)),
                  reference_start_CI = vapply(references, function(x) x$ci[1], numeric(1)),
                  reference_end_CI = vapply(references, function(x) tail(x$ci, 1), numeric(1)))
tbl(cfg, "TableS1_pathway_configurations.csv")
tbl(core_global, "TableS2_global_delay_grid.csv")
tbl(core_au, "TableS3_australia_delay_grid.csv")
tbl(subset(full, scale == "Australia" & case %in% c("BAU", "IP", "AR") & delay %in% MARKERS),
    "TableS4_australia_demand_sensitivity.csv")
s5 <- rbind(subset(core_au, delay %in% c(0, MARKERS)),
            subset(full, reference_id == "Australia:Legacy-scale" & delay %in% c(0, MARKERS)))
s5$energy_anchor_PJ <- ifelse(s5$reference_id == "Australia:Legacy-scale", LEGACY_ENERGY_PJ, AU_ENERGY_PROXY_PJ)
s5$relative_energy_change_pct <- 100 * (s5$energy_anchor_PJ / AU_ENERGY_PROXY_PJ - 1)
tbl(s5, "TableS5_legacy_energy_scale.csv")
tbl(rbind(subset(core_global, delay %in% c(0, MARKERS)), subset(core_au, delay %in% c(0, MARKERS))),
    "TableS6_headline_results.csv")
tbl(rbind(subset(full, family == "Shape" & delay %in% MARKERS), subset(core_global, delay %in% MARKERS)),
    "TableS7_transition_shape.csv")
tbl(analytical, "TableS11_analytical_verification.csv")
tbl(boundary, "TableS12_boundary_checks.csv")

mass <- data.frame(Passenger_mass_kg = c(80, 90, 100))
core_ip_cu <- subset(core_global, response == "Catch-up")
mass$Global_uninterrupted <- core_ip_cu$baseline[1]
for (d in MARKERS) mass[[paste0("Global_catchup_", d, "y")]] <- core_ip_cu$penalty[core_ip_cu$delay == d]
for (i in seq_len(nrow(mass))) {
  m <- mass$Passenger_mass_kg[i]
  q <- subset(full, reference_id == (if (m == 90) "Australia:BITRE-AES-proxy" else paste0("Australia:Mass", m)) &
                response == "Catch-up")
  mass$Australia_uninterrupted[i] <- q$baseline[1]
  for (d in MARKERS) mass[i, paste0("Australia_catchup_", d, "y")] <- q$penalty[q$delay == d]
}
tbl(mass, "TableS13_passenger_mass.csv")

s8 <- lapply(seq_along(cases), function(j) {
  q <- subset(full, reference_id == paste0("Global:", cases[j]) & delay %in% MARKERS)
  q$display_case <- labels[j]; q$OFAT_family <- if (j <= 3) "Demand" else "Efficiency"; q
})
tbl(do.call(rbind, s8), "TableS8_global_OFAT.csv")
tbl(subset(full, family %in% c("Lifecycle endpoint", "Start proxy") & delay %in% MARKERS),
    "TableS9_endpoint_start_sensitivity.csv")
s10 <- subset(z, mode == "Partial delay" & delay %in% MARKERS)
s10$full_pause_penalty <- mapply(function(d, r) core_global$penalty[core_global$delay == d & core_global$response == r],
                                 s10$delay, s10$response)
s10$partial_to_full_penalty_ratio <- s10$penalty / s10$full_pause_penalty
tbl(s10, "TableS10_partial_delay.csv")
tbl(review_gates, "TableS14_review_gates.csv")

# ---------------------------------------------------------------------------
# Headline values quoted in the Abstract and text
# ---------------------------------------------------------------------------
pick <- function(id, d, resp, col) full[full$reference_id == id & full$delay == d & full$response == resp, col]
mm <- aggregate(marginal_penalty ~ reference_id + response,
                subset(full, reference_id %in% c("Global:Demand-IP", "Australia:BITRE-AES-proxy") & delay %in% 1:10), mean)
mmv <- function(id, resp) mm$marginal_penalty[mm$reference_id == id & mm$response == resp]
G <- "Global:Demand-IP"; A <- "Australia:BITRE-AES-proxy"
ep5 <- pick(G, 5, "Catch-up", "penalty")
headline <- data.frame(
  item = c("Global uninterrupted cumulative emissions 2025-2050",
           "Global mean marginal penalty, delays 1-10, catch-up",
           "Global mean marginal penalty, delays 1-10, no catch-up",
           "Global 5-year delay penalty, catch-up",
           "Global 5-year delay penalty, catch-up, share of uninterrupted total",
           "Global 5-year delay penalty, no catch-up",
           "Global 5-year delay avoided-penalty share",
           "Global 5-year delay required pace",
           "Global 5-year delay peak supply addition, catch-up",
           "Global peak supply addition, no delay",
           "Australia uninterrupted cumulative emissions 2025-2050",
           "Australia 5-year delay penalty, catch-up",
           "Australia 5-year delay penalty, no catch-up",
           "Australia mean marginal penalty, delays 1-10, catch-up",
           "Australia mean marginal penalty, delays 1-10, no catch-up",
           "Global 5-year catch-up penalty valued at US$100/t CO2 (undiscounted)",
           "Global 5-year catch-up penalty valued at US$200/t CO2 (undiscounted)",
           "First year overshoot exceeds 5% after 5-year delay, no catch-up",
           "First year overshoot exceeds 5% after 5-year delay, catch-up"),
  value = c(pick(G, 0, "Catch-up", "baseline"), mmv(G, "Catch-up"), mmv(G, "No catch-up"),
            ep5, pick(G, 5, "Catch-up", "penalty_pct_own_baseline"), pick(G, 5, "No catch-up", "penalty"),
            pick(G, 5, "Catch-up", "avoided_penalty_pct"), pick(G, 5, "Catch-up", "required_pace_faster_pct"),
            pick(G, 5, "Catch-up", "peak_supply_increment_Mt_per_year"), pick(G, 0, "Catch-up", "peak_supply_increment_Mt_per_year"),
            pick(A, 0, "Catch-up", "baseline"), pick(A, 5, "Catch-up", "penalty"), pick(A, 5, "No catch-up", "penalty"),
            mmv(A, "Catch-up"), mmv(A, "No catch-up"), ep5 * 100, ep5 * 200,
            first_crossing$first_crossing_year[first_crossing$response == "No catch-up"],
            first_crossing$first_crossing_year[first_crossing$response == "Catch-up"]),
  unit = c("Gt CO2", "Gt CO2 per year of delay", "Gt CO2 per year of delay", "Gt CO2", "%", "Gt CO2", "%",
           "% faster than reference", "Mt fuel equivalent/yr", "Mt fuel equivalent/yr",
           "Mt CO2", "Mt CO2", "Mt CO2", "Mt CO2 per year of delay", "Mt CO2 per year of delay",
           "US$ billion", "US$ billion", "year", "year"),
  where_reported = c("Section 4; Table 3A notes", "Abstract; Section 4; Section 5", "Supporting value", "Abstract; Table 3A",
                     "Abstract; Table 3A", "Table 3A", "Abstract; Table 3A", "Abstract; Table 3B", "Abstract; Table 3B",
                     "Abstract; Table 3B", "Section 4; Table 3A notes", "Abstract; Table 3A", "Table 3A",
                     "Section 4; Section 5", "Supporting value", "Section 4", "Section 4", "Figure 6", "Figure 6"))
emit(headline, "headline_values.csv")
