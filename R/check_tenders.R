# High-level orchestrator ------------------------------------------------------

#' Check Vergabemarktplatz Brandenburg for relevant tenders
#'
#' End-to-end pipeline: open a chromote session, (optionally) log in, scrape all
#' tenders, score them for relevance and write the overview report. This is the
#' function called by the scheduled GitHub Action.
#'
#' The public tender search works **without** login, so `login = FALSE` by
#' default. Set `login = TRUE` once you have valid credentials.
#'
#' @param dir Output directory for the report (default `"reports"`).
#' @param headless Kept for API compatibility (chromote runs headless).
#' @param login Log in before scraping (default `FALSE`; the search is public).
#' @param max_pages Maximum number of result pages to scrape (default `Inf`).
#' @param publication_types,contracting_rules Search filter passed to
#'   [vmp_bb_scrape_tenders()]. Defaults to Beabsichtigte Ausschreibung +
#'   Ausschreibung (`c("ExAnte", "Tender")`) and VgV / VOL/A / UVgO (`"VOL"`).
#' @param screen_details Second relevance layer: fetch each ongoing tender's
#'   public detail page and match its full text + CPV codes (default `TRUE`).
#'   See [enrich_with_details()].
#' @param max_detail Maximum number of detail pages to screen (default `Inf`).
#' @param screen_notice Third relevance layer: log in and read each ongoing
#'   tender's published Bekanntmachung PDF(s), matching the text (default
#'   `FALSE`; forces `login = TRUE`). See [enrich_with_notice()].
#' @param max_notice Maximum number of new notice PDFs to read (default `Inf`).
#' @param username,password Credentials used when `login = TRUE` (default env
#'   vars `VMP_BB_USERNAME` / `VMP_BB_PASSWORD`).
#' @param keywords Keyword list for relevance scoring (default
#'   [tender_keywords()]).
#' @return Invisibly, the scored tibble of all tenders.
#' @export
#' @examples
#' \dontrun{
#' check_tenders() # public search, all pages
#' check_tenders(max_pages = 2) # quick test
#' }
check_tenders <- function(dir = "reports",
                          headless = TRUE,
                          login = FALSE,
                          max_pages = Inf,
                          publication_types = c("ExAnte", "Tender"),
                          contracting_rules = "VOL",
                          screen_details = TRUE,
                          max_detail = Inf,
                          screen_notice = FALSE,
                          max_notice = Inf,
                          username = Sys.getenv("VMP_BB_USERNAME"),
                          password = Sys.getenv("VMP_BB_PASSWORD"),
                          keywords = tender_keywords()) {
  if (isTRUE(screen_notice)) login <- TRUE # notice PDFs need a logged-in session

  session <- vmp_bb_session(headless = headless)
  on.exit(try(session$close(), silent = TRUE), add = TRUE)

  if (isTRUE(login)) {
    vmp_bb_login(session, username = username, password = password)
  }

  tenders <- vmp_bb_scrape_tenders(
    session,
    publication_types = publication_types,
    contracting_rules = contracting_rules,
    max_pages = max_pages
  )
  scored <- score_relevance(tenders, keywords = keywords)

  detail_cache_file <- file.path(dir, "detail_cache.rds")
  notice_cache_file <- file.path(dir, "notice_cache.rds")
  detail_cache_out <- NULL
  notice_cache_out <- NULL

  if (isTRUE(screen_details)) {
    scored <- enrich_with_details(
      session, scored,
      keywords = keywords, max_detail = max_detail,
      cache = read_detail_cache(detail_cache_file)
    )
    detail_cache_out <- attr(scored, "detail_cache")
  }
  if (isTRUE(screen_notice)) {
    scored <- enrich_with_notice(
      session, scored,
      keywords = keywords, max_notice = max_notice,
      cache = read_notice_cache(notice_cache_file)
    )
    notice_cache_out <- attr(scored, "notice_cache")
  }

  res <- write_tender_report(scored, dir = dir)
  if (!is.null(detail_cache_out)) write_detail_cache(detail_cache_out, detail_cache_file)
  if (!is.null(notice_cache_out)) write_notice_cache(notice_cache_out, notice_cache_file)

  message(sprintf(
    "Done: %d tenders, %d relevant, %d new. Report: %s",
    res$n_total, res$n_relevant, res$n_new, res$xlsx
  ))

  invisible(scored)
}
