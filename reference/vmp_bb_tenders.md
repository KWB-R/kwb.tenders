# Scrape + score Vergabemarktplatz Brandenburg (portal connector)

The VMP-BB connector for
[`screen_portals()`](https://kwb-r.github.io/kwb.tenders/reference/screen_portals.md)
/
[`screen_all_portals()`](https://kwb-r.github.io/kwb.tenders/reference/screen_all_portals.md):
opens a chromote session, optionally logs in, scrapes tenders, scores
them
([`score_relevance()`](https://kwb-r.github.io/kwb.tenders/reference/score_relevance.md)),
enriches via the detail and (optional) notice layers, applies the title
exclusions
([`apply_title_excludes()`](https://kwb-r.github.io/kwb.tenders/reference/apply_title_excludes.md))
and tags `Plattform = "Vergabe Brandenburg"`. Returns the scored tibble
(it writes no report); the detail/notice screening caches are
read/written under `cache_dir`.

## Usage

``` r
vmp_bb_tenders(
  keywords = tender_keywords(),
  login = FALSE,
  max_pages = Inf,
  publication_types = c("ExAnte", "Tender"),
  contracting_rules = "VOL",
  screen_details = TRUE,
  max_detail = Inf,
  screen_notice = FALSE,
  max_notice = Inf,
  username = Sys.getenv("VMP_BB_USERNAME"),
  password = Sys.getenv("VMP_BB_PASSWORD"),
  cache_dir = "reports",
  headless = TRUE
)
```

## Arguments

- keywords:

  Keyword list for relevance scoring (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- login:

  Log in before scraping (default `FALSE`; the search is public).

- max_pages:

  Maximum number of result pages to scrape (default `Inf`).

- publication_types, contracting_rules:

  Search filter passed to
  [`vmp_bb_scrape_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_scrape_tenders.md).

- screen_details:

  Detail-page layer (default `TRUE`; see
  [`enrich_with_details()`](https://kwb-r.github.io/kwb.tenders/reference/enrich_with_details.md)).

- max_detail:

  Maximum number of detail pages to screen (default `Inf`).

- screen_notice:

  Notice-PDF layer (default `FALSE`; forces `login = TRUE`; see
  [`enrich_with_notice()`](https://kwb-r.github.io/kwb.tenders/reference/enrich_with_notice.md)).

- max_notice:

  Maximum number of new notice PDFs to read (default `Inf`).

- username, password:

  Credentials when `login = TRUE` (default env vars `VMP_BB_USERNAME` /
  `VMP_BB_PASSWORD`).

- cache_dir:

  Directory for the detail/notice caches (default `"reports"`).

- headless:

  Run chromote headless (default `TRUE`).

## Value

A scored tibble with a `Plattform` column.

## Examples

``` r
if (FALSE) { # \dontrun{
vmp_bb_tenders(max_pages = 2)
} # }
```
