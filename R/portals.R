# Multi-portal connectors ------------------------------------------------------
# A portal "connector" is a function(keywords, ...) that queries ONE procurement
# portal and returns a SCORED tender tibble (see score_relevance()), using these
# conventional columns where available:
#   Plattform              portal display name (e.g. "TED", "Oeffentliche Vergabe")
#   Kurzbezeichnung        short title (matched by score_relevance)
#   Beschreibung           longer description text (matched too)
#   Vergabestelle          contracting authority
#   Erfuellungsort         place of performance
#   Frist                  submission deadline
#   cpv                    comma-separated CPV codes (-> cpv_groups / matched_cpv)
#   Aktion                 URL to the notice / detail page
#   Veroeffentlichungstyp  "Ausschreibung" / "Geplante Ausschreibung" / ...
# plus the score_relevance() columns (groups, match_source, score, is_relevant).
# Connectors are merged with combine_tenders() and written by write_tender_report().

#' Combine scored tender tibbles from several portal connectors
#'
#' Row-binds the per-portal results, filling columns absent in some sources with
#' `NA`, and guarantees a `Plattform` column. Each input should be a scored tibble
#' (see [score_relevance()]) as returned by a portal connector.
#'
#' @param tenders_list A list of data frames (one per portal). `NULL` entries and
#'   zero-row frames are dropped.
#' @return One combined data frame (an empty data frame if all inputs are empty).
#' @export
#' @examples
#' a <- data.frame(Plattform = "A", Kurzbezeichnung = "x", stringsAsFactors = FALSE)
#' b <- data.frame(Plattform = "B", cpv = "71351500-8", stringsAsFactors = FALSE)
#' combine_tenders(list(a, b))
combine_tenders <- function(tenders_list) {
  tenders_list <- Filter(function(x) is.data.frame(x) && nrow(x) > 0L, tenders_list)
  if (length(tenders_list) == 0L) return(data.frame())
  all_cols <- unique(unlist(lapply(tenders_list, names)))
  norm <- lapply(tenders_list, function(df) {
    for (m in setdiff(all_cols, names(df))) df[[m]] <- NA
    df[, all_cols, drop = FALSE]
  })
  out <- do.call(rbind, norm)
  if (is.null(out$Plattform)) out$Plattform <- NA_character_
  rownames(out) <- NULL
  out
}

#' Run several portal connectors, combine and write one report
#'
#' Calls each source connector (a function returning a scored tender tibble),
#' tagging it with a `Plattform`, combines the results with [combine_tenders()]
#' and writes one report via [write_tender_report()]. A source that errors is
#' logged and skipped, so one portal failing does not abort the run.
#'
#' @param sources A named list of functions, each returning a scored tibble
#'   (e.g. `list("TED" = function() ted_tenders())`). The name is used as the
#'   `Plattform` if the connector does not set one.
#' @param dir Output directory (default `"reports"`).
#' @param portal File-name id for the combined report (default `"tenders"`).
#' @param keywords Passed to connectors that take it (currently informational).
#' @param keep_types Keep only these `Veroeffentlichungstyp` values (default the
#'   biddable ones -> drops "Vergebener Auftrag"/awards). `NULL` keeps all.
#' @param verbose Print progress (default `TRUE`).
#' @return Invisibly, the combined scored tibble.
#' @export
#' @examples
#' \dontrun{
#' screen_portals(list(
#'   "Oeffentliche Vergabe" = function() oeffentlichevergabe_tenders(days = 7),
#'   "TED" = function() ted_tenders()
#' ))
#' }
screen_portals <- function(sources, dir = "reports", portal = "tenders",
                           keywords = tender_keywords(),
                           keep_types = c("Ausschreibung", "Geplante Ausschreibung"),
                           verbose = TRUE) {
  results <- lapply(names(sources), function(nm) {
    if (verbose) message("== Source: ", nm, " ==")
    out <- tryCatch(sources[[nm]](), error = function(e) {
      message("  source '", nm, "' failed: ", conditionMessage(e)); NULL
    })
    if (!is.null(out) && nrow(out) > 0L &&
        (is.null(out$Plattform) || all(is.na(out$Plattform) | !nzchar(out$Plattform)))) {
      out$Plattform <- nm
    }
    out
  })
  ok <- sum(vapply(results, function(x) is.data.frame(x) && nrow(x) > 0L, logical(1)))
  combined <- combine_tenders(results)
  if (nrow(combined) == 0L) {
    message("No tenders from any source.")
    return(invisible(combined))
  }
  # Keep only biddable notice types (drop awards / "Vergebener Auftrag").
  if (length(keep_types) && !is.null(combined$Veroeffentlichungstyp)) {
    typ <- combined$Veroeffentlichungstyp
    keep <- is.na(typ) | !nzchar(typ) | typ %in% keep_types
    if (verbose && any(!keep)) {
      message(sprintf("Keeping biddable types only: dropped %d notice(s) (e.g. Vergebener Auftrag).",
                      sum(!keep)))
    }
    combined <- combined[keep, , drop = FALSE]
  }
  res <- write_tender_report(combined, dir = dir, portal = portal)
  message(sprintf("Done: %d tenders, %d relevant, %d new across %d source(s). Report: %s",
                  res$n_total, res$n_relevant, res$n_new, ok, res$xlsx))
  invisible(combined)
}

