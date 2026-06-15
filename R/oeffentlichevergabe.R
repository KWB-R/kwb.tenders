# Connector: Datenservice Oeffentlicher Einkauf (oeffentlichevergabe.de) --------
# Login-free open-data API. Bulk download of all notices published on a given day
# as an OCDS .zip, then filter locally with the shared relevance pipeline.
#   GET /api/notice-exports?pubDay=YYYY-MM-DD&format=ocds.zip
# Aggregates Bund + Laender + Kommunen, so one connector covers many portals.

#' @noRd
.oeffentlichevergabe_chr <- function(x) {
  if (is.null(x)) return("")
  if (is.list(x)) {
    if (!is.null(x[["de"]])) return(.oeffentlichevergabe_chr(x[["de"]]))
    x <- unlist(x, use.names = FALSE)
    if (!length(x)) return("")
    return(as.character(x)[1])
  }
  if (length(x) == 0L || is.na(x[1])) return("")
  as.character(x)[1]
}

#' @noRd
.oeffentlichevergabe_pluck <- function(x, ...) {
  for (k in c(...)) {
    if (is.null(x) || is.null(x[[k]])) return(NULL)
    x <- x[[k]]
  }
  x
}

#' @noRd
.oeffentlichevergabe_is_cpv <- function(cl) {
  if (is.null(cl)) return(FALSE)
  identical(toupper(.oeffentlichevergabe_chr(cl[["scheme"]])), "CPV") ||
    grepl("^[0-9]{8}", gsub("[^0-9]", "", .oeffentlichevergabe_chr(cl[["id"]])))
}

#' Collect CPV ids from an OCDS items list (classification + additionalClassifications)
#' @noRd
.oeffentlichevergabe_cpv_from_items <- function(items) {
  out <- character()
  if (!length(items)) return(out)
  for (it in items) {
    cl <- it[["classification"]]
    if (.oeffentlichevergabe_is_cpv(cl)) out <- c(out, .oeffentlichevergabe_chr(cl[["id"]]))
    ac <- it[["additionalClassifications"]]
    if (length(ac)) for (a in ac) if (.oeffentlichevergabe_is_cpv(a)) out <- c(out, .oeffentlichevergabe_chr(a[["id"]]))
  }
  out
}

#' Parse one OCDS release into a standard tender row
#' @noRd
oeffentlichevergabe_parse_release <- function(rel) {
  ten <- rel[["tender"]]
  title <- .oeffentlichevergabe_chr(.oeffentlichevergabe_pluck(ten, "title"))
  desc <- .oeffentlichevergabe_chr(.oeffentlichevergabe_pluck(ten, "description"))

  buyer <- .oeffentlichevergabe_chr(.oeffentlichevergabe_pluck(rel, "buyer", "name"))
  parties <- rel[["parties"]]
  if (!nzchar(buyer) && length(parties)) {
    for (p in parties) if ("buyer" %in% unlist(p[["roles"]])) { buyer <- .oeffentlichevergabe_chr(p[["name"]]); break }
    if (!nzchar(buyer)) buyer <- .oeffentlichevergabe_chr(.oeffentlichevergabe_pluck(parties[[1]], "name"))
  }
  ort <- ""
  if (length(parties)) for (p in parties) {
    a <- p[["address"]]
    if (!is.null(a)) { ort <- .oeffentlichevergabe_chr(a[["locality"]]); if (!nzchar(ort)) ort <- .oeffentlichevergabe_chr(a[["region"]]); if (nzchar(ort)) break }
  }

  # Deadline: tender-level, else first lot that carries one.
  deadline <- .oeffentlichevergabe_chr(.oeffentlichevergabe_pluck(ten, "tenderPeriod", "endDate"))
  if (!nzchar(deadline) && length(ten[["lots"]])) {
    for (lo in ten[["lots"]]) {
      dd <- .oeffentlichevergabe_chr(.oeffentlichevergabe_pluck(lo, "tenderPeriod", "endDate"))
      if (nzchar(dd)) { deadline <- dd; break }
    }
  }

  # CPV: tender classification + item/lot-item classifications (scheme CPV only).
  cpv <- character()
  mc <- .oeffentlichevergabe_pluck(ten, "classification")
  if (.oeffentlichevergabe_is_cpv(mc)) cpv <- c(cpv, .oeffentlichevergabe_chr(mc[["id"]]))
  cpv <- c(cpv, .oeffentlichevergabe_cpv_from_items(ten[["items"]]))
  if (length(ten[["lots"]])) for (lo in ten[["lots"]]) cpv <- c(cpv, .oeffentlichevergabe_cpv_from_items(lo[["items"]]))
  cpv <- unique(cpv[nzchar(cpv)])

  # Detail link: a direct document URL from the source portal when the notice
  # carries one, otherwise the canonical notice page on oeffentlichevergabe.de.
  # The OCDS release id is the notice UUID and
  # https://oeffentlichevergabe.de/ui/de/notices/<id> is its public detail page;
  # `documents[].url` is frequently absent, which is why federal notices
  # previously had no "Details" link in the report.
  url <- ""
  docs <- ten[["documents"]]
  if (length(docs)) url <- .oeffentlichevergabe_chr(.oeffentlichevergabe_pluck(docs[[1]], "url"))
  if (!nzchar(url)) {
    notice_id <- .oeffentlichevergabe_chr(rel[["id"]])
    if (nzchar(notice_id)) {
      url <- sprintf("https://oeffentlichevergabe.de/ui/de/notices/%s", notice_id)
    }
  }

  tag <- tolower(paste(unlist(rel[["tag"]]), collapse = ","))
  typ <- if (grepl("planning", tag)) "Geplante Ausschreibung" else "Ausschreibung"

  data.frame(
    Kurzbezeichnung = title, Beschreibung = desc, Vergabestelle = buyer,
    Erfuellungsort = ort, Frist = deadline,
    Veroeffentlicht = substr(.oeffentlichevergabe_chr(rel[["date"]]), 1, 10),
    cpv = paste(cpv, collapse = ", "),
    Aktion = url, Veroeffentlichungstyp = typ, ocid = .oeffentlichevergabe_chr(rel[["ocid"]]),
    stringsAsFactors = FALSE
  )
}

