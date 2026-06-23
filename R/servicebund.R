# service.bund.de Ausschreibungen ----------------------------------------------
# The federal service portal aggregates tender notices from Bund/Laender/Kommunen.
# It is a *separate* aggregator from the Datenservice (oeffentlichevergabe.de) --
# a sample showed ~half of its notices are not in the Datenservice (esp. below
# threshold / municipal). Read login-free over HTTP via its public RSS feeds; no
# CPV is provided, so scoring is title/text-based. Awarded contracts have their
# own feed and are labelled "Vergebener Auftrag".

SERVICEBUND_FEEDS <- c(
  "Ausschreibung" = "https://www.service.bund.de/Content/Globals/Functions/RSSFeed/RSSGenerator_Ausschreibungen.xml",
  "Vergebener Auftrag" = "https://www.service.bund.de/Content/Globals/Functions/RSSFeed/RSSGenerator_Vergebene_Auftraege.xml"
)

#' HTTP GET returning the body as text ("" on any failure)
#' @noRd
.servicebund_fetch <- function(url) {
  resp <- tryCatch(
    httr::GET(url, httr::user_agent("kwb.tenders (https://github.com/KWB-R/kwb.tenders)")),
    error = function(e) NULL
  )
  if (is.null(resp) || httr::status_code(resp) != 200L) return("")
  httr::content(resp, as = "text", encoding = "UTF-8")
}

#' Parse an RFC822 pubDate ("Tue, 23 Jun 2026 13:30:00 +0200") to ISO `YYYY-MM-DD`
#' @noRd
.servicebund_pubdate <- function(x) {
  m <- regmatches(x, regexec("(\\d{1,2})\\s+([A-Za-z]{3})\\s+(\\d{4})", x))
  vapply(m, function(g) {
    if (length(g) < 4L) return("")
    mon <- match(tolower(g[3]),
                 c("jan", "feb", "mar", "apr", "may", "jun",
                   "jul", "aug", "sep", "oct", "nov", "dec"))
    if (is.na(mon)) "" else sprintf("%s-%02d-%02d", g[4], mon, as.integer(g[2]))
  }, character(1))
}

#' Value of a "Label: ..." field from the (pipe-joined) description text
#' @noRd
.servicebund_field <- function(txt, label) {
  m <- regmatches(txt, regexpr(paste0(label, ":\\s*[^|]+"), txt))
  if (!length(m)) return("")
  trimws(sub(paste0(".*?", label, ":\\s*"), "", m))
}

#' Parse one service.bund.de RSS feed into raw rows
#' @noRd
servicebund_parse_feed <- function(xml, typ) {
  doc <- tryCatch(xml2::read_xml(xml), error = function(e) NULL)
  if (is.null(doc)) return(data.frame())
  items <- xml2::xml_find_all(doc, ".//item")
  if (!length(items)) return(data.frame())
  rows <- lapply(items, function(it) {
    title <- trimws(xml2::xml_text(xml2::xml_find_first(it, "./title")))
    link <- sub("#.*$", "", trimws(xml2::xml_text(xml2::xml_find_first(it, "./link"))))
    pub <- trimws(xml2::xml_text(xml2::xml_find_first(it, "./pubDate")))
    # description is HTML inside CDATA: turn <br> into separators, then strip tags
    # and decode entities via the HTML parser.
    desc_raw <- xml2::xml_text(xml2::xml_find_first(it, "./description"))
    desc_raw <- gsub("<br\\s*/?>", " | ", desc_raw, ignore.case = TRUE)
    desc <- tryCatch(
      rvest::html_text2(rvest::read_html(paste0("<div>", desc_raw, "</div>"))),
      error = function(e) desc_raw
    )
    desc <- trimws(gsub("[[:space:]]+", " ", desc))
    fr <- regmatches(desc, regexpr("Angebotsfrist:\\s*\\d{2}\\.\\d{2}\\.\\d{4}", desc))
    fr <- if (length(fr)) sub(".*?(\\d{2}\\.\\d{2}\\.\\d{4}).*", "\\1", fr) else ""
    data.frame(
      Kurzbezeichnung = title,
      Beschreibung = desc,
      Vergabestelle = .servicebund_field(desc, "Vergabestelle"),
      Erfuellungsort = .servicebund_field(desc, "Erf.{0,3}llungsort"),
      Veroeffentlicht = .servicebund_pubdate(pub),
      Frist = .format_iso_date(fr),
      cpv = "",
      Aktion = link,
      Veroeffentlichungstyp = typ,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' service.bund.de tender connector (HTTP, login-free)
#'
#' Reads the public RSS feeds of the federal service portal (service.bund.de),
#' which aggregates tender notices from Bund/Laender/Kommunen, and scores them
#' ([score_layered()]). A separate aggregator from the Datenservice
#' (oeffentlichevergabe.de) that adds notices the Datenservice does not carry
#' (esp. below threshold). No browser and no login required. The feed provides no
#' CPV, so relevance is title/text-based.
#'
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param cpv_map CPV-to-group map (default [tender_cpv_map()]).
#' @param include_awarded Also read the "Vergebene Auftraege" feed, labelled
#'   `Vergebener Auftrag` (default `TRUE`).
#' @param relevant_only Return only relevant tenders (default `TRUE`).
#' @param verbose Print progress (default `TRUE`).
#' @return A scored tibble with `Plattform = "Serviceportal des Bundes (service.bund.de)"`.
#' @export
#' @examples
#' \dontrun{
#' servicebund_tenders()
#' }
servicebund_tenders <- function(keywords = tender_keywords(), cpv_map = tender_cpv_map(),
                                include_awarded = TRUE, relevant_only = TRUE, verbose = TRUE) {
  feeds <- if (isTRUE(include_awarded)) SERVICEBUND_FEEDS else SERVICEBUND_FEEDS["Ausschreibung"]
  parts <- list()
  for (typ in names(feeds)) {
    x <- .servicebund_fetch(feeds[[typ]])
    if (!nzchar(x)) next
    r <- servicebund_parse_feed(x, typ)
    if (verbose) message(sprintf("service.bund.de [%s]: %d notice(s)", typ, nrow(r)))
    if (nrow(r)) parts[[typ]] <- r
  }
  raw <- if (length(parts)) do.call(rbind, parts) else data.frame()
  if (!nrow(raw)) {
    if (verbose) message("service.bund.de: no notices fetched.")
    return(data.frame())
  }
  scored <- score_layered(raw, title_cols = "Kurzbezeichnung", text_cols = "Beschreibung",
                          cpv_col = "cpv", keywords = keywords, cpv_map = cpv_map)
  scored$Plattform <- "Serviceportal des Bundes (service.bund.de)"
  n_rel <- sum(scored$is_relevant %in% TRUE)
  if (isTRUE(relevant_only)) scored <- scored[scored$is_relevant %in% TRUE, , drop = FALSE]
  if (verbose) message("service.bund.de: ", n_rel, " relevant of ", nrow(raw), " fetched.")
  scored
}
