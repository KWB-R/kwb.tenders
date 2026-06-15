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
  keep_types = c("Ausschreibung", "Geplante Ausschreibung"),
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

  Keep only these `Veroeffentlichungstyp` values (default the biddable
  ones -\> drops "Vergebener Auftrag"/awards). `NULL` keeps all.

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
