test_that("score_relevance flags strong- and supporting-keyword hits (single group)", {
  kw <- list(
    strong = c("Grundwasser", "Brunnen"),
    supporting = c("Monitoring", "Modellierung")
  )
  df <- data.frame(
    Bezeichnung = c(
      "Grundwassermonitoring Berlin",         # strong -> relevant
      "Neubau Sporthalle",                    # nothing -> not relevant
      "Monitoring und Modellierung Hydraulik" # 2 supporting -> relevant
    ),
    stringsAsFactors = FALSE
  )
  out <- score_relevance(df, keywords = kw)

  expect_true(all(c("groups", "score", "matched_keywords", "is_relevant") %in% names(out)))
  expect_equal(sum(out$is_relevant), 2L)
  expect_false(out$is_relevant[out$Bezeichnung == "Neubau Sporthalle"])
  expect_true(all(diff(out$score) <= 0)) # sorted by descending score
})

test_that("score_relevance tags multiple groups", {
  kw <- list(
    grundwasser = list(name = "Grundwasser", strong = "Grundwasser", supporting = character()),
    smartcity = list(name = "Smart City & Infrastruktur",
                     strong = c("Kanalsanierung", "Sensorik"), supporting = character())
  )
  df <- data.frame(
    Bezeichnung = c("Grundwasser Messstelle", "Kanalsanierung mit Sensorik", "Buerobedarf"),
    stringsAsFactors = FALSE
  )
  out <- score_relevance(df, keywords = kw)

  expect_true(grepl("Grundwasser", out$groups[out$Bezeichnung == "Grundwasser Messstelle"]))
  expect_true(grepl("Smart City", out$groups[out$Bezeichnung == "Kanalsanierung mit Sensorik"]))
  expect_equal(out$groups[out$Bezeichnung == "Buerobedarf"], "")
})

test_that("default keywords define groups with strong/supporting", {
  kw <- tender_keywords()
  expect_true(is.list(kw) && length(kw) >= 1)
  expect_true(all(vapply(kw, function(g) !is.null(g$strong), logical(1))))
  expect_true("Grundwasser" %in% vapply(kw, function(g) as.character(g$name), character(1)))
})

test_that("score_relevance handles zero rows", {
  df <- data.frame(Bezeichnung = character(), stringsAsFactors = FALSE)
  out <- score_relevance(
    df,
    keywords = list(strong = "Grundwasser", supporting = character())
  )
  expect_equal(nrow(out), 0L)
})

test_that("matching folds umlauts (both spellings match)", {
  ae <- intToUtf8(0x00e4) # a-umlaut
  kw <- list(strong = paste0("Kl", ae, "rschlamm"), supporting = character())
  df <- data.frame(
    Bezeichnung = c(
      paste0("Verwertung von Kl", ae, "rschlamm"), # umlaut spelling
      "Entsorgung von Klaerschlamm"                # ae spelling
    ),
    stringsAsFactors = FALSE
  )
  out <- score_relevance(df, keywords = kw)
  expect_equal(sum(out$is_relevant), 2L)
})
