# Report rendering -------------------------------------------------------------

#' Write a tender overview report (Excel + Markdown + HTML)
#'
#' Writes a dated Excel workbook (sheets "Relevant", "Alle", "Neu"), a
#' `latest.md` summary, a browsable `latest.html` (for GitHub Pages) and a small
#' state file used to flag tenders that are new since the previous run.
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

  # Aktion holds the project detail URL; derive project_url + a stable id (pid).
  tenders$project_url <- if (!is.null(tenders$Aktion)) {
    as.character(tenders$Aktion)
  } else {
    rep(NA_character_, nrow(tenders))
  }
  tenders$tender_id <- tender_ids(tenders)

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
  if (!is.null(tenders$cpv) && any(nzchar(tenders$cpv))) {
    add_sheet("CPV", cpv_summary(tenders))
  }
  openxlsx::saveWorkbook(wb, xlsx_file, overwrite = TRUE)

  # Markdown summary --------------------------------------------------------
  md_file <- file.path(dir, "latest.md")
  writeLines(
    render_tender_markdown(tenders, relevant, new_relevant, portal, date),
    md_file
  )

  # HTML summary (browsable on GitHub Pages) --------------------------------
  html_file <- file.path(dir, "latest.html")
  writeLines(
    render_tender_html(tenders, relevant, new_relevant, portal, date),
    html_file
  )

  # Persist state for the next run ------------------------------------------
  saveRDS(tenders$tender_id, state_file)

  invisible(list(
    xlsx = xlsx_file,
    md = md_file,
    html = html_file,
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

  if (nrow(relevant) == 0L) {
    return(c(lines, "## Relevante Vergaben (0)", "", "Keine relevanten Vergaben gefunden."))
  }
  typ <- if (!is.null(relevant$Veroeffentlichungstyp)) {
    as.character(relevant$Veroeffentlichungstyp)
  } else {
    rep("Ausschreibung", nrow(relevant))
  }
  ord <- c("Ausschreibung", "Geplante Ausschreibung", "Vergebener Auftrag")
  present <- c(intersect(ord, unique(typ)), setdiff(unique(typ), ord))
  for (tp in present) {
    sub <- relevant[typ == tp, , drop = FALSE]
    if (nrow(sub) == 0L) next
    lines <- c(lines, sprintf("## %s (%d)", tp, nrow(sub)), "",
               tender_markdown_table(sub), "")
  }
  lines
}

#' Build a Markdown table from a sensible subset of tender columns
#' @noRd
tender_markdown_table <- function(df) {
  meta <- c("tender_id", "is_relevant", "is_new", "Aktion", "project_url",
            "groups", "match_source", "score", "matched_keywords",
            "detail_groups", "cpv", "cpv_groups", "notice_groups",
            "Veroeffentlichungstyp")
  base_cols <- setdiff(names(df), meta)
  if (length(base_cols) > 5L) base_cols <- base_cols[seq_len(5L)]
  cols <- c(base_cols, "groups", "match_source", "score", "matched_keywords")
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

#' Render a browsable, filterable HTML report (interactive DataTables table)
#'
#' The relevant tenders are shown in a sortable/filterable table (global search,
#' per-column filters, pagination) enhanced with DataTables from a CDN. Without
#' JavaScript it degrades to a plain HTML table.
#' @noRd
render_tender_html <- function(tenders, relevant, new_relevant, portal, date) {
  esc <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
  }

  meta <- c("tender_id", "is_relevant", "is_new", "Aktion", "project_url",
            "groups", "match_source", "score", "matched_keywords",
            "detail_groups", "cpv", "cpv_groups", "notice_groups",
            "Veroeffentlichungstyp")
  base_cols <- setdiff(names(relevant), meta)
  if (length(base_cols) > 5L) base_cols <- base_cols[seq_len(5L)]
  data_cols <- c(base_cols, "groups", "match_source", "score", "matched_keywords")
  data_cols <- data_cols[data_cols %in% names(relevant)]
  headers <- c(data_cols, "Neu", "Link")

  gl <- if (!is.null(relevant$groups)) unlist(strsplit(relevant$groups, ", ", fixed = TRUE)) else character()
  gl <- gl[nzchar(gl)]
  grp_line <- if (length(gl) > 0) {
    tab <- sort(table(gl), decreasing = TRUE)
    paste0("Treffer je Gruppe: ", paste(sprintf("%s (%d)", names(tab), as.integer(tab)), collapse = ", "))
  } else {
    ""
  }

  css <- paste(
    "body{font-family:system-ui,Segoe UI,Arial,sans-serif;margin:1.5rem;color:#222}",
    "h1{font-size:1.4rem}.muted{color:#666;font-size:14px}",
    "table.dataTable td{vertical-align:top;font-size:13px}",
    "tfoot input{width:100%;box-sizing:border-box;font-weight:normal}",
    sep = "\n"
  )

  head_part <- c(
    "<!doctype html>",
    "<html lang=\"de\"><head><meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    sprintf("<title>Vergabe-Report %s</title>", toupper(portal)),
    "<link rel=\"stylesheet\" href=\"https://cdn.datatables.net/2.1.8/css/dataTables.dataTables.min.css\">",
    sprintf("<style>%s</style></head><body>", css),
    sprintf("<h1>Vergabe-Report (%s)</h1>", toupper(portal)),
    sprintf("<p class=\"muted\">Stand: %s &middot; Gesamt: %d &middot; relevant: %d &middot; neu: %d</p>",
            format(date, "%Y-%m-%d"), nrow(tenders), nrow(relevant), nrow(new_relevant))
  )
  if (nzchar(grp_line)) {
    head_part <- c(head_part, sprintf("<p class=\"muted\">%s</p>", esc(grp_line)))
  }

  if (nrow(relevant) == 0L) {
    return(c(head_part, "<p>Keine relevanten Vergaben gefunden.</p>", "</body></html>"))
  }

  head_cells <- paste0("<th>", esc(headers), "</th>", collapse = "")
  one_table <- function(sub, id) {
    body_rows <- vapply(seq_len(nrow(sub)), function(i) {
      vals <- vapply(data_cols, function(cn) esc(sub[[cn]][i]), character(1))
      neu <- if (isTRUE(sub$is_new[i])) "ja" else "nein"
      u <- if (!is.null(sub$project_url)) sub$project_url[i] else NA_character_
      link <- if (!is.na(u) && nzchar(u)) sprintf("<a href=\"%s\" target=\"_blank\">Details</a>", esc(u)) else ""
      paste0("<tr>", paste0("<td>", c(vals, neu, link), "</td>", collapse = ""), "</tr>")
    }, character(1))
    paste0("<table id=\"", id, "\" class=\"display tender-table\" style=\"width:100%\">",
           "<thead><tr>", head_cells, "</tr></thead>",
           "<tfoot><tr>", head_cells, "</tr></tfoot>",
           "<tbody>", paste(body_rows, collapse = ""), "</tbody></table>")
  }

  typ <- if (!is.null(relevant$Veroeffentlichungstyp)) {
    as.character(relevant$Veroeffentlichungstyp)
  } else {
    rep("Ausschreibung", nrow(relevant))
  }
  ord <- c("Ausschreibung", "Geplante Ausschreibung", "Vergebener Auftrag")
  present <- c(intersect(ord, unique(typ)), setdiff(unique(typ), ord))
  body_parts <- "<p class=\"muted\">Tabellen: oben global suchen, Spalten per Klick sortieren, unten je Spalte filtern.</p>"
  k <- 0L
  for (tp in present) {
    sub <- relevant[typ == tp, , drop = FALSE]
    if (nrow(sub) == 0L) next
    k <- k + 1L
    body_parts <- c(body_parts, sprintf("<h2>%s (%d)</h2>", esc(tp), nrow(sub)),
                    one_table(sub, paste0("tenders-", k)))
  }

  score_idx <- which(headers == "score")
  opts_line <- if (length(score_idx) > 0) {
    sprintf("      pageLength: 25, scrollX: true, order: [[%d, 'desc']],", score_idx[1] - 1L)
  } else {
    "      pageLength: 25, scrollX: true,"
  }

  scripts <- c(
    "<script src=\"https://code.jquery.com/jquery-3.7.1.min.js\"></script>",
    "<script src=\"https://cdn.datatables.net/2.1.8/js/dataTables.min.js\"></script>",
    "<script>",
    "$(function () {",
    "  $('table.tender-table').each(function () {",
    "    var tbl = this;",
    "    $('tfoot th', tbl).each(function () { var t = $(this).text(); $(this).html('<input type=\"text\" placeholder=\"' + t + '\" />'); });",
    "    new DataTable(tbl, {",
    opts_line,
    "      initComplete: function () {",
    "        this.api().columns().every(function () {",
    "          var that = this;",
    "          $('input', this.footer()).on('keyup change clear', function () {",
    "            if (that.search() !== this.value) { that.search(this.value).draw(); }",
    "          });",
    "        });",
    "      }",
    "    });",
    "  });",
    "});",
    "</script>"
  )

  c(head_part, body_parts, scripts, "</body></html>")
}
