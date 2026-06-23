# Deutsche eVergabe (deutsche-evergabe.de) connector (chromote, login-free)

Renders the public Healy-Hudson dashboard grid with chromote, pages
through it and scores the hits
([`score_layered()`](https://kwb-r.github.io/kwb.tenders/reference/score_layered.md));
relevant tenders are enriched via the login-free per-tender detail
endpoint (Vergabestelle / Publikationsdatum / Angebotsfrist / CPV). No
API/RSS exists, so a browser render is required; the result list carries
no CPV/free text, so relevance is title-based.

## Usage

``` r
deutsche_evergabe_tenders(
  keywords = tender_keywords(),
  cpv_map = tender_cpv_map(),
  terms = NULL,
  status = c("aktuell", "geplant", "vergeben"),
  max_detail = Inf,
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

- terms:

  Search terms (default: minimal roots of the strong KWB keywords,
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).
  The grid is searched per term (DevExpress `searchByText`) and the hits
  are unioned.

- status:

  Which notice classes to query via the dashboard category dropdown:
  `"aktuell"` (open tenders), `"geplant"` (Vorinformationen) and/or
  `"vergeben"` (Zuschlagsbekanntmachungen). Default: all three.

- max_detail:

  Cap on relevant tenders to enrich via the detail endpoint (default
  `Inf`).

- relevant_only:

  Return only relevant tenders (default `TRUE`).

- verbose:

  Print progress (default `TRUE`).

## Value

A scored tibble with
`Plattform = "Deutsche eVergabe (deutsche-evergabe.de)"`.

## Examples

``` r
if (FALSE) { # \dontrun{
deutsche_evergabe_tenders(status = "aktuell")
} # }
```
