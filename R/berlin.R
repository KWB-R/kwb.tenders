# Vergabeplattform Berlin (berlin.de) -------------------------------------------
# Berlin runs iTWO tender (RIB Software), NOT cosinex. We read its public notices
# over plain HTTP (no browser, login-free). The RSS feed is primary: it has clean
# titles plus the iTWO detail link per notice (~50 newest, a few days -- enough
# for a regularly-run screening). The HTML list (?start=N, 10/page) can add older
# notices for a deeper backfill, but that page exposes no per-notice link (titles
# are plain text, click-through is JS), so HTML-only items have no detail URL.

BERLIN_LIST_URL <- "https://www.berlin.de/vergabeplattform/veroeffentlichungen/bekanntmachungen/"
BERLIN_FEED_URL <- "https://www.berlin.de/vergabeplattform/veroeffentlichungen/bekanntmachungen/feed.rss"

#' HTTP GET returning the response body as text ("" on any failure)
#' @noRd
berlin_fetch <- function(url) {
  resp <- tryCatch(
    httr::GET(url, httr::user_agent("kwb.tenders (https://github.com/KWB-R/kwb.tenders)")),
    error = function(e) NULL
  )
  if (is.null(resp) || httr::status_code(resp) != 200L) return("")
  httr::content(resp, as = "text", encoding = "UTF-8")
}

#' Extract per-item metadata blocks ("Verfahrensart: ... Online seit: <date>")
#' from rendered page/feed text; returns a data.frame (verf, ort, online, frist).
#' @noRd
berlin_meta_blocks <- function(txt) {
  blocks <- regmatches(
    txt, gregexpr("(?s)Verfahrensart:.*?Online seit:\\s*\\d{2}\\.\\d{2}\\.\\d{4}", txt, perl = TRUE)
  )[[1]]
  if (length(blocks) == 0L) return(data.frame())
  one <- function(b) {
    verf <- regmatches(b, regexpr("Verfahrensart:\\s*[^\n<|]+", b))
    verf <- if (length(verf)) trimws(sub("Verfahrensart:\\s*", "", verf)) else ""
    ort <- regmatches(b, regexpr("Ausf.{0,2}hrungsort:\\s*[^\n<|]+", b))
    ort <- if (length(ort)) trimws(sub("^[^:]+:\\s*", "", ort)) else ""
    online <- regmatches(b, regexpr("Online seit:\\s*\\d{2}\\.\\d{2}\\.\\d{4}", b))
    online <- if (length(online)) sub(".*?(\\d{2}\\.\\d{2}\\.\\d{4}).*", "\\1", online) else ""
    alld <- unlist(regmatches(b, gregexpr("\\d{2}\\.\\d{2}\\.\\d{4}", b)))
    frist <- setdiff(alld, online)
    frist <- if (length(frist)) frist[1] else NA_character_
    data.frame(verf = verf, ort = ort, online = online, frist = frist, stringsAsFactors = FALSE)
  }
  do.call(rbind, lapply(blocks, one))
}

