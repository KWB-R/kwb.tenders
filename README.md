[![R-CMD-check](https://github.com/KWB-R/kwb.tenders/workflows/R-CMD-check/badge.svg)](https://github.com/KWB-R/kwb.tenders/actions?query=workflow%3AR-CMD-check)
[![pkgdown](https://github.com/KWB-R/kwb.tenders/workflows/pkgdown/badge.svg)](https://github.com/KWB-R/kwb.tenders/actions?query=workflow%3Apkgdown)
[![codecov](https://codecov.io/github/KWB-R/kwb.tenders/branch/main/graphs/badge.svg)](https://codecov.io/github/KWB-R/kwb.tenders)
[![Project Status](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![CRAN_Status_Badge](https://www.r-pkg.org/badges/version/kwb.tenders)]()
[![R-Universe_Status_Badge](https://kwb-r.r-universe.dev/badges/kwb.tenders)](https://kwb-r.r-universe.dev/)

# kwb.tenders

Logs into public procurement portals (starting with
Vergabemarktplatz Brandenburg), scrapes published tenders, scores them
for relevance to KWB research topics (e.g. groundwater) and renders an
overview report.

## Installation

For details on how to install KWB-R packages checkout our [installation tutorial](https://kwb-r.github.io/kwb.pkgbuild/articles/install.html).

```r
### Optionally: specify GitHub Personal Access Token (GITHUB_PAT)
### See here why this might be important for you:
### https://kwb-r.github.io/kwb.pkgbuild/articles/install.html#set-your-github_pat

# Sys.setenv(GITHUB_PAT = "mysecret_access_token")

# Install package "remotes" from CRAN
if (! require("remotes")) {
  install.packages("remotes", repos = "https://cloud.r-project.org")
}

# Install KWB package 'kwb.tenders' from GitHub
remotes::install_github("KWB-R/kwb.tenders")
```

## Usage

```r
library(kwb.tenders)

# Credentials via environment variables (e.g. in ~/.Renviron):
#   VMP_BB_USERNAME = "you@example.com"
#   VMP_BB_PASSWORD = "your-password"

# One-shot: log in, scrape, score and write to reports/
check_tenders()                 # headless
check_tenders(headless = FALSE) # watch the browser (debug the login)
```

This writes `reports/vmp-bb_<date>.xlsx` (sheets *Relevant* / *Alle* / *Neu*)
and `reports/latest.md`, flagging tenders that are new since the previous run.
Tenders are scored against **all KWB research groups** (Grundwasser, Energie &
Ressourcen, Regenwasser & Gewässer, Smart City & Infrastruktur, Wasseraufbereitung
& -wiederverwendung, Wasser & Risiko) and tagged with the matching group(s).
Keywords live in `inst/extdata/keywords_<group>.yml` (one file per group, fully
configurable). See `vignette("tutorial")` for details.

## Automated checks (GitHub Actions)

The workflow `.github/workflows/check-tenders.yaml` runs `check_tenders()` on a
schedule (weekdays 05:00 UTC by default) and publishes the report to the
**`gh-pages`** branch under `reports/`:

- Overview: <https://kwb-r.github.io/kwb.tenders/reports/latest.html>
- Excel: `https://kwb-r.github.io/kwb.tenders/reports/vmp-bb_<date>.xlsx`

The public tender search needs **no login**, so no repository secrets are
required. Publishing to `gh-pages` keeps the report out of the `main` history and
browsable on the project site. The Excel file is also kept as a build artifact.

> **Note:** The portal scrape runs in a headless browser on CI (login is
> optional, off by default). If a future logged-in scrape is blocked headless,
> run the workflow on a self-hosted runner instead.

## Documentation

Release: [https://kwb-r.github.io/kwb.tenders](https://kwb-r.github.io/kwb.tenders)

Development: [https://kwb-r.github.io/kwb.tenders/dev](https://kwb-r.github.io/kwb.tenders/dev)
