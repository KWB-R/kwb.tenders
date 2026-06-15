# Fetch a tender detail page and extract its text + CPV codes

Uses a plain HTTP GET (the published detail page is public), so no
browser or login is required.

## Usage

``` r
tender_detail_text(url)
```

## Arguments

- url:

  Project detail URL (the `Aktion` column from
  [`vmp_bb_scrape_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_scrape_tenders.md)).

## Value

A list with `text` (page text) and `cpv` (character vector of CPV
codes).

## Examples

``` r
if (FALSE) { # \dontrun{
tender_detail_text(tenders$Aktion[1])
} # }
```
