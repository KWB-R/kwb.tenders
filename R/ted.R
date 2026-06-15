# Connector: TED (Tenders Electronic Daily, EU) --------------------------------
# Login-free EU API: POST /v3/notices/search with an expert query + a REQUIRED
# `fields` list (valid eForms field ids). We full-text query German water terms
# restricted to a country, then score locally with score_layered().

#' @noRd
.ted_text <- function(x) {
  if (is.null(x)) return("")
  if (is.list(x)) {
    if (!is.null(x[["DEU"]])) return(.ted_text(x[["DEU"]]))
    if (!is.null(x[["ENG"]])) return(.ted_text(x[["ENG"]]))
    parts <- vapply(x, .ted_text, character(1))
    return(paste(unique(parts[nzchar(parts)]), collapse = " | "))
  }
  x <- x[!is.na(x)]
  if (!length(x)) return("")
  paste(unique(as.character(x)), collapse = " | ")
}

#' @noRd
.ted_link <- function(notice) {
  h <- notice[["links"]][["html"]]
  if (is.null(h)) h <- notice[["links"]][["pdf"]]
  if (is.null(h)) return("")
  if (!is.null(h[["DEU"]])) return(.ted_text(h[["DEU"]]))
  if (!is.null(h[["ENG"]])) return(.ted_text(h[["ENG"]]))
  .ted_text(h[[1]])
}

#' Extract the real (German) title from TED's multilingual "Country - Type - Title"
#' @noRd
.ted_title <- function(x) {
  s <- .ted_text(x)
  if (!nzchar(s)) return("")
  first <- strsplit(s, " | ", fixed = TRUE)[[1]][1]      # one language variant
  seg <- strsplit(first, " – ", fixed = TRUE)[[1]]  # split on en-dash " - "
  trimws(seg[length(seg)])                               # the actual project title
}

#' Default German full-text query terms for TED (water-specific strong terms)
#' @noRd
ted_default_terms <- function() {
  c("Grundwasser", "Wassermanagement", "Wassermengenmanagement", "Uferfiltration",
    "Hydrogeologie", "Grundwassermessstelle", "Trinkwassergewinnung", "Wasserwerk",
    "Kläranlage", "Wasseraufbereitung", "Abwasserbehandlung", "Klärschlamm",
    "Wasserwiederverwendung", "Regenwasserbewirtschaftung", "Niederschlagswasser",
    "Trinkwasserhygiene")
}

#' Parse one TED notice into a standard tender row
#' @noRd
ted_parse_notice <- function(nt) {
  cpv <- unlist(nt[["classification-cpv"]], use.names = FALSE)
  cpv <- unique(cpv[!is.na(cpv) & nzchar(cpv)])
  dl <- unlist(nt[["deadline-receipt-tender-date-lot"]], use.names = FALSE)
  dl <- dl[!is.na(dl) & nzchar(dl)]
  ntype <- tolower(.ted_text(nt[["notice-type"]]))
  typ <- if (grepl("pin|prior|planning", ntype)) "Geplante Ausschreibung" else "Ausschreibung"
  data.frame(
    Kurzbezeichnung = .ted_title(nt[["notice-title"]]),
    Beschreibung = trimws(paste(.ted_text(nt[["description-proc"]]),
                                .ted_text(nt[["description-lot"]]))),
    Vergabestelle = .ted_text(nt[["buyer-name"]]),
    Frist = if (length(dl)) dl[1] else "",
    cpv = paste(cpv, collapse = ", "),
    Aktion = .ted_link(nt),
    Veroeffentlichungstyp = typ,
    publication_number = .ted_text(nt[["publication-number"]]),
    stringsAsFactors = FALSE
  )
}

