# Read / write the detail-screening cache

The cache (one row per already-screened tender) lets the scheduled job
screen only *new* tenders and reuse earlier results; persisted with the
report so it survives across runs.

## Usage

``` r
read_detail_cache(path)

write_detail_cache(cache, path)
```

## Arguments

- path:

  Cache file path (`.rds`).

- cache:

  A cache data.frame (columns `tender_id`, `detail_groups`, `cpv`,
  `cpv_groups`).

## Value

`read_detail_cache()` returns the cache data.frame (empty if absent);
`write_detail_cache()` returns `path` invisibly.
