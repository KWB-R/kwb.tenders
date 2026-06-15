# Read / write the notice-screening cache

Read / write the notice-screening cache

## Usage

``` r
read_notice_cache(path)

write_notice_cache(cache, path)
```

## Arguments

- path:

  Cache file path (`.rds`).

- cache:

  A cache data.frame (`tender_id`, `notice_groups`).

## Value

`read_notice_cache()` a data.frame (empty if absent);
`write_notice_cache()` returns `path` invisibly.
