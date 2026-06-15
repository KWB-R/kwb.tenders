# Combine scored tender tibbles from several portal connectors

Row-binds the per-portal results, filling columns absent in some sources
with `NA`, and guarantees a `Plattform` column. Each input should be a
scored tibble (see
[`score_relevance()`](https://kwb-r.github.io/kwb.tenders/reference/score_relevance.md))
as returned by a portal connector.

## Usage

``` r
combine_tenders(tenders_list)
```

## Arguments

- tenders_list:

  A list of data frames (one per portal). `NULL` entries and zero-row
  frames are dropped.

## Value

One combined data frame (an empty data frame if all inputs are empty).

## Examples

``` r
a <- data.frame(Plattform = "A", Kurzbezeichnung = "x", stringsAsFactors = FALSE)
b <- data.frame(Plattform = "B", cpv = "71351500-8", stringsAsFactors = FALSE)
combine_tenders(list(a, b))
#>   Plattform Kurzbezeichnung        cpv
#> 1         A               x       <NA>
#> 2         B            <NA> 71351500-8
```
