# CPV-code to research-group mapping

CPV-code to research-group mapping

## Usage

``` r
tender_cpv_map(
  path = system.file("extdata", "cpv_groups.yml", package = "kwb.tenders")
)
```

## Arguments

- path:

  YAML file mapping CPV prefixes to group slugs
  (`inst/extdata/cpv_groups.yml`).

## Value

A list of entries, each a list with `prefix` and `groups`.

## Examples

``` r
str(tender_cpv_map())
#> List of 13
#>  $ :List of 2
#>   ..$ prefix: chr "71351"
#>   ..$ groups: chr "groundwater"
#>  $ :List of 2
#>   ..$ prefix: chr "65120"
#>   ..$ groups: chr "water-treatment-reuse"
#>  $ :List of 2
#>   ..$ prefix: chr "65110"
#>   ..$ groups: chr [1:2] "smart-city-infrastructure" "water-treatment-reuse"
#>  $ :List of 2
#>   ..$ prefix: chr "65130"
#>   ..$ groups: chr "smart-city-infrastructure"
#>  $ :List of 2
#>   ..$ prefix: chr "9041"
#>   ..$ groups: chr "water-treatment-reuse"
#>  $ :List of 2
#>   ..$ prefix: chr "9042"
#>   ..$ groups: chr "water-treatment-reuse"
#>  $ :List of 2
#>   ..$ prefix: chr "90440"
#>   ..$ groups: chr [1:2] "water-treatment-reuse" "energy-resources"
#>  $ :List of 2
#>   ..$ prefix: chr "9048"
#>   ..$ groups: chr [1:2] "water-treatment-reuse" "smart-city-infrastructure"
#>  $ :List of 2
#>   ..$ prefix: chr "9070"
#>   ..$ groups: chr [1:2] "stormwater-surface-waters" "water-risk"
#>  $ :List of 2
#>   ..$ prefix: chr "9073"
#>   ..$ groups: chr [1:2] "stormwater-surface-waters" "groundwater"
#>  $ :List of 2
#>   ..$ prefix: chr "45232"
#>   ..$ groups: chr "smart-city-infrastructure"
#>  $ :List of 2
#>   ..$ prefix: chr "45252"
#>   ..$ groups: chr "water-treatment-reuse"
#>  $ :List of 2
#>   ..$ prefix: chr "45247"
#>   ..$ groups: chr "stormwater-surface-waters"
```
