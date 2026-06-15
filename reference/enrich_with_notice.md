# Enrich tenders with a notice-PDF (Bekanntmachung) relevance layer

For ongoing tenders not yet cached, reads the published announcement
PDF(s) via the logged-in `session` and matches the keyword groups
against the text. Adds a `notice_groups` column, merges it into
`groups`/`is_relevant` and adds the `notice` source to `match_source`.
Requires a logged-in session. The updated cache is returned as
`attr(result, "notice_cache")`.

## Usage

``` r
enrich_with_notice(
  session,
  tenders,
  keywords = tender_keywords(),
  ongoing_only = TRUE,
  max_notice = Inf,
  delay = 0.3,
  cache = NULL
)
```

## Arguments

- session:

  A logged-in session from
  [`vmp_bb_session()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_session.md).

- tenders:

  A tibble (typically already passed through
  [`enrich_with_details()`](https://kwb-r.github.io/kwb.tenders/reference/enrich_with_details.md)).

- keywords:

  Keyword groups (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- ongoing_only:

  Only screen ongoing tenders (default `TRUE`).

- max_notice:

  Maximum number of *new* notice PDFs to read (default `Inf`).

- delay:

  Seconds between tenders (default `0.3`).

- cache:

  Notice cache from a previous run (see
  [`read_notice_cache()`](https://kwb-r.github.io/kwb.tenders/reference/read_notice_cache.md)).

## Value

`tenders` with the notice layer merged in.
