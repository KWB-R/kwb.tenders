# Vergabeplattform Berlin connector (HTTP, login-free)

Reads the Berlin notices (berlin.de, iTWO tender backend) over HTTP and
scores them
([`score_layered()`](https://kwb-r.github.io/kwb.tenders/reference/score_layered.md)).
The paginated HTML list (`?start=N`) is the primary source: it covers
the full look-back window and carries the iTWO detail link per notice in
a `data-href` attribute, with a date-based early stop. If the HTML
cannot be parsed it falls back to the RSS feed (latest ~50), which is
also used to backfill any missing links. No browser and no login
required.

## Usage

``` r
berlin_tenders(
  keywords = tender_keywords(),
  cpv_map = tender_cpv_map(),
  since_days = 30,
  max_pages = 60,
  relevant_only = TRUE,
  verbose = TRUE
)
```

## Arguments

- keywords:

  Keyword groups (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- cpv_map:

  CPV-to-group map (default
  [`tender_cpv_map()`](https://kwb-r.github.io/kwb.tenders/reference/tender_cpv_map.md)).

- since_days:

  Stop paging once a page is entirely older than this many days (the
  list is newest-first; default `30`). `NULL` pages up to `max_pages`.

- max_pages:

  Safety cap on pages fetched (default `60`; 10 notices/page).

- relevant_only:

  Return only relevant tenders (default `TRUE`).

- verbose:

  Print progress (default `TRUE`).

## Value

A scored tibble with `Plattform = "Vergabeplattform Berlin"`.

## Examples

``` r
if (FALSE) { # \dontrun{
berlin_tenders(since_days = 30)
} # }
```
