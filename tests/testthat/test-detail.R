test_that("extract_cpv finds CPV codes in text", {
  cpv <- kwb.tenders:::extract_cpv("Leistung: Grundwasser. CPV 71351910-5, 90733000.")
  expect_true("71351910-5" %in% cpv)
  expect_true("90733000" %in% cpv)
  expect_equal(kwb.tenders:::extract_cpv(""), character())
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
  out <- enrich_with_details(NULL, scored, max_detail = 0)
  expect_true(all(c("detail_groups", "cpv", "cpv_groups", "match_source") %in% names(out)))
  expect_true(out$is_relevant[1]) # title layer still flags it
  expect_true(grepl("title", out$match_source[1]))
  expect_true(is.data.frame(attr(out, "detail_cache")))
})

test_that("enrich_with_details reuses the cache and prunes stale entries", {
  scored <- score_relevance(data.frame(
    Kurzbezeichnung = "Buerobedarf", # no title match
    Aktion = "https://x/y?pid=42",
    stringsAsFactors = FALSE
  ))
  cache <- data.frame(
    tender_id = c("42", "999"), # 999 no longer in the listing -> should be pruned
    detail_groups = c("Grundwasser", "Wasser & Risiko"),
    cpv = c("71351910-5", ""),
    cpv_groups = c("Grundwasser", ""),
    stringsAsFactors = FALSE
  )
  # session is NULL: id 42 is cached, so no fetch happens (session never used).
  out <- enrich_with_details(NULL, scored, cache = cache)
  expect_true(grepl("Grundwasser", out$groups[1])) # reused from cache
  expect_true(out$is_relevant[1])
  expect_true(grepl("detail", out$match_source[1]))
  expect_equal(attr(out, "detail_cache")$tender_id, "42") # 999 pruned, 42 kept
})

test_that("cpv_summary aggregates CPV codes with counts and groups", {
  tenders <- data.frame(
    cpv = c("71351910-5, 90733000", "71351910-5", ""),
    stringsAsFactors = FALSE
  )
  s <- cpv_summary(tenders)
  expect_true(all(c("cpv", "n_tenders", "groups") %in% names(s)))
  expect_equal(s$n_tenders[s$cpv == "71351910-5"], 2L)
  expect_true(grepl("Grundwasser", s$groups[s$cpv == "71351910-5"])) # 71351 -> groundwater
})

test_that("read/write detail cache round-trips", {
  p <- file.path(tempdir(), "detail_cache.rds")
  unlink(p)
  expect_equal(nrow(read_detail_cache(p)), 0L) # missing -> empty
  cc <- data.frame(tender_id = "1", detail_groups = "Grundwasser",
                   cpv = "", cpv_groups = "", stringsAsFactors = FALSE)
  write_detail_cache(cc, p)
  expect_equal(read_detail_cache(p)$tender_id, "1")
  unlink(p)
})
