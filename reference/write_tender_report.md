# Write a tender overview report (Excel + Markdown + HTML)

Writes a dated Excel workbook (sheets "Relevant", "Alle", "Neu"), a
`latest.md` summary, a browsable `latest.html` (for GitHub Pages) and a
small state file used to flag tenders that are new since the previous
run.

## Usage

``` r
write_tender_report(
  tenders,
  dir = "reports",
  portal = "vmp-bb",
  date = Sys.time()
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

  Report timestamp (default
  [`Sys.time()`](https://rdrr.io/r/base/Sys.time.html)); its date part
  names the files, the full timestamp (Europe/Berlin) shows in the
  "Stand" line.

## Value

Invisibly, a list with the written file paths and counts.

## Examples

``` r
if (FALSE) { # \dontrun{
tenders <- score_relevance(vmp_bb_scrape_tenders(session))
write_tender_report(tenders)
} # }
```
