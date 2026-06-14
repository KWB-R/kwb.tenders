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
  tenders$is_relevant <- nzchar(tenders$groups)

  tenders[order(-tenders$score), , drop = FALSE]
}
