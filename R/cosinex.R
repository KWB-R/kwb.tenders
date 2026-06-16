# cosinex "Vergabemarktplatz" connectors ---------------------------------------
# Vergabemarktplatz Brandenburg, Vergabemarktplatz NRW and the Deutsches
# Vergabeportal (DTVP) all run the same cosinex VMP software and differ only in
# host + mount segment ("VMPCenter" for the Land marketplaces, "Center" for
# DTVP); see cosinex_urls(). cosinex_tenders() is the shared engine, the
# *_tenders() functions below are thin wrappers pinning host, name and cache slug.

#' Scrape + score a cosinex Vergabemarktplatz instance (generic connector)
#'
#' Shared engine behind [vmp_bb_tenders()], [vmp_nrw_tenders()] and
#' [dtvp_tenders()]: opens a chromote session, optionally logs in, scrapes the
#' extended-search results, scores them ([score_relevance()]), enriches via the
#' detail (and optional notice) layers, applies the title/CPV exclusions
#' ([apply_title_excludes()]) and tags `Plattform = plattform`. The detail and
#' notice caches are namespaced by `slug`, so several portals can share one
#' `cache_dir` without clobbering each other.
#'
#' @param base_url Portal host, e.g. `"https://www.evergabe.nrw.de"`.
#' @param plattform Display name written to the `Plattform` column.
#' @param slug Short id used for the per-portal cache files (e.g. `"vmp_nrw"`).
#' @param mount cosinex mount segment: `"VMPCenter"` (Land marketplaces) or
#'   `"Center"` (DTVP).
#' @param since_days If set, stop paging once a result page is entirely older
#'   than this many days (the search is sorted newest-first). Bounds the scrape
#'   for large portals/award histories; `NULL` scrapes up to `max_pages`. The
#'   precise date trim happens later in [screen_portals()].
#' @inheritParams vmp_bb_tenders
#' @return A scored tibble with a `Plattform` column.
#' @export
#' @examples
#' \dontrun{
#' cosinex_tenders("https://www.evergabe.nrw.de", "Vergabemarktplatz NRW",
#'                 slug = "vmp_nrw", max_pages = 2)
#' }
cosinex_tenders <- function(base_url, plattform, slug, mount = "VMPCenter",
                            keywords = tender_keywords(),
                            login = FALSE,
                            max_pages = Inf,
                            since_days = NULL,
                            publication_types = c("ExAnte", "Tender"),
                            contracting_rules = "VOL",
                            screen_details = TRUE,
                            max_detail = Inf,
                            screen_notice = FALSE,
                            max_notice = Inf,
                            username = "",
                            password = "",
                            cache_dir = "reports",
                            relevant_only = FALSE,
                            headless = TRUE) {
  if (isTRUE(screen_notice)) login <- TRUE # notice PDFs need a logged-in session
  urls <- cosinex_urls(base_url, mount = mount)
  stop_before <- if (!is.null(since_days)) Sys.Date() - as.integer(since_days) else NULL

  session <- vmp_bb_session(headless = headless)
  on.exit(try(session$close(), silent = TRUE), add = TRUE)
  if (isTRUE(login)) {
    vmp_bb_login(session, username = username, password = password, auth_url = urls$auth)
  }

  tenders <- vmp_bb_scrape_tenders(
    session,
    publication_types = publication_types,
    contracting_rules = contracting_rules,
    max_pages = max_pages,
    search_url = urls$search,
    stop_before = stop_before
  )
  # Canonical date column names, shared with the API connectors (the portal
  # headers are e.g. "Veroeffentlicht" / "Angebots- / Teilnahmefrist").
  names(tenders)[grepl("frist", names(tenders), ignore.case = TRUE)] <- "Frist"
  names(tenders)[grepl("ffentlich", names(tenders), ignore.case = TRUE)] <- "Veroeffentlicht"
  # Classify by the portal's Verfahrensart ("Typ") where present: "Beabsichtigte
  # ..." = planned, "Vergeben ..." = awarded (refines the search-type label).
  if (!is.null(tenders$Typ)) {
    tenders$Veroeffentlichungstyp[grepl("beabsichtigt", tenders$Typ, ignore.case = TRUE)] <-
      "Geplante Ausschreibung"
    tenders$Veroeffentlichungstyp[grepl("vergeben", tenders$Typ, ignore.case = TRUE)] <-
      "Vergebener Auftrag"
  }
  scored <- score_relevance(tenders, keywords = keywords)

  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  if (isTRUE(screen_details)) {
    f <- file.path(cache_dir, sprintf("detail_cache_%s.rds", slug))
    scored <- enrich_with_details(session, scored, keywords = keywords,
                                  max_detail = max_detail, cache = read_detail_cache(f))
    write_detail_cache(attr(scored, "detail_cache"), f)
  }
  if (isTRUE(screen_notice)) {
    f <- file.path(cache_dir, sprintf("notice_cache_%s.rds", slug))
    scored <- enrich_with_notice(session, scored, keywords = keywords,
                                 max_notice = max_notice, cache = read_notice_cache(f))
    write_notice_cache(attr(scored, "notice_cache"), f)
  }

  scored <- apply_title_excludes(scored, keywords = keywords) # drop pure building/maintenance titles
  scored$Plattform <- plattform
  if (isTRUE(relevant_only)) scored <- scored[scored$is_relevant %in% TRUE, , drop = FALSE]
  scored
}