#' Screen TED (Tenders Electronic Daily) for relevant tenders
#'
#' Login-free EU connector. Full-text queries `terms` (German water terms)
#' restricted to `countries`, fetches matching notices and scores them with
#' [score_layered()]. Returns relevant tenders with a `Plattform` column.
#'
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param cpv_map CPV-to-group map (default [tender_cpv_map()]).
#' @param terms Full-text query terms (default: a built-in water-term set).
#' @param countries Place-of-performance country codes (default `"DEU"`;
#'   `NULL`/`character()` for EU-wide).
#' @param since_days Only notices published within the last N days (default `90`,
#'   via TED `today(-N)`); `NULL` to disable. Past-deadline notices are dropped too.
#' @param scope Notice scope (`"ACTIVE"`, `"ALL"`, `"LATEST"`; default `"ACTIVE"`).
#' @param max_pages,page_size Pagination caps (default `5` x `100`).
#' @param relevant_only Keep only relevant tenders (default `TRUE`).
#' @param verbose Print progress (default `TRUE`).
#' @return A scored tibble of (relevant) tenders; empty data frame if none.
#' @export
#' @examples
#' \dontrun{
#' ted_tenders(max_pages = 1)
#' }
ted_tenders <- function(keywords = tender_keywords(), cpv_map = tender_cpv_map(),
                        terms = ted_default_terms(), countries = "DEU", since_days = 90,
                        scope = "ACTIVE", max_pages = 5, page_size = 100,
                        relevant_only = TRUE, verbose = TRUE) {
  terms <- terms[nzchar(terms)]
  query <- sprintf("(%s)", paste(sprintf('FT ~ "%s"', terms), collapse = " OR "))
  if (length(countries)) {
    query <- sprintf("%s AND place-of-performance IN (%s)", query, paste(countries, collapse = " "))
  }
  if (!is.null(since_days) && since_days > 0) { # only recently published notices
    query <- sprintf("%s AND publication-date >= today(-%d)", query, as.integer(since_days))
  }
  fields <- list("publication-number", "notice-title", "description-proc", "description-lot",
                 "buyer-name", "classification-cpv", "deadline-receipt-tender-date-lot", "notice-type")
  if (verbose) message("TED: query = ", query)

  rows <- list()
  page <- 1L
  repeat {
    body <- list(query = query, fields = fields, page = page, limit = page_size, scope = scope)
    resp <- httr::POST("https://api.ted.europa.eu/v3/notices/search",
                       httr::add_headers(`Content-Type` = "application/json", Accept = "application/json"),
                       body = jsonlite::toJSON(body, auto_unbox = TRUE))
    if (httr::status_code(resp) != 200L) {
      msg <- tryCatch(httr::content(resp, as = "parsed")$message, error = function(e) "")
      if (verbose) message("TED: HTTP ", httr::status_code(resp), " - ", msg)
      break
    }
    res <- httr::content(resp, as = "parsed", type = "application/json")
    nl <- res[["notices"]]
    if (!length(nl)) break
    for (nt in nl) rows[[length(rows) + 1L]] <- ted_parse_notice(nt)
    total <- res[["totalNoticeCount"]]
    if (is.null(total)) total <- length(nl)
    if (verbose) message("TED: page ", page, " (+", length(nl), "), total ", total)
    if (page * page_size >= total || page >= max_pages) break
    page <- page + 1L
  }
  if (!length(rows)) return(data.frame())
  tenders <- do.call(rbind, rows)
  scored <- score_layered(tenders, title_cols = "Kurzbezeichnung", text_cols = "Beschreibung",
                          cpv_col = "cpv", keywords = keywords, cpv_map = cpv_map)
  scored$Plattform <- "TED (EU)"
  if (nrow(scored)) { # drop notices whose submission deadline has already passed
    fr <- suppressWarnings(as.Date(substr(scored$Frist, 1, 10)))
    scored <- scored[is.na(fr) | fr >= Sys.Date(), , drop = FALSE]
  }
  if (isTRUE(relevant_only)) scored <- scored[scored$is_relevant %in% TRUE, , drop = FALSE]
  if (verbose) message("TED: ", nrow(scored), " relevant of ", nrow(tenders), " fetched.")
  scored
}
