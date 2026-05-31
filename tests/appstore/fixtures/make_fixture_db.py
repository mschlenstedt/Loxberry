import sqlite3, os
HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "struct_sample.sqlite3")
if os.path.exists(DB): os.remove(DB)
c = sqlite3.connect(DB); cur = c.cursor()
cur.execute("""CREATE TABLE data_pluginuebersicht (
  pid TEXT DEFAULT '', rid INTEGER, rev INTEGER, latest BOOLEAN NOT NULL DEFAULT 0,
  col1 DEFAULT '', col2 DEFAULT '', col3 DEFAULT '', col4 DEFAULT '', col5 DEFAULT '',
  col6 DEFAULT '', col7 DEFAULT '', col8 DEFAULT '', col9 DEFAULT '', col10 DEFAULT '',
  col11 DEFAULT '', published INT DEFAULT NULL, PRIMARY KEY(pid, rid, rev))""")
cur.execute("""CREATE TABLE titles (pid NOT NULL, title NOT NULL,
  lasteditor NOT NULL DEFAULT '', lastrev NOT NULL DEFAULT '',
  lastsummary NOT NULL DEFAULT '', PRIMARY KEY(pid))""")

# rev = Unix-Timestamp der letzten Wiki-Revision (echte, unterschiedliche Werte,
# damit Datumsableitung + Sortierung testbar sind):
#   1700000000 -> 2023-11-14, 1710000000 -> 2024-03-09
rows = [
  # STABLE mit ZIP (installierbar)
  ("plugins:1_wire_ng:start", 0, 1700000000, 1, "prof.mobilux", ":plugins:1_wire_ng:icon.png",
   "STABLE", "2.2.1", "https://github.com/x/LoxBerry-Plugin-1-Wire-NG/archive/v2.5.zip",
   "", "1-Wire Busmaster auslesen.", "EN, DE", "https://loxforum.com/t/1wire", "", "", None),
  # Repo-only (kein ZIP, nur Repo) -> nicht installierbar; neuer als 1-Wire-NG
  ("plugins:repoonly:start", 0, 1710000000, 1, "someone", "",
   "BETA", "1.0", "https://github.com/x/some-plugin",
   "", "Nur als Repo verfuegbar.", "EN", "", "", "", None),
  # Nicht-Plugin-Unterseite -> herausfiltern (kein col4)
  ("plugins:1_wire_ng:faq", 0, 1700000000, 1, "", "", "", "", "", "", "FAQ-Text", "", "", "", "", None),
]
cur.executemany("""INSERT INTO data_pluginuebersicht
  (pid,rid,rev,latest,col1,col2,col3,col4,col5,col6,col7,col8,col9,col10,col11,published)
  VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", rows)
cur.executemany("INSERT INTO titles (pid,title) VALUES (?,?)", [
  ("plugins:1_wire_ng:start","1-Wire-NG"),
  ("plugins:repoonly:start","Repo Only Plugin"),
  ("plugins:1_wire_ng:faq","FAQ"),
])
c.commit(); c.close(); print("wrote", DB)
