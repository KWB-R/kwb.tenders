# Write a tender overview report (Excel + Markdown)

Writes a dated Excel workbook (sheets "Relevant", "Alle", "Neu"), a
`latest.md` summary that renders nicely on GitHub, and a small state
file used to flag tenders that are new since the previous run.

## Usage

``` r
write_tender_report(
  tenders,
  dir = "reports",
  portal = "vmp-bb",
  date = Sys.Date()
)
```

## Arguments

- tenders:

  A scored tibble (see
  [`score_relevance()`](https://kwb-r.github.io/kwb.tenders/reference/score_relevance.md)).

- dir:

  Output directory (created if needed). Default `"reports"`.

- portal:

  Short portal id used in file names. Default `"vmp-bb"`.

- date:

  Report date (default
  [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html)).

## Value

Invisibly, a list with the written file paths and counts.

## Examples

``` r
if (FALSE) { # \dontrun{
tenders <- score_relevance(vmp_bb_scrape_tenders(session))
write_tender_report(tenders)
} # }
```
