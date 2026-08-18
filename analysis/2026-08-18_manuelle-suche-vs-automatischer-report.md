# Analyse: Warum reproduziert der automatisierte Report Christophs manuelle Suche nicht?

Stand: 2026-08-18 · Datenbasis: `wGBScreening_Grundwasser.xlsx` (manuelle Suche, 39 Suchvorgänge, 14 relevante Funde),
`tenders_20260818.xlsx` + `VergabeReport_TENDERS.htm` (aktueller Report) sowie **alle 47 archivierten Tagesreports**
(gh-pages, 15.06.–18.08.2026) und der Code auf `main` (635923b).

## Kurzfassung

Der zentrale Befund ist positiv: **Die Pipeline hat 8 der 14 manuellen Funde als laufende Ausschreibung erfasst
— teils Wochen vor Christophs manueller Suche.** Dass der Vergleich "aktueller Report vs. manuelle Liste" trotzdem
fast leer ausgeht, hat vier strukturelle Gründe:

1. **Äpfel-Birnen-Vergleich: kumulative Liste vs. rollierender Schnappschuss.** Christophs Excel sammelt Funde seit
   dem 06.05. Der Report zeigt nur, was die Konnektoren *heute* liefern, beschnitten auf Veröffentlichungen der
   letzten 30 Tage (`since_days = 30`). Ein Verfahren verschwindet aus dem Report, sobald seine Veröffentlichung
   >30 Tage zurückliegt — **auch wenn die Angebotsfrist noch läuft**. Messbar: **129 Verfahren mit Frist nach dem
   18.08. waren in früheren Tagesreports enthalten, fehlen aber im aktuellen Report.** Prominentes Beispiel:
   Fund 12 (Klimarisikoanalyse Sachsen-Anhalt, Frist 10.08.) stand vom 19.06. bis 16.07. im Report und fiel dann
   — 25 Tage vor Fristablauf — aus dem 30-Tage-Fenster.
2. **Die Pipeline existiert erst seit 15.06.** Alle Funde aus Christophs Suchen vom 06.05.–13.05. (Funde 1–6) mit
   Fristen im Mai/Anfang Juni waren beendet, bevor der erste automatische Lauf stattfand. Sie tauchen heute
   höchstens noch als „Vergebener Auftrag" auf (Funde 1, 3).
