# Deutsche eVergabe (deutsche-evergabe.de) -------------------------------------
# Healy-Hudson portal. The public dashboard (Dashboards/Dashboard_off) renders a
# DevExpress DataGrid client-side (50 rows/page + pager), each tender an
# `<a class="BekSummary" data-button="<GUID>">` (title + Verfahrensart in <small>).
# We render the grid with chromote (no API/RSS, JS-driven) and page through it,
# then enrich the relevant hits via the login-free per-tender detail endpoint
# `/verfahren/BekSummaryModal/{GUID}` (HTML with Vergabestelle / Publikationsdatum
# / Angebotsfrist / CPV). chromote is already a dependency (cosinex connectors).

DEUTSCHE_EVERGABE_BASE <- "https://www.deutsche-evergabe.de"
.deutsche_evergabe_ua <- paste0("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:152.0) ",
                                "Gecko/20100101 Firefox/152.0")

# JS: one row object {guid,title,art} per BekSummary anchor (title without the
# <small> Verfahrensart, which is captured separately).
.DEV_EXTRACT_JS <- paste0(
  "JSON.stringify(Array.prototype.slice.call(document.querySelectorAll('a.BekSummary'))",
  ".map(function(a){var c=a.cloneNode(true);var s=c.querySelector('small');",
  "var art=s?s.textContent.replace(/\\s+/g,' ').trim():'';if(s){s.parentNode.removeChild(s);}",
  "var t=c.textContent.replace(/\\s+/g,' ').trim();",
  "return {guid:a.getAttribute('data-button')||'',title:t,art:art};})",
  ".filter(function(x){return x.guid && x.title;}))")
#' Reduce the strong KWB keywords to minimal search roots: drop a term if a
#' shorter term is a substring of it. The grid search is a "contains" match, so
#' e.g. "Grundwasser" already covers "Grundwassermessstelle" -> fewer searches.
#' @noRd
.deutsche_evergabe_search_terms <- function(keywords) {
  s <- unique(unlist(lapply(keywords, function(g) g$strong)))
  s <- s[nzchar(s)]
  sl <- tolower(s)
  drop <- logical(length(s))
  for (i in seq_along(s)) for (j in seq_along(s)) {
    if (i != j && nchar(sl[j]) < nchar(sl[i]) && grepl(sl[j], sl[i], fixed = TRUE)) {
      drop[i] <- TRUE; break
    }
  }
  unique(s[!drop])
}

#' searchByText() JS for one term (JSON-encoded for safe quoting/umlauts)
#' @noRd
.deutsche_evergabe_search_js <- function(term) {
  paste0("(function(){try{var el=document.querySelector('.dx-datagrid');",
         "var r=el.closest('.dx-widget')||el;",
         "jQuery(r).dxDataGrid('instance').searchByText(",
         jsonlite::toJSON(term, auto_unbox = TRUE), ");return true;}catch(e){return false;}})()")
}

# The dashboard's category dropdown (a DevExpress dxLookup) switches which notice
# class the grid shows. Its three items map cleanly onto our three publication
# types, so we drive it once per requested status and tag the rows accordingly:
#   V = "aktuelle Ausschreibungen"           -> Ausschreibung
#   I = "aktuelle Vorinformationen"          -> Geplante Ausschreibung
#   Z = "aktuelle Zuschlagsbekanntmachungen" -> Vergebener Auftrag
.DEUTSCHE_EVERGABE_CATS <- list(
  aktuell  = list(id = "V", typ = "Ausschreibung"),
  geplant  = list(id = "I", typ = "Geplante Ausschreibung"),
  vergeben = list(id = "Z", typ = "Vergebener Auftrag")
)

