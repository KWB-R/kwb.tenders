# Summarise all CPV codes found across the tenders

Aggregates the CPV codes collected by
[`enrich_with_details()`](https://kwb-r.github.io/kwb.tenders/reference/enrich_with_details.md)
into a table: one row per code, the number of tenders it appears in, and
the KWB research group(s) it maps to. Useful as an extra "CPV" sheet in
the Excel report.

## Usage

``` r
cpv_summary(tenders, cpv_map = tender_cpv_map(), keywords = tender_keywords())
```

## Arguments

- tenders:

  A tibble with a `cpv` column (comma-separated CPV codes).

- cpv_map:

  CPV-to-group mapping (default
  [`tender_cpv_map()`](https://kwb-r.github.io/kwb.tenders/reference/tender_cpv_map.md)).

- keywords:

  Keyword groups, for group display names (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

## Value

A data.frame with columns `cpv`, `n_tenders`, `groups`, sorted by
descending frequency.

## Examples

``` r
cpv_summary(data.frame(cpv = c("71351910-5, 90733000", "71351910-5")))
#>          cpv n_tenders                              groups
#> 1 71351910-5         2                         Grundwasser
#> 2   90733000         1 Regenwasser & Gewässer, Grundwasser
```