#' Screen all configured portals into one combined report
#'
#' Convenience entry point (used by the scheduled GitHub Action): wires the
#' built-in connectors -- Vergabe Brandenburg ([vmp_bb_tenders()]), the federal
#' Datenservice ([oeffentlichevergabe_tenders()]) and TED ([ted_tenders()]) --
#' and runs them through [screen_portals()]. Only VMP-BB can use a login; the API
#' portals are login-free, and a portal that fails is skipped (the others still
#' produce the report).
#'
#' @param dir Output directory (default `"reports"`).
#' @param vmp_bb,oeffentlichevergabe,ted Enable each source (all `TRUE`).
#' @param vmp_bb_login,vmp_bb_notice Log in / read notice PDFs for VMP-BB
#'   (default `FALSE`; need `VMP_BB_*` secrets).
#' @param oeffentlichevergabe_days Days of OCDS notices to fetch (default `8`).
#' @param ted_since_days TED look-back window in days (default `90`).
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param verbose Print progress (default `TRUE`).
#' @return Invisibly, the combined scored tibble.
#' @export
#' @examples
#' \dontrun{
#' screen_all_portals(vmp_bb_login = TRUE, vmp_bb_notice = TRUE)
#' }
screen_all_portals <- function(dir = "reports",
                               vmp_bb = TRUE, oeffentlichevergabe = TRUE, ted = TRUE,
                               vmp_bb_login = FALSE, vmp_bb_notice = FALSE,
                               oeffentlichevergabe_days = 8, ted_since_days = 90,
                               keywords = tender_keywords(), verbose = TRUE) {
  sources <- list()
  if (isTRUE(vmp_bb)) {
    sources[["Vergabe Brandenburg"]] <- function() {
      vmp_bb_tenders(keywords = keywords, login = vmp_bb_login,
                     screen_notice = vmp_bb_notice, cache_dir = dir, relevant_only = TRUE)
    }
  }
  if (isTRUE(oeffentlichevergabe)) {
    sources[["Oeffentliche Vergabe (Bund)"]] <- function() {
      oeffentlichevergabe_tenders(keywords = keywords, days = oeffentlichevergabe_days,
                                  verbose = verbose)
    }
  }
  if (isTRUE(ted)) {
    sources[["TED (EU)"]] <- function() {
      ted_tenders(keywords = keywords, since_days = ted_since_days, verbose = verbose)
    }
  }
  screen_portals(sources, dir = dir, portal = "tenders", keywords = keywords, verbose = verbose)
}
