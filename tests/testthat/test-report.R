test_that("write_tender_report writes files and detects new tenders", {
  kw <- list(strong = "Grundwasser", supporting = character())
  df <- data.frame(
    Bezeichnung = c("Grundwasser Projekt A", "Strassenbau B"),
    Aktion = c("ID-1", "ID-2"),
    stringsAsFactors = FALSE
  )
  scored <- score_relevance(df, keywords = kw)
  dir <- file.path(tempdir(), "kwb-tenders-test-report")
  unlink(dir, recursive = TRUE)

  res1 <- write_tender_report(scored, dir = dir)
  expect_true(file.exists(res1$xlsx))
  expect_true(file.exists(res1$md))
  expect_equal(res1$n_relevant, 1L)
  expect_equal(res1$n_new, 1L) # first run: the relevant tender is new

  res2 <- write_tender_report(scored, dir = dir)
  expect_equal(res2$n_new, 0L) # second run: nothing new

  unlink(dir, recursive = TRUE)
})

test_that("write_tender_report errors on unscored input", {
  expect_error(
    write_tender_report(data.frame(x = 1), dir = tempdir()),
    "scored"
  )
})
