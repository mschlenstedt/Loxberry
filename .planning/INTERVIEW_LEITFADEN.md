# Interview-Leitfaden: LoxBerry Core-Entwickler

**Dauer:** max. 30 Minuten
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

---

### 5. Plugin-Ökosystem (5 Min)

> "Plugin-Kompatibilität ist mir wichtig. Dazu ein paar Fragen."

**Frage 10:** Wie viele aktive Plugins gibt es ungefähr? Welche sind die wichtigsten?
- _Notizen:_

**Frage 11:** Nutzen Plugins `LoxBerry::System_v1.pm` oder den localhost-Bypass (`Satisfy Any`)?
- _Notizen:_

**Frage 12:** Welche Plugin-API-Funktionen dürfen auf keinen Fall geändert werden?
- _Notizen:_

---

### 6. Zusammenarbeit & Prozess (3 Min)

**Frage 13:** Wie soll ich PRs einreichen — einzeln pro Fix, oder gesammelt?
- _Notizen:_

**Frage 14:** Gibt es einen Review-Prozess? Wer reviewed und merged?
- _Notizen:_

**Frage 15:** Gibt es ein Test-System oder eine Staging-Umgebung zum Testen?
- _Notizen:_

---

### 7. Abschluss (2 Min)

> "Danke! Ich arbeite das ein und schicke euch einen aktualisierten Fahrplan. Welcher Kommunikationskanal ist am besten für Rückfragen?"

**Frage 16:** Wie erreiche ich euch am besten? (GitHub Issues, Forum, Telegram, Discord?)
- _Notizen:_

**Frage 17:** Wann wäre ein Follow-up sinnvoll?
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

**Nächster Kontaktpunkt:**
-

---

## Zeitplan-Checkliste

```
00:00 - 02:00  Einstieg + Kontext
02:00 - 07:00  Aktuelle Situation (3 Fragen)
07:00 - 12:00  Quick Wins bewerten (1 Frage + Tabelle)
12:00 - 20:00  Größere Themen priorisieren (5 Fragen)
20:00 - 25:00  Plugin-Ökosystem (3 Fragen)
25:00 - 28:00  Zusammenarbeit & Prozess (3 Fragen)
28:00 - 30:00  Abschluss + nächste Schritte
```

---

*Tipp: Nicht alle Fragen müssen gestellt werden — folge dem Gesprächsfluss. Die wichtigsten Infos sind: Prioritäten, Ablehnungen, Plugin-Risiken und PR-Workflow.*
