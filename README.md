[![R-CMD-check](https://github.com/KWB-R/kwb.tenders/workflows/R-CMD-check/badge.svg)](https://github.com/KWB-R/kwb.tenders/actions?query=workflow%3AR-CMD-check)
[![pkgdown](https://github.com/KWB-R/kwb.tenders/workflows/pkgdown/badge.svg)](https://github.com/KWB-R/kwb.tenders/actions?query=workflow%3Apkgdown)
[![codecov](https://codecov.io/github/KWB-R/kwb.tenders/branch/main/graphs/badge.svg)](https://codecov.io/github/KWB-R/kwb.tenders)
[![Project Status](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![CRAN_Status_Badge](https://www.r-pkg.org/badges/version/kwb.tenders)]()
[![R-Universe_Status_Badge](https://kwb-r.r-universe.dev/badges/kwb.tenders)](https://kwb-r.r-universe.dev/)

# kwb.tenders

Screens several public procurement portals for tenders relevant to KWB research
topics (e.g. groundwater), scores them and renders one combined overview report.
See [Covered portals](#covered-portals) below.

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

## Covered portals

`screen_all_portals()` queries nine sources by default and writes one combined
report:

| Portal | Connector | Access |
|---|---|---|
| Datenservice Öffentlicher Einkauf (Bund + Länder + Kommunen) | `oeffentlichevergabe_tenders()` | OCDS API, login-free |
| Deutsche eVergabe (deutsche-evergabe.de) | `deutsche_evergabe_tenders()` | Healy Hudson; chromote render, login-free |
| Deutsches Vergabeportal (DTVP) | `dtvp_tenders()` | cosinex; login-free |
| e-Vergabe des Bundes (evergabe-online.de) | `evergabe_online_tenders()` | HTTP/Wicket, login-free; below-threshold federal/Land/Kommunal notices not in the Datenservice |
| Serviceportal des Bundes (service.bund.de) | `servicebund_tenders()` | RSS, login-free; Bund/Länder/Kommunen, adds notices not in the Datenservice |
| TED (EU) | `ted_tenders()` | TED v3 API, login-free |
| Vergabemarktplatz Brandenburg | `vmp_bb_tenders()` | cosinex; login-free (optional login) |
| Vergabemarktplatz NRW | `vmp_nrw_tenders()` | cosinex; login-free (optional login) |
| Vergabeplattform Berlin | `berlin_tenders()` | berlin.de / iTWO; HTTP, login-free |

**e-Vergabe des Bundes (evergabe-online.de):** its *above-threshold* (EU) notices
already flow into the *Datenservice* and TED (covered above), but its
*below-threshold* national notices are **not** in the Datenservice (verified: 0/10
of the latest hits), so the connector adds genuine coverage — federal water bodies
(Wasserstraßen- und Schifffahrtsverwaltung, Umweltbundesamt, Bundesanstalt für
Wasserbau) plus Länder/Kommunal water and wastewater associations. Login-free, but
driven by an Apache-Wicket scrape (full-text search batched over the KWB keywords,
title-based scoring); set `screen_all_portals(evergabe_online = FALSE)` to skip it.

**Deutsche eVergabe (deutsche-evergabe.de):** a Healy-Hudson portal whose public
dashboard is a DevExpress grid with no API/RSS, so the connector renders it with
**chromote** (already used by the cosinex connectors). It searches the grid per
keyword (`searchByText`) across all three dashboard categories — current tenders,
Vorinformationen (planned) and Zuschlagsbekanntmachungen (awarded) — and enriches
relevant hits via the login-free per-tender detail endpoint (Vergabestelle /
Publikationsdatum / Angebotsfrist / CPV). On by default; the three-category render
roughly triples its runtime, so `screen_all_portals(deutsche_evergabe = FALSE)`
skips it and `deutsche_evergabe_tenders(status = "aktuell")` limits it to current
notices only.

### Coverage by notice type

Every connector tags each notice as one of three publication types; the report
groups them into three sections (English column header / German report label):
**Planned** (*Geplante Ausschreibung* / Vorinformation) → **Current**
(*Ausschreibung*) → **Awarded** (*Vergebener Auftrag*).

| Portal | Planned | Current | Awarded |
|---|:--:|:--:|:--:|
| Datenservice Öffentlicher Einkauf (Bund) | ✅ | ✅ | ✅ |
| Deutsche eVergabe (deutsche-evergabe.de) | ✅ | ✅ | ✅ |
| Deutsches Vergabeportal (DTVP) | ✅ | ✅ | ✅ |
| e-Vergabe des Bundes (evergabe-online.de) | ✅ | ✅ | ❌ ² |
| Serviceportal des Bundes (service.bund.de) | ✅ ¹ | ✅ | ✅ |
| TED (EU) | ✅ | ✅ | ✅ |
| Vergabemarktplatz Brandenburg | ✅ | ✅ | ✅ |
| Vergabemarktplatz NRW | ✅ | ✅ | ✅ |
| Vergabeplattform Berlin | ✅ | ✅ | ✅ |

✅ = the connector emits that type when the source carries it. The cosinex portals
(Brandenburg / NRW / DTVP) actively query all three (`publication_types =
ExAnte/Tender/ExPost`); Datenservice, TED and Berlin map it from the source's own
notice tags; deutsche-evergabe switches the dashboard category (current /
Vorinformation / Zuschlag).

¹ service.bund.de has no separate planned feed, but forward-looking notices
("Beabsichtigte Vergabe …", "Vorinformation …", ex-ante "Transparenzbekanntmachung")
arrive inside the Ausschreibungen feed and are re-tagged *geplant* by title.

² evergabe-online.de's login-free simple search has no notice-type/status filter and
no separate award listing, so awarded notices are not reachable there — federal
awards still arrive via TED and the Datenservice.

## Automated checks (GitHub Actions)

The workflow `.github/workflows/check-tenders.yaml` runs `screen_all_portals()`
on a schedule (weekdays 03:00 UTC by default) and publishes the report to the
**`gh-pages`** branch under `reports/`:

- Overview (sortable / filterable table): <https://kwb-r.github.io/kwb.tenders/reports/latest.html>
- Excel: `https://kwb-r.github.io/kwb.tenders/reports/tenders_<date>.xlsx`

The public tender search needs **no login**, so no repository secrets are
required. Publishing to `gh-pages` keeps the report out of the `main` history and
browsable on the project site. The Excel file is also kept as a build artifact.

> **Note:** The portal scrape runs in a headless browser on CI (login is
> optional, off by default). If a future logged-in scrape is blocked headless,
> run the workflow on a self-hosted runner instead.

## Documentation

Release: [https://kwb-r.github.io/kwb.tenders](https://kwb-r.github.io/kwb.tenders)

Development: [https://kwb-r.github.io/kwb.tenders/dev](https://kwb-r.github.io/kwb.tenders/dev)