3. **Vier von Christoph durchsuchte Landesportale sind nicht angebunden:** vergabe.niedersachsen.de, evergabe-mv.de,
   evergabe.sachsen.de, evergabe.sachsen-anhalt.de. Unterschwellige Verfahren, die nur dort laufen, sieht die
   Pipeline gar nicht (Fund 14 nur indirekt als vermeintlicher „Vergebener Auftrag" über den service.bund-Import)
   oder nur über Umwege (Fund 13 kam über Datenservice/DTVP/service.bund herein).
4. **Stille Konnektor-Ausfälle.** Quellen, die fehlschlagen, werden nur als Log-Meldung übersprungen. Die Historie
   zeigt: Datenservice-Bund lieferte an 7 von 47 Tagen 0 Zeilen, **DTVP ist seit 31.07. praktisch tot** (0 Zeilen
   bis 14.08., seither 6–7 statt ~100), Brandenburg+NRW fielen 09.–13.07. komplett aus, evergabe-online an 3 Tagen.
   Im Report ist davon nichts zu sehen — die Trefferzahl je Plattform sinkt einfach.

## Fund-für-Fund-Abgleich (alle 47 Tagesreports durchsucht)

| # | Verfahren (Kurzform) | Portal (manuell) | manuell gefunden | im Tagesreport? | Bewertung |
|---|---|---|---|---|---|
| 1 | Grundwassermonitoring Dow Böhlen | oeffentlichevergabe.de | 06.05. | nur als „Vergebener Auftrag" ab 13.07. | vor Pipeline-Start beendet (Frist 18.05.) |
| 2 | BWB Betriebsbeauftragte:r Grundwasser | oeffentlichevergabe.de | 06.05. | **16.–18.06. als Ausschreibung** (TED+DTVP, Frist verlängert bis 25.06.) | erfasst; verschwand am 19.06. vorzeitig (mutmaßlich Änderung/Statuswechsel an der Quelle, TED-scope=ACTIVE) |
| 3 | Wassermengenmanagement Lüchow-Dannenberg | oeffentlichevergabe.de | 06.05. | nur als „Vergebener Auftrag" (09.07.–06.08.) | vor Pipeline-Start beendet (Frist 02.06.) |
| 4 | Nitrat/Altersbestimmung GW-Messstellen LfU BB | VMP Brandenburg | 07.05. | **nie** | vor Pipeline-Start beendet (Frist 27.05.) — kein Pipeline-Fehler |
| 5 | Smartes Wassermanagement Hameln (Messkampagne) | oeffentlichevergabe.de | 13.05. | Ursprungsverfahren nie; **Folgeausschreibung** „Niederschlagsmessgeräte" (Veröff. 02.07.) ab 06.07. | Ursprung vor Pipeline-Start; Folgeverfahren erfasst |
| 6 | VB-26-128 Rohwasserproben BB (ex-ante) | VMP Brandenburg | 13.05. | **nie** | vor Pipeline-Start beendet (Abgabe 25.05.) — kein Pipeline-Fehler |
| 7 | GW-Monitoring Spree-Neiße Probenahme | VMP Brandenburg | 25.06. | **ab 15.06.** (BB/DTVP/Bund) | erfasst, 10 Tage vor manueller Suche |
| 8 | EU-WRRL Landesmessnetz B (LfU BB) | VMP Brandenburg | 25.06. | **ab 15.06.** (BB/DTVP/TED/Bund), bis ~Fristablauf 17.07. | erfasst, 10 Tage vor manueller Suche |
| 9 | EU-WRRL N2-Argon-Analytik (LfU BB) | VMP Brandenburg | 25.06. | **ab 15.06.** | erfasst |
| 10 | Ing.-technische Begleitung GW-Monitoring | VMP Brandenburg | 25.06. | **ab 19.06.** | erfasst (von Christoph selbst als irrelevant markiert) |
| 11 | LCKW Staaken GWSM/STM (LK Havelland) | VMP Brandenburg | 25.06. | **ab 23.06.** | erfasst (von Christoph selbst als irrelevant markiert) |
| 12 | Klimarisikoanalyse Sachsen-Anhalt | evergabe-online.de | 09.07. | **19.06.–16.07.** (Datenservice Bund, via CPV-Ebene) | erfasst, 3 Wochen vor manueller Suche; fiel am 16.07. aus dem 30-Tage-Fenster, obwohl Frist 10.08. |
| 13 | GW-Modell Lausitz (LfULG Sachsen) | evergabe.sachsen.de | 29.07. | **17.07.–14.08.** (Bund + service.bund + DTVP) | erfasst, 12 Tage vor manueller Suche — trotz fehlendem Sachsen-Portal (Verfahren war auch im Datenservice) |
| 14 | RAW_700-41 hydraulisches Modell | evergabe.sachsen-anhalt.de | 29.07. | nur als „Vergebener Auftrag" ab 24.07. (service.bund-Import von evergabe.de) | Lücke: Live-Verfahren lief auf nicht angebundenem Landesportal; Typ-Einstufung des Imports fraglich |

**Bilanz:** 8/14 live erfasst (7–13, plus 2 kurzzeitig), 4/14 aus Zeitgründen unmöglich (1, 3, 4, 6 — Pipeline
existierte noch nicht), 1 Folgeverfahren statt Ursprung (5), 1 echte Abdeckungslücke (14).

## Die Detail-Befunde

### B1 · 30-Tage-Fenster wirft laufende Verfahren raus (Hauptproblem)

`screen_portals()` (R/portals.R:211–220) filtert hart auf `Veroeffentlicht >= heute - 30`. Die Frist spielt keine
Rolle. Verfahren mit langen Angebotsfristen (bei EU-Verfahren Standard) verschwinden mitten in der Bewerbungsphase.
129 noch offene Verfahren aus früheren Reports fehlen im aktuellen. Für ein Screening, dessen Zweck „worauf können
wir uns noch bewerben?" ist, ist das Sichtbarkeitskriterium falsch gewählt: relevant ist „Frist in der Zukunft",
nicht „kürzlich veröffentlicht".

### B2 · Listen-Konnektoren haben effektive Fenster von wenigen Tagen

Der 30-Tage-Filter ist zudem nur die Obergrenze. Mehrere Konnektoren liefern nur, was das Portal aktuell listet:
service.bund.de (RSS-Feeds, ~neueste Einträge; R/servicebund.R), deutsche-evergabe (Dashboard-Kategorien),
evergabe-online (Portal-Fenster fix „28 Tage", max. 30 Seiten × 10 Treffer je Suchbatch). Viele Verfahren waren
dadurch nur 1–2 Tagesreporte lang sichtbar. Wer den Report nicht täglich liest, verpasst sie — anders als bei
Christophs kumulativer Liste. Verschärfend: Der Cron läuft nur werktags 03:00 UTC — was zwischen Freitag- und
Montaglauf aus einem flachen RSS-Feed herausrollt, wird nie gesehen.

### B3 · Stille Ausfälle einzelner Portale

R/portals.R:181–183 fängt Konnektor-Fehler ab und macht weiter — richtig fürs Durchlaufen, aber der Report weist
nirgends aus, welche Quelle heute leer/ausgefallen war (DTVP seit 31.07.!). Zusätzlich verfälschen Ausfälle die
„Neu"-Markierung: `is_new` diffed gegen die IDs des Vorlaufs (R/report.R:37–39); fällt ein Portal einen Tag aus,
gelten dessen Bestandsverfahren am Folgetag wieder als „neu".

### B4 · „Alle" == „Relevant" im Excel

Alle Konnektoren werden in `screen_all_portals()` mit `relevant_only = TRUE` aufgerufen; `write_tender_report()`
bekommt daher nur noch relevante Zeilen, und das Sheet „Alle" (R/report.R:66) ist seit dem 16.06. in jedem Report
identisch mit „Relevant". Christophs manuelle Trefferzahlen (z. B. „326 Treffer DTVP") lassen sich so nicht
nachvollziehen — die Vorfilter-Rohzahlen gehen verloren (nur im Action-Log sichtbar).

### B5 · Keyword-Lücken, durch CPV-Ebene nur teilweise kompensiert

Nachgerechnet mit der exakten Matching-Semantik (score_layered, R/relevance.R): 12 der 14 Fund-Titel matchen die
Keyword-Gruppen (fast alle über `Grundwasser`-strong). **Nicht** über den Titel matchen:

- Fund 12 „Klimarisikoanalyse … Wasserhaushaltsanalyse … Klimaanpassung": nur 1 supporting-Treffer
  (`Klimaanpassung`); weder `Klimarisiko` noch `Wasserhaushalt` stehen in einer Liste. Das Verfahren wurde nur
  dank CPV-Codes (90713000, 71351900, …) über den Datenservice erfasst. Der evergabe-online-Konnektor — das
  Portal, auf dem Christoph es fand — hätte es dagegen **sicher verworfen**: Seine Ergebnisliste liefert keinen
  Freitext, `Beschreibung` wird explizit leer gesetzt (R/evergabe_online.R:254) und das Scoring ist dort rein
  titelbasiert.
- Fund 14 „RAW_700-41_hydraulisches Modell": kein Titel-Keyword (`hydraulisch`/`Modell` fehlen; `Modellierung`
  matcht „Modell" nicht); Rettung nur über `Grundwasser` in der Beschreibung des service.bund-Imports.

Zwei verwandte Engstellen:

- **TED wird portalseitig nur mit 16 fixen Termen durchsucht** (R/ted.R:43–50) — deutlich enger als die
  79 strong-Keywords der YAML-Gruppen. `Brunnen`, `Aquifer`, `Grundwasseranreicherung`, `Schwammstadt` u. a.
  fehlen; ein TED-only-Verfahren, das nur über solche Begriffe matcht, wird gar nicht erst abgeholt.
- Historie: `Wassermanagement`/`Wassermengenmanagement` wurden erst am 15.06. ergänzt — mit dem Mai-Stand der
  Keywords hätten die Funde 3 und 5 auch inhaltlich nicht gematcht (praktisch irrelevant, da die Pipeline im Mai
  ohnehin nicht lief; zeigt aber, dass die Listen lebende Konfiguration sind).

Empfohlene Ergänzungen: `Klimarisiko`, `Wasserhaushalt`, `Rohwasser`, `hydraulisch`, ggf. `Wasserrecht`;
TED-Termliste aus den strong-Keywords generieren statt separat pflegen.

### B6 · Fehlende Landesportale Ost/Nord

Nicht angebunden: Niedersachsen, Mecklenburg-Vorpommern, Sachsen, Sachsen-Anhalt. Oberschwellige Verfahren dieser
Länder kommen über Datenservice/TED trotzdem herein (Beleg: Funde 12, 13). **Unterschwellige** Verfahren, die nur
auf dem Landesportal laufen, fehlen (Fund 14; Christophs 7 Treffer auf evergabe.sachsen-anhalt.de am 29.07. vs. 0
direkte Abdeckung). Brandenburg zeigt, dass genau diese Lücke der Grund für den dortigen Scraper war.

### B6b · Cosinex-Portale: nur Vergabeordnung „VOL"

Brandenburg/NRW/DTVP werden ausschließlich mit `contracting_rules = "VOL"` (VgV/VOL-A/UVgO) abgefragt
(R/portals.R:273). Verfahren unter VOB/A, SektVO, VSVgV oder „Sonstige" werden gar nicht erst geladen. Für die
Grundwasser-Dienstleistungen war das nie der Blocker, erklärt aber zusammen mit Fenster + Relevanzfilter einen
Teil der Differenz „Christoph: 326 DTVP-Treffer vs. Report: 6 DTVP-Nennungen" (sein Portal-Suchfilter zählte
alle Vergabeordnungen und ohne Zeitfenster).

