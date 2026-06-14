# tutorial

``` r

library(kwb.tenders)
```

## Overview

`kwb.tenders` automates checking German public procurement portals
(“Vergabeportale”) for tenders relevant to KWB research topics. The
first supported portal is **Vergabemarktplatz Brandenburg** (VMP-BB).

Pipeline: open a browser → scrape all published tenders → score them for
relevance (groundwater keywords) → write an Excel + Markdown report that
flags what is new since the previous run. The browser is driven directly
via `chromote` (headless), which works locally and on headless CI
runners.

## One-shot run

``` r

check_tenders()                  # public search, all pages
check_tenders(max_pages = 2)     # quick test (first 2 pages)
```

This writes `reports/vmp-bb_<date>.xlsx` (sheets *Relevant* / *Alle* /
*Neu*) and `reports/latest.md`.

## Login is optional

The public tender search returns results **without** logging in, so
[`check_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/check_tenders.md)
does not log in by default. If you have valid credentials and want to
log in (env vars `VMP_BB_USERNAME` / `VMP_BB_PASSWORD`, e.g. in
`~/.Renviron`):

``` r

check_tenders(login = TRUE)
```

## Step by step

``` r

session <- vmp_bb_session()
# vmp_bb_login(session)                       # optional
tenders <- vmp_bb_scrape_tenders(session, max_pages = 2)

scored <- score_relevance(tenders)
write_tender_report(scored)

session$close()
# session$view()   # open a live view of the headless session in your browser
```

## Research groups & keywords

Tenders are scored against **all KWB research groups** and each relevant
tender is tagged (column `groups`) with the matching group(s). The
keyword lists live in `inst/extdata/keywords_<slug>.yml` – one file per
group, each with a display `name` and `strong` / `supporting` vectors. A
tender matches a group if it contains at least one `strong` keyword OR
at least two `supporting` keywords, and is relevant if it matches at
least one group. Matching is case-insensitive and folds umlauts (so
“Klärschlamm” and “Klaerschlamm” both match).

``` r

kw <- tender_keywords()
names(kw)        # the research-group slugs
str(kw$groundwater)

# Score against a custom subset (e.g. only two groups):
scored <- score_relevance(tenders, keywords = kw[c("groundwater", "water-risk")])
```

Edit the `inst/extdata/keywords_<slug>.yml` files to tune the keywords,
or add a new file to add a group – no code change needed.

## Automation (GitHub Actions)

The workflow `.github/workflows/check-tenders.yaml` runs
[`check_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/check_tenders.md)
on a schedule (weekdays, 05:00 UTC by default), commits the updated
report to the repository and uploads the Excel file as a build artifact.
Change the `cron:` expression to adjust the frequency.
