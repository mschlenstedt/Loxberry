import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
GEN = os.path.join(ROOT, "bin", "showcase", "appstore", "gen_plugins_json.py")
FIX = os.path.join(HERE, "fixtures", "struct_sample.sqlite3")
EXP = os.path.join(HERE, "fixtures", "expected_plugins.json")

def run(tmp_path):
    out = tmp_path / "out.json"
    subprocess.run([sys.executable, GEN, "--db", FIX, "--out", str(out)], check=True)
    return json.loads(out.read_text(encoding="utf-8"))

def test_maps_columns_and_filters(tmp_path):
    got = run(tmp_path)
    exp = json.loads(open(EXP, encoding="utf-8").read())
    assert got["plugins"] == exp["plugins"]

def test_repoonly_has_no_zip(tmp_path):
    got = run(tmp_path)
    repo = [p for p in got["plugins"] if p["pid"] == "plugins:repoonly:start"][0]
    assert repo["zip"] == "" and repo["repo"].startswith("https://github.com/")

def test_nonplugin_subpage_filtered(tmp_path):
    got = run(tmp_path)
    assert all(p["pid"] != "plugins:1_wire_ng:faq" for p in got["plugins"])

def test_has_generated_timestamp(tmp_path):
    got = run(tmp_path)
    assert "generated" in got and got["source"] == "loxberry-wiki/struct"
