# e-Vergabe des Bundes (evergabe-online.de) connector (HTTP, login-free)

Searches the federal procurement platform evergabe-online.de for the KWB
keywords and scores the hits
([`score_layered()`](https://kwb-r.github.io/kwb.tenders/reference/score_layered.md)).
Adds *below-threshold* federal notices that the Datenservice
(oeffentlichevergabe.de) does not carry. Driven login-free over httr
(Apache-Wicket form POST + Wicket-Ajax paging); no CPV/free text in the
result list, so relevance is title-based.

## Usage

``` r
evergabe_online_tenders(
  keywords = tender_keywords(),
  cpv_map = tender_cpv_map(),
  query = NULL,
  date_range = "TWENTY_EIGHT_DAYS",
  max_pages = 30,
  max_query_chars = 90,
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

- query:

  Full-text query; default is the strong KWB keywords joined with
  `" | "` (the portal treats `|` as OR).

- date_range:

  Portal publish-date window: one of `"ALL"`, `"SEVEN_DAYS"`,
  `"FOURTEEN_DAYS"`, `"TWENTY_ONE_DAYS"`, `"TWENTY_EIGHT_DAYS"` (default
  `"TWENTY_EIGHT_DAYS"`).

- max_pages:

  Page cap per batch (10 hits/page) (default 30).

- max_query_chars:

  Max length of each OR-batch query (default 90). The portal silently
  returns nothing for long queries (~\>110 chars), so the strong
  keywords are packed into short OR-batches (each \<= this) and the hits
  are unioned.

- relevant_only:

  Return only relevant tenders (default `TRUE`).

- verbose:

  Print progress (default `TRUE`).

## Value

A scored tibble with
`Plattform = "e-Vergabe des Bundes (evergabe-online.de)"`.

## Examples

``` r
if (FALSE) { # \dontrun{
evergabe_online_tenders(date_range = "SEVEN_DAYS")
} # }
```