### B7 · Kleinere Anomalien

- Fund 2 verschwand am 19.06. aus dem Report, obwohl die (verlängerte) Frist erst am 25.06. ablief — TED- und
  DTVP-Kopie gleichzeitig; wahrscheinlichste Erklärung ist ein Statuswechsel/Änderung an der Quelle
  (TED `scope="ACTIVE"`), offline nicht abschließend klärbar.
- TED-Cap: `max_pages = 5 × 100` (R/ted.R:109) — bei breiterem Suchprofil oder EU-weiter Suche wird das zum
  stillen Limit; aktuell (DEU, 30 Tage) kein beobachteter Verlust.
- `Veroeffentlichungstyp`-Mapping des service.bund-Imports: Fund 14 lief als „Vergebener Auftrag", war aber
  (laut manueller Recherche) ein laufendes Verfahren mit Frist 20.08.
- Der Scheduled Run setzt `vmp_bb_login=TRUE` (leere `github.event.inputs` ⇒ `!= 'false'` ⇒ TRUE) — abgelaufene
  VMP-BB-Zugangsdaten würden den Brandenburg-Konnektor still lahmlegen. Ebenso überspringt ein Render-Timeout der
  Cosinex-Ergebnisliste (25 s) einen ganzen Publikationstyp nur mit einer Warning.
