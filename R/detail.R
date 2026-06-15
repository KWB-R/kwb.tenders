# Detail-page enrichment (second relevance layer) ------------------------------
# The detail page is a JavaScript app, so it is rendered via the chromote
# session (same origin as the search -> stable on CI; no login needed). For each
# ongoing tender we match the keyword groups against the rendered text and map
# its CPV codes to groups.

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

#' CPV code -> German label lookup
#'
#' Reads the bundled CPV label table (`inst/extdata/cpv_labels.csv`, columns
#' `code`, `name`). Edit/extend that file (or drop in the full official CPV list)
#' to cover more codes.
#'
#' @param path CSV file with columns `code`, `name`.
#' @return A named character vector (names = CPV codes, values = German labels).
#' @export
#' @examples
#' head(cpv_labels())
cpv_labels <- function(path = system.file("extdata", "cpv_labels.csv", package = "kwb.tenders")) {
  if (!nzchar(path) || !file.exists(path)) return(character())
  df <- tryCatch(
    utils::read.csv(path, colClasses = "character", encoding = "UTF-8"),
    error = function(e) NULL
  )
  if (is.null(df) || !all(c("code", "name") %in% names(df))) return(character())
  out <- df$name
  names(out) <- df$code
  out
}

#' Summarise all CPV codes found across the tenders
#'
#' Aggregates the CPV codes collected by [enrich_with_details()] into a table:
#' one row per code (`cpv_id`) with its German label (`cpv_name`, via
#' [cpv_labels()]), the number of tenders it appears in (`n_tenders`) and the KWB
#' research group(s) it maps to (`groups`). Used as the "CPV" sheet of the report.
#'
#' @param tenders A tibble with a `cpv` column (comma-separated CPV codes).
#' @param cpv_map CPV-to-group mapping (default [tender_cpv_map()]).
#' @param keywords Keyword groups, for group display names (default
#'   [tender_keywords()]).
#' @param labels CPV code -> name lookup (default [cpv_labels()]).
#' @return A data.frame with columns `cpv_id`, `cpv_name`, `n_tenders`, `groups`,
#'   sorted by descending frequency.
#' @export
#' @examples
#' cpv_summary(data.frame(cpv = c("90700000-4, 90733000-4", "90700000-4")))
cpv_summary <- function(tenders, cpv_map = tender_cpv_map(), keywords = tender_keywords(),
                        labels = cpv_labels()) {
  empty <- data.frame(cpv_id = character(), cpv_name = character(),
                      n_tenders = integer(), groups = character(), stringsAsFactors = FALSE)
  if (is.null(tenders$cpv)) return(empty)
  codes <- unlist(strsplit(as.character(tenders$cpv), ", ", fixed = TRUE))
  codes <- codes[nzchar(codes)]
  if (length(codes) == 0L) return(empty)
  tab <- sort(table(codes), decreasing = TRUE)
  cpvs <- names(tab)
  slug2name <- vapply(keywords, function(g) {
    if (is.null(g$name)) "" else as.character(g$name)
  }, character(1))
  nm <- unname(labels[cpvs])
  nm[is.na(nm)] <- ""
  groups <- vapply(cpvs, function(cc) {
    paste(cpv_to_group_names(cc, cpv_map, slug2name), collapse = ", ")
  }, character(1))
  data.frame(cpv_id = cpvs, cpv_name = nm, n_tenders = as.integer(tab),
             groups = groups, stringsAsFactors = FALSE, row.names = NULL)
}

