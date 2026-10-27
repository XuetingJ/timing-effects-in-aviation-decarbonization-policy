# Fixed inputs used in the published analysis (see Table 2 and Supplementary S3-S7).
AU_ENERGY_PROXY_PJ      <- 135.251              # AES 2025 Table F, AUS!BA1831: FY2023-24 domestic air transport energy (PJ), used as model-2025 proxy
AU_SOURCE_FY            <- "2023-24"
AU_MODEL_ANCHOR_YEAR    <- 2025L
AU_DENOMINATOR_2025     <- 7.8762               # BITRE 2025 combined activity (billion tonne-km equivalent)
AU_START_CI             <- 73.5                 # Australian starting fuel carbon intensity (g CO2/MJ)
LOGISTIC_INFLECTION_YEAR <- 2038                # logistic transition-shape sensitivity (Figure S3)
LOGISTIC_K              <- 10
CI_FOSSIL               <- 73.5                 # fossil jet-fuel reference intensity (g CO2/MJ) in the fuel-equivalent conversion
LHV_MJ_KG               <- 44                   # fuel mass-equivalent conversion (MJ/kg)
LEGACY_ENERGY_PJ        <- 9.43 * 1000 / 70.21  # legacy energy-scale sensitivity (Table S5)
