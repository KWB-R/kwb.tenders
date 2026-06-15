# Notice-PDF enrichment (third relevance layer) --------------------------------
# Reads the published "Bekanntmachung" (notice) PDF(s) per tender. These are
# reachable after a plain LOGIN (no "am Verfahren teilnehmen" / no bidder
# registration), so this layer requires a logged-in session.

#' @noRd
empty_notice_cache <- function() {
  data.frame(tender_id = character(), notice_groups = character(),
             stringsAsFactors = FALSE)
}

#' Read / write the notice-screening cache
#' @param path Cache file path (`.rds`).
#' @param cache A cache data.frame (`tender_id`, `notice_groups`).
#' @return `read_notice_cache()` a data.frame (empty if absent);
#'   `write_notice_cache()` returns `path` invisibly.
#' @export
read_notice_cache <- function(path) {
  if (length(path) != 1L || is.na(path) || !file.exists(path)) {
    return(empty_notice_cache())
  }
  out <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.data.frame(out) && all(c("tender_id", "notice_groups") %in% names(out))) {
    out
  } else {
    empty_notice_cache()
  }
}

#' @rdname read_notice_cache
#' @export
write_notice_cache <- function(cache, path) {
  if (is.null(cache)) cache <- empty_notice_cache()
  saveRDS(cache, path)
  invisible(path)
}

#' Build a Cookie header string from the chromote session's cookies
#' @noRd
session_cookie_header <- function(session) {
  ck <- tryCatch({
    try(session$Network$enable(), silent = TRUE)
    session$Network$getAllCookies()$cookies
  }, error = function(e) NULL)
  if (length(ck) == 0L) return("")
  paste(vapply(ck, function(x) paste0(x$name, "=", x$value), character(1)), collapse = "; ")
}

#' Download a (login-protected) PDF using the session cookies and extract text
#' @noRd
download_pdf_text <- function(session, url, cookie = NULL) {
  if (is.null(cookie)) cookie <- session_cookie_header(session)
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)
  resp <- tryCatch(
    httr::GET(url,
              httr::add_headers(Cookie = cookie),
              httr::user_agent("kwb.tenders (https://github.com/KWB-R/kwb.tenders)"),
              httr::write_disk(tmp, overwrite = TRUE)),
    error = function(e) NULL
  )
  if (is.null(resp) || httr::status_code(resp) != 200) return("")
  ct <- httr::headers(resp)[["content-type"]]
  if (!is.null(ct) && !grepl("pdf", ct, ignore.case = TRUE)) return("") # login HTML, not a PDF
  tryCatch(paste(pdftools::pdf_text(tmp), collapse = "\n"), error = function(e) "")
}

#' Find announcement (Bekanntmachung) PDF links on a logged-in detail page
#' @noRd
tender_notice_links <- function(session, detail_url, wait = 10) {
  session$Page$navigate(detail_url)
  t0 <- Sys.time()
  repeat {
    Sys.sleep(0.5)
    if (identical(cdp_eval(session, "document.readyState"), "complete")) break
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > wait) break
  }
  Sys.sleep(1)
  hrefs <- cdp_eval(session, "(function(){return Array.from(document.querySelectorAll('a')).map(function(a){return a.href||'';}).join('\\n');})()")
  ll <- if (is.character(hrefs)) strsplit(hrefs, "\n", fixed = TRUE)[[1]] else character()
  unique(grep("announcements/.*\\.pdf", ll, value = TRUE, ignore.case = TRUE, perl = TRUE))
}

#' Fetch and extract the text of a tender's announcement (notice) PDF(s)
#'
#' Opens the (logged-in) detail page, finds the published Bekanntmachung PDF
#' link(s) and returns their combined extracted text. Requires a logged-in
#' session (see [vmp_bb_login()]); no bidder registration needed.
#'
#' @param session A logged-in session from [vmp_bb_session()].
#' @param detail_url The tender's detail URL (the `Aktion` column).
#' @param max_pdfs Maximum number of PDFs to read per tender (default `3`).
#' @return The combined PDF text (empty string if none/!accessible).
#' @export
#' @examples
#' \dontrun{
#' s <- vmp_bb_session(); vmp_bb_login(s)
#' tender_notice_text(s, tenders$Aktion[1])
#' }
tender_notice_text <- function(session, detail_url, max_pdfs = 3) {
  links <- tender_notice_links(session, detail_url)
  if (length(links) == 0L) return("")
  links <- utils::head(links, max_pdfs)
  cookie <- session_cookie_header(session)
  txt <- vapply(links, function(u) download_pdf_text(session, u, cookie), character(1))
  paste(txt[nzchar(txt)], collapse = "\n")
}