#' Set the category dropdown (dxLookup) value, reloading the grid for that class
#' @noRd
.deutsche_evergabe_set_category_js <- function(id) {
  paste0("(function(){try{var f=document.querySelector('.dx-lookup-field');",
         "var r=f.closest('.dx-lookup');var lk=jQuery(r).dxLookup('instance');",
         "lk.option('value',", jsonlite::toJSON(id, auto_unbox = TRUE),
         ");return true;}catch(e){return false;}})()")
}

#' "DD.MM.YYYY ..." -> ISO YYYY-MM-DD ("" if none)
#' @noRd
.deutsche_evergabe_date <- function(x) {
  m <- regmatches(x, regexpr("\\d{2}\\.\\d{2}\\.\\d{4}", x))
  if (!length(m)) return("")
  p <- strsplit(m, ".", fixed = TRUE)[[1]]
  sprintf("%s-%s-%s", p[3], p[2], p[1])
}

#' Parse a BekSummaryModal detail HTML into a one-row field list
#' @noRd
.deutsche_evergabe_parse_detail <- function(html) {
  doc <- tryCatch(rvest::read_html(html), error = function(e) NULL)
  if (is.null(doc)) return(NULL)
  vst <- trimws(rvest::html_text2(rvest::html_element(doc, ".modal-header strong")))
  trs <- rvest::html_elements(doc, ".modal-body table tr")
  lab <- vapply(trs, function(tr) {
    td <- rvest::html_elements(tr, "td"); if (length(td)) trimws(rvest::html_text2(td[[1]])) else ""
  }, character(1))
  val <- vapply(trs, function(tr) {
    td <- rvest::html_elements(tr, "td"); if (length(td) >= 2L) trimws(rvest::html_text2(td[[2]])) else ""
  }, character(1))
  getv <- function(pat) { i <- grep(pat, lab, ignore.case = TRUE)[1]; if (is.na(i)) "" else val[i] }
  cpv <- paste(unique(trimws(rvest::html_text2(rvest::html_elements(doc, ".badge-primary")))),
               collapse = ", ")
  list(Vergabestelle = if (is.na(vst)) "" else vst,
       Veroeffentlicht = .deutsche_evergabe_date(getv("Publikation")),
       Frist = .deutsche_evergabe_date(getv("Angebotsfrist")),
       cpv = cpv)
}

#' Fetch + parse one tender's detail (login-free; needs a session cookie on `h`)
#' @noRd
.deutsche_evergabe_detail <- function(guid, h, ua) {
  url <- sprintf("%s/verfahren/BekSummaryModal/%s?isProd=true&DashOff=true", DEUTSCHE_EVERGABE_BASE, guid)
  r <- tryCatch(httr::GET(url, handle = h,
                          httr::add_headers(`User-Agent` = ua, `X-Requested-With` = "XMLHttpRequest")),
                error = function(e) NULL)
  if (is.null(r) || httr::status_code(r) != 200L) return(NULL)
  .deutsche_evergabe_parse_detail(httr::content(r, as = "text", encoding = "UTF-8"))
}

