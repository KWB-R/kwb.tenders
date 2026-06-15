# Title-level exclusion (veto) terms

Reads `inst/extdata/keywords_exclude.yml` – terms that mark a tender as
not relevant when they appear in its title (and no strong water keyword
does). Used by
[`apply_title_excludes()`](https://kwb-r.github.io/kwb.tenders/reference/apply_title_excludes.md).
This file is deliberately ignored by
[`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md);
it is not a research group.

## Usage

``` r
tender_excludes(
  path = system.file("extdata", "keywords_exclude.yml", package = "kwb.tenders")
)
```

## Arguments

- path:

  YAML file with a `terms:` list (and optional `name`).

## Value

A list with `name` and `terms` (character vector).
