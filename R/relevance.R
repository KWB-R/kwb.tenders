# Relevance scoring ------------------------------------------------------------

#' KWB research-group keywords
#'
#' Reads the keyword lists for all KWB research groups shipped with the package
#' (`inst/extdata/keywords.yml`). Each group has a display `name` and `strong` /
#' `supporting` keyword vectors.
#'
#' @param dir Directory holding the per-group keyword files
#'   (`keywords_<slug>.yml`, one file per research group).
#' @return A named list of groups (named by slug), each a list with `name`,
#'   `strong`, `supporting`.
#' @export
#' @examples
#' names(tender_keywords())
tender_keywords <- function(dir = system.file("extdata", package = "kwb.tenders")) {
  files <- list.files(dir, pattern = "^keywords_.*\\.ya?ml$", full.names = TRUE)
  files <- files[!grepl("^keywords_exclude\\.ya?ml$", basename(files))] # veto list, not a group
  if (length(files) == 0L) {
    stop("No keyword files (keywords_*.yml) found in: ", dir, call. = FALSE)
  }
  groups <- lapply(files, yaml::read_yaml)
  names(groups) <- sub("^keywords_(.*)\\.ya?ml$", "\\1", basename(files))
  groups
}

#' @noRd
or_empty <- function(x) if (is.null(x)) character() else as.character(x)

#' Normalise keyword input into a list of groups (name/strong/supporting)
#' @noRd
normalize_keyword_groups <- function(keywords) {
  # A single group passed directly as list(strong = ..., supporting = ...).
  if (!is.null(keywords$strong) || !is.null(keywords$supporting)) {
    return(list(list(
      name = "Relevant",
      strong = or_empty(keywords$strong),
      supporting = or_empty(keywords$supporting)
    )))
  }
  nms <- names(keywords)
  lapply(seq_along(keywords), function(i) {
    g <- keywords[[i]]
    list(
      name = if (!is.null(g$name)) as.character(g$name) else nms[i],
      strong = or_empty(g$strong),
      supporting = or_empty(g$supporting)
    )
  })
}

#' Normalise German text for matching: fold umlauts (ae/oe/ue/ss) + lowercase
#'
#' Makes matching robust to both "Klaerschlamm" and the umlaut spelling. Umlaut
#' characters are built via [intToUtf8()] so this source file stays ASCII.
#' @noRd
normalize_de <- function(x) {
  lower <- intToUtf8(c(0x00e4, 0x00f6, 0x00fc, 0x00df)) # a-uml, o-uml, u-uml, sz
  upper <- intToUtf8(c(0x00c4, 0x00d6, 0x00dc))         # A-uml, O-uml, U-uml
  reps <- list(
    c(substr(upper, 1, 1), "Ae"), c(substr(lower, 1, 1), "ae"),
    c(substr(upper, 2, 2), "Oe"), c(substr(lower, 2, 2), "oe"),
    c(substr(upper, 3, 3), "Ue"), c(substr(lower, 3, 3), "ue"),
    c(substr(lower, 4, 4), "ss")
  )
  for (r in reps) x <- gsub(r[1], r[2], x, fixed = TRUE)
  tolower(x)
}

#' Combined normalised text per row (all character columns)
#' @noRd
build_row_text <- function(tenders) {
  char_cols <- vapply(tenders, is.character, logical(1))
  if (!any(char_cols)) return(rep("", nrow(tenders)))
  parts <- lapply(tenders[char_cols], function(x) ifelse(is.na(x), "", as.character(x)))
  normalize_de(do.call(paste, c(parts, sep = " | ")))
}

#' Matched keywords per row (case-insensitive, umlaut-folded substring)
#' @noRd
match_terms <- function(row_text, kws) {
  n <- length(row_text)
  if (length(kws) == 0L) return(rep(list(character()), n))
  mat <- vapply(normalize_de(kws), function(k) grepl(k, row_text, fixed = TRUE), logical(n))
  if (is.null(dim(mat))) mat <- matrix(mat, nrow = n)
  lapply(seq_len(n), function(i) kws[mat[i, ]])
}

