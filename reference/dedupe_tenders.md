# Merge duplicate tenders that appear on several portals

The same tender is often syndicated across sources (a federal tender in
the Datenservice *and* in TED, a Land tender on its cosinex marketplace
*and* the Datenservice, ...). Rows whose normalised title matches are
collapsed to one, keeping the highest-priority platform's record
(Datenservice \> TED \> cosinex \> Berlin) and listing every source in
`Plattform`; the relevance `groups` are unioned. Only titles with \>= 20
normalised characters are matched, so short generic titles are never
merged.

## Usage

``` r
dedupe_tenders(tenders, verbose = TRUE)
```

## Arguments

- tenders:

  A combined scored tibble (see
  [`combine_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/combine_tenders.md)).

- verbose:

  Print how many rows were merged (default `TRUE`).

## Value

`tenders` with cross-portal duplicates merged (fewer or equal rows).

## Examples

``` r
a <- data.frame(Kurzbezeichnung = "Erneuerung Schaltanlage Wasserwerk Lodmannshagen",
                Plattform = "TED (EU)", groups = "Grundwasser", stringsAsFactors = FALSE)
b <- data.frame(Kurzbezeichnung = "Erneuerung Schaltanlage Wasserwerk Lodmannshagen",
                Plattform = "Oeffentliche Vergabe (Bund)", groups = "Grundwasser",
                stringsAsFactors = FALSE)
dedupe_tenders(combine_tenders(list(a, b)))
#> Dedup: merged 1 cross-portal duplicate(s).
#>                                    Kurzbezeichnung
#> 2 Erneuerung Schaltanlage Wasserwerk Lodmannshagen
#>                               Plattform      groups
#> 2 Oeffentliche Vergabe (Bund), TED (EU) Grundwasser
```
