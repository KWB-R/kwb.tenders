# Screen all configured portals into one combined report

Convenience entry point (used by the scheduled GitHub Action): wires the
built-in connectors – Vergabemarktplatz Brandenburg
([`vmp_bb_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_tenders.md)),
the federal Datenservice
([`oeffentlichevergabe_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/oeffentlichevergabe_tenders.md))
and TED
([`ted_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/ted_tenders.md))
– and runs them through
[`screen_portals()`](https://kwb-r.github.io/kwb.tenders/reference/screen_portals.md).
Only VMP-BB can use a login; the API portals are login-free, and a
portal that fails is skipped (the others still produce the report).

## Usage

``` r
screen_all_portals(
  dir = "reports",
  vmp_bb = TRUE,
  oeffentlichevergabe = TRUE,
  ted = TRUE,
  vmp_bb_login = FALSE,
  vmp_bb_notice = FALSE,
  oeffentlichevergabe_days = 8,
  ted_since_days = 90,
  keywords = tender_keywords(),
  verbose = TRUE
)
```

## Arguments

- dir:

  Output directory (default `"reports"`).

- vmp_bb, oeffentlichevergabe, ted:

  Enable each source (all `TRUE`).

- vmp_bb_login, vmp_bb_notice:

  Log in / read notice PDFs for VMP-BB (default `FALSE`; need `VMP_BB_*`
  secrets).

- oeffentlichevergabe_days:

  Days of OCDS notices to fetch (default `8`).

- ted_since_days:

  TED look-back window in days (default `90`).

- keywords:

  Keyword groups (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- verbose:

  Print progress (default `TRUE`).

## Value

Invisibly, the combined scored tibble.

## Examples

``` r
if (FALSE) { # \dontrun{
screen_all_portals(vmp_bb_login = TRUE, vmp_bb_notice = TRUE)
} # }
```
