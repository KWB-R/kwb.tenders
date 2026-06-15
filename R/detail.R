# Detail-page enrichment (second relevance layer) ------------------------------
# For ongoing tenders, fetch the PUBLIC detail page (no login/browser needed),
# match the keyword groups against its full text and map its CPV codes to groups.

#' CPV-code to research-group mapping
#'
#' @param path YAML file mapping CPV prefixes to group slugs
#'   (`inst/extdata/cpv_groups.yml`).
#' @return A list of entries, each a list with `prefix` and `groups`.
#' @export
#' @examples
#' str(tender_cpv_map())
tender_cpv_map <- function(path = system.file("extdata", "cpv_groups.yml",
                                              package = "kwb.tenders")) {
  if (!nzchar(path) || !file.exists(path)) {
    return(list())
  }
  yaml::read_yaml(path)
}

#' Fetch a tender detail page and extract its text + CPV codes
#'
#' Uses a plain HTTP GET (the published detail page is public), so no browser or
#' login is required.
#'
#' @param url Project detail URL (the `Aktion` column from
#'   [vmp_bb_scrape_tenders()]).
#' @return A list with `text` (page text) and `cpv` (character vector of CPV codes).
#' @export
#' @examples
#' \dontrun{
#' tender_detail_text(tenders$Aktion[1])
#' }
tender_detail_text <- function(url) {
  resp <- httr::GET(url, httr::user_agent(
    "kwb.tenders (https://github.com/KWB-R/kwb.tenders)"
  ))
  html <- httr::content(resp, as = "text", encoding = "UTF-8")
  parse_detail_html(html)
}

#' @noRd
parse_detail_html <- function(html) {
  if (!is.character(html) || length(html) == 0 || is.na(html[1]) || !nzchar(html[1])) {
    return(list(text = "", cpv = character()))
  }
  doc <- rvest::read_html(html)
  body <- rvest::html_element(doc, "body")
  text <- rvest::html_text2(body)
  if (length(text) == 0 || is.na(text)) text <- ""
  cpv <- stringr::str_extract_all(text, "[0-9]{8}(-[0-9])?")[[1]]
  list(text = text, cpv = unique(cpv))
}

#' Map CPV codes to research-group display names
#' @noRd
cpv_to_group_names <- function(cpv, cpv_map, slug2name) {
  if (length(cpv) == 0L || length(cpv_map) == 0L) {
    return(character())
  }
  codes <- gsub("[^0-9]", "", cpv)
  slugs <- character()
  for (entry in cpv_map) {
    pfx <- gsub("[^0-9]", "", as.character(entry$prefix))
    if (nzchar(pfx) && any(startsWith(codes, pfx))) {
      slugs <- c(slugs, as.character(entry$groups))
    }
  }
  nm <- slug2name[unique(slugs)]
  unique(as.character(nm[!is.na(nm)]))
}

#' Which tenders are still ongoing (deadline not passed)?
#' @noRd
is_ongoing <- function(tenders, today = Sys.Date()) {
  col <- grep("frist", tolower(names(tenders)))
  if (length(col) == 0L) {
    return(rep(TRUE, nrow(tenders)))
  }
  d <- as.Date(
    stringr::str_extract(as.character(tenders[[col[1]]]), "[0-9]{2}\\.[0-9]{2}\\.[0-9]{4}"),
    format = "%d.%m.%Y"
  )
  is.na(d) | d >= today # keep undated rows (be inclusive)
}

#' Enrich tenders with a detail-page relevance layer (full text + CPV codes)
#'
#' For ongoing tenders, fetches the public detail page, matches the keyword
#' groups against its full text and maps its CPV codes to groups. The matching
#' group(s) are merged into `groups`/`is_relevant`; adds columns `detail_groups`,
#' `cpv`, `cpv_groups` and `match_source` (which layer(s) matched).
#'
#' @param tenders A scored tibble (see [score_relevance()]).
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param cpv_map CPV-to-group mapping (default [tender_cpv_map()]).
#' @param ongoing_only Only screen tenders whose deadline has not passed
#'   (default `TRUE`).
#' @param max_detail Maximum number of detail pages to fetch (default `Inf`).
#' @param delay Seconds between detail requests (politeness; default `0.3`).
#' @return `tenders` with the detail layer merged in.
#' @export
enrich_with_details <- function(tenders, keywords = tender_keywords(),
                                cpv_map = tender_cpv_map(),
                                ongoing_only = TRUE, max_detail = Inf, delay = 0.3) {
  n <- nrow(tenders)
  tenders$detail_groups <- rep("", n)
  tenders$cpv <- rep("", n)
  tenders$cpv_groups <- rep("", n)
  if (n == 0L) {
    tenders$match_source <- character()
    return(tenders)
  }

  slug2name <- vapply(keywords, function(g) {
    if (is.null(g$name)) "" else as.character(g$name)
  }, character(1))

  pick <- if (isTRUE(ongoing_only)) which(is_ongoing(tenders)) else seq_len(n)
  if (length(pick) > max_detail) pick <- pick[seq_len(max_detail)]
  urls <- if (!is.null(tenders$Aktion)) as.character(tenders$Aktion) else rep(NA_character_, n)

  message(sprintf("Screening %d detail page(s) (description + CPV)...", length(pick)))
  for (k in seq_along(pick)) {
    i <- pick[k]
    u <- urls[i]
    if (is.na(u) || !nzchar(u)) next
    det <- tryCatch(tender_detail_text(u), error = function(e) NULL)
    if (is.null(det)) next
    if (nzchar(det$text)) {
      sc <- score_relevance(data.frame(t = det$text, stringsAsFactors = FALSE), keywords = keywords)
      tenders$detail_groups[i] <- sc$groups[1]
    }
    tenders$cpv[i] <- paste(det$cpv, collapse = ", ")
    tenders$cpv_groups[i] <- paste(cpv_to_group_names(det$cpv, cpv_map, slug2name), collapse = ", ")
    if (delay > 0) Sys.sleep(delay)
    if (k %% 25 == 0) message(sprintf("  ...%d/%d", k, length(pick)))
  }

  split_groups <- function(x) {
    g <- unlist(strsplit(x, ", ", fixed = TRUE))
    g[nzchar(g)]
  }
  tenders$groups <- vapply(seq_len(n), function(i) {
    g <- unique(split_groups(c(tenders$groups[i], tenders$detail_groups[i], tenders$cpv_groups[i])))
    paste(g, collapse = ", ")
  }, character(1))
  title_hit <- if (is.null(tenders$matched_keywords)) rep("", n) else tenders$matched_keywords
  tenders$match_source <- vapply(seq_len(n), function(i) {
    paste(c(
      if (nzchar(title_hit[i])) "title",
      if (nzchar(tenders$detail_groups[i])) "detail",
      if (nzchar(tenders$cpv_groups[i])) "cpv"
    ), collapse = "+")
  }, character(1))
  tenders$is_relevant <- nzchar(tenders$groups)
  tenders
}
