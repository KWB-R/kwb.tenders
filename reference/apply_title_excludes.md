# Veto out-of-scope tenders by title (e.g. pure building / maintenance projects)

Sets `is_relevant = FALSE` for tenders whose **title** contains an
exclusion term (see
[`tender_excludes()`](https://kwb-r.github.io/kwb.tenders/reference/tender_excludes.md))
**unless** the title also contains a strong water keyword (so
"Klaeranlage ... Bauleistungen" or any "Grundwasser..." title is kept).
Adds an `excluded` column naming the vetoing term (`NA` otherwise).
Catches building/maintenance notices that only matched via incidental
detail text or CPV codes. Matching folds umlauts / is case-insensitive.

## Usage

``` r
apply_title_excludes(
  df,
  title_cols = c("Kurzbezeichnung", "Bezeichnung", "Titel"),
  keywords = tender_keywords(),
  excludes = tender_excludes()
)
```

## Arguments

- df:

  A scored tibble (must contain `is_relevant`).

- title_cols:

  Candidate title columns (those present are used).

- keywords:

  Keyword groups, for the strong-keyword rescue (default
  [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)).

- excludes:

  Exclusion list (default
  [`tender_excludes()`](https://kwb-r.github.io/kwb.tenders/reference/tender_excludes.md)).

## Value

`df` with vetoed rows' `is_relevant` set `FALSE` and an `excluded`
column.
