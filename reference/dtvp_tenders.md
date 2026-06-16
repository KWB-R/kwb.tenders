# Deutsches Vergabeportal (DTVP) connector (cosinex)

Thin wrapper around
[`cosinex_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/cosinex_tenders.md)
for the Deutsches Vergabeportal (`dtvp.de`). DTVP uses the `"Center"`
mount; its published search is login-free (registration is only needed
to submit bids).

## Usage

``` r
dtvp_tenders(keywords = tender_keywords(), ...)
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

A scored tibble with `Plattform = "Deutsches Vergabeportal (DTVP)"`.

## Examples

``` r
if (FALSE) { # \dontrun{
dtvp_tenders(max_pages = 2)
} # }
```
