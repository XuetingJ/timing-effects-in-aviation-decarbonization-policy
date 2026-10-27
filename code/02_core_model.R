# Core delay grids for the global pathway (Bergero et al., 2023) and the Australian application.
#
# Units
#   Global    : demand million tkme, EI PJ/(billion tkme), CI g CO2/MJ  -> Gt CO2 = D * EI * CI / 1e9
#   Australia : demand billion tkme, EI PJ/(billion tkme), CI g CO2/MJ  -> Mt CO2 = D * EI * CI / 1e3
# The AES FY2023-24 domestic energy observation is used explicitly as a model-2025 proxy;
# the commercial/general-aviation boundary crosswalk is incomplete (Supplementary S3).

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------
gl_all <- read.csv(file.path(input_dir, "global_pathways_2025_2050.csv"), check.names = FALSE)
au_all <- read.csv(file.path(input_dir, "australia_demand_pathways_2025_2050.csv"), check.names = FALSE)
bit    <- read.csv(file.path(input_dir, "bitre_domestic_aviation_2025_2050.csv"), check.names = FALSE)
aes    <- read.csv(file.path(input_dir, "aes_table_f_extract.csv"), colClasses = "character")

g <- gl_all[gl_all$Year >= T0 & gl_all$Year <= TF, ]; g <- g[order(g$Year), ]
a <- au_all[au_all$Year >= T0 & au_all$Year <= TF, ]; a <- a[order(a$Year), ]
stopifnot(nrow(g) == length(YEARS), nrow(a) == length(YEARS), nrow(bit) == length(YEARS))
d_bitre <- as.numeric(bit$Combined_demand_billion_tonne_km_eq)

# ---------------------------------------------------------------------------
# Global cases: central Demand-IP, demand variants (BAU, AR) and energy-intensity variants
# ---------------------------------------------------------------------------
ci_g <- g$f_NZ_global
for (cs in c("BAU", "IP", "AR"))
  run_grid(g[[paste0("Dtot_", cs, "_global")]], g$e_IP_global, ci_g, 1e9, paste0("Demand-", cs), "Global")
for (cs in c("BAU", "AR"))
  run_grid(g$Dtot_IP_global, g[[paste0("e_", cs, "_global")]], ci_g, 1e9, paste0("EI-", cs), "Global")

# ---------------------------------------------------------------------------
# Australian central case (BITRE activity, AES energy proxy) and harmonized demand variants
# ---------------------------------------------------------------------------
aes_cell <- function(cell) aes$value[match(cell, aes$cell)]
stopifnot(as.numeric(aes_cell("BA1831")) == AU_ENERGY_PROXY_PJ,
          aes_cell("BA6") == AU_SOURCE_FY,
          aes_cell("BA7") == "PJ",
          aes_cell("B1785") == "Of which domestic air transport",
          abs(d_bitre[1] - AU_DENOMINATOR_2025) < 1e-12)
p_ref  <- (ci_g[1] - ci_g) / (ci_g[1] - tail(ci_g, 1))          # source reference progress, 0 -> 1
ci_a   <- AU_START_CI - (AU_START_CI - tail(ci_g, 1)) * p_ref
ei_corr <- AU_ENERGY_PROXY_PJ / AU_DENOMINATOR_2025 * g$e_IP_global / g$e_IP_global[1]
run_grid(d_bitre, ei_corr, ci_a, 1e3, "BITRE-AES-proxy", "Australia")

# Harmonized BAU/IP/AR demand (Table S4, Figure S2), same energy- and carbon-intensity paths.
for (cs in c("BAU", "IP", "AR"))
  run_grid(a[[paste0("Dtot_", cs, "_au")]], ei_corr, ci_a, 1e3, cs, "Australia")

# Case order and labels for the one-factor-at-a-time comparison (Figure 5, Table S8).
cases  <- c("Demand-BAU", "Demand-IP", "Demand-AR", "EI-BAU", "Demand-IP", "EI-AR")
labels <- c("Demand-BAU", "Demand-IP", "Demand-AR", "EI-BAU", "EI-IP", "EI-AR")
