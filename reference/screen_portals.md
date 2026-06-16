# Run several portal connectors, combine and write one report

Calls each source connector (a function returning a scored tender
tibble), tagging it with a `Plattform`, combines the results with
[`combine_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/combine_tenders.md)
and writes one report via
[`write_tender_report()`](https://kwb-r.github.io/kwb.tenders/reference/write_tender_report.md).
A source that errors is logged and skipped, so one portal failing does
not abort the run.

## Usage

``` r
screen_portals(
  sources,
  dir = "reports",
  portal = "tenders",
  keywords = tender_keywords(),
  keep_types = c("Ausschreibung", "Geplante Ausschreibung", "Vergebener Auftrag"),
  since_days = NULL,
  dedupe = TRUE,
  verbose = TRUE
)
```

## Arguments

- sources:

  A named list of functions, each returning a scored tibble (e.g.
  `list("TED" = function() ted_tenders())`). The name is used as the
  `Plattform` if the connector does not set one.

- dir:

  Output directory (default `"reports"`).

- portal:

  File-name id for the combined report (default `"tenders"`).

- keywords:

  Passed to connectors that take it (currently informational).

- keep_types:

  Keep only these `Veroeffentlichungstyp` values (default:
  Ausschreibung, Geplante Ausschreibung and Vergebener Auftrag -\> own
  section each). `NULL` keeps all types.

- since_days:

  If set, keep only notices whose `Veroeffentlicht` (publication date)
  is within the last `since_days` days; `NULL` (default) applies no date
  filter. Used to unify the look-back window across portals.

- dedupe:

  Merge cross-portal duplicates with
  [`dedupe_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/dedupe_tenders.md)
  before writing (default `TRUE`).

- verbose:

  Print progress (default `TRUE`).

## Value

Invisibly, the combined scored tibble.

## Examples

``` r
if (FALSE) { # \dontrun{
screen_portals(list(
  "Oeffentliche Vergabe" = function() oeffentlichevergabe_tenders(days = 7),
  "TED" = function() ted_tenders()
))
} # }
```