#' Download + parse one day of OCDS notices
#' @noRd
oeffentlichevergabe_fetch_day <- function(day, verbose = TRUE) {
  url <- sprintf("https://oeffentlichevergabe.de/api/notice-exports?pubDay=%s&format=ocds.zip", day)
  zip <- tempfile(fileext = ".zip")
  on.exit(unlink(zip), add = TRUE)
  resp <- httr::GET(url, httr::write_disk(zip, overwrite = TRUE),
                    httr::user_agent("kwb.tenders (https://github.com/KWB-R/kwb.tenders)"))
  if (httr::status_code(resp) != 200L) {
    if (verbose) message("  ", day, ": HTTP ", httr::status_code(resp))
    return(NULL)
  }
  exdir <- file.path(tempdir(), paste0("oeffentlichevergabe_", gsub("[^0-9]", "", day)))
  dir.create(exdir, showWarnings = FALSE)
  on.exit(unlink(exdir, recursive = TRUE), add = TRUE)
  files <- tryCatch(utils::unzip(zip, exdir = exdir), error = function(e) character())
  js <- files[grepl("\\.json$", files, ignore.case = TRUE)]
  if (length(js) == 0L) {
    if (verbose) message("  ", day, ": no JSON extracted (zip empty or needs a robust unzip)")
    return(NULL)
  }
  rows <- list()
  for (f in js) {
    doc <- tryCatch(jsonlite::fromJSON(f, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(doc)) next
    rels <- doc[["releases"]]
    if (is.null(rels) && !is.null(doc[["tender"]])) rels <- list(doc)
    if (is.null(rels) && !is.null(doc[["records"]])) {
      rels <- lapply(doc[["records"]], function(rec) {
        if (!is.null(rec[["compiledRelease"]])) rec[["compiledRelease"]]
        else if (length(rec[["releases"]])) rec[["releases"]][[1]] else NULL
      })
    }
    for (rel in rels) if (!is.null(rel)) rows[[length(rows) + 1L]] <- oeffentlichevergabe_parse_release(rel)
  }
  if (verbose) message("  ", day, ": ", length(rows), " notices")
  if (length(rows)) do.call(rbind, rows) else NULL
}

#' Screen the Datenservice Oeffentlicher Einkauf (oeffentlichevergabe.de)
#'
#' Login-free connector: downloads the OCDS notice export for the last `days`
#' days, parses each notice and scores it with [score_layered()] (title full
#' rule, description strong-only, CPV mapped). Returns relevant tenders with a
#' `Plattform` column, ready for [combine_tenders()] / [write_tender_report()].
#'
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param cpv_map CPV-to-group map (default [tender_cpv_map()]).
#' @param days Number of past days to fetch (default `7`; the API serves data up
#'   to the previous day).
#' @param end Most recent date to consider (default `Sys.Date()`).
#' @param relevant_only Keep only relevant tenders (default `TRUE`).
#' @param verbose Print per-day progress (default `TRUE`).
#' @return A scored tibble of (relevant) tenders; empty data frame if none.
#' @export
#' @examples
#' \dontrun{
#' oeffentlichevergabe_tenders(days = 3)
#' }
oeffentlichevergabe_tenders <- function(keywords = tender_keywords(),
                                        cpv_map = tender_cpv_map(),
                                        days = 7, end = Sys.Date(),
                                        relevant_only = TRUE, verbose = TRUE) {
  if (verbose) message("Oeffentliche Vergabe: fetching ", days, " day(s) of OCDS notices...")
  parts <- list()
  for (d in seq_len(days)) {
    day <- format(as.Date(end) - d, "%Y-%m-%d")
    p <- tryCatch(oeffentlichevergabe_fetch_day(day, verbose), error = function(e) {
      if (verbose) message("  ", day, " failed: ", conditionMessage(e)); NULL
    })
    if (!is.null(p) && nrow(p) > 0L) parts[[length(parts) + 1L]] <- p
  }
  if (length(parts) == 0L) return(data.frame())
  tenders <- do.call(rbind, parts)
  scored <- score_layered(tenders, title_cols = "Kurzbezeichnung",
                          text_cols = "Beschreibung", cpv_col = "cpv",
                          keywords = keywords, cpv_map = cpv_map)
  scored$Plattform <- "Oeffentliche Vergabe (Bund)"
  if (isTRUE(relevant_only)) scored <- scored[scored$is_relevant %in% TRUE, , drop = FALSE]
  if (verbose) message("Oeffentliche Vergabe: ", nrow(scored), " relevant of ", nrow(tenders), " notices.")
  scored
}
