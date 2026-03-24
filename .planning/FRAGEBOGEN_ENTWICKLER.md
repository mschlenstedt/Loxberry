# LoxBerry NeXtGen — Fragebogen für Core-Entwickler

**Von:** Strike1988
**Kontext:** Codebase-Audit mit Modernisierungsvorschlägen — bitte um eure Einschätzung
**Zeitaufwand:** ca. 15 Minuten zum Ausfüllen
**Bitte bis zum [DATUM] zurückschicken**

> Ich habe ein ausführliches Codebase-Audit durchgeführt und einen Fahrplan für mögliche Verbesserungen erstellt. Bevor ich PRs einreiche, möchte ich eure Meinung dazu einholen. Ihr müsst nicht jede Frage beantworten — jede Rückmeldung hilft!

---

## A. Allgemein

**A1.** Was sind aktuell eure größten Schmerzpunkte mit der LoxBerry-Codebase?

```
Antwort:


```

**A2.** Gibt es aktuell laufende Arbeiten oder geplante Änderungen, die ich kennen sollte?

```
Antwort:


```

**A3.** Wie viele aktive Entwickler arbeiten gerade an LoxBerry Core?

- [ ] 1
- [ ] 2-3
- [ ] 4+
- Wer macht was? _______________

---

## B. Quick Wins — Sofort einreichbare PRs

Ich habe folgende kleine Verbesserungen vorbereitet. Bitte kreuzt an, welche ihr annehmen würdet:

| # | Quick Win | Annehmen? | Kommentar |
|---|-----------|-----------|-----------|
| 1 | **MQTT Gateway Performance** — 7 Optimierungen (Connection-Pooling, Early-Filtering, Caching). Optimierte Datei liegt vor. Rückwärtskompatibel. | [ ] Ja  [ ] Nein  [ ] Vielleicht | |
| 2 | **Shell-Injection Fix** — admin.cgi übergibt Passwörter via STDIN statt Kommandozeile | [ ] Ja  [ ] Nein  [ ] Vielleicht | |
| 3 | **fatalsToBrowser entfernen** — 13 CGI-Scripts zeigen keine Stack Traces mehr im Browser | [ ] Ja  [ ] Nein  [ ] Vielleicht | |
| 4 | **Debug-Noise gaten** — 63 `print STDERR` hinter $DEBUG-Flag setzen | [ ] Ja  [ ] Nein  [ ] Vielleicht | |
| 5 | **AJAX-Handler mergen** — ajax-generic2.php in ajax-generic.php zusammenführen | [ ] Ja  [ ] Nein  [ ] Vielleicht | |
| 6 | **jsonrpc.php Logging** — Request/Response-Bodies nicht mehr ins Error Log schreiben | [ ] Ja  [ ] Nein  [ ] Vielleicht | |
| 7 | **Install-Script Optimierung** — 50% weniger apt-Aufrufe, gleiche Schritte | [ ] Ja  [ ] Nein  [ ] Vielleicht | |

**B1.** Gibt es Quick Wins die ihr auf keinen Fall wollt? Warum?

```
Antwort:


```

---

## C. Sicherheit

Das Audit hat folgende Sicherheitsprobleme gefunden:

- Shell Injection via Passwörter in admin.cgi
- Kein CSRF-Schutz auf state-changing Endpoints
- JsonRPC exponiert alle LBSystem/LBWeb-Funktionen (Denylist statt Allowlist)
- SSL-Verifizierung für Miniserver komplett deaktiviert
- `fatalsToBrowser` leakt Stack Traces in 13 Scripts
- Credentials werden im Apache Error Log geloggt

**C1.** Wie wichtig ist euch Sicherheitshärtung? (1 = unwichtig, 5 = kritisch)

```
[ ] 1   [ ] 2   [ ] 3   [ ] 4   [ ] 5
```

**C2.** CSRF-Schutz würde einen Plugin-Bypass brauchen (damit localhost-Aufrufe weiter funktionieren). Ist das akzeptabel?

- [ ] Ja, mit Bypass-Mechanismus für Plugins
- [ ] Nein, zu riskant für Plugin-Kompatibilität
- [ ] Müsste ich mir genauer anschauen

**C3.** SSL/TLS-Verifizierung für Miniserver — wollt ihr das optional anbieten?

- [ ] Ja, optional pro Miniserver einstellbar
- [ ] Nein, LAN-intern reicht uns
- [ ] Sonstiges: _______________

