# Report rendering -------------------------------------------------------------

#' Write a tender overview report (Excel + Markdown)
#'
#' Writes a dated Excel workbook (sheets "Relevant", "Alle", "Neu"), a
#' `latest.md` summary that renders nicely on GitHub, and a small state file
#' used to flag tenders that are new since the previous run.
#'
#' @param tenders A scored tibble (see [score_relevance()]).
#' @param dir Output directory (created if needed). Default `"reports"`.
#' @param portal Short portal id used in file names. Default `"vmp-bb"`.
#' @param date Report date (default `Sys.Date()`).
#' @return Invisibly, a list with the written file paths and counts.
#' @export
#' @examples
#' \dontrun{
#' tenders <- score_relevance(vmp_bb_scrape_tenders(session))
#' write_tender_report(tenders)
#' }
write_tender_report <- function(tenders, dir = "reports",
                                portal = "vmp-bb", date = Sys.Date()) {
  if (is.null(tenders$is_relevant)) {
    stop("`tenders` must be scored first (see score_relevance()).", call. = FALSE)
  }
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)

  # Aktion holds the project detail URL; derive a stable id (pid) + project_url.
  url <- if (!is.null(tenders$Aktion)) as.character(tenders$Aktion) else rep(NA_character_, nrow(tenders))
  pid <- stringr::str_match(url, "pid=([0-9]+)")[, 2]
  tenders$project_url <- url
  tenders$tender_id <- ifelse(
    !is.na(pid), pid,
    ifelse(!is.na(url) & nzchar(url), url, paste0("row-", seq_len(nrow(tenders))))
  )

  # Diff against the previous run.
  state_file <- file.path(dir, paste0(portal, "_state.rds"))
  prev_ids <- if (file.exists(state_file)) readRDS(state_file) else character()
  tenders$is_new <- !(tenders$tender_id %in% prev_ids)

  relevant <- tenders[tenders$is_relevant %in% TRUE, , drop = FALSE]
  new_relevant <- relevant[relevant$is_new %in% TRUE, , drop = FALSE]

  # Excel workbook ----------------------------------------------------------
  xlsx_file <- file.path(dir, sprintf("%s_%s.xlsx", portal, format(date, "%Y-%m-%d")))
  wb <- openxlsx::createWorkbook()
  add_sheet <- function(name, data) {
    openxlsx::addWorksheet(wb, name)
    openxlsx::writeData(wb, name, data)
    if (nrow(data) > 0) openxlsx::freezePane(wb, name, firstRow = TRUE)
  }
  add_sheet("Relevant", relevant)
  add_sheet("Alle", tenders)
  add_sheet("Neu", new_relevant)
  openxlsx::saveWorkbook(wb, xlsx_file, overwrite = TRUE)

  # Markdown summary --------------------------------------------------------
  md_file <- file.path(dir, "latest.md")
  writeLines(
    render_tender_markdown(tenders, relevant, new_relevant, portal, date),
    md_file
  )

  # Persist state for the next run ------------------------------------------
  saveRDS(tenders$tender_id, state_file)

  invisible(list(
    xlsx = xlsx_file,
    md = md_file,
    n_total = nrow(tenders),
    n_relevant = nrow(relevant),
    n_new = nrow(new_relevant)
  ))
}

#' Render the Markdown summary for a report
#' @noRd
render_tender_markdown <- function(tenders, relevant, new_relevant, portal, date) {
  lines <- c(
    sprintf("# Vergabe-Report (%s)", toupper(portal)),
    "",
    sprintf("Stand: %s", format(date, "%Y-%m-%d")),
    "",
    sprintf(
      "Gesamt: %d Ausschreibungen, davon %d relevant, %d neu.",
      nrow(tenders), nrow(relevant), nrow(new_relevant)
    ),
    ""
  )

  # Per-group breakdown of the relevant tenders.
  gl <- if (!is.null(relevant$groups)) {
    unlist(strsplit(relevant$groups, ", ", fixed = TRUE))
  } else {
    character()
  }
  gl <- gl[nzchar(gl)]
  if (length(gl) > 0) {
    tab <- sort(table(gl), decreasing = TRUE)
    brk <- paste(sprintf("%s (%d)", names(tab), as.integer(tab)), collapse = ", ")
    lines <- c(lines, sprintf("Treffer je Gruppe: %s", brk), "")
  }

  if (nrow(new_relevant) > 0) {
    lines <- c(
      lines,
      sprintf("## Neu seit letztem Lauf (%d)", nrow(new_relevant)),
      "",
      tender_markdown_table(new_relevant),
      ""
    )
  }

  lines <- c(lines, sprintf("## Relevante Vergaben (%d)", nrow(relevant)), "")
  if (nrow(relevant) > 0) {
    lines <- c(lines, tender_markdown_table(relevant))
  } else {
    lines <- c(lines, "Keine relevanten Vergaben gefunden.")
  }

  lines
}

#' Build a Markdown table from a sensible subset of tender columns
#' @noRd
tender_markdown_table <- function(df) {
  meta <- c("tender_id", "is_relevant", "is_new", "Aktion", "project_url",
            "groups", "score", "matched_keywords")
  base_cols <- setdiff(names(df), meta)
  if (length(base_cols) > 5L) base_cols <- base_cols[seq_len(5L)]
  cols <- c(base_cols, "groups", "score", "matched_keywords")
  cols <- cols[cols %in% names(df)]

  esc <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    gsub("|", "\\|", gsub("[\r\n]+", " ", x), fixed = TRUE)
  }

  has_link <- "project_url" %in% names(df) &&
    any(!is.na(df$project_url) & nzchar(df$project_url))
  out_cols <- c(cols, if (has_link) "Link")

  header <- paste0("| ", paste(out_cols, collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", length(out_cols)), collapse = " | "), " |")
  rows <- vapply(seq_len(nrow(df)), function(i) {
    vals <- vapply(cols, function(cn) esc(df[[cn]][i]), character(1))
    if (has_link) {
      u <- df$project_url[i]
      vals <- c(vals, if (!is.na(u) && nzchar(u)) sprintf("[Details](%s)", u) else "")
    }
    paste0("| ", paste(vals, collapse = " | "), " |")
  }, character(1))

  c(header, sep, rows)
}
