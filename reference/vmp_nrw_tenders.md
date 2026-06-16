# Vergabemarktplatz NRW connector (cosinex)

Thin wrapper around
[`cosinex_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/cosinex_tenders.md)
for Vergabemarktplatz NRW (`evergabe.nrw.de`). The published search is
login-free.

## Usage

``` r
vmp_nrw_tenders(keywords = tender_keywords(), ...)
```

## Arguments

- keywords:

  Keyword groups (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- ...:

  Further arguments passed to
  [`cosinex_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/cosinex_tenders.md)
  (e.g. `login`, `publication_types`, `contracting_rules`, `since_days`,
  `max_pages`, `cache_dir`, `relevant_only`).

## Value

A scored tibble with `Plattform = "Vergabemarktplatz NRW"`.

## Examples

``` r
if (FALSE) { # \dontrun{
vmp_nrw_tenders(max_pages = 2)
} # }
```