#' Score tenders for relevance to KWB research groups
#'
#' Case-insensitive substring matching of each group's keywords against all
#' character columns. A tender matches a group if it contains at least one
#' `strong` keyword or at least two `supporting` keywords; it is relevant if it
#' matches at least one group.
#'
#' @param tenders A data frame / tibble of tenders (e.g. from
#'   [vmp_bb_scrape_tenders()]).
#' @param keywords Keyword groups (default [tender_keywords()]). May also be a
#'   single group as `list(strong = ..., supporting = ...)`.
#' @return `tenders` with added columns `groups` (matching group names, comma
#'   separated), `matched_keywords`, `score` and `is_relevant`, sorted by
#'   descending score.
#' @export
#' @examples
#' df <- data.frame(
#'   Bezeichnung = c("Grundwassermonitoring Brunnen", "Kanalsanierung Sensorik"),
#'   stringsAsFactors = FALSE
#' )
#' res <- score_relevance(df)
#' res[, c("Bezeichnung", "groups", "score")]
score_relevance <- function(tenders, keywords = tender_keywords()) {
  groups <- normalize_keyword_groups(keywords)
  n <- nrow(tenders)
  if (n == 0L) {
    tenders$groups <- character()
    tenders$matched_keywords <- character()
    tenders$score <- integer()
    tenders$is_relevant <- logical()
    return(tenders)
  }

  row_text <- build_row_text(tenders)
  group_names <- vapply(groups, function(g) g$name, character(1))
  match_mat <- matrix(FALSE, nrow = n, ncol = length(groups))
  terms_per_row <- replicate(n, character(0), simplify = FALSE)
  score <- integer(n)

  for (gi in seq_along(groups)) {
    g <- groups[[gi]]
    sh <- match_terms(row_text, g$strong)
    ph <- match_terms(row_text, g$supporting)
    ns <- lengths(sh)
    np <- lengths(ph)
    matched <- ns >= 1L | np >= 2L
    match_mat[, gi] <- matched
    score <- score + ifelse(matched, 2L * ns + np, 0L)
    for (i in which(matched)) {
      terms_per_row[[i]] <- c(terms_per_row[[i]], sh[[i]], ph[[i]])
    }
  }

  tenders$groups <- vapply(seq_len(n), function(i) {
    paste(group_names[match_mat[i, ]], collapse = ", ")
  }, character(1))
  tenders$matched_keywords <- vapply(seq_len(n), function(i) {
    paste(unique(terms_per_row[[i]]), collapse = ", ")
  }, character(1))
  tenders$score <- as.integer(score)
  tenders$is_relevant <- !is.na(tenders$groups) & nzchar(tenders$groups)

  tenders[order(-tenders$score), , drop = FALSE]
}

#' Per-row matching group names (no reordering), given normalised groups
#' @noRd
.row_group_hits <- function(df, groups) {
  n <- nrow(df)
  if (n == 0L) return(character(0))
  row_text <- build_row_text(df)
  gn <- vapply(groups, function(g) g$name, character(1))
  mm <- matrix(FALSE, nrow = n, ncol = length(groups))
  for (gi in seq_along(groups)) {
    g <- groups[[gi]]
    ns <- lengths(match_terms(row_text, g$strong))
    np <- lengths(match_terms(row_text, g$supporting)) # empty supporting -> strong-only
    mm[, gi] <- ns >= 1L | np >= 2L
  }
  vapply(seq_len(n), function(i) paste(gn[mm[i, ]], collapse = ", "), character(1))
}

