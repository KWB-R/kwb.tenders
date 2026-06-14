[![R-CMD-check](https://github.com/KWB-R/kwb.tenders/workflows/R-CMD-check/badge.svg)](https://github.com/KWB-R/kwb.tenders/actions?query=workflow%3AR-CMD-check)
[![pkgdown](https://github.com/KWB-R/kwb.tenders/workflows/pkgdown/badge.svg)](https://github.com/KWB-R/kwb.tenders/actions?query=workflow%3Apkgdown)
[![codecov](https://codecov.io/github/KWB-R/kwb.tenders/branch/main/graphs/badge.svg)](https://codecov.io/github/KWB-R/kwb.tenders)
[![Project Status](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![CRAN_Status_Badge](https://www.r-pkg.org/badges/version/kwb.tenders)]()
[![R-Universe_Status_Badge](https://kwb-r.r-universe.dev/badges/kwb.tenders)](https://kwb-r.r-universe.dev/)

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
