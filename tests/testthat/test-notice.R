test_that("enrich_with_notice corroborates an already-relevant tender", {
  scored <- score_relevance(data.frame(
    Kurzbezeichnung = "Grundwasser Messstelle", # relevant via title
    Aktion = "https://x/y?pid=7",
    stringsAsFactors = FALSE
  ))
  cache <- data.frame(tender_id = "7", notice_groups = "Wasser & Risiko",
                      stringsAsFactors = FALSE)
  # session NULL: id 7 is cached, so no PDF fetch happens.
  out <- enrich_with_notice(NULL, scored, cache = cache)
  expect_true(grepl("notice", out$match_source[1]))    # notice source tagged
  expect_true(grepl("Wasser & Risiko", out$groups[1])) # extra group merged in
  expect_equal(attr(out, "notice_cache")$tender_id, "7")
})

test_that("enrich_with_notice never makes an irrelevant tender relevant", {
  scored <- score_relevance(data.frame(
    Kurzbezeichnung = "Buerobedarf", # no title/detail/cpv match
    Aktion = "https://x/y?pid=8",
    stringsAsFactors = FALSE
  ))
  cache <- data.frame(tender_id = "8", notice_groups = "Grundwasser",
                      stringsAsFactors = FALSE)
  # A PDF keyword hit alone must not flag an otherwise-irrelevant tender.
  out <- enrich_with_notice(NULL, scored, cache = cache)
  expect_false(out$is_relevant[1])
  expect_false(grepl("notice", out$match_source[1]))
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