- evergabe-online nutzt fest das Portal-Fenster „28 Tage" und einen Cap von 300 Treffern je Keyword-Batch.
- Detail-Cache-Vergiftung (plausibel, nicht beobachtet): Rendert eine Cosinex-Detailseite binnen 10 s keine
  >200 Zeichen (R/detail.R:137–144), wird der Tender trotzdem als gescreent gecacht (R/detail.R:328–339) und nie
  erneut geladen — ein Verfahren, dessen Relevanz nur aus Detailtext/CPV käme, bliebe dauerhaft unsichtbar
  (Cache wird über gh-pages über alle Läufe persistiert).

## Empfehlungen (nach Wirkung sortiert)

1. **Sichtbarkeit an der Frist ausrichten, nicht an der Veröffentlichung:** Verfahren im Report halten, solange
   `Frist >= heute` (oder Frist unbekannt und Veröffentlichung < X Tage). Technisch am einfachsten über einen
   persistenten Bestand (das State-File zum vollen Tender-Store ausbauen), aus dem der Report generiert wird —
   dann heilt das auch B2 (kurzlebige Listen-Konnektoren) und macht den Report kumulativ wie Christophs Liste.
2. **Portal-Gesundheit sichtbar machen:** Je Quelle „heute geliefert: n (Vortag: m)" in den Report; bei 0 Zeilen
   deutlicher Warnhinweis (DTVP-Ausfall seit 31.07. wäre sofort aufgefallen).