#' Layered relevance scoring for portal connectors (title + long text + CPV)
#'
#' Scores a tender tibble the way the VMP-BB pipeline does, but in one call for
#' connectors that already ship a description and CPV codes (e.g. the API
#' portals): `title_cols` use the full rule (>=1 strong OR >=2 supporting),
#' `text_cols` (long free text) are matched STRONG-only (incidental supporting
#' hits in long text are noise), and `cpv_col` codes are mapped to groups. The
#' three group sets are merged into `groups`, with `match_source`
#' (title/detail/cpv), `cpv_groups`, `score` and `is_relevant`.
#'
#' @param df A data frame of tenders.
#' @param title_cols Columns scored with the full rule (e.g. the title).
#' @param text_cols Columns scored strong-only (e.g. description); default none.
#' @param cpv_col Name of a comma/space-separated CPV column, or `NULL`.
#' @param keywords Keyword groups (default [tender_keywords()]).
#' @param cpv_map CPV-to-group map (default [tender_cpv_map()]).
#' @param exclude Apply [apply_title_excludes()] afterwards to drop construction
#'   / building / maintenance tenders (default `TRUE`).
#' @return `df` with `groups`, `cpv_groups`, `match_source`, `score`,
#'   `is_relevant` added, sorted by descending score.
#' @export
score_layered <- function(df, title_cols, text_cols = character(), cpv_col = NULL,
                          keywords = tender_keywords(), cpv_map = tender_cpv_map(),
                          exclude = TRUE) {
  n <- nrow(df)
  full <- normalize_keyword_groups(keywords)
  strong <- lapply(full, function(g) list(name = g$name, strong = g$strong, supporting = character()))
  # slug2name must be keyed by slug (names of the keyword list) for the CPV map.
  slug2name <- vapply(keywords, function(g) if (is.null(g$name)) "" else as.character(g$name),
                      character(1))
  split_g <- function(x) { g <- unlist(strsplit(x, ", ", fixed = TRUE)); g[nzchar(g)] }
  pick <- function(cols) {
    cols <- intersect(cols, names(df))
    if (length(cols) == 0L) return(data.frame(.t = rep("", n), stringsAsFactors = FALSE))
    df[, cols, drop = FALSE]
  }

  title_hits <- if (n) .row_group_hits(pick(title_cols), full) else character(0)
  text_hits <- if (n && length(text_cols)) .row_group_hits(pick(text_cols), strong) else rep("", n)
  cpv_hits <- rep("", n)
  if (n && !is.null(cpv_col) && !is.null(df[[cpv_col]])) {
    cpv_hits <- vapply(as.character(df[[cpv_col]]), function(s) {
      codes <- unlist(strsplit(s, "[,; ]+"))
      paste(cpv_to_group_names(codes[nzchar(codes)], cpv_map, slug2name), collapse = ", ")
    }, character(1), USE.NAMES = FALSE)
  }

  df$groups <- if (n) vapply(seq_len(n), function(i) {
    paste(unique(split_g(c(title_hits[i], text_hits[i], cpv_hits[i]))), collapse = ", ")
  }, character(1)) else character(0)
  df$cpv_groups <- cpv_hits
  df$match_source <- if (n) vapply(seq_len(n), function(i) paste(c(
    if (nzchar(title_hits[i])) "title",
    if (nzchar(text_hits[i])) "detail",
    if (nzchar(cpv_hits[i])) "cpv"
  ), collapse = "+"), character(1)) else character(0)
  df$is_relevant <- !is.na(df$groups) & nzchar(df$groups)
  df$score <- if (n) vapply(strsplit(df$groups, ", ", fixed = TRUE),
                            function(g) sum(nzchar(g)), integer(1)) else integer(0)
  out <- df[order(-df$score), , drop = FALSE]
  if (isTRUE(exclude)) out <- apply_title_excludes(out, title_cols = title_cols, keywords = keywords)
  out
}

#' Title-level exclusion (veto) terms
#'
#' Reads `inst/extdata/keywords_exclude.yml` -- terms that mark a tender as not
#' relevant when they appear in its title (and no strong water keyword does). Used
#' by [apply_title_excludes()]. This file is deliberately ignored by
#' [tender_keywords()]; it is not a research group.
#'
#' @param path YAML file with a `terms:` list (and optional `name`).
#' @return A list with `name` and `terms` (character vector).
#' @export
tender_excludes <- function(path = system.file("extdata", "keywords_exclude.yml", package = "kwb.tenders")) {
  if (!nzchar(path) || !file.exists(path)) return(list(name = "exclude", terms = character()))
  y <- yaml::read_yaml(path)
  list(name = if (!is.null(y$name)) as.character(y$name) else "exclude", terms = or_empty(y$terms))
}

