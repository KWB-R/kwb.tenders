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
  since_days = 30,
  vmp_bb_contracting_rules = "VOL",
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

- since_days:

  Unified look-back window in days, applied to every portal by
  publication date (default `30`): the API connectors fetch this many
  days and a final filter trims all sources (incl. VMP-BB) to the same
  window.

- vmp_bb_contracting_rules:

  VMP-BB procurement regulations (Vergabeart), default `"VOL"` (VgV /
  VOL/A / UVgO; excludes VOB/Bau). See
  [`vmp_bb_scrape_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_scrape_tenders.md)
  for other values. The API portals have no such filter (construction is
  excluded there via the CPV-45 veto).

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
