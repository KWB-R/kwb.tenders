# Screen TED (Tenders Electronic Daily) for relevant tenders

Login-free EU connector. Full-text queries `terms` (German water terms)
restricted to `countries`, fetches matching notices and scores them with
[`score_layered()`](https://kwb-r.github.io/kwb.tenders/reference/score_layered.md).
Returns relevant tenders with a `Plattform` column.

## Usage

``` r
ted_tenders(
  keywords = tender_keywords(),
  cpv_map = tender_cpv_map(),
  terms = ted_default_terms(),
  countries = "DEU",
  since_days = 90,
  scope = "ACTIVE",
  max_pages = 5,
  page_size = 100,
  relevant_only = TRUE,
  verbose = TRUE
)
```

## Arguments

- keywords:

  Keyword groups (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- cpv_map:

  CPV-to-group map (default
  [`tender_cpv_map()`](https://kwb-r.github.io/kwb.tenders/reference/tender_cpv_map.md)).

- terms:

  Full-text query terms (default: a built-in water-term set).

- countries:

  Place-of-performance country codes (default `"DEU"`;
  `NULL`/[`character()`](https://rdrr.io/r/base/character.html) for
  EU-wide).

- since_days:

  Only notices published within the last N days (default `90`, via TED
  `today(-N)`); `NULL` to disable. Past-deadline notices are dropped
  too.

- scope:

  Notice scope (`"ACTIVE"`, `"ALL"`, `"LATEST"`; default `"ACTIVE"`).

- max_pages, page_size:

  Pagination caps (default `5` x `100`).

- relevant_only:

  Keep only relevant tenders (default `TRUE`).

- verbose:

  Print progress (default `TRUE`).

## Value

A scored tibble of (relevant) tenders; empty data frame if none.

## Examples

``` r
if (FALSE) { # \dontrun{
ted_tenders(max_pages = 1)
} # }
```