#' Render the dashboard grid with chromote and scrape it per search term
#' (DevExpress searchByText() filters globally, like the UI search box). The grid
#' is scraped once per requested `status`: the category dropdown is switched
#' (V/I/Z) so planned (Vorinformationen) and awarded (Zuschlagsbekanntmachungen)
#' notices are covered alongside the open tenders. Each row is tagged with the
#' category's `Veroeffentlichungstyp`.
#' @noRd
deutsche_evergabe_scrape <- function(terms, status = c("aktuell", "geplant", "vergeben"),
                                     verbose = TRUE) {
  if (!requireNamespace("chromote", quietly = TRUE)) {
    if (verbose) message("deutsche-evergabe.de: chromote not available.")
    return(data.frame())
  }
  status <- intersect(status, names(.DEUTSCHE_EVERGABE_CATS))
  if (!length(status)) status <- "aktuell"
  sess <- tryCatch(chromote::ChromoteSession$new(), error = function(e) NULL)
  if (is.null(sess)) { if (verbose) message("deutsche-evergabe.de: no chromote session."); return(data.frame()) }
  on.exit(try(sess$close(), silent = TRUE), add = TRUE)
  ev <- function(js) tryCatch(sess$Runtime$evaluate(js)$result$value, error = function(e) NULL)
  count <- function() { n <- ev("document.querySelectorAll('a.BekSummary').length"); if (is.null(n)) -1L else n }
  # wait until the grid count is stable across two reads (>=min on first load)
  settle <- function(min = 0L) {
    prev <- -2L
    for (i in 1:40) { Sys.sleep(0.5); n <- count(); if (n >= min && n == prev) return(n); prev <- n }
    prev
  }
  sess$Page$navigate(paste0(DEUTSCHE_EVERGABE_BASE, "/Dashboards/Dashboard_off"))
  try(sess$Page$loadEventFired(), silent = TRUE)
  settle(min = 1L) # dashboard always loads with rows
  reachable <- ev(paste0("(function(){try{var el=document.querySelector('.dx-datagrid');",
                         "var r=el.closest('.dx-widget')||el;",
                         "return !!(window.jQuery && jQuery(r).dxDataGrid('instance'));}catch(e){return false;}})()"))
  if (!isTRUE(reachable)) {
    if (verbose) message("deutsche-evergabe.de: grid instance not reachable (layout changed?).")
    return(data.frame())
  }
  rows <- list(); seen <- character()
  for (st in status) {
    ct <- .DEUTSCHE_EVERGABE_CATS[[st]]
    if (!isTRUE(ev(.deutsche_evergabe_set_category_js(ct$id)))) {
      if (verbose) message(sprintf("deutsche-evergabe.de: Kategorie '%s' (%s) nicht setzbar.", st, ct$id))
      next
    }
    ev(.deutsche_evergabe_search_js("")) # clear any leftover filter from the previous category
    Sys.sleep(1); settle() # let the grid reload for the new category
    if (verbose) message(sprintf("deutsche-evergabe.de: Kategorie '%s' (%s) -> %s", st, ct$id, ct$typ))
    for (t in terms) {
      if (!isTRUE(ev(.deutsche_evergabe_search_js(t)))) next
      c1 <- count() # wait for the filtered grid to settle (count stable across two reads)
      for (k in 1:10) { Sys.sleep(0.3); c2 <- count(); if (identical(c1, c2)) break; c1 <- c2 }
      pg <- tryCatch(jsonlite::fromJSON(ev(.DEV_EXTRACT_JS)), error = function(e) NULL)
      if (is.null(pg) || !length(pg) || !nrow(pg)) next
      newr <- pg[nzchar(pg$title) & !(pg$guid %in% seen), , drop = FALSE]
      if (!nrow(newr)) next
      newr$Veroeffentlichungstyp <- ct$typ
      rows[[length(rows) + 1L]] <- newr
      seen <- c(seen, newr$guid)
      if (verbose) message(sprintf("deutsche-evergabe.de:   '%s' -> +%d (%d gesamt)", t, nrow(newr), length(seen)))
    }
  }
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

#' Deutsche eVergabe (deutsche-evergabe.de) connector (chromote, login-free)
#'
#' Renders the public Healy-Hudson dashboard grid with chromote, pages through it
#' and scores the hits ([score_layered()]); relevant tenders are enriched via the
#' login-free per-tender detail endpoint (Vergabestelle / Publikationsdatum /
#' Angebotsfrist / CPV). No API/RSS exists, so a browser render is required; the
#' result list carries no CPV/free text, so relevance is title-based.
#'
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param cpv_map CPV-to-group map (default [tender_cpv_map()]).
#' @param terms Search terms (default: minimal roots of the strong KWB keywords,
#'   [tender_keywords()]). The grid is searched per term (DevExpress
#'   `searchByText`) and the hits are unioned.
#' @param status Which notice classes to query via the dashboard category
#'   dropdown: `"aktuell"` (open tenders), `"geplant"` (Vorinformationen) and/or
#'   `"vergeben"` (Zuschlagsbekanntmachungen). Default: all three.
#' @param max_detail Cap on relevant tenders to enrich via the detail endpoint
#'   (default `Inf`).
#' @param relevant_only Return only relevant tenders (default `TRUE`).
#' @param verbose Print progress (default `TRUE`).
#' @return A scored tibble with `Plattform = "Deutsche eVergabe (deutsche-evergabe.de)"`.
#' @export
#' @examples
#' \dontrun{
#' deutsche_evergabe_tenders(status = "aktuell")
#' }
deutsche_evergabe_tenders <- function(keywords = tender_keywords(), cpv_map = tender_cpv_map(),
                                      terms = NULL, status = c("aktuell", "geplant", "vergeben"),
                                      max_detail = Inf, relevant_only = TRUE,
                                      verbose = TRUE) {
  if (is.null(terms)) terms <- .deutsche_evergabe_search_terms(keywords)
  raw <- deutsche_evergabe_scrape(terms = terms, status = status, verbose = verbose)
  if (!nrow(raw)) {
    if (verbose) message("deutsche-evergabe.de: no results.")
    return(data.frame())
  }
  raw$Kurzbezeichnung <- raw$title
  raw$Verfahrensart <- raw$art
  # Prefer the authoritative category tag from the scrape; fall back to the
  # <small> Verfahrensart text only where it is missing.
  art_typ <- ifelse(
    grepl("Vorinformation", raw$art, ignore.case = TRUE), "Geplante Ausschreibung",
    ifelse(grepl("vergeben|Zuschlag", raw$art, ignore.case = TRUE), "Vergebener Auftrag", "Ausschreibung"))
  raw$Veroeffentlichungstyp <- if (!is.null(raw$Veroeffentlichungstyp)) {
    ifelse(nzchar(raw$Veroeffentlichungstyp), raw$Veroeffentlichungstyp, art_typ)
  } else art_typ
  raw$Aktion <- sprintf("%s/verfahren/BekSummaryModal/%s?DashOff=true", DEUTSCHE_EVERGABE_BASE, raw$guid)
  raw$Beschreibung <- ""; raw$cpv <- ""
  raw$Vergabestelle <- ""; raw$Veroeffentlicht <- ""; raw$Frist <- ""
  scored <- score_layered(raw, title_cols = "Kurzbezeichnung", text_cols = "Beschreibung",
                          cpv_col = "cpv", keywords = keywords, cpv_map = cpv_map)
  scored$Plattform <- "Deutsche eVergabe (deutsche-evergabe.de)"
  n_rel <- sum(scored$is_relevant %in% TRUE)
  if (isTRUE(relevant_only)) scored <- scored[scored$is_relevant %in% TRUE, , drop = FALSE]
  if (nrow(scored)) {
    ua <- .deutsche_evergabe_ua
    h <- httr::handle(DEUTSCHE_EVERGABE_BASE)
    tryCatch(httr::GET(paste0(DEUTSCHE_EVERGABE_BASE, "/Dashboards/Dashboard_off"),
                       handle = h, httr::add_headers(`User-Agent` = ua)),
             error = function(e) NULL) # prime ASP.NET_SessionId
    for (i in seq_len(min(nrow(scored), max_detail))) {
      d <- .deutsche_evergabe_detail(scored$guid[i], h, ua)
      if (!is.null(d)) {
        scored$Vergabestelle[i] <- d$Vergabestelle
        scored$Veroeffentlicht[i] <- d$Veroeffentlicht
        scored$Frist[i] <- d$Frist
        scored$cpv[i] <- d$cpv
      }
    }
  }
  if (verbose) message("deutsche-evergabe.de: ", n_rel, " relevant of ", nrow(raw), " fetched.")
  scored
}
