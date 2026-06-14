# Score tenders for relevance to KWB research groups

Case-insensitive substring matching of each group's keywords against all
character columns. A tender matches a group if it contains at least one
`strong` keyword or at least two `supporting` keywords; it is relevant
if it matches at least one group.

## Usage

``` r
score_relevance(tenders, keywords = tender_keywords())
```

## Arguments

- tenders:

  A data frame / tibble of tenders (e.g. from
  [`vmp_bb_scrape_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_scrape_tenders.md)).

- keywords:

  Keyword groups (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).
  May also be a single group as `list(strong = ..., supporting = ...)`.

## Value

`tenders` with added columns `groups` (matching group names, comma
separated), `matched_keywords`, `score` and `is_relevant`, sorted by
descending score.

## Examples

``` r
df <- data.frame(
  Bezeichnung = c("Grundwassermonitoring Brunnen", "Kanalsanierung Sensorik"),
  stringsAsFactors = FALSE
)
res <- score_relevance(df)
res[, c("Bezeichnung", "groups", "score")]
#>                     Bezeichnung                     groups score
#> 1 Grundwassermonitoring Brunnen                Grundwasser     5
#> 2       Kanalsanierung Sensorik Smart City & Infrastruktur     4
```
