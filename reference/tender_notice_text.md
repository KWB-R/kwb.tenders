# Fetch and extract the text of a tender's announcement (notice) PDF(s)

Opens the (logged-in) detail page, finds the published Bekanntmachung
PDF link(s) and returns their combined extracted text. Requires a
logged-in session (see
[`vmp_bb_login()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_login.md));
no bidder registration needed.

## Usage

``` r
tender_notice_text(session, detail_url, max_pdfs = 3)
```

## Arguments

- session:

  A logged-in session from
  [`vmp_bb_session()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_session.md).

- detail_url:

  The tender's detail URL (the `Aktion` column).

- max_pdfs:

  Maximum number of PDFs to read per tender (default `3`).

## Value

The combined PDF text (empty string if none/!accessible).

## Examples

``` r
if (FALSE) { # \dontrun{
s <- vmp_bb_session(); vmp_bb_login(s)
tender_notice_text(s, tenders$Aktion[1])
} # }
```