#' Enrich tenders with a notice-PDF (Bekanntmachung) relevance layer
#'
#' For ongoing tenders not yet cached, reads the published announcement PDF(s)
#' via the logged-in `session` and matches the keyword groups against the text.
#' Adds a `notice_groups` column, merges it into `groups`/`is_relevant` and adds
#' the `notice` source to `match_source`. Requires a logged-in session. The
#' updated cache is returned as `attr(result, "notice_cache")`.
#'
#' @param session A logged-in session from [vmp_bb_session()].
#' @param tenders A tibble (typically already passed through
#'   [enrich_with_details()]).
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param ongoing_only Only screen ongoing tenders (default `TRUE`).
#' @param max_notice Maximum number of *new* notice PDFs to read (default `Inf`).
#' @param delay Seconds between tenders (default `0.3`).
#' @param cache Notice cache from a previous run (see [read_notice_cache()]).
#' @return `tenders` with the notice layer merged in.
#' @export
enrich_with_notice <- function(session, tenders, keywords = tender_keywords(),
                               ongoing_only = TRUE, max_notice = Inf, delay = 0.3,
                               cache = NULL) {
  n <- nrow(tenders)
  tenders$notice_groups <- rep("", n)
  if (n == 0L) {
    attr(tenders, "notice_cache") <- empty_notice_cache()
    return(tenders)
  }
  if (is.null(cache)) cache <- empty_notice_cache()

  ids <- tender_ids(tenders)
  cidx <- match(ids, cache$tender_id)
  have <- !is.na(cidx)
  tenders$notice_groups[have] <- cache$notice_groups[cidx[have]]

  base_pick <- if (isTRUE(ongoing_only)) which(is_ongoing(tenders)) else seq_len(n)
  pick <- base_pick[!have[base_pick]]
  if (length(pick) > max_notice) pick <- pick[seq_len(max_notice)]
  urls <- if (!is.null(tenders$Aktion)) as.character(tenders$Aktion) else rep(NA_character_, n)

  message(sprintf("Notice layer: %d cached, reading %d new notice PDF(s)...",
                  sum(have), length(pick)))
  fetched <- logical(n)
  for (k in seq_along(pick)) {
    i <- pick[k]
    u <- urls[i]
    if (is.na(u) || !nzchar(u)) next
    txt <- tryCatch(tender_notice_text(session, u), error = function(e) "")
    if (nzchar(txt)) {
      sc <- score_relevance(data.frame(t = txt, stringsAsFactors = FALSE), keywords = keywords)
      tenders$notice_groups[i] <- sc$groups[1]
    }
    fetched[i] <- TRUE
    if (delay > 0) Sys.sleep(delay)
    if (k %% 10 == 0) message(sprintf("  ...%d/%d", k, length(pick)))
  }

  # Merge notice into groups/match_source (alongside title/detail/cpv if present).
  col <- function(nm) if (is.null(tenders[[nm]])) rep("", n) else as.character(tenders[[nm]])
  split_g <- function(x) {
    g <- unlist(strsplit(x, ", ", fixed = TRUE))
    g[nzchar(g)]
  }
  cur <- col("groups")
  ng <- tenders$notice_groups
  tenders$groups <- vapply(seq_len(n), function(i) {
    paste(unique(split_g(c(cur[i], ng[i]))), collapse = ", ")
  }, character(1))
  th <- col("matched_keywords"); dg <- col("detail_groups"); cg <- col("cpv_groups")
  tenders$match_source <- vapply(seq_len(n), function(i) {
    paste(c(
      if (nzchar(th[i])) "title",
      if (nzchar(dg[i])) "detail",
      if (nzchar(cg[i])) "cpv",
      if (nzchar(ng[i])) "notice"
    ), collapse = "+")
  }, character(1))
  tenders$is_relevant <- nzchar(tenders$groups)

  screened <- have | fetched
  upd <- data.frame(tender_id = ids[screened], notice_groups = tenders$notice_groups[screened],
                    stringsAsFactors = FALSE)
  upd <- upd[nzchar(upd$tender_id) & !duplicated(upd$tender_id), , drop = FALSE]
  attr(tenders, "notice_cache") <- upd
  tenders
}
