# e-Vergabe des Bundes (evergabe-online.de) ------------------------------------
# The federal transaction platform (Beschaffungsamt des BMI). Its *below-
# threshold* national notices are NOT in the Datenservice (oeffentlichevergabe.de)
# -- a sample showed 0/10 of the latest evergabe-online notices there -- so it
# adds genuine coverage (federal water bodies: WSV, UBA, Bundesanstalt fuer
# Wasserbau, plus Laender/Kommunal water/wastewater associations).
#
# It is an Apache-Wicket app: no JSON/RSS API. The search is a Wicket form POST
# that returns the result table as an <ajax-response> XML document; pagination is
# a Wicket-Ajax GET. We drive it login-free over httr with a browser User-Agent
# (the default WebFetch UA is blocked with HTTP 400). The result list carries no
# CPV and no free text, so scoring is title-based (which also drops the
# "Wasserstrassen- und Schifffahrtsamt" navigation noise that only matches via
# the buyer name).

EVERGABE_ONLINE_BASE <- "https://www.evergabe-online.de"
.evergabe_online_ua <- paste0("Mozilla/5.0 (Windows NT 10.0; Win64; x64) ",
                              "AppleWebKit/537.36 (KHTML, like Gecko) ",
                              "Chrome/124.0 Safari/537.36")

#' Pack the strong KWB keywords into short OR-query batches. The portal silently
#' returns nothing for long queries (empirically ~>110 chars), so we greedily
#' fill each batch up to `max_chars` and union the hits.
#' @noRd
.evergabe_online_query_batches <- function(keywords, max_chars = 90) {
  strong <- unique(unlist(lapply(keywords, function(g) g$strong)))
  strong <- strong[nzchar(strong)]
  if (!length(strong)) return(character())
  batches <- character()
  cur <- character()
  for (t in strong) {
    if (length(cur) && nchar(paste(c(cur, t), collapse = " | ")) > max_chars) {
      batches <- c(batches, paste(cur, collapse = " | "))
      cur <- t
    } else {
      cur <- c(cur, t)
    }
  }
  c(batches, paste(cur, collapse = " | "))
}

#' Extract a Wicket <component id="..."> CDATA payload (HTML) by regex
#' (avoids XML-parsing the response, whose <evaluate> block has nested CDATA).
#' @noRd
.evergabe_online_component <- function(xml, id) {
  start <- regexpr(sprintf("<component id=\"%s\"[^>]*><!\\[CDATA\\[", id), xml)
  if (start < 0L) return("")
  rest <- substring(xml, start + attr(start, "match.length"))
  end <- regexpr("]]></component>", rest, fixed = TRUE)
  if (end < 0L) return("")
  substring(rest, 1L, end - 1L)
}

#' Total hit count from the "Zeige X bis Y von TOTAL" navigator label
#' @noRd
.evergabe_online_total <- function(html) {
  m <- regmatches(html, regexpr("von\\s+([0-9]+)", html))
  if (!length(m)) return(NA_integer_)
  as.integer(sub("\\D+", "", m))
}

#' "DD.MM.YY" or "DD.MM.YYYY" (optionally with ", HH:MM") -> ISO YYYY-MM-DD
#' @noRd
.evergabe_online_date <- function(x) {
  vapply(x, function(s) {
    mm <- regmatches(s, regexpr("(\\d{2})\\.(\\d{2})\\.(\\d{2,4})", s))
    if (!length(mm) || !nzchar(mm)) return("")
    p <- strsplit(mm, ".", fixed = TRUE)[[1]]
    yr <- if (nchar(p[3]) == 2L) paste0("20", p[3]) else p[3]
    sprintf("%s-%s-%s", yr, p[2], p[1])
  }, character(1), USE.NAMES = FALSE)
}

#' Extract a Wicket AJAX callback URL (the `"u":"./search.html?...needle..."` in
#' the response's inline script) -- the exact URL the browser GETs/POSTs, so
#' Wicket returns the <ajax-response> XML rather than a full page.
#' @noRd
.evergabe_online_ajax_url <- function(xml, needle) {
  m <- regmatches(xml, regexpr(sprintf("\"u\":\"\\./search\\.html\\?[^\"]*%s[^\"]*\"", needle), xml))
  if (!length(m)) return("")
  sub("^\"u\":\"\\./", "", sub("\"$", "", m)) # JS strings use a literal & (no &amp;)
}

#' "next page" AJAX URL from a Wicket response ("" on the last page)
#' @noRd
.evergabe_online_next <- function(xml) .evergabe_online_ajax_url(xml, "-navigator-next")

