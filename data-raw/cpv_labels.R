# data-raw/cpv_labels.R
# Regenerates inst/extdata/cpv_labels.csv (CPV code -> German label) from the
# OFFICIAL EU CPV 2008 list (TED). Run ONCE locally (needs internet), from the
# package root:
#   setwd("C:/kwb/kwb.tenders"); source("data-raw/cpv_labels.R")

url <- "https://ted.europa.eu/documents/d/ted/cpv_2008_xml"
tmp <- tempfile(fileext = ".zip")
utils::download.file(url, tmp, mode = "wb")

# The archive holds the main list (cpv_2008.xml) plus a supplement file
# (code_cpv_suppl_2008.xml); pick the main one explicitly. Listing the central
# directory works even when extraction fails.
members <- utils::unzip(tmp, list = TRUE)$Name
xn <- grep("(^|/)cpv_2008\\.xml$", members, value = TRUE, ignore.case = TRUE)[1]
if (is.na(xn)) xn <- grep("\\.xml$", members, value = TRUE, ignore.case = TRUE)[1]
if (is.na(xn)) stop("No .xml found in the downloaded archive.")
# This TED zip uses DEFLATE64 (method 9), which R's unzip()/unz() AND libarchive
# ({archive}) cannot decompress. Extract with a tool that supports it: 7-Zip if
# present, otherwise the Windows Explorer zip engine (Shell.Application).
extract_member <- function(zip, member) {
  outdir <- file.path(tempdir(), "cpv_extract")
  dir.create(outdir, showWarnings = FALSE)
  target <- file.path(outdir, basename(member))
  if (file.exists(target)) file.remove(target)

  sevenz <- Sys.which("7z")
  if (!nzchar(sevenz)) {
    for (p in c("C:/Program Files/7-Zip/7z.exe", "C:/Program Files (x86)/7-Zip/7z.exe")) {
      if (file.exists(p)) { sevenz <- p; break }
    }
  }
  if (nzchar(sevenz) && file.exists(sevenz)) {
    system2(sevenz, c("x", shQuote(zip), paste0("-o", outdir), "-y", shQuote(member)),
            stdout = FALSE, stderr = FALSE)
    if (file.exists(target) && file.info(target)$size > 0) {
      cat("Extracted via 7-Zip\n"); return(target)
    }
  }

  if (.Platform$OS.type == "windows") {
    ps <- sprintf(
      "$s=New-Object -ComObject Shell.Application; $z=$s.NameSpace('%s'); $d=$s.NameSpace('%s'); $d.CopyHere($z.Items(),0x14)",
      normalizePath(zip, winslash = "\\"), normalizePath(outdir, winslash = "\\")
    )
    system2("powershell", c("-NoProfile", "-NonInteractive", "-Command", ps),
            stdout = FALSE, stderr = FALSE)
    for (i in seq_len(120)) { # CopyHere is async -> poll up to ~60s
      if (file.exists(target) && file.info(target)$size > 0) break
      Sys.sleep(0.5)
    }
    Sys.sleep(1)
    if (file.exists(target) && file.info(target)$size > 0) {
      cat("Extracted via Windows Explorer engine\n"); return(target)
    }
  }

  stop("Could not auto-extract (Deflate64). Extract '", zip, "' manually (right-click -> ",
       "'Alle extrahieren'), then run:  doc <- xml2::read_xml('.../", basename(member), "')  ",
       "and continue from the line after 'doc <- ...'.")
}

xml_path <- extract_member(tmp, xn)
doc <- xml2::read_xml(xml_path)
xml2::xml_ns_strip(doc) # ignore any default namespace so plain XPath matches

# Structure: <CPV_CODE> (root) > <CPV CODE="03000000-1"> > <TEXT LANG="DE">..</TEXT>
nodes <- xml2::xml_find_all(doc, "//CPV[@CODE]")
cat("CPV entries found:", length(nodes), "\n")

code <- xml2::xml_attr(nodes, "CODE")
de <- vapply(nodes, function(n) {
  t <- xml2::xml_find_first(n, ".//TEXT[@LANG='DE']")
  if (inherits(t, "xml_missing")) t <- xml2::xml_find_first(n, ".//*[@LANG='DE' or @lang='de']")
  if (inherits(t, "xml_missing")) NA_character_ else trimws(xml2::xml_text(t))
}, character(1))

out <- data.frame(code = code, name = de, stringsAsFactors = FALSE)
out <- out[!is.na(out$code) & nzchar(out$code) & !is.na(out$name) & nzchar(out$name), ]
out <- out[!duplicated(out$code), ]
cat("Writing", nrow(out), "code -> German label rows\n")
print(utils::head(out, 4))

if (nrow(out) > 0) {
  utils::write.csv(out, "inst/extdata/cpv_labels.csv", row.names = FALSE, fileEncoding = "UTF-8")
  cat("Done -> inst/extdata/cpv_labels.csv\n")
} else {
  cat("No labels extracted. Inspect structure:\n",
      "  print(xml2::xml_structure(xml2::xml_child(doc)))\n", sep = "")
}
