# Search for and scrape tender results

Applies a filter via the portal's deep-link (the search state is a
base64 JSON in the URL hash) and scrapes the result table across pages.
Works without login (the search is public).

## Usage

``` r
vmp_bb_scrape_tenders(
  session,
  publication_types = c("ExAnte", "Tender"),
  contracting_rules = "VOL",
  max_pages = Inf,
  search_url = VMP_BB_SEARCH_URL,
  stop_before = NULL
)
```

## Arguments

- session:

  A session from
  [`vmp_bb_session()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_session.md).

- publication_types:

  Publication types to include. Default `c("ExAnte", "Tender")`
  (Beabsichtigte Ausschreibung + Ausschreibung). Further option:
  `"ExPost"` (Vergebener Auftrag).

- contracting_rules:

  Procurement regulations to include. Default `"VOL"` (VgV / VOL/A /
  UVgO). Others: `"VOB"`, `"VSVGV"`, `"SEKTVO"`, `"OTHER"`.

- max_pages:

  Maximum number of result pages to scrape (default `Inf`).

- search_url:

  Extended-search URL (default the Brandenburg one; other cosinex
  portals pass their own via `cosinex_urls()`).

- stop_before:

  Optional `Date`: stop paging once a result page is entirely older than
  this (results are sorted newest-first). Bounds the scrape for large
  portals/award histories; `NULL` (default) scrapes up to `max_pages`.

## Value

A tibble with one row per tender (all pages combined). The `Aktion`
column holds the project detail URL; the `Veroeffentlichungstyp` column
labels each row ("Ausschreibung" / "Geplante Ausschreibung").

## Examples

``` r
if (FALSE) { # \dontrun{
session <- vmp_bb_session()
tenders <- vmp_bb_scrape_tenders(session, max_pages = 2)
} # }
```
