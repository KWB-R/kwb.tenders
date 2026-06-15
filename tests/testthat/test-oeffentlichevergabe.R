test_that("parse_release builds a detail link from the notice id when documents are absent", {
  # Most federal OCDS notices carry no tender.documents[].url, so the link must
  # fall back to the canonical notice page derived from the release id (UUID).
  rel <- list(
    id = "001b37a5-1dca-498d-8403-442ad212d9b2",
    ocid = "ocds-mnwr74-x", date = "2026-06-10T22:00:00Z", tag = list("tender"),
    tender = list(title = "Leitsystem der Ver- und Entsorgung", description = "x")
  )
  row <- oeffentlichevergabe_parse_release(rel)
  expect_equal(
    row$Aktion,
    "https://oeffentlichevergabe.de/ui/de/notices/001b37a5-1dca-498d-8403-442ad212d9b2"
  )
})

test_that("parse_release keeps a direct document URL when the notice carries one", {
  rel <- list(
    id = "uuid-2", ocid = "ocds-x", date = "2026-06-10T22:00:00Z", tag = list("tender"),
    tender = list(
      title = "Umbau Los 05 Rohbau", description = "d",
      documents = list(list(url = "https://vergabemarktplatz.brandenburg.de/x/documents"))
    )
  )
  row <- oeffentlichevergabe_parse_release(rel)
  expect_equal(row$Aktion, "https://vergabemarktplatz.brandenburg.de/x/documents")
})

test_that("parse_release yields an empty link without id or documents", {
  rel <- list(date = "2026-06-10T22:00:00Z", tag = list("tender"),
              tender = list(title = "T", description = "d"))
  expect_identical(oeffentlichevergabe_parse_release(rel)$Aktion, "")
})
