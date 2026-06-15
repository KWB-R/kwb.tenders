test_that("enrich_with_notice reuses cache and adds the notice source", {
  scored <- score_relevance(data.frame(
    Kurzbezeichnung = "Buerobedarf", # no title match
    Aktion = "https://x/y?pid=7",
    stringsAsFactors = FALSE
  ))
  cache <- data.frame(tender_id = "7", notice_groups = "Grundwasser",
                      stringsAsFactors = FALSE)
  # session NULL: id 7 is cached, so no PDF fetch happens.
  out <- enrich_with_notice(NULL, scored, cache = cache)
  expect_true(grepl("Grundwasser", out$groups[1]))
  expect_true(grepl("notice", out$match_source[1]))
  expect_equal(attr(out, "notice_cache")$tender_id, "7")
})

test_that("read/write notice cache round-trips", {
  p <- file.path(tempdir(), "notice_cache.rds")
  unlink(p)
  expect_equal(nrow(read_notice_cache(p)), 0L)
  write_notice_cache(
    data.frame(tender_id = "1", notice_groups = "X", stringsAsFactors = FALSE), p
  )
  expect_equal(read_notice_cache(p)$tender_id, "1")
  unlink(p)
})
