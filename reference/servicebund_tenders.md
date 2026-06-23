# service.bund.de tender connector (HTTP, login-free)

Reads the public RSS feeds of the federal service portal
(service.bund.de), which aggregates tender notices from
Bund/Laender/Kommunen, and scores them
([`score_layered()`](https://kwb-r.github.io/kwb.tenders/reference/score_layered.md)).
A separate aggregator from the Datenservice (oeffentlichevergabe.de)
that adds notices the Datenservice does not carry (esp. below
threshold). No browser and no login required. The feed provides no CPV,
so relevance is title/text-based.

## Usage

``` r
servicebund_tenders(
  keywords = tender_keywords(),
  cpv_map = tender_cpv_map(),
  include_awarded = TRUE,
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

- include_awarded:

  Also read the "Vergebene Auftraege" feed, labelled
  `Vergebener Auftrag` (default `TRUE`).

- relevant_only:

  Return only relevant tenders (default `TRUE`).

- verbose:

  Print progress (default `TRUE`).

## Value

A scored tibble with
`Plattform = "Serviceportal des Bundes (service.bund.de)"`.

## Examples

``` r
if (FALSE) { # \dontrun{
servicebund_tenders()
} # }
```
