# Check Vergabemarktplatz Brandenburg for relevant tenders

End-to-end pipeline: open a chromote session, (optionally) log in,
scrape all tenders, score them for relevance and write the overview
report. This is the function called by the scheduled GitHub Action.

## Usage

``` r
check_tenders(
  dir = "reports",
  headless = TRUE,
  login = FALSE,
  max_pages = Inf,
  publication_types = c("ExAnte", "Tender"),
  contracting_rules = "VOL",
  screen_details = TRUE,
  max_detail = Inf,
  username = Sys.getenv("VMP_BB_USERNAME"),
  password = Sys.getenv("VMP_BB_PASSWORD"),
  keywords = tender_keywords()
)
```

## Arguments

- dir:

  Output directory for the report (default `"reports"`).

- headless:

  Kept for API compatibility (chromote runs headless).

- login:

  Log in before scraping (default `FALSE`; the search is public).

- max_pages:

  Maximum number of result pages to scrape (default `Inf`).

- publication_types, contracting_rules:

  Search filter passed to
  [`vmp_bb_scrape_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_scrape_tenders.md).
  Defaults to Beabsichtigte Ausschreibung + Ausschreibung
  (`c("ExAnte", "Tender")`) and VgV / VOL/A / UVgO (`"VOL"`).

- screen_details:

  Second relevance layer: fetch each ongoing tender's public detail page
  and match its full text + CPV codes (default `TRUE`). See
  [`enrich_with_details()`](https://kwb-r.github.io/kwb.tenders/reference/enrich_with_details.md).

- max_detail:

  Maximum number of detail pages to screen (default `Inf`).

- username, password:

  Credentials used when `login = TRUE` (default env vars
  `VMP_BB_USERNAME` / `VMP_BB_PASSWORD`).

- keywords:

  Keyword list for relevance scoring (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

## Value

Invisibly, the scored tibble of all tenders.

## Details

The public tender search works **without** login, so `login = FALSE` by
default. Set `login = TRUE` once you have valid credentials.

## Examples

``` r
if (FALSE) { # \dontrun{
check_tenders() # public search, all pages
check_tenders(max_pages = 2) # quick test
} # }
```
