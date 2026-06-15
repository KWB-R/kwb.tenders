# Summarise all CPV codes found across the tenders

Aggregates the CPV codes collected by
[`enrich_with_details()`](https://kwb-r.github.io/kwb.tenders/reference/enrich_with_details.md)
into a table: one row per code (`cpv_id`) with its German label
(`cpv_name`, via
[`cpv_labels()`](https://kwb-r.github.io/kwb.tenders/reference/cpv_labels.md)),
the number of tenders it appears in (`n_tenders`) and the KWB research
group(s) it maps to (`groups`). Used as the "CPV" sheet of the report.

## Usage

``` r
cpv_summary(
  tenders,
  cpv_map = tender_cpv_map(),
  keywords = tender_keywords(),
  labels = cpv_labels()
)
```

## Arguments

- tenders:

  A tibble with a `cpv` column (comma-separated CPV codes).

- cpv_map:

  CPV-to-group mapping (default
  [`tender_cpv_map()`](https://kwb-r.github.io/kwb.tenders/reference/tender_cpv_map.md)).

- keywords:

  Keyword groups, for group display names (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- labels:

  CPV code -\> name lookup (default
  [`cpv_labels()`](https://kwb-r.github.io/kwb.tenders/reference/cpv_labels.md)).

## Value

A data.frame with columns `cpv_id`, `cpv_name`, `n_tenders`, `groups`,
sorted by descending frequency.

## Examples

``` r
cpv_summary(data.frame(cpv = c("90700000-4, 90733000-4", "90700000-4")))
#>       cpv_id                                                 cpv_name n_tenders
#> 1 90700000-4                         Dienstleistungen im Umweltschutz         2
#> 2 90733000-4 Dienstleistungen im Zusammenhang mit Wasserverschmutzung         1
#>                                    groups
#> 1 Regenwasser & Gewässer, Wasser & Risiko
#> 2     Regenwasser & Gewässer, Grundwasser
```
