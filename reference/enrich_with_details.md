# Enrich tenders with a detail-page relevance layer (full text + CPV codes)

For ongoing tenders, fetches the public detail page, matches the keyword
groups against its full text and maps its CPV codes to groups. The
matching group(s) are merged into `groups`/`is_relevant`; adds columns
`detail_groups`, `cpv`, `cpv_groups` and `match_source` (which layer(s)
matched).

## Usage

``` r
enrich_with_details(
  tenders,
  keywords = tender_keywords(),
  cpv_map = tender_cpv_map(),
  ongoing_only = TRUE,
  max_detail = Inf,
  delay = 0.3
)
```

## Arguments

- tenders:

  A scored tibble (see
  [`score_relevance()`](https://kwb-r.github.io/kwb.tenders/reference/score_relevance.md)).

- keywords:

  Keyword groups (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- cpv_map:

  CPV-to-group mapping (default
  [`tender_cpv_map()`](https://kwb-r.github.io/kwb.tenders/reference/tender_cpv_map.md)).

- ongoing_only:

  Only screen tenders whose deadline has not passed (default `TRUE`).

- max_detail:

  Maximum number of detail pages to fetch (default `Inf`).

- delay:

  Seconds between detail requests (politeness; default `0.3`).

## Value

`tenders` with the detail layer merged in.
