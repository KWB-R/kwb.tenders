# Screen all configured portals into one combined report

Convenience entry point (used by the scheduled GitHub Action): wires the
built-in connectors – the cosinex marketplaces Vergabemarktplatz
Brandenburg
([`vmp_bb_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_tenders.md)),
Vergabemarktplatz NRW
([`vmp_nrw_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_nrw_tenders.md))
and DTVP
([`dtvp_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/dtvp_tenders.md)),
Vergabeplattform Berlin
([`berlin_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/berlin_tenders.md)),
the federal Datenservice
([`oeffentlichevergabe_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/oeffentlichevergabe_tenders.md)),
TED
([`ted_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/ted_tenders.md))
and the service portal
([`servicebund_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/servicebund_tenders.md))
– and runs them through
[`screen_portals()`](https://kwb-r.github.io/kwb.tenders/reference/screen_portals.md).
The searches are login-free (only VMP-BB optionally logs in for the
notice layer), and a portal that fails is skipped (the others still
produce the report).

## Usage

``` r
screen_all_portals(
  dir = "reports",
  vmp_bb = TRUE,
  nrw = TRUE,
  dtvp = TRUE,
  berlin = TRUE,
  oeffentlichevergabe = TRUE,
  ted = TRUE,
  servicebund = TRUE,
  evergabe_online = TRUE,
  vmp_bb_login = FALSE,
  vmp_bb_notice = FALSE,
  nrw_login = FALSE,
  nrw_notice = FALSE,
  since_days = 30,
  cosinex_contracting_rules = "VOL",
  keywords = tender_keywords(),
  verbose = TRUE
)
```

## Arguments

- dir:

  Output directory (default `"reports"`).

- vmp_bb, nrw, dtvp, berlin, oeffentlichevergabe, ted, servicebund:

  Enable each source (all `TRUE`).

- evergabe_online:

  Enable the evergabe-online.de connector (default `TRUE`; login-free
  Wicket scrape,
  [`evergabe_online_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/evergabe_online_tenders.md)).
  Adds below-threshold federal/Land/Kommunal notices not in the
  Datenservice.

- vmp_bb_login, vmp_bb_notice:

  Log in / read notice PDFs for VMP-BB (default `FALSE`; need `VMP_BB_*`
  secrets).

- nrw_login, nrw_notice:

  Log in / read notice PDFs for Vergabemarktplatz NRW (default `FALSE`;
  need an NRW account + `VMP_NRW_*` secrets).

- since_days:

  Unified look-back window in days, applied to every portal by
  publication date (default `30`): the API connectors fetch this many
  days and a final filter trims all sources (incl. VMP-BB) to the same
  window.

- cosinex_contracting_rules:

  Procurement regulations (Vergabeart) for the cosinex portals
  (Brandenburg/NRW/DTVP), default `"VOL"` (VgV / VOL/A / UVgO; excludes
  VOB/Bau). See
  [`vmp_bb_scrape_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_scrape_tenders.md)
  for other values. The API portals have no such filter (construction is
  excluded via the CPV-45 veto).

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
