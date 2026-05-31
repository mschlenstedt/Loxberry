# -*- coding: utf-8 -*-
"""Dev-Tool: dokuwiki struct.sqlite3 -> sauberes plugins.json (Datenvertrag).
Laeuft NICHT auf dem LoxBerry; erzeugt den mitgelieferten Fallback-Katalog."""
import argparse, json, sqlite3, datetime

WIKI_MEDIA = "https://wiki.loxberry.de/lib/exe/fetch.php?media="

def logo_url(col2):
    c = (col2 or "").lstrip(":")
    return WIKI_MEDIA + c if c else ""

def clean(s):
    return (s or "").strip().replace("\r", " ").replace("\n", " ")

def build(db_path):
    c = sqlite3.connect(db_path); cur = c.cursor()
    cur.execute("""
      SELECT d.pid, t.title, d.col1,d.col2,d.col3,d.col4,d.col5,d.col7,d.col8,d.col9,d.col10
      FROM data_pluginuebersicht d LEFT JOIN titles t ON t.pid=d.pid
      WHERE d.latest=1
        AND d.rev=(SELECT MAX(rev) FROM data_pluginuebersicht d2
                   WHERE d2.pid=d.pid AND d2.latest=1)
        AND d.pid LIKE 'plugins:%:start'
        AND TRIM(d.col4) != ''
      GROUP BY d.pid
      ORDER BY t.title COLLATE NOCASE
    """)
    plugins = []
    for pid,title,author,logo,status,ver,url5,desc,langs,forum,mod in cur.fetchall():
        url5 = clean(url5)
        is_zip = url5.lower().endswith(".zip")
        plugins.append({
            "pid": pid, "title": clean(title) or pid, "author": clean(author),
            "logo": logo_url(logo), "status": clean(status).upper(),
            "version": clean(ver),
            "zip": url5 if is_zip else "",
            "repo": "" if is_zip else url5,
            "description": clean(desc), "languages": clean(langs),
            "forum": clean(forum), "lastmodified": clean(mod),
        })
    c.close()
    return {"generated": datetime.datetime.utcnow().replace(microsecond=0).isoformat()+"Z",
            "source": "loxberry-wiki/struct", "plugins": plugins}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    data = build(a.db)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("wrote", a.out, "with", len(data["plugins"]), "plugins")

if __name__ == "__main__":
    main()
