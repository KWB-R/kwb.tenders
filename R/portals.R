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

#' Parse a publication-date column (ISO `YYYY-MM-DD` or German `DD.MM.YYYY`)
#' @noRd
.parse_pub_date <- function(x) {
  x <- trimws(as.character(x))
  d <- rep(as.Date(NA), length(x))
  iso <- !is.na(x) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", x)
  if (any(iso)) d[iso] <- as.Date(substr(x[iso], 1, 10))
  ger <- is.na(d) & !is.na(x) & grepl("^[0-9]{2}[.][0-9]{2}[.][0-9]{4}", x)
  if (any(ger)) d[ger] <- as.Date(substr(x[ger], 1, 10), format = "%d.%m.%Y")
  d
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
#' @param keep_types Keep only these `Veroeffentlichungstyp` values (default:
#'   Ausschreibung, Geplante Ausschreibung and Vergebener Auftrag -> own section
#'   each). `NULL` keeps all types.
#' @param since_days If set, keep only notices whose `Veroeffentlicht` (publication
#'   date) is within the last `since_days` days; `NULL` (default) applies no date
#'   filter. Used to unify the look-back window across portals.
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
                           keep_types = c("Ausschreibung", "Geplante Ausschreibung",
                                          "Vergebener Auftrag"),
                           since_days = NULL,
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
  # Keep only the configured notice types (default keeps all three -> own report
  # section each; pass a narrower keep_types to e.g. drop awards).
  if (length(keep_types) && !is.null(combined$Veroeffentlichungstyp)) {
    typ <- combined$Veroeffentlichungstyp
    keep <- is.na(typ) | !nzchar(typ) | typ %in% keep_types
    if (verbose && any(!keep)) {
      message(sprintf("Filtering notice types: dropped %d notice(s) not in keep_types.",
                      sum(!keep)))
    }
    combined <- combined[keep, , drop = FALSE]
  }
  # Unify the date window across portals: keep only notices published within the
  # last `since_days` days (by Veroeffentlicht). Rows with an unparseable/absent
  # date are kept (better to show than to silently drop).
  if (!is.null(since_days) && !is.null(combined$Veroeffentlicht)) {
    cutoff <- Sys.Date() - as.integer(since_days)
    pub <- .parse_pub_date(combined$Veroeffentlicht)
    keep <- is.na(pub) | pub >= cutoff
    if (verbose && any(!keep)) {
      message(sprintf("Date window: dropped %d notice(s) published before %s.",
                      sum(!keep), format(cutoff)))
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
#' built-in connectors -- the cosinex marketplaces Vergabemarktplatz Brandenburg
#' ([vmp_bb_tenders()]), Vergabemarktplatz NRW ([vmp_nrw_tenders()]) and DTVP
#' ([dtvp_tenders()]), the federal Datenservice ([oeffentlichevergabe_tenders()])
#' and TED ([ted_tenders()]) -- and runs them through [screen_portals()]. The
#' searches are login-free (only VMP-BB optionally logs in for the notice layer),
#' and a portal that fails is skipped (the others still produce the report).
#'
#' @param dir Output directory (default `"reports"`).
#' @param vmp_bb,nrw,dtvp,oeffentlichevergabe,ted Enable each source (all `TRUE`).
#' @param vmp_bb_login,vmp_bb_notice Log in / read notice PDFs for VMP-BB
#'   (default `FALSE`; need `VMP_BB_*` secrets).
#' @param since_days Unified look-back window in days, applied to every portal by
#'   publication date (default `30`): the API connectors fetch this many days and a
#'   final filter trims all sources (incl. VMP-BB) to the same window.
#' @param cosinex_contracting_rules Procurement regulations (Vergabeart) for the
#'   cosinex portals (Brandenburg/NRW/DTVP), default `"VOL"` (VgV / VOL/A / UVgO;
#'   excludes VOB/Bau). See [vmp_bb_scrape_tenders()] for other values. The API
#'   portals have no such filter (construction is excluded via the CPV-45 veto).
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param verbose Print progress (default `TRUE`).
#' @return Invisibly, the combined scored tibble.
#' @export
#' @examples
#' \dontrun{
#' screen_all_portals(vmp_bb_login = TRUE, vmp_bb_notice = TRUE)
#' }
screen_all_portals <- function(dir = "reports",
                               vmp_bb = TRUE, nrw = TRUE, dtvp = TRUE,
                               oeffentlichevergabe = TRUE, ted = TRUE,
                               vmp_bb_login = FALSE, vmp_bb_notice = FALSE,
                               since_days = 30, cosinex_contracting_rules = "VOL",
                               keywords = tender_keywords(), verbose = TRUE) {
  sources <- list()
  cosinex_pt <- c("ExAnte", "Tender", "ExPost") # planned + active + awarded
  if (isTRUE(vmp_bb)) {
    sources[["Vergabemarktplatz Brandenburg"]] <- function() {
      vmp_bb_tenders(keywords = keywords, login = vmp_bb_login,
                     screen_notice = vmp_bb_notice, cache_dir = dir, relevant_only = TRUE,
                     since_days = since_days, publication_types = cosinex_pt,
                     contracting_rules = cosinex_contracting_rules)
    }
  }
  if (isTRUE(nrw)) {
    sources[["Vergabemarktplatz NRW"]] <- function() {
      vmp_nrw_tenders(keywords = keywords, cache_dir = dir, relevant_only = TRUE,
                      since_days = since_days, publication_types = cosinex_pt,
                      contracting_rules = cosinex_contracting_rules)
    }
  }
  if (isTRUE(dtvp)) {
    sources[["Deutsches Vergabeportal (DTVP)"]] <- function() {
      dtvp_tenders(keywords = keywords, cache_dir = dir, relevant_only = TRUE,
                   since_days = since_days, publication_types = cosinex_pt,
                   contracting_rules = cosinex_contracting_rules)
    }
  }
  if (isTRUE(oeffentlichevergabe)) {
    sources[["Oeffentliche Vergabe (Bund)"]] <- function() {
      oeffentlichevergabe_tenders(keywords = keywords, days = since_days,
                                  verbose = verbose)
    }
  }
  if (isTRUE(ted)) {
    sources[["TED (EU)"]] <- function() {
      ted_tenders(keywords = keywords, since_days = since_days, verbose = verbose)
    }
  }
  screen_portals(sources, dir = dir, portal = "tenders", keywords = keywords,
                 since_days = since_days, verbose = verbose)
}
