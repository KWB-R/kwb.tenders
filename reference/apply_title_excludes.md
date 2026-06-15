# Veto out-of-scope tenders (construction / building / maintenance)

Drops tenders that are not a fit for a research institute, two ways:

1.  **title** contains a building/maintenance term (see
    [`tender_excludes()`](https://kwb-r.github.io/kwb.tenders/reference/tender_excludes.md))
    and no strong water keyword rescues it (so a "Grundwasser..." title
    is kept);

2.  **CPV** shows a construction-works code (`45...`) without an
    engineering-services code (`71...`) – a Bauauftrag; this is hard, so
    even "Neubau Klaeranlage" is dropped while "Ingenieurleistungen ..."
    stays.

Sets `is_relevant = FALSE` and records the reason in an `excluded`
column. Matching folds umlauts / is case-insensitive.

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
