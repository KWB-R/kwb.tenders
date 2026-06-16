# Package index

## All functions

- [`apply_title_excludes()`](https://kwb-r.github.io/kwb.tenders/reference/apply_title_excludes.md)
  : Veto out-of-scope tenders (construction / building / maintenance)
- [`berlin_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/berlin_tenders.md)
  : Vergabeplattform Berlin connector (HTTP, login-free)
- [`check_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/check_tenders.md)
  : Check Vergabemarktplatz Brandenburg for relevant tenders
  (single-portal report)
- [`combine_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/combine_tenders.md)
  : Combine scored tender tibbles from several portal connectors
- [`cosinex_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/cosinex_tenders.md)
  : Scrape + score a cosinex Vergabemarktplatz instance (generic
  connector)
- [`cpv_labels()`](https://kwb-r.github.io/kwb.tenders/reference/cpv_labels.md)
  : CPV code -\> German label lookup
- [`cpv_summary()`](https://kwb-r.github.io/kwb.tenders/reference/cpv_summary.md)
  : Summarise all CPV codes found across the tenders
- [`dedupe_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/dedupe_tenders.md)
  : Merge duplicate tenders that appear on several portals
- [`dtvp_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/dtvp_tenders.md)
  : Deutsches Vergabeportal (DTVP) connector (cosinex)
- [`enrich_with_details()`](https://kwb-r.github.io/kwb.tenders/reference/enrich_with_details.md)
  : Enrich tenders with a detail-page relevance layer (rendered text +
  CPV codes)
- [`enrich_with_notice()`](https://kwb-r.github.io/kwb.tenders/reference/enrich_with_notice.md)
  : Enrich tenders with a notice-PDF (Bekanntmachung) relevance layer
- [`oeffentlichevergabe_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/oeffentlichevergabe_tenders.md)
  : Screen the Datenservice Oeffentlicher Einkauf
  (oeffentlichevergabe.de)
- [`read_detail_cache()`](https://kwb-r.github.io/kwb.tenders/reference/read_detail_cache.md)
  [`write_detail_cache()`](https://kwb-r.github.io/kwb.tenders/reference/read_detail_cache.md)
  : Read / write the detail-screening cache
- [`read_notice_cache()`](https://kwb-r.github.io/kwb.tenders/reference/read_notice_cache.md)
  [`write_notice_cache()`](https://kwb-r.github.io/kwb.tenders/reference/read_notice_cache.md)
  : Read / write the notice-screening cache
- [`score_layered()`](https://kwb-r.github.io/kwb.tenders/reference/score_layered.md)
  : Layered relevance scoring for portal connectors (title + long text +
  CPV)
- [`score_relevance()`](https://kwb-r.github.io/kwb.tenders/reference/score_relevance.md)
  : Score tenders for relevance to KWB research groups
- [`screen_all_portals()`](https://kwb-r.github.io/kwb.tenders/reference/screen_all_portals.md)
  : Screen all configured portals into one combined report
- [`screen_portals()`](https://kwb-r.github.io/kwb.tenders/reference/screen_portals.md)
  : Run several portal connectors, combine and write one report
- [`ted_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/ted_tenders.md)
  : Screen TED (Tenders Electronic Daily) for relevant tenders
- [`tender_cpv_map()`](https://kwb-r.github.io/kwb.tenders/reference/tender_cpv_map.md)
  : CPV-code to research-group mapping
- [`tender_detail_text()`](https://kwb-r.github.io/kwb.tenders/reference/tender_detail_text.md)
  : Fetch a tender detail page (rendered) and extract its text + CPV
  codes
- [`tender_excludes()`](https://kwb-r.github.io/kwb.tenders/reference/tender_excludes.md)
  : Title-level exclusion (veto) terms
- [`tender_keywords()`](https://kwb-r.github.io/kwb.tenders/reference/tender_keywords.md)
  : KWB research-group keywords
- [`tender_notice_text()`](https://kwb-r.github.io/kwb.tenders/reference/tender_notice_text.md)
  : Fetch and extract the text of a tender's announcement (notice)
  PDF(s)
- [`vmp_bb_login()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_login.md)
  : Log in to Vergabemarktplatz Brandenburg (optional)
- [`vmp_bb_scrape_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_scrape_tenders.md)
  : Search for and scrape tender results
- [`vmp_bb_session()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_session.md)
  : Start a chromote browser session
- [`vmp_bb_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_bb_tenders.md)
  : Scrape + score Vergabemarktplatz Brandenburg (portal connector)
- [`vmp_nrw_tenders()`](https://kwb-r.github.io/kwb.tenders/reference/vmp_nrw_tenders.md)
  : Vergabemarktplatz NRW connector (cosinex)
- [`write_tender_report()`](https://kwb-r.github.io/kwb.tenders/reference/write_tender_report.md)
  : Write a tender overview report (Excel + Markdown + HTML)
