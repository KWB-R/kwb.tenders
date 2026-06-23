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
#' @param date Report timestamp (default `Sys.time()`); its date part names the
#'   files, the full timestamp (Europe/Berlin) shows in the "Stand" line.
#' @return Invisibly, a list with the written file paths and counts.
#' @export
#' @examples
#' \dontrun{
#' tenders <- score_relevance(vmp_bb_scrape_tenders(session))
#' write_tender_report(tenders)
#' }
write_tender_report <- function(tenders, dir = "reports",
                                portal = "vmp-bb", date = Sys.time()) {
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

  # Human-readable names of the CPV codes that drove the cpv layer (derived from
  # the raw codes now, so it tracks the current mapping + labels).
  if (!is.null(tenders$cpv)) {
    tenders$matched_cpv <- matched_cpv_names(tenders$cpv)
  }

  # Normalise date columns to ISO YYYY-MM-DD so the report shows one consistent
  # format across portals (and sorts correctly in the DataTable).
  for (.col in c("Veroeffentlicht", "Frist")) {
    if (!is.null(tenders[[.col]])) tenders[[.col]] <- .format_iso_date(tenders[[.col]])
  }

  relevant <- tenders[tenders$is_relevant %in% TRUE &
                        !is.na(tenders$groups) & nzchar(as.character(tenders$groups)), , drop = FALSE]
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

#' "Treffer je Gruppe: ..." line for a set of tenders ("" if none); each group a
#' tender matched is counted (a tender can match several), descending by count.
#' @noRd
group_breakdown <- function(df) {
  gl <- if (!is.null(df$groups)) unlist(strsplit(as.character(df$groups), ", ", fixed = TRUE)) else character()
  gl <- gl[nzchar(gl)]
  if (!length(gl)) return("")
  tab <- sort(table(gl), decreasing = TRUE)
  paste0("Treffer je Gruppe: ", paste(sprintf("%s (%d)", names(tab), as.integer(tab)), collapse = ", "))
}

#' Build the per-platform breakdown and search-window header lines (plain text)
#'
#' Lists every screened portal with its relevant-hit count (so a portal screened
#' with zero hits is still visible) and the publication-date span actually
#' covered. Shared by both renderers.
#' @noRd
report_meta_lines <- function(tenders, relevant) {
  out <- character()
  splat <- function(v) unlist(strsplit(as.character(v), ", ", fixed = TRUE)) # merged rows list several
  plats <- unique(c(splat(tenders$Plattform), splat(relevant$Plattform)))
  plats <- plats[!is.na(plats) & nzchar(plats)]
  if (length(plats) > 0) {
    relp <- splat(relevant$Plattform)
    cnt <- vapply(plats, function(p) sum(relp == p, na.rm = TRUE), integer(1))
    o <- order(cnt, decreasing = TRUE)
    out <- c(out, sprintf("Treffer je Plattform: %s",
                          paste(sprintf("%s (%d)", plats[o], cnt[o]), collapse = ", ")))
  }
  if (!is.null(tenders$Veroeffentlicht)) {
    vd <- .parse_pub_date(tenders$Veroeffentlicht)
    vd <- vd[!is.na(vd)]
    if (length(vd) > 0) {
      out <- c(out, sprintf("Suchzeitraum: %s bis %s (%d Tage)",
                            format(min(vd)), format(max(vd)),
                            as.integer(max(vd) - min(vd)) + 1L))
    }
  }
  out
}

#' Render the Markdown summary for a report
#' @noRd
render_tender_markdown <- function(tenders, relevant, new_relevant, portal, date) {
  lines <- c(
    sprintf("# Vergabe-Report (%s)", toupper(portal)),
    "",
    sprintf("Stand: %s", format(date, "%Y-%m-%d %H:%M %Z", tz = "Europe/Berlin")),
    "",
    sprintf(
      "Gesamt: %d Ausschreibungen, davon %d relevant, %d neu.",
      nrow(tenders), nrow(relevant), nrow(new_relevant)
    ),
    ""
  )

  # Per-group breakdown of the relevant tenders (overall).
  gb <- group_breakdown(relevant)
  if (nzchar(gb)) lines <- c(lines, gb, "")

  ml <- report_meta_lines(tenders, relevant)
  if (length(ml) > 0) lines <- c(lines, ml, "")

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
  typ[is.na(typ) | !nzchar(typ)] <- "Ausschreibung" # no blank-heading section
  ord <- c("Geplante Ausschreibung", "Ausschreibung", "Vergebener Auftrag")
  present <- c(intersect(ord, unique(typ)), setdiff(unique(typ), ord))
  for (tp in present) {
    sub <- relevant[typ == tp, , drop = FALSE]
    if (nrow(sub) == 0L) next
    gb <- group_breakdown(sub)
    lines <- c(lines, sprintf("## %s (%d)", tp, nrow(sub)), "")
    if (nzchar(gb)) lines <- c(lines, gb, "")
    lines <- c(lines, tender_markdown_table(sub), "")
  }
  lines
}

#' Short platform label for compact link / cross-tab display
#' @noRd
.platform_short <- function(p) {
  m <- c("Oeffentliche Vergabe (Bund)" = "Bund", "TED (EU)" = "TED",
         "Vergabemarktplatz Brandenburg" = "BB", "Vergabemarktplatz NRW" = "NRW",
         "Deutsches Vergabeportal (DTVP)" = "DTVP", "Vergabeplattform Berlin" = "Berlin",
         "Serviceportal des Bundes (service.bund.de)" = "service.bund",
         "e-Vergabe des Bundes (evergabe-online.de)" = "e-Vergabe")
  out <- unname(m[as.character(p)])
  ifelse(is.na(out), as.character(p), out)
}

#' Per-portal (label, url) links for one tender row; for a deduped tender on
#' several portals returns one pair per portal, else a single "Details" link.
#' @noRd
.portal_link_pairs <- function(plattform, portal_links, project_url) {
  multi <- length(plattform) == 1L && !is.na(plattform) && grepl(", ", plattform, fixed = TRUE)
  if (multi && length(portal_links) == 1L && !is.na(portal_links) && nzchar(portal_links)) {
    labs <- .platform_short(strsplit(plattform, ", ", fixed = TRUE)[[1]])
    urls <- strsplit(portal_links, " | ", fixed = TRUE)[[1]]
    nn <- min(length(labs), length(urls))
    keep <- which(nzchar(urls[seq_len(nn)]))
    if (length(keep)) return(list(label = labs[keep], url = urls[keep]))
  }
  if (length(project_url) == 1L && !is.na(project_url) && nzchar(project_url)) {
    return(list(label = "Details", url = project_url))
  }
  list(label = character(), url = character())
}

#' Cross-portal redundancy matrix as HTML (empty if no tender is multi-listed)
#' @noRd
redundancy_matrix_html <- function(relevant, esc) {
  if (is.null(relevant$Plattform) || !nrow(relevant)) return(character())
  sets <- lapply(strsplit(as.character(relevant$Plattform), ", ", fixed = TRUE), unique)
  nmulti <- sum(vapply(sets, length, integer(1)) >= 2L)
  if (nmulti == 0L) return(character()) # nothing redundant -> no table
  plats <- sort(unique(unlist(sets)))
  M <- matrix(0L, length(plats), length(plats), dimnames = list(plats, plats))
  for (s in sets) for (a in s) for (b in s) M[a, b] <- M[a, b] + 1L
  short <- .platform_short(plats)
  th <- paste0("<th></th>", paste0("<th>", esc(short), "</th>", collapse = ""))
  rows <- vapply(seq_along(plats), function(i) {
    cells <- vapply(seq_along(plats), function(j) {
      v <- M[i, j]
      sprintf("<td%s>%s</td>", if (i != j && v > 0L) " class=\"hot\"" else "",
              if (v > 0L) v else "")
    }, character(1))
    paste0("<tr><th>", esc(short[i]), "</th>", paste(cells, collapse = ""), "</tr>")
  }, character(1))
  c("<h2>Plattform-&Uuml;berschneidungen</h2>",
    sprintf(paste0("<p class=\"muted\">%d von %d relevanten Vergaben sind auf &ge;2 Portalen ",
                   "gelistet. Diagonale = gesamt je Portal, au&szlig;erhalb = gemeinsam.</p>"),
            nmulti, nrow(relevant)),
    "<table class=\"xtab\"><thead><tr>", th, "</tr></thead><tbody>",
    rows, "</tbody></table>")
}

#' Build a Markdown table from a sensible subset of tender columns
#' @noRd
tender_markdown_table <- function(df) {
  meta <- c("tender_id", "is_relevant", "is_new", "Aktion", "project_url", "portal_links",
            "groups", "match_source", "score", "matched_keywords", "matched_cpv",
            "detail_groups", "cpv", "cpv_groups", "notice_groups", "excluded",
            "Plattform", "Beschreibung", "ocid", "publication_number", "Veroeffentlicht",
            "Frist", "Veroeffentlichungstyp", "Typ")
  base_cols <- setdiff(names(df), meta)
  if (length(base_cols) > 5L) base_cols <- base_cols[seq_len(5L)]
  cols <- c(if ("Plattform" %in% names(df)) "Plattform", base_cols,
            "Veroeffentlicht", "Frist", "groups", "match_source", "matched_cpv",
            "score", "matched_keywords")
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
      pr <- .portal_link_pairs(if (!is.null(df$Plattform)) df$Plattform[i] else NA,
                               if (!is.null(df$portal_links)) df$portal_links[i] else NA,
                               df$project_url[i])
      vals <- c(vals, if (length(pr$url)) {
        paste(sprintf("[%s](%s)", pr$label, pr$url), collapse = " / ")
      } else "")
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

  meta <- c("tender_id", "is_relevant", "is_new", "Aktion", "project_url", "portal_links",
            "groups", "match_source", "score", "matched_keywords", "matched_cpv",
            "detail_groups", "cpv", "cpv_groups", "notice_groups", "excluded",
            "Plattform", "Beschreibung", "ocid", "publication_number", "Veroeffentlicht",
            "Frist", "Veroeffentlichungstyp", "Typ")
  base_cols <- setdiff(names(relevant), meta)
  if (length(base_cols) > 5L) base_cols <- base_cols[seq_len(5L)]
  data_cols <- c(if ("Plattform" %in% names(relevant)) "Plattform", base_cols,
                 "Veroeffentlicht", "Frist", "groups", "match_source", "matched_cpv",
                 "score", "matched_keywords")
  data_cols <- data_cols[data_cols %in% names(relevant)]
  headers <- c(data_cols, "Neu", "Link")

  grp_line <- group_breakdown(relevant)

  css <- paste(
    "body{font-family:system-ui,Segoe UI,Arial,sans-serif;margin:1.5rem;color:#222}",
    "h1{font-size:1.4rem}.muted{color:#666;font-size:14px}",
    "table.dataTable td{vertical-align:top;font-size:13px}",
    "tfoot input{width:100%;box-sizing:border-box;font-weight:normal}",
    "table.xtab{border-collapse:collapse;font-size:13px;margin:.4rem 0 1rem}",
    "table.xtab th,table.xtab td{border:1px solid #ddd;padding:3px 9px;text-align:center}",
    "table.xtab td.hot{background:#fde9a9;font-weight:bold}",
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
            format(date, "%Y-%m-%d %H:%M %Z", tz = "Europe/Berlin"), nrow(tenders), nrow(relevant), nrow(new_relevant))
  )
  if (nzchar(grp_line)) {
    head_part <- c(head_part, sprintf("<p class=\"muted\">%s</p>", esc(grp_line)))
  }
  for (ln in report_meta_lines(tenders, relevant)) {
    head_part <- c(head_part, sprintf("<p class=\"muted\">%s</p>", esc(ln)))
  }
  head_part <- c(head_part, redundancy_matrix_html(relevant, esc))

  if (nrow(relevant) == 0L) {
    return(c(head_part, "<p>Keine relevanten Vergaben gefunden.</p>", "</body></html>"))
  }

  head_cells <- paste0("<th>", esc(headers), "</th>", collapse = "")
  one_table <- function(sub, id) {
    body_rows <- vapply(seq_len(nrow(sub)), function(i) {
      vals <- vapply(data_cols, function(cn) esc(sub[[cn]][i]), character(1))
      neu <- if (isTRUE(sub$is_new[i])) "ja" else "nein"
      pr <- .portal_link_pairs(if (!is.null(sub$Plattform)) sub$Plattform[i] else NA,
                               if (!is.null(sub$portal_links)) sub$portal_links[i] else NA,
                               if (!is.null(sub$project_url)) sub$project_url[i] else NA)
      link <- paste(sprintf("<a href=\"%s\" target=\"_blank\">%s</a>", esc(pr$url), esc(pr$label)),
                    collapse = " ")
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
  typ[is.na(typ) | !nzchar(typ)] <- "Ausschreibung" # no blank-heading section
  ord <- c("Geplante Ausschreibung", "Ausschreibung", "Vergebener Auftrag")
  present <- c(intersect(ord, unique(typ)), setdiff(unique(typ), ord))
  body_parts <- "<p class=\"muted\">Tabellen: oben global suchen, Spalten per Klick sortieren, unten je Spalte filtern.</p>"
  k <- 0L
  for (tp in present) {
    sub <- relevant[typ == tp, , drop = FALSE]
    if (nrow(sub) == 0L) next
    k <- k + 1L
    gb <- group_breakdown(sub)
    body_parts <- c(body_parts, sprintf("<h2>%s (%d)</h2>", esc(tp), nrow(sub)),
                    if (nzchar(gb)) sprintf("<p class=\"muted\">%s</p>", esc(gb)),
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
