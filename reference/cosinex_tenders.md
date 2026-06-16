# Scrape + score a cosinex Vergabemarktplatz instance (generic connector)

Shared engine behind
[`vmp_bb_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_tenders.md),
[`vmp_nrw_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_nrw_tenders.md)
and
[`dtvp_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/dtvp_tenders.md):
opens a chromote session, optionally logs in, scrapes the
extended-search results, scores them
([`score_relevance()`](https://kwb-r.github.io/kwb.tenders/reference/score_relevance.md)),
enriches via the detail (and optional notice) layers, applies the
title/CPV exclusions
([`apply_title_excludes()`](https://kwb-r.github.io/kwb.tenders/reference/apply_title_excludes.md))
and tags `Plattform = plattform`. The detail and notice caches are
namespaced by `slug`, so several portals can share one `cache_dir`
without clobbering each other.

## Usage

``` r
cosinex_tenders(
  base_url,
  plattform,
  slug,
  mount = "VMPCenter",
  keywords = tender_keywords(),
  login = FALSE,
  max_pages = Inf,
  since_days = NULL,
  publication_types = c("ExAnte", "Tender"),
  contracting_rules = "VOL",
  screen_details = TRUE,
  max_detail = Inf,
  screen_notice = FALSE,
  max_notice = Inf,
  username = "",
  password = "",
  cache_dir = "reports",
  relevant_only = FALSE,
  headless = TRUE
)
```

## Arguments

- base_url:

  Portal host, e.g. `"https://www.evergabe.nrw.de"`.

- plattform:

  Display name written to the `Plattform` column.

- slug:

  Short id used for the per-portal cache files (e.g. `"vmp_nrw"`).

- mount:

  cosinex mount segment: `"VMPCenter"` (Land marketplaces) or `"Center"`
  (DTVP).

- keywords:

  Keyword list for relevance scoring (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- login:

  Log in before scraping (default `FALSE`; the search is public).

- max_pages:

  Maximum number of result pages to scrape (default `Inf`).

- since_days:

  If set, stop paging once a result page is entirely older than this
  many days (the search is sorted newest-first). Bounds the scrape for
  large portals/award histories; `NULL` scrapes up to `max_pages`. The
  precise date trim happens later in
  [`screen_portals()`](https://kwb-r.github.io/kwb.tenders/reference/screen_portals.md).

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

- relevant_only:

  Return only relevant tenders (default `FALSE`; the combined
  multi-portal run in
  [`screen_all_portals()`](https://kwb-r.github.io/kwb.tenders/reference/screen_all_portals.md)
  sets this `TRUE`).

- headless:

  Run chromote headless (default `TRUE`).

## Value

A scored tibble with a `Plattform` column.

## Examples

``` r
if (FALSE) { # \dontrun{
cosinex_tenders("https://www.evergabe.nrw.de", "Vergabemarktplatz NRW",
                slug = "vmp_nrw", max_pages = 2)
} # }
```
