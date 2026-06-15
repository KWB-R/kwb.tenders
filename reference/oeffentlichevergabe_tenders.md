# Screen the Datenservice Oeffentlicher Einkauf (oeffentlichevergabe.de)

Login-free connector: downloads the OCDS notice export for the last
`days` days, parses each notice and scores it with
[`score_layered()`](https://kwb-r.github.io/kwb.tenders/reference/score_layered.md)
(title full rule, description strong-only, CPV mapped). Returns relevant
tenders with a `Plattform` column, ready for
[`combine_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/combine_tenders.md)
/
[`write_tender_report()`](https://kwb-r.github.io/kwb.tenders/reference/write_tender_report.md).

## Usage

``` r
oeffentlichevergabe_tenders(
  keywords = tender_keywords(),
  cpv_map = tender_cpv_map(),
  days = 7,
  end = Sys.Date(),
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

- days:

  Number of past days to fetch (default `7`; the API serves data up to
  the previous day).

- end:

  Most recent date to consider (default
  [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html)).

- relevant_only:

  Keep only relevant tenders (default `TRUE`).

- verbose:

  Print per-day progress (default `TRUE`).

## Value

A scored tibble of (relevant) tenders; empty data frame if none.

## Examples

``` r
if (FALSE) { # \dontrun{
oeffentlichevergabe_tenders(days = 3)
} # }
```
