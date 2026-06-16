# Vergabemarktplatz NRW connector (cosinex)

Thin wrapper around
[`cosinex_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/cosinex_tenders.md)
for Vergabemarktplatz NRW (`evergabe.nrw.de`). The published search is
login-free; an optional login (`login = TRUE`, or `screen_notice = TRUE`
for the Bekanntmachung-PDF layer) uses the same cosinex Keycloak flow as
Brandenburg and needs an NRW account.

## Usage

``` r
vmp_nrw_tenders(
  keywords = tender_keywords(),
  username = Sys.getenv("VMP_NRW_USERNAME"),
  password = Sys.getenv("VMP_NRW_PASSWORD"),
  ...
)
```

## Arguments

- keywords:

  Keyword groups (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- username, password:

  NRW credentials for the optional login (default env vars
  `VMP_NRW_USERNAME` / `VMP_NRW_PASSWORD`).

- ...:

  Further arguments passed to
  [`cosinex_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/cosinex_tenders.md)
  (e.g. `login`, `screen_notice`, `publication_types`,
  `contracting_rules`, `since_days`, `max_pages`, `cache_dir`,
  `relevant_only`).

## Value

A scored tibble with `Plattform = "Vergabemarktplatz NRW"`.

## Examples

``` r
if (FALSE) { # \dontrun{
vmp_nrw_tenders(max_pages = 2)
} # }
```
