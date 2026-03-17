# Interview-Leitfaden: LoxBerry Core-Entwickler

**Dauer:** ca. 30 Minuten (max. 35 Min)
**Ziel:** Alle Informationen sammeln, die wir für das Modernisierungs-Proposal brauchen
**Format:** Videocall

---

## Vorbereitung (vor dem Call)

- [ ] Fahrplan (DEVELOPER_PROPOSAL.md) vorab an Entwickler schicken
- [ ] Kurz erklären: "Ich habe ein Codebase-Audit gemacht und möchte eure Einschätzung dazu holen"
- [ ] Screen-Sharing vorbereiten (Fahrplan als Referenz)

---

## Ablauf

### 1. Einstieg (2 Min)

> "Danke für eure Zeit. Ich habe mir LoxBerry genauer angeschaut und ein paar Optimierungen vorbereitet — MQTT Gateway Performance, Install-Script, und weitere Ideen. Ich möchte eure Einschätzung dazu holen und verstehen, wo ihr die Prioritäten seht."

---

### 2. Aktuelle Situation (5 Min)

**Frage 1:** Was sind aktuell eure größten Schmerzpunkte mit der Codebase?
- _Notizen:_

**Frage 2:** Gibt es laufende Arbeiten oder geplante Änderungen, die ich kennen sollte?
- _Notizen:_

**Frage 3:** Wie viele aktive Entwickler arbeiten gerade an LoxBerry? Wer kümmert sich um was?
- _Notizen:_

---

### 3. Quick Wins bewerten (5 Min)

> "Ich habe einige schnelle Verbesserungen vorbereitet. Welche davon wären am willkommensten?"

**Zeigen:** Quick-Wins-Liste aus dem Fahrplan

| Quick Win | Entwickler-Einschätzung | Prio (1-3) |
|-----------|------------------------|------------|
| MQTT Gateway Performance | | |
| Shell-Injection Fix (admin.cgi) | | |
| fatalsToBrowser entfernen | | |
| Debug-Noise gaten | | |
| AJAX-Handler mergen | | |
| jsonrpc Logging fix | | |
| Install-Script Optimierung | | |

**Frage 4:** Gibt es Quick Wins die ihr ablehnen würdet? Wenn ja, warum?
- _Notizen:_

---

### 4. Größere Themen priorisieren (8 Min)

> "Jetzt zu den größeren Themen. Was seht ihr als am wichtigsten an?"

**Frage 5:** Wie steht ihr zum Thema Sicherheit (CSRF, JsonRPC Allowlist, SSL)? Wie dringend ist das für euch?
- _Notizen:_

**Frage 6:** Theme-System / Modernes UI — ist das was die Community fordert, oder eher Nice-to-have?
- _Notizen:_

**Frage 7:** Backup (Miniserver-Config + System) — gibt es dafür Nachfrage aus der Community?
- _Notizen:_

**Frage 8:** Python-Migration — wie steht ihr dazu? Ist das realistisch oder zu ambitioniert?
- _Notizen:_

**Frage 9:** Debian 13 Trixie — plant ihr das sowieso? Oder ist Bookworm noch das Ziel?
- _Notizen:_

**Frage 10:** LoxBerry Statistik-Seite — die war ja mal online. Wäre es sinnvoll, die mit frischem Design wieder aufzubauen? Welche Daten wären für euch und die Community am wertvollsten? (z.B. aktive Installationen, Plugin-Nutzung, Debian-Versionen, Hardware-Verteilung)
- _Notizen:_

**Frage 11:** Ticketsystem für Bug-Reports — nutzt ihr aktuell GitHub Issues oder gibt es was anderes? Wäre ein eigenes, integriertes Ticketsystem sinnvoll, z.B. direkt aus dem LoxBerry Admin-UI heraus Bugs melden mit automatischem System-Info-Anhang?
- _Notizen:_

**Frage 12:** Benchmark-Plugin — ich stelle mir ein Plugin vor, das die gesamte Installation durchmisst: MQTT-Performance, Plugin-Antwortzeiten, Speicherverbrauch, Systemressourcen. Am Ende gibt's einen Health-Score (z.B. A-F oder 0-100) und eine Übersicht welche Plugins Probleme verursachen. Wäre sowas nützlich für Support und Community?
- _Notizen:_

