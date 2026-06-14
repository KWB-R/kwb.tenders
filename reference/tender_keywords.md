# KWB research-group keywords

Reads the keyword lists for all KWB research groups shipped with the
package (`inst/extdata/keywords.yml`). Each group has a display `name`
and `strong` / `supporting` keyword vectors.

## Usage

``` r
tender_keywords(dir = system.file("extdata", package = "kwb.tenders"))
```

## Arguments

- dir:

  Directory holding the per-group keyword files (`keywords_<slug>.yml`,
  one file per research group).

## Value

A named list of groups (named by slug), each a list with `name`,
`strong`, `supporting`.

## Examples

``` r
names(tender_keywords())
#> [1] "energy-resources"          "groundwater"              
#> [3] "smart-city-infrastructure" "stormwater-surface-waters"
#> [5] "water-risk"                "water-treatment-reuse"    
```