#' Parse the result-table HTML (a Wicket component payload) into raw rows
#' @noRd
evergabe_online_parse <- function(html) {
  doc <- tryCatch(rvest::read_html(html), error = function(e) NULL)
  if (is.null(doc)) return(data.frame())
  trs <- rvest::html_elements(doc, "tbody tr")
  rows <- lapply(trs, function(tr) {
    tds <- rvest::html_elements(tr, "td")
    if (length(tds) < 7L) return(NULL)
    a <- rvest::html_element(tr, "a[href*='tenderdetails']")
    href <- rvest::html_attr(a, "href")
    if (is.na(href)) return(NULL)
    txt <- function(i) trimws(rvest::html_text2(tds[[i]]))
    data.frame(
      Kurzbezeichnung = trimws(rvest::html_text2(a)),
      Geschaeftszeichen = txt(2),
      Vergabestelle = txt(3),
      Erfuellungsort = txt(4),
      Verfahrensart = txt(5),
      Frist = .evergabe_online_date(txt(6)),
      Veroeffentlicht = .evergabe_online_date(txt(7)),
      Aktion = paste0(EVERGABE_ONLINE_BASE, "/", sub("^\\./", "", href)),
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

#' Full Wicket search-form body (mirrors the browser POST; empty advanced fields)
#' @noRd
.evergabe_online_form <- function(query, date_range) {
  list(
    "simpleSearchParametersPanel:keywordStringGroup:searchString" = query,
    "simpleSearchParametersPanel:publishDateRangeGroup:publishDateRange" = date_range,
    "advancedSearchParameters:advancedSearchParameterPanel:placeStringGroup:placeString" = "",
    "advancedSearchParameters:advancedSearchParameterPanel:cpvCodeStringGroup:cpvCodes:cpvCodeViewContainer:cpvCodeInputField" = "",
    "advancedSearchParameters:advancedSearchParameterPanel:deadlineGroup:deadlineFrom" = "",
    "advancedSearchParameters:advancedSearchParameterPanel:deadlineGroup:deadlineTo" = "",
    "advancedSearchParameters:advancedSearchParameterPanel:tenderFloatingPeriodGroup:tenderFloatingPeriodFrom" = "",
    "advancedSearchParameters:advancedSearchParameterPanel:tenderFloatingPeriodGroup:tenderFloatingPeriodTo" = "",
    "advancedSearchParameters:advancedSearchParameterPanel:publishDateGroup:publishDateFrom" = "",
    "advancedSearchParameters:advancedSearchParameterPanel:publishDateGroup:publishDateTo" = "",
    "advancedSearchParameters:advancedSearchParameterPanel:authoritiesGroup:authorities:control:userInputTextField" = "",
    "searchLinkModal:input" = "link",
    "submitButton" = "1"
  )
}

#' Run one keyword search against evergabe-online.de and page through the results
#'
#' Login-free Wicket flow over httr: GET the search page (sets the session
#' cookies), POST the search form, then follow the "next" navigator links.
#' @noRd
evergabe_online_search <- function(query, date_range = "TWENTY_EIGHT_DAYS",
                                   max_pages = 30, handle = NULL, verbose = TRUE) {
  ua <- .evergabe_online_ua
  h <- if (is.null(handle)) httr::handle(EVERGABE_ONLINE_BASE) else handle
  ref <- paste0(EVERGABE_ONLINE_BASE, "/search.html?0&cookieCheck")
  hdr_ajax <- httr::add_headers(`User-Agent` = ua, `Wicket-Ajax` = "true",
                                `Wicket-Ajax-BaseURL` = "search.html?0&cookieCheck",
                                `X-Requested-With` = "XMLHttpRequest",
                                Origin = EVERGABE_ONLINE_BASE, Referer = ref,
                                `Sec-Fetch-Site` = "same-origin",
                                `Sec-Fetch-Mode` = "cors", `Sec-Fetch-Dest` = "empty")
  g <- tryCatch(httr::GET(paste0(EVERGABE_ONLINE_BASE, "/search.html"), handle = h,
                          httr::add_headers(`User-Agent` = ua, Accept = "text/html")),
                error = function(e) NULL)
  if (is.null(g) || httr::status_code(g) != 200L) {
    if (verbose) message("evergabe-online.de: initial GET failed.")
    return(data.frame())
  }
  body <- httr::content(g, as = "text", encoding = "UTF-8")
  submit <- .evergabe_online_ajax_url(body, "searchForm-submitButton")
  if (!nzchar(submit)) {
    if (verbose) message("evergabe-online.de: search submit URL not found (layout changed?).")
    return(data.frame())
  }
  r <- tryCatch(httr::POST(paste0(EVERGABE_ONLINE_BASE, "/", submit),
                           handle = h, encode = "form", hdr_ajax,
                           body = .evergabe_online_form(query, date_range)),
                error = function(e) NULL)
  if (is.null(r) || httr::status_code(r) != 200L) {
    if (verbose) message("evergabe-online.de: search POST failed (status ",
                         if (is.null(r)) "error" else httr::status_code(r), ").")
    return(data.frame())
  }
  cur <- httr::content(r, as = "text", encoding = "UTF-8")
  html <- .evergabe_online_component(cur, "results")
  if (!nzchar(html)) html <- .evergabe_online_component(cur, "datatable")
  total <- .evergabe_online_total(html)
  all <- evergabe_online_parse(html)
  if (verbose) message(sprintf("evergabe-online.de: %s Treffer, Seite 1 (%d)",
                               if (is.na(total)) "?" else total, nrow(all)))
  page <- 1L
  while (page < max_pages) {
    nxt <- .evergabe_online_next(cur)
    if (!nzchar(nxt)) break
    gr <- tryCatch(httr::GET(paste0(EVERGABE_ONLINE_BASE, "/", nxt), handle = h, hdr_ajax),
                   error = function(e) NULL)
    if (is.null(gr) || httr::status_code(gr) != 200L) break
    cur <- httr::content(gr, as = "text", encoding = "UTF-8")
    rows <- evergabe_online_parse(.evergabe_online_component(cur, "datatable"))
    if (!nrow(rows)) break
    before <- nrow(all)
    all <- rbind(all, rows)
    all <- all[!duplicated(all$Aktion), , drop = FALSE]
    if (nrow(all) == before) break # no new rows -> stop (last page repeated)
    page <- page + 1L
    if (verbose) message(sprintf("evergabe-online.de: Seite %d (%d gesamt)", page, nrow(all)))
    if (!is.na(total) && nrow(all) >= total) break
  }
  all
}

#' e-Vergabe des Bundes (evergabe-online.de) connector (HTTP, login-free)
#'
#' Searches the federal procurement platform evergabe-online.de for the KWB
#' keywords and scores the hits ([score_layered()]). Adds *below-threshold*
#' federal notices that the Datenservice (oeffentlichevergabe.de) does not carry.
#' Driven login-free over httr (Apache-Wicket form POST + Wicket-Ajax paging); no
#' CPV/free text in the result list, so relevance is title-based.
#'
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param cpv_map CPV-to-group map (default [tender_cpv_map()]).
#' @param query Full-text query; default is the strong KWB keywords joined with
#'   `" | "` (the portal treats `|` as OR).
#' @param date_range Portal publish-date window: one of `"ALL"`, `"SEVEN_DAYS"`,
#'   `"FOURTEEN_DAYS"`, `"TWENTY_ONE_DAYS"`, `"TWENTY_EIGHT_DAYS"`
#'   (default `"TWENTY_EIGHT_DAYS"`).
#' @param max_pages Page cap per batch (10 hits/page) (default 30).
#' @param max_query_chars Max length of each OR-batch query (default 90). The
#'   portal silently returns nothing for long queries (~>110 chars), so the
#'   strong keywords are packed into short OR-batches (each <= this) and the
#'   hits are unioned.
#' @param relevant_only Return only relevant tenders (default `TRUE`).
#' @param verbose Print progress (default `TRUE`).
#' @return A scored tibble with `Plattform = "e-Vergabe des Bundes (evergabe-online.de)"`.
#' @export
#' @examples
#' \dontrun{
#' evergabe_online_tenders(date_range = "SEVEN_DAYS")
#' }
evergabe_online_tenders <- function(keywords = tender_keywords(), cpv_map = tender_cpv_map(),
                                    query = NULL, date_range = "TWENTY_EIGHT_DAYS",
                                    max_pages = 30, max_query_chars = 90, relevant_only = TRUE,
                                    verbose = TRUE) {
  batches <- if (is.null(query)) .evergabe_online_query_batches(keywords, max_query_chars) else query
  parts <- list()
  for (i in seq_along(batches)) {
    # Fresh session per batch: a reused Wicket session returns 0 on follow-up searches.
    rows <- evergabe_online_search(query = batches[i], date_range = date_range,
                                   max_pages = max_pages, verbose = FALSE)
    if (verbose) message(sprintf("evergabe-online.de: Batch %d/%d -> %d Treffer",
                                 i, length(batches), nrow(rows)))
    if (nrow(rows)) parts[[length(parts) + 1L]] <- rows
  }
  raw <- if (length(parts)) do.call(rbind, parts) else data.frame()
  if (nrow(raw)) raw <- raw[!duplicated(raw$Aktion), , drop = FALSE]
  if (!nrow(raw)) {
    if (verbose) message("evergabe-online.de: no results.")
    return(data.frame())
  }
  raw$Veroeffentlichungstyp <- ifelse(grepl("Vorinformation", raw$Verfahrensart, ignore.case = TRUE),
                                      "Geplante Ausschreibung", "Ausschreibung")
  raw$Beschreibung <- "" # result list carries no free text -> title-based scoring
  raw$cpv <- ""
  scored <- score_layered(raw, title_cols = "Kurzbezeichnung", text_cols = "Beschreibung",
                          cpv_col = "cpv", keywords = keywords, cpv_map = cpv_map)
  scored$Plattform <- "e-Vergabe des Bundes (evergabe-online.de)"
  n_rel <- sum(scored$is_relevant %in% TRUE)
  if (isTRUE(relevant_only)) scored <- scored[scored$is_relevant %in% TRUE, , drop = FALSE]
  if (verbose) message("evergabe-online.de: ", n_rel, " relevant of ", nrow(raw), " fetched.")
  scored
}
