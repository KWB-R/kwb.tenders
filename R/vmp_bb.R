# Vergabemarktplatz Brandenburg (VMP-BB) -- driven directly via chromote (CDP) --

VMP_BB_AUTH_URL <- "https://vergabemarktplatz.brandenburg.de//VMPCenter/company/auth.do?method=show"
VMP_BB_SEARCH_URL <- "https://vergabemarktplatz.brandenburg.de/VMPCenter/common/project/search.do?method=showExtendedSearch"

#' Build the cosinex VMP endpoint URLs for a portal
#'
#' All cosinex "Vergabemarktplatz" instances share the same paths and differ only
#' in host and mount segment ("VMPCenter" for the Land marketplaces such as
#' Brandenburg/NRW, "Center" for DTVP). Used by [cosinex_tenders()].
#' @param base_url Portal host (e.g. `"https://www.evergabe.nrw.de"`).
#' @param mount Mount segment (`"VMPCenter"` or `"Center"`).
#' @return A list with `auth` and `search` URLs.
#' @noRd
cosinex_urls <- function(base_url, mount = "VMPCenter") {
  base <- sub("/+$", "", base_url)
  list(
    auth   = sprintf("%s/%s/company/auth.do?method=show", base, mount),
    search = sprintf("%s/%s/common/project/search.do?method=showExtendedSearch", base, mount)
  )
}

#' Start a chromote browser session
#'
#' Creates a headless Chrome session via `chromote`. The portal performs
#' cross-origin SSO redirects, which a direct chromote session handles reliably.
#'
#' @param headless Kept for API compatibility. The chromote backend always runs
#'   headless; `FALSE` only emits a note. Use `session$view()` to watch a live
#'   session in your browser.
#' @return A [chromote::ChromoteSession] object.
#' @export
#' @examples
#' \dontrun{
#' session <- vmp_bb_session()
#' }
vmp_bb_session <- function(headless = TRUE) {
  if (!isTRUE(headless)) {
    message("Note: the chromote backend runs Chrome headless; 'headless = FALSE' is ignored. ",
            "Use session$view() to watch the session.")
  }
  chromote::ChromoteSession$new()
}

#' Log in to Vergabemarktplatz Brandenburg (optional)
#'
#' Logs in via the Keycloak SSO form. Note: the public tender search works
#' *without* login (see [vmp_bb_scrape_tenders()]), so logging in is optional.
#'
#' @param session A session from [vmp_bb_session()].
#' @param username,password Credentials (default env vars `VMP_BB_USERNAME` /
#'   `VMP_BB_PASSWORD`).
#' @param auth_url Login (Keycloak SSO) URL (default the Brandenburg one; other
#'   cosinex portals pass their own via `cosinex_urls()`).
#' @return The `session`, invisibly. Errors if the login is rejected.
#' @export
#' @examples
#' \dontrun{
#' session <- vmp_bb_session()
#' vmp_bb_login(session)
#' }
vmp_bb_login <- function(session,
                         username = Sys.getenv("VMP_BB_USERNAME"),
                         password = Sys.getenv("VMP_BB_PASSWORD"),
                         auth_url = VMP_BB_AUTH_URL) {
  if (!nzchar(username) || !nzchar(password)) {
    stop("Missing credentials. Set 'VMP_BB_USERNAME' and 'VMP_BB_PASSWORD' ",
         "(e.g. in your .Renviron).", call. = FALSE)
  }

  cdp_navigate(session, auth_url, wait = 5)
  if (!cdp_wait_for(session, "#username", timeout = 20)) {
    stop("Login page did not load (no '#username' field).", call. = FALSE)
  }

  cdp_set_value(session, "#username", username)
  cdp_set_value(session, "#password", password)
  cdp_click_first(session, "#kc-login")
  Sys.sleep(5)

  # Keycloak re-renders the login form (with an error) when login fails.
  if (isTRUE(cdp_eval(session, "!!document.querySelector('#kc-login')"))) {
    msg <- cdp_eval(session, "(function(){var e=document.querySelector('.alert-error, .pf-c-alert__title, #input-error');return e?e.innerText:'';})()")
    stop(sprintf("Login failed%s.",
                 if (is.character(msg) && nzchar(msg)) paste0(": ", msg) else ""),
         call. = FALSE)
  }
  invisible(session)
}

#' Build the base64 search-state hash used by the portal's deep-link
#'
#' `publication_types`: "ExAnte" (Beabsichtigte Ausschreibung / planned),
#' "Tender" (Ausschreibung), "ExPost" (Vergebener Auftrag).
#' `contracting_rules`: "VOL" (VgV / VOL/A / UVgO), "VOB" (VOB/A), "VSVGV",
#' "SEKTVO", "OTHER" (Sonstige).
#' @noRd
vmp_bb_filter_hash <- function(publication_types, contracting_rules, page = 1) {
  arr <- function(x) paste0("[", paste(sprintf('"%s"', x), collapse = ","), "]")
  json <- sprintf(
    '{"cpvCodes":[],"contractingRules":%s,"publicationTypes":%s,"distance":0,"postalCode":"","order":"0","page":"%d","searchText":"","sortField":"PROJECT_PUBLICATION_DATE_LNG"}',
    arr(contracting_rules), arr(publication_types), as.integer(page)
  )
  gsub("=+$", "", jsonlite::base64_enc(charToRaw(json)))
}

