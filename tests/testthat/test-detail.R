test_that("parse_detail_html extracts text and CPV codes", {
  html <- "<html><body><h1>Grundwassermonitoring</h1><p>CPV: 71351910-5, 90733000</p></body></html>"
  d <- kwb.tenders:::parse_detail_html(html)
  expect_true(grepl("Grundwasser", d$text))
  expect_true("71351910-5" %in% d$cpv)
  expect_true("90733000" %in% d$cpv)
})

test_that("cpv_to_group_names maps CPV prefixes to group display names", {
  cpv_map <- list(
    list(prefix = "71351", groups = "groundwater"),
    list(prefix = "9073", groups = c("stormwater-surface-waters", "groundwater"))
  )
  slug2name <- c(groundwater = "Grundwasser",
                 "stormwater-surface-waters" = "Regenwasser")
  out <- kwb.tenders:::cpv_to_group_names("71351910-5", cpv_map, slug2name)
  expect_true("Grundwasser" %in% out)
  out2 <- kwb.tenders:::cpv_to_group_names("90733000", cpv_map, slug2name)
  expect_true(all(c("Regenwasser", "Grundwasser") %in% out2))
})

test_that("default CPV map loads and is well-formed", {
  m <- tender_cpv_map()
  expect_true(is.list(m) && length(m) > 0)
  expect_true(all(vapply(m, function(e) !is.null(e$prefix) && !is.null(e$groups), logical(1))))
})

test_that("is_ongoing parses the deadline column", {
  df <- data.frame(
    "Angebots- / Teilnahmefrist" = c("01.01.2099", "01.01.2000"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  on <- kwb.tenders:::is_ongoing(df, today = as.Date("2026-06-14"))
  expect_equal(on, c(TRUE, FALSE))
})

test_that("enrich_with_details adds columns without fetching when max_detail = 0", {
  scored <- score_relevance(data.frame(
    Kurzbezeichnung = "Grundwasser Messstelle",
    Aktion = "https://example.org/x?pid=1",
    stringsAsFactors = FALSE
  ))
  out <- enrich_with_details(scored, max_detail = 0)
  expect_true(all(c("detail_groups", "cpv", "cpv_groups", "match_source") %in% names(out)))
  expect_true(out$is_relevant[1]) # title layer still flags it
  expect_true(grepl("title", out$match_source[1]))
})
