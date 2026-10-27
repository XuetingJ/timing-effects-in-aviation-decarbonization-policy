# Code and data: Evaluating timing effects in aviation decarbonization policy

Companion package for **"Evaluating timing effects in aviation decarbonization policy: Cumulative emissions and catch-up pressure from delayed fuel transitions."**

Authors: Xueting Jiang, Raymundo Marcos-Martinez, Walter Okelo and Aditi Mankad (CSIRO). Contact: xueting.jiang@csiro.au.

Status: supplementary material for a manuscript submitted to *Transportation Research Part A: Policy and Practice* (Special Issue: Recent Advances in Air Transport Policies), 2026. The full article citation will be added on publication.

Repository: https://github.com/XuetingJ/timing-effects-in-aviation-decarbonization-policy. The same package is also supplied as a supplementary file with the manuscript.

Licence: Creative Commons Attribution 4.0 International (CC BY 4.0), covering both code and data. Third-party source data remain subject to their original terms; see Inputs below.

## Contents

```
data/       model inputs (compact extracts of the published sources)
code/       R model (base R only) and Python figure script
results/    shipped outputs: every table and figure value in the paper
```

| File | What it holds |
|---|---|
| `results/tables.xlsx` | Tables 2–4 and S1–S14 exactly as printed (presentation rounding), one sheet per table. Supplied as shipped; the code does not regenerate this workbook |
| `results/figure_data.xlsx` | Data plotted in Figures 2–6 and S1–S3, one sheet per panel |
| `results/headline_values.csv` | Full-precision values behind the numbers quoted in the Abstract and text |
| `results/diagnostics.csv` | One row per model run (636 runs): cumulative penalty, endpoint gap, required pace, peak supply addition, marginal penalty, avoided-penalty share |
| `results/annual_results.csv` | Annual 2025–2050 trajectories for every feasible run (627 runs × 26 years) |

Figure 1 is a conceptual schematic and has no underlying data.

## Reproduce

Requirements: R ≥ 4.0 using base R only, tested with R 4.3.3. The figures need Python ≥ 3.10 with the packages in `code/requirements.txt`. Run all commands from the package root.

```bash
Rscript code/run_analysis.R      # about 5 s; writes output/ and checks it against results/
pip install -r code/requirements.txt
python3 code/make_figures.py     # after an R run: output/figure_data.xlsx and output/figures/; without R: figures/
```

`run_analysis.R` writes `output/diagnostics.csv`, `output/annual_results.csv`, `output/headline_values.csv`, a full-precision CSV for each model-based table in `output/tables/` (Tables 2, 3 and S1–S14; Tables 3A and 3B share one CSV, as do each S-table's A and B panels; Table 4 is descriptive and has no CSV), and `output/checks/checks.csv` (70 consistency checks, including a match against `results/` and a check that every table CSV was written). Any missing reference file fails verification. Without R, `make_figures.py` redraws the figures from `results/figure_data.xlsx` and writes them to `figures/` in the package root.

## Inputs (`data/`)

| File | Source |
|---|---|
| `global_pathways_2025_2050.csv` | Annual global demand (passenger, freight, total; BAU/IP/AR), energy intensity (BAU/IP/AR) and net-zero fuel carbon intensity, from Bergero et al. (2023), *Nature Sustainability*, doi:10.1038/s41893-022-01046-9 |
| `bitre_domestic_aviation_2025_2050.csv` | Australian domestic passenger-km and freight tonne-km, annualized from BITRE (2024), *Australian aviation forecasts—2024 to 2050*, Research Report 157. Combined demand = freight + 0.09 × passenger-km |
| `aes_table_f_extract.csv` | Cells used from DCCEEW (2025), *Australian Energy Statistics*, Table F: Australian energy consumption, by state and territory, by industry and fuel type, energy units (August 2025 release): FY2023–24 domestic air transport energy, 135.251 PJ |
| `australia_demand_pathways_2025_2050.csv` | Harmonized Australian BAU, IP and AR demand in billion tonne-km equivalent, used only in Table S4 and Figure S2 (columns `Dtot_BAU_au`, `Dtot_IP_au` and `Dtot_AR_au`). These are the authors' own derivation, built as Australian counterparts to the Bergero et al. (2023) BAU, IP and AR demand assumptions. They are not a published projection and are separate from the BITRE central case. The columns were exported from the authors' working file (`Australia.xlsx`, Sheet1), which is not included. 2025 levels: 6.83 (BAU), 6.76 (IP) and 6.71 (AR). 2050 levels: 18.22, 13.82 and 7.53. The BAU series is a constant 0.630% share of global BAU demand. |

The FY2023–24 AES energy observation is assigned to model year 2025 as a start-year proxy, with BITRE projected activity (7.8762 billion tonne-km equivalent). Their ratio is a calibration proxy, not an observed commercial-aviation energy intensity. The harmonized BAU, IP and AR cases use the same energy-intensity and carbon-intensity paths but keep their own demand levels. Their 2025 energy use is therefore not re-anchored to 135.251 PJ.

## Definitions and units

- **Runs** are identified by `reference_id` × `mode` × `delay` × `response`. `reference_id` names the reference pathway (for example `Global:Demand-IP`, the central global case, and `Australia:BITRE-AES-proxy`, the Australian central case). `mode` is `Full pause` or `Partial delay` (half pace). `response` is `No catch-up` or `Catch-up`.
- **Units.** Global demand: million tonne-km equivalent. Australian demand: billion tonne-km equivalent. Energy intensity: PJ per billion tonne-km equivalent. Fuel carbon intensity (CI): g CO₂ MJ⁻¹. Emissions: Gt CO₂ for global runs and Mt CO₂ for Australian runs (column `emissions_unit` in `diagnostics.csv`).
- **Cumulative emissions** sum 26 annual observations, 2025–2050. **Penalty** = delayed cumulative emissions − matched uninterrupted reference (`baseline`). **Marginal penalty** = EP(d) − EP(d−1). **Avoided-penalty share** = 1 − EP_CU / EP_NC.
- **Required pace** = 25/(25 − d) for a full pause and (25 − d/2)/(25 − d) for the half-pace partial delay; `required_pace_faster_pct` = 100 × (pace − 1). Catch-up is undefined at d = 25 (`feasible = FALSE`).
- **Low-carbon-fuel equivalent.** Energy L = Q × (1 − CI/73.5) PJ yr⁻¹; mass equivalent = L/44 Mt yr⁻¹ at 44 MJ kg⁻¹. **Peak supply addition** is the largest year-on-year increase in the mass equivalent. These are accounting equivalents, not physical SAF production volumes or feasibility limits.
- **Review gates** (Figure 6, Table S14): overshoot = cumulative emissions to date above the reference; recovery starts from the no-catch-up history at each gate. Signals are illustrative: overshoot > 5.0% and required pace > 25.0% faster (equality does not trigger).
- Numbers in the CSV files carry 15 significant digits; empty cells are undefined values.