#' German labels of a tender's CPV codes that match the group mapping
#'
#' For each row, returns the [cpv_labels()] names of the `cpv` codes that map to
#' at least one research group (via `cpv_map`), "; "-separated (empty if none).
#' Derived at report time from the raw codes, so it tracks the current mapping.
#' @param cpv Character vector; each element comma-separated CPV codes.
#' @param cpv_map CPV-to-group mapping (default [tender_cpv_map()]).
#' @param labels CPV code -> German name lookup (default [cpv_labels()]).
#' @return Character vector (one per input element); names "; "-separated.
#' @noRd
matched_cpv_names <- function(cpv, cpv_map = tender_cpv_map(), labels = cpv_labels()) {
  prefixes <- vapply(cpv_map, function(e) gsub("[^0-9]", "", as.character(e$prefix)), character(1))
  prefixes <- prefixes[nzchar(prefixes)]
  by_base8 <- as.character(labels)
  names(by_base8) <- substr(gsub("[^0-9]", "", names(labels)), 1, 8) # match on 8-digit base
  vapply(as.character(cpv), function(s) {
    codes <- unlist(strsplit(s, ", ", fixed = TRUE))
    codes <- codes[!is.na(codes) & nzchar(codes)]
    if (length(codes) == 0L || length(prefixes) == 0L) return("")
    digits <- gsub("[^0-9]", "", codes)
    matched <- vapply(digits, function(d) any(startsWith(d, prefixes)), logical(1))
    if (!any(matched)) return("")
    nm <- unname(by_base8[substr(digits[matched], 1, 8)])
    nm <- ifelse(is.na(nm) | !nzchar(nm), codes[matched], nm) # fall back to the code
    paste(unique(nm), collapse = "; ")
  }, character(1), USE.NAMES = FALSE)
}

#' Extract CPV codes (8 digits, optional check digit) from text
#' @noRd
extract_cpv <- function(text) {
  if (length(text) == 0L || is.na(text[1]) || !nzchar(text[1])) {
    return(character())
  }
  unique(stringr::str_extract_all(text, "[0-9]{8}(-[0-9])?")[[1]])
}

#' Fetch a tender detail page (rendered) and extract its text + CPV codes
#'
#' Navigates the (JavaScript-rendered) public detail page via the chromote
#' session and reads the rendered text. No login required.
#'
#' @param session A session from [vmp_bb_session()].
#' @param url Project detail URL (the `Aktion` column).
#' @param wait Maximum seconds to wait for the page to render (default `10`).
#' @return A list with `text` (rendered page text) and `cpv` (character vector).
#' @export
#' @examples
#' \dontrun{
#' session <- vmp_bb_session()
#' tender_detail_text(session, tenders$Aktion[1])
#' }
tender_detail_text <- function(session, url, wait = 10) {
  session$Page$navigate(url)
  t0 <- Sys.time()
  text <- ""
  repeat {
    Sys.sleep(0.5)
    text <- cdp_eval(session, "(document.body && document.body.innerText) || ''")
    if (is.character(text) && nchar(text) > 200) break # rendered
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > wait) break
  }
  if (is.null(text) || !is.character(text)) text <- ""
  list(text = text, cpv = extract_cpv(text))
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

#' Stable per-tender id (the portal `pid` from the `Aktion` URL)
#' @noRd
tender_ids <- function(tenders) {
  n <- nrow(tenders)
  url <- if (!is.null(tenders$Aktion)) as.character(tenders$Aktion) else rep(NA_character_, n)
  pid <- stringr::str_match(url, "pid=([0-9]+)")[, 2]
  ifelse(!is.na(pid), pid,
         ifelse(!is.na(url) & nzchar(url), url, paste0("row-", seq_len(n))))
}

#' @noRd
empty_detail_cache <- function() {
  data.frame(tender_id = character(), detail_groups = character(),
             cpv = character(), cpv_groups = character(), stringsAsFactors = FALSE)
}

#' Read / write the detail-screening cache
#'
#' The cache (one row per already-screened tender) lets the scheduled job screen
#' only *new* tenders and reuse earlier results; persisted with the report so it
#' survives across runs.
#'
#' @param path Cache file path (`.rds`).
#' @param cache A cache data.frame (columns `tender_id`, `detail_groups`, `cpv`,
#'   `cpv_groups`).
#' @return `read_detail_cache()` returns the cache data.frame (empty if absent);
#'   `write_detail_cache()` returns `path` invisibly.
#' @export
read_detail_cache <- function(path) {
  if (length(path) != 1L || is.na(path) || !file.exists(path)) {
    return(empty_detail_cache())
  }
  out <- tryCatch(readRDS(path), error = function(e) NULL)
  ok <- is.data.frame(out) &&
    all(c("tender_id", "detail_groups", "cpv", "cpv_groups") %in% names(out))
  if (ok) out else empty_detail_cache()
}

#' @rdname read_detail_cache
#' @export
write_detail_cache <- function(cache, path) {
  if (is.null(cache)) cache <- empty_detail_cache()
  saveRDS(cache, path)
  invisible(path)
}

