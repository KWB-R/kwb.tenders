# Enrich tenders with a detail-page relevance layer (rendered text + CPV codes)

For ongoing tenders that are not yet in `cache`, renders the public
detail page via `session`, matches the keyword groups against its full
text and maps its CPV codes to groups. Cached tenders are reused without
re-fetching. The matching group(s) are merged into
`groups`/`is_relevant`; adds columns `detail_groups`, `cpv`,
`cpv_groups`, `match_source`. The updated cache is returned as
`attr(result, "detail_cache")`.

## Usage

``` r
enrich_with_details(
  session,
  tenders,
  keywords = tender_keywords(),
  cpv_map = tender_cpv_map(),
  ongoing_only = TRUE,
  max_detail = Inf,
  delay = 0.2,
  cache = NULL
)
```

## Arguments

- session:

  A session from
  [`vmp_bb_session()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_session.md).

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

  Maximum number of *new* detail pages to render per call (default
  `Inf`).

- delay:

  Seconds between detail pages (politeness; default `0.2`).

- cache:

  Detail cache from a previous run (see
  [`read_detail_cache()`](https://kwb-r.github.io/kwb.tenders/reference/read_detail_cache.md)).

## Value

`tenders` with the detail layer merged in; the updated cache is in
`attr(result, "detail_cache")`.