#' Parse one HTML listing page into raw rows (title, link, verf, ort, dates)
#'
#' Each notice renders its metadata as label/value on separate lines without
#' colons ("Verfahrensart\\nOffenes Verfahren (VgV)"; only "Online seit:" is
#' inline), with the title on the line directly above "Verfahrensart". The detail
#' link is not an `<a>` (click-through is JS) but a `data-href` attribute holding
#' the iTWO URL (".../tenderId/<n>"); we read those in document order and zip
#' them to the metadata blocks (one each per notice).
#' @noRd
berlin_parse_listing <- function(html) {
  doc <- tryCatch(rvest::read_html(html), error = function(e) NULL)
  if (is.null(doc)) return(data.frame())
  lines <- trimws(unlist(strsplit(rvest::html_text2(doc), "\n")))
  lines <- lines[nzchar(lines)]
  vi <- which(lines == "Verfahrensart") # one metadata block per notice
  if (!length(vi)) return(data.frame())
  online_idx <- grep("^Online seit", lines)
  dh <- rvest::html_attr(rvest::html_elements(doc, "[data-href]"), "data-href")
  dh <- dh[!is.na(dh) & grepl("tenderId|DetailsByPlatform", dh)] # detail link per notice
  zip_ok <- length(dh) == length(vi) # one data-href per metadata block, same order
  rows <- lapply(seq_along(vi), function(k) {
    i <- vi[k]
    oi <- online_idx[online_idx >= i][1]
    if (is.na(oi) || i < 2L) return(NULL)
    block <- lines[i:oi]
    title <- lines[i - 1L] # title sits directly above "Verfahrensart"
    if (grepl("^(iTWO tender|Zu den Unterlagen|Details ?zu|Details$)", title) && i >= 3L) {
      title <- lines[i - 2L]
    }
    verf <- if (length(block) >= 2L) block[2L] else ""
    ko <- grep("^Ausf.{0,2}hrungsort$", block)
    ort <- if (length(ko) && ko[1] < length(block)) block[ko[1] + 1L] else ""
    online <- sub(".*?(\\d{2}\\.\\d{2}\\.\\d{4}).*", "\\1", block[length(block)])
    alld <- unlist(regmatches(block, gregexpr("\\d{2}\\.\\d{2}\\.\\d{4}", block)))
    frist <- setdiff(alld, online)
    frist <- if (length(frist)) frist[1] else NA_character_
    href <- if (zip_ok) dh[k] else ""
    data.frame(title = title, link = href, verf = verf, ort = ort,
               online = online, frist = frist, stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

#' Parse the RSS feed into the same raw rows (fallback when HTML parsing fails)
#' @noRd
berlin_parse_feed <- function(xml) {
  doc <- tryCatch(xml2::read_xml(xml), error = function(e) NULL)
  if (is.null(doc)) return(data.frame())
  items <- xml2::xml_find_all(doc, ".//item")
  if (length(items) == 0L) return(data.frame())
  fld <- function(it, tag) xml2::xml_text(xml2::xml_find_first(it, tag))
  rows <- lapply(items, function(it) {
    desc <- fld(it, "./description")
    m <- berlin_meta_blocks(desc)
    if (!nrow(m)) m <- data.frame(verf = "", ort = "", online = "", frist = NA_character_,
                                  stringsAsFactors = FALSE)
    data.frame(title = trimws(fld(it, "./title")), link = trimws(fld(it, "./link")),
               m[1, , drop = FALSE], stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

#' Turn raw Berlin rows into a scored-ready tender tibble (shared by HTML + RSS)
#' @noRd
berlin_make_tenders <- function(raw) {
  if (!nrow(raw)) return(data.frame())
  has_cpv <- grepl("^\\s*\\d{8}", raw$title)
  cpv <- ifelse(has_cpv, sub("^\\s*(\\d{8}-?\\d?).*", "\\1", raw$title), "")
  kurz <- trimws(sub("^\\s*\\d{8}-?\\d?\\s*", "", raw$title))
  typ <- rep("Ausschreibung", nrow(raw))
  blob <- paste(raw$title, raw$verf)
  typ[grepl("vorinformation|geplant", blob, ignore.case = TRUE)] <- "Geplante Ausschreibung"
  typ[grepl("vergeben|zuschlag|ex post", blob, ignore.case = TRUE)] <- "Vergebener Auftrag"
  data.frame(
    Kurzbezeichnung = kurz,
    Beschreibung = trimws(paste(raw$verf, raw$ort)),
    Vergabestelle = "",
    Erfuellungsort = raw$ort,
    Veroeffentlicht = .format_iso_date(raw$online),
    Frist = .format_iso_date(raw$frist),
    cpv = cpv,
    Typ = raw$verf,
    Aktion = raw$link,
    Veroeffentlichungstyp = typ,
    stringsAsFactors = FALSE
  )
}

#' Vergabeplattform Berlin connector (HTTP, login-free)
#'
#' Reads the Berlin notices (berlin.de, iTWO tender backend) over HTTP and scores
#' them ([score_layered()]). The paginated HTML list (`?start=N`) is the primary
#' source: it covers the full look-back window and carries the iTWO detail link
#' per notice in a `data-href` attribute, with a date-based early stop. If the
#' HTML cannot be parsed it falls back to the RSS feed (latest ~50), which is also
#' used to backfill any missing links. No browser and no login required.
#'
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param cpv_map CPV-to-group map (default [tender_cpv_map()]).
#' @param since_days Stop paging once a page is entirely older than this many days
#'   (the list is newest-first; default `30`). `NULL` pages up to `max_pages`.
#' @param max_pages Safety cap on pages fetched (default `60`; 10 notices/page).
#' @param relevant_only Return only relevant tenders (default `TRUE`).
#' @param verbose Print progress (default `TRUE`).
#' @return A scored tibble with `Plattform = "Vergabeplattform Berlin"`.
#' @export
#' @examples
#' \dontrun{
#' berlin_tenders(since_days = 30)
#' }
berlin_tenders <- function(keywords = tender_keywords(), cpv_map = tender_cpv_map(),
                           since_days = 30, max_pages = 60,
                           relevant_only = TRUE, verbose = TRUE) {
  cutoff <- if (!is.null(since_days)) Sys.Date() - as.integer(since_days) else NULL
  pages <- list()
  start <- 0L
  for (p in seq_len(max_pages)) {
    raw <- berlin_parse_listing(berlin_fetch(paste0(BERLIN_LIST_URL, "?start=", start)))
    if (!nrow(raw)) break
    pages[[length(pages) + 1L]] <- raw
    if (verbose) message(sprintf("Berlin: page %02d (+%d notices)", p, nrow(raw)))
    if (!is.null(cutoff)) {
      d <- .parse_pub_date(raw$online)
      if (length(d) && all(!is.na(d)) && all(d < cutoff)) break
    }
    if (nrow(raw) < 10L) break # last page
    if (p == max_pages && verbose) message("Berlin: hit max_pages cap (", max_pages, ").")
    start <- start + 10L
  }
  raw <- if (length(pages)) do.call(rbind, pages) else data.frame()
  if (!nrow(raw)) { # HTML unparsable -> RSS feed (also carries the iTWO links)
    if (verbose) message("Berlin: HTML empty -> RSS fallback.")
    raw <- berlin_parse_feed(berlin_fetch(BERLIN_FEED_URL))
  } else if (any(!nzchar(raw$link))) { # backfill any missing links from the RSS by title
    rss <- berlin_parse_feed(berlin_fetch(BERLIN_FEED_URL))
    if (nrow(rss)) {
      miss <- which(!nzchar(raw$link))
      raw$link[miss] <- rss$link[match(raw$title[miss], rss$title)]
      raw$link[is.na(raw$link)] <- ""
    }
  }
  if (!nrow(raw)) {
    if (verbose) message("Berlin: no notices fetched.")
    return(data.frame())
  }
  tenders <- berlin_make_tenders(raw)
  scored <- score_layered(tenders, title_cols = "Kurzbezeichnung", text_cols = "Beschreibung",
                          cpv_col = "cpv", keywords = keywords, cpv_map = cpv_map)
  scored$Plattform <- "Vergabeplattform Berlin"
  n_rel <- sum(scored$is_relevant %in% TRUE)
  if (isTRUE(relevant_only)) scored <- scored[scored$is_relevant %in% TRUE, , drop = FALSE]
  if (verbose) message("Berlin: ", n_rel, " relevant of ", nrow(tenders), " fetched.")
  scored
}