---

## D. UI und Design

**D1.** Wie wichtig ist euch ein moderneres UI? (1 = unwichtig, 5 = kritisch)

```
[ ] 1   [ ] 2   [ ] 3   [ ] 4   [ ] 5
```

**D2.** Theme-System (hell, dunkel, klassisch, auto via CSS) — Interesse?

- [ ] Ja, gute Idee
- [ ] Nice-to-have, nicht prioritär
- [ ] Nein, unnötig

**D3.** Fordert die Community ein moderneres Design?

- [ ] Ja, regelmäßig
- [ ] Manchmal
- [ ] Kaum/nie

**D4.** jQuery 1.12.4 + jQuery Mobile 1.4.0 sind End-of-Life. Wie steht ihr zu einer schrittweisen Migration auf Vue 3 (Seite für Seite, kein Big Bang)?

- [ ] Sinnvoll, aber langfristiges Ziel
- [ ] Zu aufwändig, lieber jQuery updaten
- [ ] Offen — müsste ich mir anschauen
- [ ] Sonstiges: _______________

---

## E. Neue Features

**E1.** Backup-System (Miniserver-Config + LoxBerry Full-Backup, zeitgesteuert, auf NAS/Cloud) — wie groß ist die Nachfrage?

- [ ] Wird oft gefragt
- [ ] Wäre willkommen
- [ ] Braucht niemand
- Kommentar: _______________

**E2.** Gibt es bestehende Backup-Workarounds in der Community die ich kennen sollte?

```
Antwort:


```

**E3.** Miniserver HTTP API für Config-Export — welche Endpoints sind dafür relevant? Kennt ihr die Doku?

```
Antwort:


```

---

## F. Technische Richtung

**F1.** Python als neue Backend-Sprache neben Perl/PHP (schrittweise, nicht als Ersatz) — wie steht ihr dazu?

- [ ] Gut, Python ist besser wartbar
- [ ] Lieber bei Perl/PHP bleiben
- [ ] Offen, aber müsste gut begründet sein
- Kommentar: _______________

**F2.** Debian 13 Trixie — plant ihr das bereits?

- [ ] Ja, aktiv
- [ ] Geplant, aber noch nicht begonnen
- [ ] Nein, Bookworm reicht erstmal
- Kommentar: _______________

**F3.** Test-Infrastruktur (automatisierte Tests für Core-Module) — wie wichtig ist euch das?

```
[ ] 1   [ ] 2   [ ] 3   [ ] 4   [ ] 5
```

---

## G. Plugin-Ökosystem

**G1.** Ungefähr wie viele aktive Plugins gibt es?

- [ ] < 20
- [ ] 20-50
- [ ] 50-100
- [ ] 100+

**G2.** Welche Plugins sind die wichtigsten / meistgenutzten?

```
Antwort:


```

**G3.** Nutzen Plugins aktiv `LoxBerry::System_v1.pm`?

- [ ] Ja, einige
- [ ] Nein / Weiß nicht
- Welche? _______________

**G4.** Nutzen Plugins den localhost-Bypass (`Satisfy Any` in .htaccess)?

- [ ] Ja
- [ ] Nein / Weiß nicht
- Welche? _______________

**G5.** Welche Plugin-API-Funktionen dürfen auf KEINEN FALL geändert werden?

```
Antwort:


```

---

## H. Zusammenarbeit

**H1.** Wie soll ich PRs einreichen?

- [ ] Einzeln pro Fix (1 PR = 1 Thema)
- [ ] Gesammelt nach Kategorie (z.B. alle Security-Fixes)
- [ ] Sonstiges: _______________

**H2.** Wer reviewed und merged PRs?

```
Antwort:


```

**H3.** Gibt es ein Test-/Staging-System?

- [ ] Ja: _______________
- [ ] Nein, wird lokal getestet

**H4.** Bester Kommunikationskanal für Rückfragen?

- [ ] GitHub Issues/Discussions
- [ ] Forum (forum.loxberry.de)
- [ ] Telegram
- [ ] Discord
- [ ] Sonstiges: _______________

---

## I. Freie Anmerkungen

Gibt es noch etwas, das ich wissen sollte? Ideen, Bedenken, Wünsche?

```
Antwort:




```

---

*Vielen Dank für eure Zeit! Ich arbeite die Antworten ein und schicke einen aktualisierten Fahrplan.*

*— Strike1988*
