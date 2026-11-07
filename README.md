# econ5560-replication-GielSchroeder

Replication package for ECON 5560. It reproduces the experimental-auction (Tobit) willingness-to-pay estimates in Table 6 of Wei, Khachatryan and Rihn (2021) from the authors' raw data.

## Paper

Wei, X., Khachatryan, H., & Rihn, A. (2021). Estimating willingness-to-pay for neonicotinoid-free plants: Incorporating pro-environmental behavior in hypothetical and non-hypothetical experiments. *PLoS ONE*, 16(5), e0251798. https://doi.org/10.1371/journal.pone.0251798

## Data

The data come from the Harvard Dataverse archive that the paper's Data Availability Statement points to: https://doi.org/10.7910/DVN/XCG1N8. Our team downloaded it on September 23, 2026. The file in `data/` is exactly as downloaded, with no edits.

The archive also contains `CE_combined_sample.xls`, the discrete choice experiment data. It is not included here. Our code does not use it, because we replicated only the auction results, and at 30 MB it is larger than GitHub's web upload limit.

## How to run

You need R (version 4.6.1 was used) and the `readxl` package. Download the repository with the green **Code** button (either `git clone https://github.com/gielschroder1-ship-it/econ5560-replication-GielSchroeder.git` or **Download ZIP** and unzip it), then from a terminal inside the repository folder run:

```
Rscript -e 'install.packages("readxl", repos="https://cloud.r-project.org")'
Rscript run_all.R > logs/run_log.txt 2>&1
```

The script must be run from the repository's top folder, because it uses relative paths (`data/`, `outputs/`). If you prefer RStudio, restart R, set the working directory to the repository folder with Session → Set Working Directory → Choose Directory, and run `system("Rscript run_all.R > logs/run_log.txt 2>&1")` in the console. The script creates `outputs/` and `logs/` if they are missing.

## Files

- `run_all.R` — the master script; loads the data, estimates the Tobit model and the WTP for each subgroup, and writes the table to `outputs/`.
- `data/SPA_combined_sample.xls` — the second-price auction data from Harvard Dataverse, unmodified.
- `outputs/table6_tobit_wtp.csv` — our replicated Table 6 (WTP mean, significance stars, standard error) as a CSV.
- `outputs/table6_tobit_wtp.tex` — the same table as a LaTeX tabular.
- `logs/run_log.txt` — the full log of a clean run from a freshly downloaded copy of this repository, ending with `sessionInfo()`.
- `paper/tobit_recreation_table_092926.tex` — a hand-made LaTeX table from our team write-up that puts the paper's original numbers beside ours. It is not produced by the code, and its replication numbers come from an earlier version of the script, so a few standard errors differ slightly from `outputs/`; the files in `outputs/` are the authoritative results.

## Software

R 4.6.1 (2026-06-24) on macOS (aarch64-apple-darwin23). Packages: `readxl` 1.6.0, plus base R `stats`. `readxl` also loaded cellranger 1.1.0, tibble 3.3.1, cli 3.6.6, rlang 1.3.0, vctrs 0.7.3, pillar 1.11.1, glue 1.8.1, lifecycle 1.0.5, magrittr 2.0.5 and pkgconfig 2.0.3. The full `sessionInfo()` output is at the end of `logs/run_log.txt`.

## Run time

About half a second on a MacBook Air (Apple silicon). The log records 0.54 seconds.

## What does not work or did not replicate

The point estimates replicate closely, but our standard errors do not. For the full sample, the paper reports WTP of 0.250 (SE 0.079) for the neonicotinoid-free text label, 0.489 (0.087) for the logo, and −0.099 (0.085) for the treated label; we get 0.208 (0.146), 0.455 (0.157) and −0.122 (0.160). The subgroup results follow the same pattern: signs and magnitudes are similar, but our standard errors are roughly 1.3 to 2.1 times larger (usually about 1.8 times), so many of the paper's significance stars do not appear in our table (for example, the paper's text-label WTP for the regulation-agree group is 0.512***, and ours is 0.415*).

We believe the gap comes from choices the paper does not fully document:

1. We omitted the between-individual random effect (the Cᵢ term in equation 2), because the paper does not explain how it is estimated. Our model is a pooled Tobit.
2. We used a dummy variable for each plant code rather than the paper's plant-type attributes, because the data did not include a dictionary mapping plant codes to types.
3. We computed WTP standard errors with the delta method and a numerical gradient, and significance with two-sided normal z-tests; the paper does not say how it computed either.
4. For the labeling-importance subgroups, we dropped respondents with a missing `att_importance` value.

The team's original script also had a data path that only existed on one teammate's computer (`C:/Users/...`) and did not save its results to a file. Both were fixed in `run_all.R`.

## Use of AI

We used AI tools to help write the Tobit log-likelihood, and Claude to restructure the script into a single master `run_all.R` with relative paths and saved outputs, to walk through the GitHub upload and fresh-copy test, and to draft this README. All results come from running the code.
