# High-level orchestrators -----------------------------------------------------

#' Scrape + score Vergabemarktplatz Brandenburg (portal connector)
#'
#' The VMP-BB connector for [screen_portals()] / [screen_all_portals()]: opens a
#' chromote session, optionally logs in, scrapes tenders, scores them
#' ([score_relevance()]), enriches via the detail and (optional) notice layers,
#' applies the title exclusions ([apply_title_excludes()]) and tags
#' `Plattform = "Vergabe Brandenburg"`. Returns the scored tibble (it writes no
#' report); the detail/notice screening caches are read/written under `cache_dir`.
#'
#' @param keywords Keyword list for relevance scoring (default [tender_keywords()]).
#' @param login Log in before scraping (default `FALSE`; the search is public).
#' @param max_pages Maximum number of result pages to scrape (default `Inf`).
#' @param publication_types,contracting_rules Search filter passed to
#'   [vmp_bb_scrape_tenders()].
#' @param screen_details Detail-page layer (default `TRUE`; see
#'   [enrich_with_details()]).
#' @param max_detail Maximum number of detail pages to screen (default `Inf`).
#' @param screen_notice Notice-PDF layer (default `FALSE`; forces `login = TRUE`;
#'   see [enrich_with_notice()]).
#' @param max_notice Maximum number of new notice PDFs to read (default `Inf`).
#' @param username,password Credentials when `login = TRUE` (default env vars
#'   `VMP_BB_USERNAME` / `VMP_BB_PASSWORD`).
#' @param cache_dir Directory for the detail/notice caches (default `"reports"`).
#' @param headless Run chromote headless (default `TRUE`).
#' @return A scored tibble with a `Plattform` column.
#' @export
#' @examples
#' \dontrun{
#' vmp_bb_tenders(max_pages = 2)
#' }
vmp_bb_tenders <- function(keywords = tender_keywords(),
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
                           cache_dir = "reports",
                           headless = TRUE) {
  if (isTRUE(screen_notice)) login <- TRUE # notice PDFs need a logged-in session

  session <- vmp_bb_session(headless = headless)
  on.exit(try(session$close(), silent = TRUE), add = TRUE)
  if (isTRUE(login)) vmp_bb_login(session, username = username, password = password)

  tenders <- vmp_bb_scrape_tenders(
    session,
    publication_types = publication_types,
    contracting_rules = contracting_rules,
    max_pages = max_pages
  )
  scored <- score_relevance(tenders, keywords = keywords)

  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  if (isTRUE(screen_details)) {
    f <- file.path(cache_dir, "detail_cache.rds")
    scored <- enrich_with_details(session, scored, keywords = keywords,
                                  max_detail = max_detail, cache = read_detail_cache(f))
    write_detail_cache(attr(scored, "detail_cache"), f)
  }
  if (isTRUE(screen_notice)) {
    f <- file.path(cache_dir, "notice_cache.rds")
    scored <- enrich_with_notice(session, scored, keywords = keywords,
                                 max_notice = max_notice, cache = read_notice_cache(f))
    write_notice_cache(attr(scored, "notice_cache"), f)
  }

  scored <- apply_title_excludes(scored, keywords = keywords) # drop pure building/maintenance titles
  scored$Plattform <- "Vergabe Brandenburg"
  scored
}

#' Check Vergabemarktplatz Brandenburg for relevant tenders (single-portal report)
#'
#' Convenience wrapper around [vmp_bb_tenders()] that also writes the overview
#' report. For the combined multi-portal run see [screen_all_portals()].
#'
#' @inheritParams vmp_bb_tenders
#' @param dir Output directory for the report and caches (default `"reports"`).
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
  scored <- vmp_bb_tenders(
    keywords = keywords, login = login, max_pages = max_pages,
    publication_types = publication_types, contracting_rules = contracting_rules,
    screen_details = screen_details, max_detail = max_detail,
    screen_notice = screen_notice, max_notice = max_notice,
    username = username, password = password, cache_dir = dir, headless = headless
  )
  res <- write_tender_report(scored, dir = dir)
  message(sprintf(
    "Done: %d tenders, %d relevant, %d new. Report: %s",
    res$n_total, res$n_relevant, res$n_new, res$xlsx
  ))
  invisible(scored)
}
