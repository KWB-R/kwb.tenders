# Log in to Vergabemarktplatz Brandenburg (optional)

Logs in via the Keycloak SSO form. Note: the public tender search works
*without* login (see
[`vmp_bb_scrape_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_scrape_tenders.md)),
so logging in is optional.

## Usage

``` r
vmp_bb_login(
  session,
  username = Sys.getenv("VMP_BB_USERNAME"),
  password = Sys.getenv("VMP_BB_PASSWORD")
)
```

## Arguments

- session:

  A session from
  [`vmp_bb_session()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_session.md).

- username, password:

  Credentials (default env vars `VMP_BB_USERNAME` / `VMP_BB_PASSWORD`).

## Value

The `session`, invisibly. Errors if the login is rejected.

## Examples

``` r
if (FALSE) { # \dontrun{
session <- vmp_bb_session()
vmp_bb_login(session)
} # }
```
