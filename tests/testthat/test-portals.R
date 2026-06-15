test_that("combine_tenders row-binds and fills missing columns", {
  a <- data.frame(Plattform = "A", Kurzbezeichnung = "x", cpv = "71351500-8",
                  stringsAsFactors = FALSE)
  b <- data.frame(Plattform = "B", Kurzbezeichnung = "y", Vergabestelle = "Amt",
                  stringsAsFactors = FALSE)
  out <- combine_tenders(list(a, NULL, b, data.frame()))
  expect_equal(nrow(out), 2L)
  expect_true(all(c("Plattform", "Kurzbezeichnung", "cpv", "Vergabestelle") %in% names(out)))
  expect_equal(out$Plattform, c("A", "B"))
  expect_true(is.na(out$cpv[2]))            # filled for source B
  expect_true(is.na(out$Vergabestelle[1])) # filled for source A
})

test_that("combine_tenders returns an empty frame when there is no data", {
  expect_equal(nrow(combine_tenders(list(NULL, data.frame()))), 0L)
})

test_that("score_layered: title full rule, long text strong-only, cpv mapped", {
  df <- data.frame(
    Titel = c("Grundwassermonitoring Messstelle", "Rahmenvertrag Ingenieurleistungen",
              "Rahmenvertrag Planung", "Bueromaterial"),
    Beschreibung = c("", "Reinigung Hygiene Gesundheit Gebaeude", # supporting-only -> ignored
                     "Neubau einer Klaeranlage", ""),             # strong -> detail hit
    cpv = c("", "", "", "71351500-8"),                            # cpv -> Grundwasser
    stringsAsFactors = FALSE
  )
  out <- score_layered(df, title_cols = "Titel", text_cols = "Beschreibung", cpv_col = "cpv")
  rel <- stats::setNames(out$is_relevant, out$Titel)
  src <- stats::setNames(out$match_source, out$Titel)
  expect_true(rel[["Grundwassermonitoring Messstelle"]])
  expect_match(src[["Grundwassermonitoring Messstelle"]], "title")
  expect_false(rel[["Rahmenvertrag Ingenieurleistungen"]]) # supporting-only description ignored
  expect_true(rel[["Rahmenvertrag Planung"]])              # "Klaeranlage" strong in description
  expect_match(src[["Rahmenvertrag Planung"]], "detail")
  expect_true(rel[["Bueromaterial"]])                      # via CPV only
  expect_match(src[["Bueromaterial"]], "cpv")
})

test_that("apply_title_excludes vetoes building titles but keeps water ones", {
  df <- data.frame(
    Kurzbezeichnung = c("Krematorium Ofensanierung Rohbau",
                        "Sporthalle Neubau mit Grundwasserhaltung", # rescued by 'Grundwasser'
                        "Grundwassermonitoring Messstelle", "Bueromaterial"),
    is_relevant = c(TRUE, TRUE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  out <- apply_title_excludes(df)
  r <- stats::setNames(out$is_relevant, out$Kurzbezeichnung)
  expect_false(r[["Krematorium Ofensanierung Rohbau"]])         # vetoed (no water-strong in title)
  expect_true(r[["Sporthalle Neubau mit Grundwasserhaltung"]])  # rescued
  expect_true(r[["Grundwassermonitoring Messstelle"]])          # no exclude term
  expect_true(!is.na(out$excluded[out$Kurzbezeichnung == "Krematorium Ofensanierung Rohbau"]))
})

test_that("apply_title_excludes drops construction/maintenance by CPV (without 71)", {
  df <- data.frame(
    Kurzbezeichnung = c("Neubau Klaeranlage", "Ingenieurleistungen Klaeranlage Neubau",
                        "Reinigung Faulbehaelter Klaeranlage", "Grundwassermonitoring"),
    cpv = c("45252127-4", "71321000-4, 45252127-4", "90460000-3", "90733000-4"),
    is_relevant = c(TRUE, TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )
  out <- apply_title_excludes(df)
  r <- stats::setNames(out$is_relevant, out$Kurzbezeichnung)
  expect_false(r[["Neubau Klaeranlage"]])                     # CPV 45 -> Bau veto
  expect_false(r[["Reinigung Faulbehaelter Klaeranlage"]])    # CPV 9046 (cleaning) -> Wartung veto
  expect_true(r[["Ingenieurleistungen Klaeranlage Neubau"]])  # has 71 (engineering) -> kept
  expect_true(r[["Grundwassermonitoring"]])                   # no out-of-scope CPV -> kept
})