#' Search for and scrape tender results
#'
#' Applies a filter via the portal's deep-link (the search state is a base64
#' JSON in the URL hash) and scrapes the result table across pages. Works
#' without login (the search is public).
#'
#' @param session A session from [vmp_bb_session()].
#' @param publication_types Publication types to include. Default
#'   `c("ExAnte", "Tender")` (Beabsichtigte Ausschreibung + Ausschreibung).
#'   Further option: `"ExPost"` (Vergebener Auftrag).
#' @param contracting_rules Procurement regulations to include. Default `"VOL"`
#'   (VgV / VOL/A / UVgO). Others: `"VOB"`, `"VSVGV"`, `"SEKTVO"`, `"OTHER"`.
#' @param max_pages Maximum number of result pages to scrape (default `Inf`).
#' @param search_url Extended-search URL (default the Brandenburg one; other
#'   cosinex portals pass their own via `cosinex_urls()`).
#' @param stop_before Optional `Date`: stop paging once a result page is entirely
#'   older than this (results are sorted newest-first). Bounds the scrape for
#'   large portals/award histories; `NULL` (default) scrapes up to `max_pages`.
#' @return A tibble with one row per tender (all pages combined). The `Aktion`
#'   column holds the project detail URL; the `Veroeffentlichungstyp` column
#'   labels each row ("Ausschreibung" / "Geplante Ausschreibung").
#' @export
#' @examples
#' \dontrun{
#' session <- vmp_bb_session()
#' tenders <- vmp_bb_scrape_tenders(session, max_pages = 2)
#' }
vmp_bb_scrape_tenders <- function(session,
                                  publication_types = c("ExAnte", "Tender"),
                                  contracting_rules = "VOL",
                                  max_pages = Inf,
                                  search_url = VMP_BB_SEARCH_URL,
                                  stop_before = NULL) {
  labels <- c(ExAnte = "Geplante Ausschreibung",
              Tender = "Ausschreibung",
              ExPost = "Vergebener Auftrag")

  # Search each publication type separately so each row can be labelled.
  out <- list()
  for (pt in publication_types) {
    hash <- vmp_bb_filter_hash(pt, contracting_rules, page = 1)
    cdp_navigate(session, paste0(search_url, "#", hash), wait = 7)
    if (!cdp_wait_for(session, ".browsePagesText", timeout = 25)) {
      warning(sprintf("Results did not load for publication type '%s'.", pt), call. = FALSE)
      next
    }
    pc <- cdp_read_counter(session)
    if (is.na(pc$max)) {
      warning(sprintf("Could not read the counter for publication type '%s'.", pt), call. = FALSE)
      next
    }
    n_pages <- min(pc$max, max_pages)
    label <- if (pt %in% names(labels)) labels[[pt]] else pt
    message(sprintf("[%s] %s tender(s) on %s page(s); scraping %s.",
                    label, pc$total, pc$max, n_pages))

    tbls <- vector("list", n_pages)
    for (p in seq_len(n_pages)) {
      message(sprintf("  [%s] page %02d/%02d", label, p, n_pages))
      tbls[[p]] <- scrape_current_table(session)
      # Sorted newest-first: once a whole page is older than stop_before, the
      # rest is out of the date window -> stop paging (bounds award histories).
      if (!is.null(stop_before)) {
        vcol <- grep("ffentlich", names(tbls[[p]]), ignore.case = TRUE, value = TRUE)
        if (length(vcol)) {
          d <- .parse_pub_date(tbls[[p]][[vcol[1]]])
          if (length(d) && all(!is.na(d)) && all(d < stop_before)) {
            message(sprintf("  [%s] page %02d older than %s -> stop.", label, p,
                            format(stop_before)))
            break
          }
        }
      }
      if (p < n_pages && !next_page(session, p)) break
    }
    df <- dplyr::bind_rows(tbls)
    if (nrow(df) > 0) {
      df$Veroeffentlichungstyp <- label
      out[[pt]] <- df
    }
  }
  dplyr::bind_rows(out)
}

#' Scrape the tender table currently shown
#' @noRd
scrape_current_table <- function(session) {
  html <- cdp_eval(session, "document.documentElement.outerHTML")
  doc <- rvest::read_html(html)
  tbl_node <- rvest::html_element(doc, "table")

  headers <- rvest::html_text2(rvest::html_elements(tbl_node, "thead th"))
  rows <- rvest::html_elements(tbl_node, "tbody tr")
  if (length(rows) == 0 || length(headers) == 0) return(tibble::tibble())

  mat <- lapply(rows, function(r) {
    tds <- rvest::html_text2(rvest::html_elements(r, "td"))
    length(tds) <- length(headers) # pad/truncate to header count
    tds
  })
  df <- as.data.frame(do.call(rbind, mat), stringsAsFactors = FALSE)
  names(df) <- headers

  # Action column = direct project detail URL.
  df[["Aktion"]] <- vapply(rows, function(r) {
    a <- rvest::html_element(r, "td:last-child a.noTextDecorationLink")
    rvest::html_attr(a, "href")
  }, character(1))

  tibble::as_tibble(df, .name_repair = "minimal")
}

#' Click "next page" and wait for the counter to advance
#' @noRd
next_page <- function(session, current) {
  if (is.na(cdp_click_first(session, "#nextPage"))) return(FALSE)
  t0 <- Sys.time()
  repeat {
    Sys.sleep(0.4)
    cur <- cdp_read_counter(session)$cur
    if (!is.na(cur) && cur > current) return(TRUE)
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > 20) return(FALSE)
  }
}
