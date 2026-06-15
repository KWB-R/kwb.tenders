# Layered relevance scoring for portal connectors (title + long text + CPV)

Scores a tender tibble the way the VMP-BB pipeline does, but in one call
for connectors that already ship a description and CPV codes (e.g. the
API portals): `title_cols` use the full rule (\>=1 strong OR \>=2
supporting), `text_cols` (long free text) are matched STRONG-only
(incidental supporting hits in long text are noise), and `cpv_col` codes
are mapped to groups. The three group sets are merged into `groups`,
with `match_source` (title/detail/cpv), `cpv_groups`, `score` and
`is_relevant`.

## Usage

``` r
score_layered(
  df,
  title_cols,
  text_cols = character(),
  cpv_col = NULL,
  keywords = tender_keywords(),
  cpv_map = tender_cpv_map(),
  exclude = TRUE
)
```

## Arguments

- df:

  A data frame of tenders.

- title_cols:

  Columns scored with the full rule (e.g. the title).

- text_cols:

  Columns scored strong-only (e.g. description); default none.

- cpv_col:

  Name of a comma/space-separated CPV column, or `NULL`.

- keywords:

  Keyword groups (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- cpv_map:

  CPV-to-group map (default
  [`tender_cpv_map()`](https://kwb-r.github.io/kwb.tenders/reference/tender_cpv_map.md)).

- exclude:

  Apply
  [`apply_title_excludes()`](https://kwb-r.github.io/kwb.tenders/reference/apply_title_excludes.md)
  afterwards to drop construction / building / maintenance tenders
  (default `TRUE`).

## Value

`df` with `groups`, `cpv_groups`, `match_source`, `score`, `is_relevant`
added, sorted by descending score.
