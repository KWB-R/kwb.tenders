# kwb.pkgbuild installieren (von GitHub, da nicht auf CRAN)
remotes::install_github("KWB-R/kwb.pkgbuild")



usethis::create_package(".")
fs::file_delete(path = "DESCRIPTION")

author <- list(name = "Michael Rustler",
               orcid = "0000-0003-0647-7726",
               url   = "https://mrustl.de")

pkg <- list(name  = "kwb.tenders",
            title = "R Package for Automated Monitoring of German Public Procurement Portals (Vergabeportale) for KWB-Relevant Tenders",
            desc  = "Logs into public procurement portals (starting with Vergabemarktplatz Brandenburg), scrapes published tenders, scores them for relevance to KWB research topics (e.g. groundwater) and renders an overview report.")

kwb.pkgbuild::use_pkg(author, pkg, version = "0.0.0.9000", stage = "experimental")
usethis::use_vignette("tutorial")
kwb.pkgbuild::use_ghactions()
kwb.pkgbuild::create_empty_branch_ghpages(pkg$name)
