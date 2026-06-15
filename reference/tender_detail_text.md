# Fetch a tender detail page (rendered) and extract its text + CPV codes

Navigates the (JavaScript-rendered) public detail page via the chromote
session and reads the rendered text. No login required.

## Usage

``` r
tender_detail_text(session, url, wait = 10)
```

## Arguments

- session:

  A session from
  [`vmp_bb_session()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_session.md).

- url:

  Project detail URL (the `Aktion` column).

- wait:

  Maximum seconds to wait for the page to render (default `10`).

## Value

A list with `text` (rendered page text) and `cpv` (character vector).

## Examples

``` r
if (FALSE) { # \dontrun{
session <- vmp_bb_session()
tender_detail_text(session, tenders$Aktion[1])
} # }
```