3. **Landesportale Sachsen-Anhalt/Sachsen/Niedersachsen/MV anbinden** (Priorität nach Projektregion;
   Sachsen-Anhalt/Sachsen zuerst, dort lagen die realen Lücken).
4. **Keywords ergänzen und TED-Terme aus den YAMLs generieren** (B5) — billig und sofort wirksam. Für
   evergabe-online zusätzlich die Detailseite (Beschreibung/CPV) in den Scoring-Pfad holen, damit dort nicht nur
   der Titel zählt.
5. **„Alle"-Sheet ehrlich machen:** entweder Rohdaten (vor Relevanzfilter) exportieren oder das Sheet entfernen;
   zusätzlich Rohtrefferzahl je Portal in die Kopfzeile („DTVP: 812 geprüft, 95 relevant").
6. **„Neu"-Logik ausfallfest machen:** IDs über N Läufe kumulieren statt nur gegen den letzten Lauf zu diffen.

## Methodik / Reproduktion

- Manuelle Funde aus `wGBScreening_Grundwasser.xlsx` extrahiert (14 als relevant markierte Verfahren).
- Alle 47 `reports/tenders_*.xlsx` von `origin/gh-pages` per Titel-Fragment-Suche (normalisiert, umlaut-gefaltet)
  gegen jeden Fund abgeglichen; Treffer je Report mit Plattform/Typ/Frist protokolliert.
- Keyword-Matching in Python exakt nach `R/relevance.R` nachgebaut (substring, case-insensitive, Umlaut-Faltung,
  ≥1 strong ∨ ≥2 supporting) und auf die 14 Fund-Titel angewandt.
- Code-Analyse aller 9 Konnektoren, der Relevanz-/Exclude-Logik und des Report-Datenflusses; die zentralen
  Aussagen wurden zusätzlich durch unabhängige adversariale Gegenprüfung verifiziert (64 Einzel-Claims geprüft,
  0 widerlegt).
- Direkter Portal-Zugriff (oeffentlichevergabe.de-API, TED, evergabe-online) war aus dieser Umgebung netzwerkseitig
  gesperrt; alle Aussagen stützen sich auf Code, Report-Archiv und die manuelle Excel. Offene Restprüfung, die nur
  online möglich ist: ob die Mai-Verfahren (Funde 1–6) tatsächlich in den damaligen OCDS-Tages-Zips enthalten
  waren (`/api/notice-exports?pubDay=…` für ~20.04.–13.05. laden und nach den Titeln greppen).
