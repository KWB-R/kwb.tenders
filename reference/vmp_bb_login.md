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
  password = Sys.getenv("VMP_BB_PASSWORD"),
  auth_url = VMP_BB_AUTH_URL
)
```

## Arguments

- session:

  A session from
  [`vmp_bb_session()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_session.md).

- username, password:

  Credentials (default env vars `VMP_BB_USERNAME` / `VMP_BB_PASSWORD`).

- auth_url:

  Login (Keycloak SSO) URL (default the Brandenburg one; other cosinex
  portals pass their own via `cosinex_urls()`).

## Value

The `session`, invisibly. Errors if the login is rejected.

## Examples

``` r
if (FALSE) { # \dontrun{
session <- vmp_bb_session()
vmp_bb_login(session)
} # }
```
