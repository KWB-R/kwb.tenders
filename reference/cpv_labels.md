# CPV code -\> German label lookup

Reads the bundled CPV label table (`inst/extdata/cpv_labels.csv`,
columns `code`, `name`). Edit/extend that file (or drop in the full
official CPV list) to cover more codes.

## Usage

``` r
cpv_labels(
  path = system.file("extdata", "cpv_labels.csv", package = "kwb.tenders")
)
```

## Arguments

- path:

  CSV file with columns `code`, `name`.

## Value

A named character vector (names = CPV codes, values = German labels).

## Examples

``` r
head(cpv_labels())
#>                                                                                                                 03000000-1 
#> "Landwirtschaftliche Erzeugnisse des Pflanzenbaus und der Tierhaltung sowie Fischerei-, Forst- und zugehörige Erzeugnisse" 
#>                                                                                                                 03100000-2 
#>                                                                                "Landwirtschafts- und Gartenbauerzeugnisse" 
#>                                                                                                                 03110000-5 
#>                                                                        "Feldfrüchte und Erzeugnisse des Erwerbsgartenbaus" 
#>                                                                                                                 03111000-2 
#>                                                                                                                  "Saatgut" 
#>                                                                                                                 03111100-3 
#>                                                                                                               "Sojabohnen" 
#>                                                                                                                 03111200-4 
#>                                                                                                                 "Erdnüsse" 
```