#' Enrich tenders with a detail-page relevance layer (rendered text + CPV codes)
#'
#' For ongoing tenders that are not yet in `cache`, renders the public detail
#' page via `session`, matches the keyword groups against its full text and maps
#' its CPV codes to groups. Cached tenders are reused without re-fetching. The
#' matching group(s) are merged into `groups`/`is_relevant`; adds columns
#' `detail_groups`, `cpv`, `cpv_groups`, `match_source`. The updated cache is
#' returned as `attr(result, "detail_cache")`.
#'
#' @param session A session from [vmp_bb_session()].
#' @param tenders A scored tibble (see [score_relevance()]).
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param cpv_map CPV-to-group mapping (default [tender_cpv_map()]).
#' @param ongoing_only Only screen tenders whose deadline has not passed
#'   (default `TRUE`).
#' @param max_detail Maximum number of *new* detail pages to render per call
#'   (default `Inf`).
#' @param delay Seconds between detail pages (politeness; default `0.2`).
#' @param cache Detail cache from a previous run (see [read_detail_cache()]).
#' @return `tenders` with the detail layer merged in; the updated cache is in
#'   `attr(result, "detail_cache")`.
#' @export
enrich_with_details <- function(session, tenders, keywords = tender_keywords(),
                                cpv_map = tender_cpv_map(),
                                ongoing_only = TRUE, max_detail = Inf, delay = 0.2,
                                cache = NULL) {
  n <- nrow(tenders)
  tenders$detail_groups <- rep("", n)
  tenders$cpv <- rep("", n)
  tenders$cpv_groups <- rep("", n)
  if (n == 0L) {
    tenders$match_source <- character()
    attr(tenders, "detail_cache") <- empty_detail_cache()
    return(tenders)
  }
  if (is.null(cache)) cache <- empty_detail_cache()

  slug2name <- vapply(keywords, function(g) {
    if (is.null(g$name)) "" else as.character(g$name)
  }, character(1))

  ids <- tender_ids(tenders)
  cidx <- match(ids, cache$tender_id)
  have <- !is.na(cidx)
  tenders$detail_groups[have] <- cache$detail_groups[cidx[have]]
  tenders$cpv[have] <- cache$cpv[cidx[have]]
  tenders$cpv_groups[have] <- cache$cpv_groups[cidx[have]]

  base_pick <- if (isTRUE(ongoing_only)) which(is_ongoing(tenders)) else seq_len(n)
  pick <- base_pick[!have[base_pick]] # only ongoing AND not yet cached (= new)
  if (length(pick) > max_detail) pick <- pick[seq_len(max_detail)]
  urls <- if (!is.null(tenders$Aktion)) as.character(tenders$Aktion) else rep(NA_character_, n)

  message(sprintf("Detail layer: %d cached, screening %d new page(s)...",
                  sum(have), length(pick)))
  fetched <- logical(n)
  for (k in seq_along(pick)) {
    i <- pick[k]
    u <- urls[i]
    if (is.na(u) || !nzchar(u)) next
    det <- tryCatch(tender_detail_text(session, u), error = function(e) NULL)
    if (is.null(det)) next
    if (nzchar(det$text)) {
      sc <- score_relevance(data.frame(t = det$text, stringsAsFactors = FALSE), keywords = keywords)
      tenders$detail_groups[i] <- sc$groups[1]
    }
    tenders$cpv[i] <- paste(det$cpv, collapse = ", ")
    tenders$cpv_groups[i] <- paste(cpv_to_group_names(det$cpv, cpv_map, slug2name), collapse = ", ")
    fetched[i] <- TRUE
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

  # Updated cache: current tenders that were cached before OR freshly screened
  # (prunes entries for tenders that dropped out of the listing).
  screened <- have | fetched
  upd <- data.frame(
    tender_id = ids[screened],
    detail_groups = tenders$detail_groups[screened],
    cpv = tenders$cpv[screened],
    cpv_groups = tenders$cpv_groups[screened],
    stringsAsFactors = FALSE
  )
  upd <- upd[nzchar(upd$tender_id) & !duplicated(upd$tender_id), , drop = FALSE]
  attr(tenders, "detail_cache") <- upd
  tenders
}