#' Vergabemarktplatz NRW connector (cosinex)
#'
#' Thin wrapper around [cosinex_tenders()] for Vergabemarktplatz NRW
#' (`evergabe.nrw.de`). The published search is login-free; an optional login
#' (`login = TRUE`, or `screen_notice = TRUE` for the Bekanntmachung-PDF layer)
#' uses the same cosinex Keycloak flow as Brandenburg and needs an NRW account.
#'
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param username,password NRW credentials for the optional login (default env
#'   vars `VMP_NRW_USERNAME` / `VMP_NRW_PASSWORD`).
#' @param ... Further arguments passed to [cosinex_tenders()] (e.g. `login`,
#'   `screen_notice`, `publication_types`, `contracting_rules`, `since_days`,
#'   `max_pages`, `cache_dir`, `relevant_only`).
#' @return A scored tibble with `Plattform = "Vergabemarktplatz NRW"`.
#' @export
#' @examples
#' \dontrun{
#' vmp_nrw_tenders(max_pages = 2)
#' }
vmp_nrw_tenders <- function(keywords = tender_keywords(),
                            username = Sys.getenv("VMP_NRW_USERNAME"),
                            password = Sys.getenv("VMP_NRW_PASSWORD"),
                            ...) {
  cosinex_tenders(base_url = "https://www.evergabe.nrw.de",
                  plattform = "Vergabemarktplatz NRW", slug = "vmp_nrw",
                  mount = "VMPCenter", keywords = keywords,
                  username = username, password = password, ...)
}

#' Deutsches Vergabeportal (DTVP) connector (cosinex)
#'
#' Thin wrapper around [cosinex_tenders()] for the Deutsches Vergabeportal
#' (`dtvp.de`). DTVP uses the `"Center"` mount; its published search is
#' login-free (registration is only needed to submit bids).
#'
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param ... Further arguments passed to [cosinex_tenders()] (e.g. `login`,
#'   `publication_types`, `contracting_rules`, `since_days`, `max_pages`,
#'   `cache_dir`, `relevant_only`).
#' @return A scored tibble with `Plattform = "Deutsches Vergabeportal (DTVP)"`.
#' @export
#' @examples
#' \dontrun{
#' dtvp_tenders(max_pages = 2)
#' }
dtvp_tenders <- function(keywords = tender_keywords(), ...) {
  cosinex_tenders(base_url = "https://www.dtvp.de",
                  plattform = "Deutsches Vergabeportal (DTVP)", slug = "dtvp",
                  mount = "Center", keywords = keywords, ...)
}