---

### 5. Plugin-Ökosystem (5 Min)

> "Plugin-Kompatibilität ist mir wichtig. Dazu ein paar Fragen."

**Frage 13:** Wie viele aktive Plugins gibt es ungefähr? Welche sind die wichtigsten?
- _Notizen:_

**Frage 14:** Nutzen Plugins `LoxBerry::System_v1.pm` oder den localhost-Bypass (`Satisfy Any`)?
- _Notizen:_

**Frage 15:** Welche Plugin-API-Funktionen dürfen auf keinen Fall geändert werden?
- _Notizen:_

**Frage 16:** KI-gestützte Plugin-Entwicklung — immer mehr Entwickler nutzen KI-Tools (Claude, Copilot) zum Coden. Wäre es sinnvoll, empfohlene Standards und Templates dafür bereitzustellen? Z.B. ein PLUGIN_SPEC.md Template das als KI-Kontext dient, eine empfohlene Projektstruktur, Beispiel-Tests. Nicht verpflichtend, aber als Hilfestellung — damit KI-generierte Plugins eher den LoxBerry-Konventionen folgen statt dass jeder bei Null anfängt.
- _Notizen:_

---

### 6. Zusammenarbeit, Prozess & Nachhaltigkeit (5 Min)

**Frage 17:** Wie soll ich PRs einreichen — einzeln pro Fix, oder gesammelt?
- _Notizen:_

**Frage 18:** Gibt es einen Review-Prozess? Wer reviewed und merged?
- _Notizen:_

**Frage 19:** Gibt es ein Test-System oder eine Staging-Umgebung zum Testen?
- _Notizen:_

**Frage 20:** Sponsoring / Finanzierung — KI-Tools wie Claude Code oder Copilot kosten Geld und ich investiere da gerade einiges in die Modernisierung. Wie steht ihr zu einem kleinen Sponsoring-Modell? Z.B. GitHub Sponsors oder "Buy me a coffee" — nicht als Bezahlung, sondern als Wertschätzung für die Core-Entwickler und zur Deckung von Tool-Kosten. Ein kleiner Betrag der zeigt: die Community schätzt eure Arbeit.
- _Notizen:_

---

### 7. Abschluss (2 Min)

> "Danke! Ich arbeite das ein und schicke euch einen aktualisierten Fahrplan. Welcher Kommunikationskanal ist am besten für Rückfragen?"

**Frage 21:** Wie erreiche ich euch am besten? (GitHub Issues, Forum, Telegram, Discord?)
- _Notizen:_

**Frage 22:** Nächster Austausch — ich werde nach dem heutigen Gespräch die ersten PRs vorbereiten. Wann wäre ein guter Zeitpunkt für einen kurzen Follow-up-Call, um zu schauen ob die PRs in die richtige Richtung gehen und ob sich neue Prioritäten ergeben haben? (z.B. in 2-3 Wochen?)
- _Notizen:_

---

## Nach dem Call ausfüllen

### Zusammenfassung

**Top 3 Prioritäten der Entwickler:**
1.
2.
3.

**Abgelehnte Punkte:**
-

**Neue Punkte (von Entwicklern eingebracht):**
-

**Plugin-Kompatibilität — kritische Erkenntnisse:**
-

**PR-Workflow:**
-

**Sponsoring — Reaktion:**
-

**Nächster Kontaktpunkt:**
-

---

## Zeitplan-Checkliste

```
00:00 - 02:00  Einstieg + Kontext
02:00 - 07:00  Aktuelle Situation (3 Fragen)
07:00 - 12:00  Quick Wins bewerten (1 Frage + Tabelle)
12:00 - 20:00  Größere Themen priorisieren (8 Fragen — Highlights rauspicken!)
20:00 - 25:00  Plugin-Ökosystem (4 Fragen)
25:00 - 30:00  Zusammenarbeit, Prozess & Nachhaltigkeit (4 Fragen)
30:00 - 32:00  Abschluss + nächste Schritte
```

---

*Tipp: Nicht alle Fragen müssen gestellt werden — folge dem Gesprächsfluss. Die wichtigsten Infos sind: Prioritäten, Ablehnungen, Plugin-Risiken, PR-Workflow und Sponsoring-Bereitschaft.*
