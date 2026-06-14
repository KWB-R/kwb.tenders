# Start a chromote browser session

Creates a headless Chrome session via `chromote`. The portal performs
cross-origin SSO redirects, which a direct chromote session handles
reliably.

## Usage

``` r
vmp_bb_session(headless = TRUE)
```

## Arguments

- headless:

  Kept for API compatibility. The chromote backend always runs headless;
  `FALSE` only emits a note. Use `session$view()` to watch a live
  session in your browser.

## Value

A
[chromote::ChromoteSession](https://rstudio.github.io/chromote/reference/ChromoteSession.html)
object.

## Examples

``` r
if (FALSE) { # \dontrun{
session <- vmp_bb_session()
} # }
```