#' Veto out-of-scope tenders (construction / building / maintenance)
#'
#' Drops tenders that are not a fit for a research institute, two ways:
#' \enumerate{
#'   \item \strong{title} contains a building/maintenance term (see
#'     [tender_excludes()]) and no strong water keyword rescues it (so a
#'     "Grundwasser..." title is kept);
#'   \item \strong{CPV} shows a works / maintenance / cleaning code (\code{45...}
#'     Bau, \code{50...} Reparatur/Wartung, \code{9046/9047/9061/9064/9091...}
#'     Reinigung) without an engineering-services code (\code{71...}); hard veto,
#'     so even "Neubau Klaeranlage" or "Reinigung Faulbehaelter" is dropped while
#'     "Ingenieurleistungen ..." stays.
#' }
#' Sets `is_relevant = FALSE` and records the reason in an `excluded` column.
#' Matching folds umlauts / is case-insensitive.
#'
#' @param df A scored tibble (must contain `is_relevant`).
#' @param title_cols Candidate title columns (those present are used).
#' @param keywords Keyword groups, for the strong-keyword rescue (default
#'   [tender_keywords()]).
#' @param excludes Exclusion list (default [tender_excludes()]).
#' @return `df` with vetoed rows' `is_relevant` set `FALSE` and an `excluded` column.
#' @export
apply_title_excludes <- function(df,
                                 title_cols = c("Kurzbezeichnung", "Bezeichnung", "Titel"),
                                 keywords = tender_keywords(),
                                 excludes = tender_excludes()) {
  n <- nrow(df)
  if (n == 0L || is.null(df$is_relevant)) return(df)
  matched <- rep(NA_character_, n)

  # (1) Title veto: building/maintenance terms, unless a strong water term rescues.
  terms <- excludes$terms
  tcols <- intersect(title_cols, names(df))
  if (length(terms) && length(tcols)) {
    title <- normalize_de(do.call(paste, c(df[tcols], sep = " ")))
    ex_norm <- normalize_de(terms)
    strong_all <- normalize_de(unlist(lapply(normalize_keyword_groups(keywords), function(g) g$strong)))
    for (i in which(df$is_relevant %in% TRUE)) {
      if (any(vapply(strong_all, function(k) grepl(k, title[i], fixed = TRUE), logical(1)))) next # water title -> keep
      hit <- which(vapply(ex_norm, function(k) grepl(k, title[i], fixed = TRUE), logical(1)))
      if (length(hit)) matched[i] <- terms[hit[1]]
    }
  }

  # (2) Out-of-scope CPV veto: a works / maintenance / cleaning code without an
  # engineering-services code (71...) is a Bau-/Wartungs-/Reinigungsauftrag -> out
  # (KWB does studies/planning/monitoring, not works). Hard (no water rescue), so
  # "Neubau Klaeranlage" (45...) and "Reinigung Faulbehaelter" (9046...) are
  # dropped while "Ingenieurleistungen ..." (71...) is kept.
  if (!is.null(df$cpv)) {
    oos <- c("45", "50", "9046", "9047", "9061", "9064", "9091") # Bau / Reparatur+Wartung / Reinigung
    cpv_chr <- as.character(df$cpv)
    cpv_chr[is.na(cpv_chr)] <- ""
    for (i in which(df$is_relevant %in% TRUE & is.na(matched))) {
      codes <- trimws(unlist(strsplit(cpv_chr[i], "[,; ]+")))
      codes <- codes[nzchar(codes)]
      out_of_scope <- any(vapply(oos, function(p) any(startsWith(codes, p)), logical(1)))
      if (length(codes) && out_of_scope && !any(startsWith(codes, "71"))) {
        matched[i] <- "Bau/Wartung-CPV"
      }
    }
  }

  df$excluded <- matched
  df$is_relevant[!is.na(matched)] <- FALSE
  df
}
