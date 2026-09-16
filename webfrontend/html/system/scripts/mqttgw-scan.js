/*
 * mqttgw-scan.js - "Miniserver scannen" für das MQTT Gateway V2
 *
 * bin/mqtt-scan-miniserver.py liest die virtuellen Eingänge aus der
 * Programmdatei der Miniserver. Dieses Skript gleicht sie mit den Topics ab,
 * die Finder und V1-Übersicht kennen, und zeigt das Ergebnis im Dialog
 * #mqttgw-scan-popup (Markup in templates/system/mqtt-gateway.html).
 *
 * Genutzt von zwei Stellen:
 *   - Tab Abonnements (V2): Button "Miniserver scannen"
 *   - Tab Gateway: Umstieg von V1 auf V2 (ersetzt die frühere Migration)
 *
 * Abonniert wird nur, was der Anwender übernimmt. Die reinen Funktionen
 * (viName, build, guessEntry, applyRows, ...) arbeiten ohne DOM und sind
 * damit auch außerhalb des Browsers testbar.
 */
(function (root) {
	'use strict';

	var STATE_ORDER = { 'new': 0, 'rename': 1, 'guess': 2, 'sub': 3, 'json': 3, 'miss': 4 };
	var S = { lang: {} };

	// ── Hilfen ───────────────────────────────────────────────────────────

	function fmt(str, values) {
		return String(str).replace(/%([nts])/g, function (m, k) {
			return values[k] !== undefined ? values[k] : m;
		});
	}

	function escHtml(str) {
		return String(str)
			.replace(/&/g, '&amp;').replace(/</g, '&lt;')
			.replace(/>/g, '&gt;').replace(/"/g, '&quot;');
	}

	// Wie build_vi_name() in sbin/mqtt_gateway.py
	function viSegment(text) {
		return String(text).replace(/\//g, '_').replace(/ /g, '_').replace(/%/g, '_');
	}

	function viPath(path) {
		return path.replace(/\[(\d+)\]/g, '$1').replace(/@@/g, '_').replace(/ /g, '_');
	}

	function viName(topic, path) {
		var name = viSegment(topic);
		return (path === null || path === undefined) ? name : name + '_' + viPath(path);
	}

	// Blätter eines JSON-Payloads, Pfade wie renderJsonTree() im Template
	function walkJson(value, path, fn) {
		if (Array.isArray(value)) {
			for (var i = 0; i < value.length; i++) {
				walkJson(value[i], path === null ? '[' + i + ']' : path + '@@[' + i + ']', fn);
			}
		} else if (value !== null && typeof value === 'object') {
			Object.keys(value).forEach(function (k) {
				walkJson(value[k], path === null ? k : path + '@@' + k, fn);
			});
		} else if (path !== null) {
			fn(path, value === null ? 'null' : String(value));
		}
	}

	// Für "Tippfehler?": Groß/klein, Umlaute und Trennzeichen ignorieren
	function normalize(name) {
		return String(name).toLowerCase()
			.replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss')
			.replace(/[^a-z0-9]/g, '');
	}

	function findSub(subs, topic) {
		for (var i = 0; i < subs.length; i++) {
			if (subs[i].Id === topic) return subs[i];
		}
		return null;
	}

	function findField(sub, path) {
		var json = (sub && sub.Json) || [];
		for (var i = 0; i < json.length; i++) {
			if (json[i].Id === path) return json[i];
		}
		return null;
	}

	function subState(subs, entry) {
		var sub = findSub(subs, entry.topic);
		if (!sub) return 'new';
		if (entry.path === null) return sub.Jsonexpand ? 'json' : 'sub';
		return (sub.Jsonexpand && findField(sub, entry.path)) ? 'sub' : 'new';
	}

	// ── Abgleich ─────────────────────────────────────────────────────────

	// topics: { topic: payload } aus Finder und V1-Übersicht
	function candidates(topics, subs) {
		var byName = {}, byNorm = {}, entries = [], seenEntry = {}, jsonTopics = {};
		function add(entry) {
			var key = entry.topic + '\u0000' + (entry.path === null ? '' : entry.path);
			if (seenEntry[key]) return;
			seenEntry[key] = true;
			entry.segs = entry.topic.split('/');
			if (entry.path !== null) jsonTopics[entry.topic] = true;
			entries.push(entry);
			var name = viName(entry.topic, entry.path);
			(byName[name] = byName[name] || []).push(entry);
			var norm = normalize(name);
			if (!byNorm[norm]) byNorm[norm] = entry;
		}
		Object.keys(topics).forEach(function (topic) {
			var payload = topics[topic] === null || topics[topic] === undefined ? '' : String(topics[topic]);
			add({ topic: topic, path: null, value: payload });
			var first = payload.replace(/^\s+/, '').charAt(0);
			if (first === '{' || first === '[') {
				var parsed = null;
				try { parsed = JSON.parse(payload); } catch (e) {}
				if (parsed !== null && typeof parsed === 'object') {
					walkJson(parsed, null, function (path, val) {
						add({ topic: topic, path: path, value: val });
					});
				}
			}
		});
		// Abonnierte, aber gerade unbekannte Topics gelten als "schon abonniert"
		subs.forEach(function (sub) {
			add({ topic: sub.Id, path: null, value: '' });
			(sub.Json || []).forEach(function (f) { add({ topic: sub.Id, path: f.Id, value: '' }); });
		});
		return { byName: byName, byNorm: byNorm, entries: entries, jsonTopics: jsonTopics };
	}

	// Vorschlag für einen Eingang ohne bekanntes Topic, in dieser Reihenfolge:
	// 1. Bekanntes JSON-Topic, dem nur das Feld fehlt - Felder wie "action" bei
	//    z2m-Tastern stehen nur im Payload, wenn das Ereignis gerade passiert ist.
	//    z. B. Eingang z2m_X_30_001_Taster_action -> z2m/X/30_001_Taster + action
	// 2. Bekanntes Topic, das sich in genau einem Pfadabschnitt unterscheidet (der
	//    erste Abschnitt, die Topic-Gruppe, bleibt gleich); gleiches JSON-Feld zählt mehr.
	//    z. B. z2m/X/02_001_Luftfeuchtesensor + battery
	//      -> Eingang z2m_X_02_002_Luftfeuchtesensor_battery
	//      -> Vorschlag z2m/X/02_002_Luftfeuchtesensor + battery
	function guessEntry(name, cand) {
		var best = null;
		Object.keys(cand.jsonTopics || {}).forEach(function (topic) {
			var pre = viSegment(topic) + '_';
			if (name.length <= pre.length || name.indexOf(pre) !== 0) return;
			var score = 2000 + pre.length;
			if (!best || score > best.score) {
				best = { score: score, topic: topic, path: name.slice(pre.length), from: topic };
			}
		});
		if (best) return best;
		cand.entries.forEach(function (e) {
			var tail = e.path === null ? '' : '_' + viPath(e.path);
			if (tail && (name.length <= tail.length || name.slice(-tail.length) !== tail)) return;
			var core = tail ? name.slice(0, name.length - tail.length) : name;
			var vsegs = e.segs.map(viSegment);
			for (var i = 1; i < e.segs.length; i++) {
				var pre = vsegs.slice(0, i).join('_') + '_';
				var suf = i < e.segs.length - 1 ? '_' + vsegs.slice(i + 1).join('_') : '';
				if (core.length <= pre.length + suf.length) continue;
				if (core.indexOf(pre) !== 0) continue;
				if (suf && core.slice(-suf.length) !== suf) continue;
				var part = core.slice(pre.length, core.length - suf.length);
				if (part === vsegs[i]) continue;
				var score = pre.length + suf.length + (tail ? 1000 : 0);
				if (!best || score > best.score) {
					best = {
						score: score,
						topic: e.segs.slice(0, i).concat([part], e.segs.slice(i + 1)).join('/'),
						path: e.path,
						from: e.path === null ? e.topic : e.topic + ' → ' + e.path.replace(/@@/g, '.')
					};
				}
			}
		});
		return best;
	}

	// scan: Antwort von ajax=scan_miniservers, topics: { topic: payload }
	function build(scan, topics, subs) {
		var msMap = (scan && scan.miniservers) || {};
		var cand = candidates(topics, subs);
		var groups = {};
		Object.keys(topics).forEach(function (t) { groups[viSegment(t.split('/')[0]) + '_'] = true; });
		subs.forEach(function (s) { groups[viSegment(s.Id.split('/')[0]) + '_'] = true; });
		var groupList = Object.keys(groups);

		var rows = [], names = {}, hidden = 0, okCount = 0, allOk = true;
		Object.keys(msMap).forEach(function (id) {
			var ms = msMap[id];
			if (!ms.ok) { allOk = false; return; }
			okCount++;
			(ms.inputs || []).forEach(function (inp) {
				names[inp.name] = true;
				var row = { ms: parseInt(id, 10), name: inp.name, type: inp.type, entry: null, count: 0 };
				var list = cand.byName[inp.name];
				var renamed = inp.name.indexOf('##_') !== -1 ? inp.name.replace(/##_/g, '_') : null;

				if (list && list.length) {
					row.entry = list[0];
					for (var i = 0; i < list.length; i++) {
						if (subState(subs, list[i]) !== 'new') { row.entry = list[i]; break; }
					}
					row.count = list.length;
					row.state = subState(subs, row.entry);
				} else if (renamed && cand.byName[renamed]) {
					// V1 schrieb "_" in JSON-Schlüsseln als "##_", V2 sendet an den Namen ohne ##
					row.entry = cand.byName[renamed][0];
					row.newName = renamed;
					row.state = 'rename';
					names[renamed] = true;
				} else {
					var inGroup = groupList.some(function (g) { return inp.name.indexOf(g) === 0; });
					row.similar = cand.byNorm[normalize(inp.name)] || null;
					// Ein Treffer bis auf Schreibweise (Umlaute, Groß/klein) sagt mehr als ein
					// abgeleiteter Vorschlag - dann "Tippfehler?" statt eines erfundenen Topics
					row.guess = inGroup && !row.similar ? guessEntry(inp.name, cand) : null;
					if (row.guess) {
						row.state = 'guess';
					} else if (inGroup || row.similar) {
						row.state = 'miss';
					} else {
						hidden++;
						return;
					}
				}
				rows.push(row);
			});
		});
		// Zweiter Durchgang: Geräte, die in Runde 1 als JSON-Topic vorgeschlagen wurden,
		// gelten als bekannt. Ein offline Gerät liefert so seine übrigen Felder mit,
		// z. B. ..._Fernbedienung_battery -> Gerät bekannt -> ..._Fernbedienung_action als Feld.
		var guessedJson = {};
		rows.forEach(function (r) {
			if (r.state === 'guess' && r.guess.path !== null) guessedJson[r.guess.topic] = true;
		});
		if (Object.keys(guessedJson).length) {
			var cand2 = { entries: [], jsonTopics: guessedJson };
			rows.forEach(function (r) {
				var retry = (r.state === 'guess' && r.guess.path === null) || (r.state === 'miss' && !r.similar);
				if (!retry) return;
				var g2 = guessEntry(r.name, cand2);
				if (g2) {
					r.guess = g2;
					r.state = 'guess';
				}
			});
		}

		rows.sort(function (a, b) {
			return a.ms - b.ms || STATE_ORDER[a.state] - STATE_ORDER[b.state]
				|| a.name.toLowerCase().localeCompare(b.name.toLowerCase());
		});

		var orphans = okCount === 0 ? [] : subs.filter(function (sub) {
			if (sub.Jsonexpand && sub.Json && sub.Json.length) {
				return !sub.Json.some(function (f) { return names[viName(sub.Id, f.Id)]; });
			}
			return !names[viName(sub.Id, null)];
		});
		return { rows: rows, orphans: orphans, hidden: hidden, allOk: allOk, okCount: okCount };
	}

	// ── Auswahl-Knöpfe ───────────────────────────────────────────────────

	// mode: 'all' (neu + Vorschläge + Umbenennen), 'none', 'hint' (Vorschläge zusätzlich).
	// Wirkt auf alle Zeilen der Art, unabhängig vom gesetzten Filter.
	// Liefert { check: [Zeilenindex], clearOthers }.
	function selection(rows, mode) {
		var check = [];
		rows.forEach(function (r, idx) {
			var hint = r.state === 'guess' || r.state === 'rename';
			if ((mode === 'all' && (hint || r.state === 'new')) || (mode === 'hint' && hint)) check.push(idx);
		});
		return { check: check, clearOthers: mode === 'none' };
	}

	// ── Übernehmen ───────────────────────────────────────────────────────

	// picked: [{ row, entry }] - entry kann bei Vorschlägen vom Anwender geändert sein
	// opts: { defaultMS, flags: { noncached: [...], resetaftersend: [...] } }
	function applyRows(subs, picked, orphans, unsub, opts) {
		var list = JSON.parse(JSON.stringify(subs));
		var defaultMS = opts.defaultMS || 1;
		var flags = opts.flags || {};
		var nc = {}, ras = {};
		(flags.noncached || []).forEach(function (n) { nc[n] = true; });
		(flags.resetaftersend || []).forEach(function (n) { ras[n] = true; });

		if (unsub) {
			var drop = {};
			orphans.forEach(function (s) { drop[s.Id] = true; });
			list = list.filter(function (s) { return !drop[s.Id]; });
		}

		// JSON-Felder zuerst: ein Topic, das als JSON läuft, sendet keinen Gesamtwert
		picked = picked.slice().sort(function (a, b) {
			return (a.entry.path === null ? 1 : 0) - (b.entry.path === null ? 1 : 0);
		});

		var created = [], topics = {}, vis = [];
		// Toms: [] = Standard-Miniserver. Erster Treffer setzt, weitere ergänzen.
		function touch(obj, ms) {
			if (created.indexOf(obj) === -1) {
				created.push(obj);
				obj.Toms = ms === defaultMS ? [] : [ms];
				return;
			}
			var toms = (obj.Toms || []).slice();
			if (!toms.length) {
				if (ms === defaultMS) return;
				toms = [defaultMS];
			}
			if (toms.indexOf(ms) === -1) toms.push(ms);
			obj.Toms = toms.sort(function (a, b) { return a - b; });
		}
		function flagsFor(p) {
			var v2 = viName(p.entry.topic, p.entry.path);
			return {
				Noncached: !!(nc[p.row.name] || nc[v2]),
				resetaftersend: !!(ras[p.row.name] || ras[v2])
			};
		}

		picked.forEach(function (p) {
			var e = p.entry;
			var sub = findSub(list, e.topic);
			var isNewSub = !sub;
			if (isNewSub) {
				sub = { Id: e.topic, Toms: [], Noncached: false, resetaftersend: false, Jsonexpand: false, Json: [] };
				list.push(sub);
			}
			var f = flagsFor(p);
			if (e.path === null) {
				if (sub.Jsonexpand) return;
				if (isNewSub) {
					sub.Noncached = f.Noncached;
					sub.resetaftersend = f.resetaftersend;
				}
				if (isNewSub || created.indexOf(sub) !== -1) touch(sub, p.row.ms);
			} else {
				if (!sub.Jsonexpand) { sub.Jsonexpand = true; sub.Json = []; }
				var field = findField(sub, e.path);
				if (!field) {
					field = { Id: e.path, Toms: [], Noncached: f.Noncached, resetaftersend: f.resetaftersend };
					sub.Json.push(field);
					touch(field, p.row.ms);
				} else if (created.indexOf(field) !== -1) {
					touch(field, p.row.ms);
				}
			}
			topics[e.topic] = true;
			// Einmal senden nur, wenn der Eingang im Miniserver genau so heißt
			if (viName(e.topic, e.path) === p.row.name && vis.indexOf(p.row.name) === -1) vis.push(p.row.name);
		});

		return { list: list, topics: Object.keys(topics).length, vis: vis, picked: picked.length };
	}

	// ── Dialog ───────────────────────────────────────────────────────────

	var cur = null;   // { opts, scan, topics, subs, result }

	function $() { return root.jQuery.apply(root, arguments); }

	function msName(id) {
		var list = [];
		try { list = JSON.parse($('#miniserver_list').text()) || []; } catch (e) {}
		for (var i = 0; i < list.length; i++) {
			if (parseInt(list[i].id, 10) === id) return list[i].name;
		}
		return 'Miniserver ' + id;
	}

	function rowHtml(row, idx, L) {
		var isSub = row.state === 'sub' || row.state === 'json';
		var filter = isSub ? 'sub' : (row.state === 'rename' || row.state === 'guess' ? 'hint' : row.state);
		var html = '<div class="mqttgw-scan-row' + (isSub ? ' mqttgw-scan-is-sub' : '') + '" data-state="' + filter + '">';

		if (row.state === 'new') {
			html += '<input type="checkbox" class="scan-pick" data-idx="' + idx + '" checked aria-label="' + escHtml(row.name) + '">';
		} else if (row.state === 'rename' || row.state === 'guess') {
			html += '<input type="checkbox" class="scan-pick" data-idx="' + idx + '" aria-label="' + escHtml(row.name) + '">';
		} else if (isSub) {
			// Kein (deaktivierter) Haken: ein angehakter Kasten sähe wie eine Auswahl zum Übernehmen aus
			html += '<span class="mqttgw-scan-subicon" title="' + escHtml(L.stSub) + '" aria-hidden="true">✓</span>';
		} else {
			html += '<span></span>';
		}

		html += '<span class="mqttgw-scan-mono">' + escHtml(row.name)
			+ (row.type === 'VirtualTextIn' ? ' <span class="mqttgw-scan-tag">' + escHtml(L.typeText) + '</span>' : '')
			+ (row.type === 'VirtualHttpInCmd' ? ' <span class="mqttgw-scan-tag">' + escHtml(L.typeHttp) + '</span>' : '')
			+ '</span>';

		var jsonTag = function (path) {
			return path !== null ? ' <span class="mqttgw-scan-tag">JSON: ' + escHtml(path.replace(/@@/g, '.')) + '</span>' : '';
		};

		if (row.state === 'guess') {
			html += '<span class="mqttgw-scan-topic">'
				+ '<input type="text" class="mqttgw-scan-guess" data-idx="' + idx + '" value="' + escHtml(row.guess.topic) + '" aria-label="Topic">'
				+ jsonTag(row.guess.path)
				+ ' <span class="mqttgw-scan-hint">' + escHtml(fmt(L.guessHint, { s: row.guess.from })) + '</span>'
				+ '</span><span class="mqttgw-scan-val">–</span>';
		} else if (row.entry) {
			html += '<span class="mqttgw-scan-mono mqttgw-scan-topic">' + escHtml(row.entry.topic) + jsonTag(row.entry.path)
				+ (row.count > 1 ? ' <span class="mqttgw-scan-hint">' + escHtml(fmt(L.ambiguous, { n: row.count })) + '</span>' : '')
				+ (row.state === 'rename' ? ' <span class="mqttgw-scan-hint">' + escHtml(fmt(L.renameHint, { s: row.newName })) + '</span>' : '')
				+ '</span>';
			html += '<span class="mqttgw-scan-val" title="' + escHtml(row.entry.value) + '">' + escHtml(row.entry.value) + '</span>';
		} else {
			html += '<span class="mqttgw-scan-topic mqttgw-scan-none">';
			if (row.similar) {
				html += escHtml(L.noTopic) + ' <span class="mqttgw-scan-hint">' + escHtml(L.similar)
					+ ' <span class="mqttgw-scan-mono">' + escHtml(row.similar.topic
					+ (row.similar.path !== null ? ' → ' + row.similar.path.replace(/@@/g, '.') : '')) + '</span></span>';
			} else {
				html += escHtml(L.neverSeen);
			}
			html += '</span><span class="mqttgw-scan-val">–</span>';
		}

		var badge = {
			'new':    ['mqttgw-ms-ok',   L.stNew],
			'sub':    ['mqttgw-ms-new',  L.stSub],
			'json':   ['mqttgw-ms-new',  L.stJson],
			'rename': ['mqttgw-ms-warn', L.stRename],
			'guess':  ['mqttgw-ms-warn', L.stGuess],
			'miss':   ['mqttgw-ms-warn', row.similar ? L.stTypo : L.stNoTopic]
		}[row.state];
		html += '<span class="mqttgw-scan-state"><span class="mqttgw-ms-badge ' + badge[0] + '">' + escHtml(badge[1]) + '</span></span>';
		return html + '</div>';
	}

	function render() {
		var L = S.lang, scan = cur.scan || {};
		var msMap = scan.miniservers || {};
		var ids = Object.keys(msMap).sort(function (a, b) { return parseInt(a, 10) - parseInt(b, 10); });

		var info = '';
		ids.forEach(function (id) {
			var ms = msMap[id], label = msName(parseInt(id, 10));
			if (ms.ok) {
				var extra = String(ms.source).indexOf('project:') === 0
					? ' · ' + fmt(L.fromProject, { s: msName(parseInt(ms.source.slice(8), 10)) }) : '';
				info += '<span>' + escHtml(label + ' – ' + fmt(L.inputs, { n: (ms.inputs || []).length }) + extra) + '</span>';
			} else {
				info += '<span class="mqttgw-scan-err">' + escHtml(label + ' – ' + ((L.err || {})[ms.error] || (L.err || {}).internal)) + '</span>';
			}
		});
		$('#scan_ms_info').html(info);
		$('#scan_btn_retry').show();

		if (!ids.length || scan.error) {
			$('#scan_body').html('<div class="mqttgw-scan-error">' + escHtml((L.err || {})[scan.error] || (L.err || {}).internal) + '</div>');
			$('#scan_opts, #scan_select').empty();
			$('#scan_btn_apply').hide();
			return;
		}

		cur.result = build(scan, cur.topics, cur.subs);
		var rows = cur.result.rows;
		var counts = { 'all': rows.length, 'new': 0, 'hint': 0, 'sub': 0, 'miss': 0 };
		rows.forEach(function (r) {
			counts[r.state === 'json' ? 'sub' : (r.state === 'rename' || r.state === 'guess' ? 'hint' : r.state)]++;
		});

		var html = '';
		if (rows.length) {
			html += '<div class="mqttgw-scan-chips">';
			[['all', L.chipAll], ['new', L.chipNew], ['hint', L.chipHint], ['sub', L.chipSub], ['miss', L.chipMiss]].forEach(function (c) {
				if (c[0] !== 'all' && !counts[c[0]]) return;
				html += '<span class="mqttgw-chip scan-chip" data-filter="' + c[0] + '" role="button" tabindex="0">'
					+ escHtml(c[1]) + ' ' + counts[c[0]] + '</span>';
			});
			html += '</div>';
			html += '<div class="mqttgw-scan-headrow"><span></span><span>' + escHtml(L.colInput) + '</span><span>'
				+ escHtml(L.colTopic) + '</span><span style="text-align:right">' + escHtml(L.colValue)
				+ '</span><span style="text-align:right">' + escHtml(L.colStatus) + '</span></div>';
			var lastMs = null;
			rows.forEach(function (row, idx) {
				if (row.ms !== lastMs) {
					html += '<div class="mqttgw-scan-group">' + escHtml(msName(row.ms)) + '</div>';
					lastMs = row.ms;
				}
				html += rowHtml(row, idx, L);
			});
		} else {
			html += '<div class="mqttgw-scan-note">' + escHtml(L.nothing) + '</div>';
		}
		if (cur.result.hidden) {
			html += '<div class="mqttgw-scan-note">' + escHtml(fmt(L.hidden, { n: cur.result.hidden })) + '</div>';
		}
		if (cur.result.orphans.length) {
			html += '<details class="mqttgw-scan-orphans"><summary>' + escHtml(fmt(L.orphans, { n: cur.result.orphans.length }))
				+ '</summary><div>' + escHtml(L.orphansHint) + '<ul>';
			cur.result.orphans.forEach(function (s) { html += '<li>' + escHtml(s.Id) + '</li>'; });
			html += '</ul></div></details>';
		}
		$('#scan_body').html(html);
		applyFilter();

		// Auswahl-Knöpfe in der Fußzeile: immer sichtbar, egal wie weit gescrollt ist
		var select = '';
		if (counts['new'] + counts['hint']) {
			select = '<button type="button" class="lb-btn lb-btn-sm scan-select" data-select="all">' + escHtml(L.selAll) + '</button>'
				+ '<button type="button" class="lb-btn lb-btn-sm scan-select" data-select="none">' + escHtml(L.selNone) + '</button>'
				+ (counts['hint'] ? '<button type="button" class="lb-btn lb-btn-sm scan-select" data-select="hint">' + escHtml(L.selHint) + '</button>' : '');
		}
		$('#scan_select').html(select);

		var opts = '';
		if (cur.opts.allowResend && counts['new'] + counts['hint']) {
			opts += '<label for="scan_opt_resend"><input type="checkbox" id="scan_opt_resend" checked> ' + escHtml(L.optResend) + '</label>';
		}
		if (cur.result.orphans.length) {
			// Mit UDP braucht ein Abo keinen virtuellen HTTP-Eingang - dann nie abwählen
			var locked = cur.opts.useUdp ? L.unsubUdp : (!cur.result.allOk ? L.unsubIncomplete : '');
			opts += '<label for="scan_opt_unsub"><input type="checkbox" id="scan_opt_unsub"' + (locked ? ' disabled' : '') + '> '
				+ escHtml(fmt(L.optUnsub, { n: cur.result.orphans.length })) + '</label>';
			if (locked) opts += '<span class="mqttgw-scan-locked">' + escHtml(locked) + '</span>';
		}
		$('#scan_opts').html(opts);
		updateApply();
	}

	function applyFilter() {
		$('#scan_body .scan-chip').each(function () {
			$(this).toggleClass('mqttgw-chip-active', $(this).data('filter') === cur.filter);
		});
		$('#scan_body .mqttgw-scan-row').each(function () {
			$(this).toggle(cur.filter === 'all' || $(this).data('state') === cur.filter);
		});
	}

	function updateApply() {
		var $btn = $('#scan_btn_apply');
		var n = $('#scan_body .scan-pick:checked').length;
		var unsub = $('#scan_opt_unsub').prop('checked');
		if (!$('#scan_body .scan-pick').length && !$('#scan_opt_unsub').length) { $btn.hide(); return; }
		var unsubCount = unsub && cur.result ? cur.result.orphans.length : 0;
		$btn.text(applyLabel(n, unsubCount, S.lang)).show().toggleClass('lb-disabled', n === 0 && !unsub);
	}

	// Beim Abwählen zählt der Knopf alle Änderungen, sonst stünde dort "0 Eingänge übernehmen"
	function applyLabel(n, unsubCount, L) {
		return unsubCount ? fmt(L.applyChanges, { n: n + unsubCount }) : fmt(L.apply, { n: n });
	}

	function load() {
		var L = S.lang;
		cur.scan = null;
		$('#scan_ms_info, #scan_opts, #scan_select').empty();
		$('#scan_btn_apply, #scan_btn_retry').hide();
		$('#scan_body').html('<div class="mqttgw-scan-loading">' + escHtml(L.loading)
			+ '<div class="mqttgw-scan-bar"></div>' + escHtml(L.loadingHint) + '</div>');

		var jq = root.jQuery;
		var scanReq = jq.ajax({ type: 'POST', url: 'ajax/ajax-mqtt.php', data: { ajax: 'scan_miniservers' }, dataType: 'json', timeout: 300000 });
		var finderReq = jq.ajax({ type: 'POST', url: 'ajax/ajax-mqtt.php', data: { ajax: 'getmqttfinderdata' }, dataType: 'text', timeout: 60000 });
		var subsReq = cur.opts.getSubscriptions
			? jq.Deferred().resolve(cur.opts.getSubscriptions()).promise()
			: jq.ajax({ type: 'POST', url: 'ajax/ajax-mqtt.php', data: { ajax: 'get_subscriptions' }, dataType: 'json' })
				.then(function (d) { return (d && d.Subscriptions) || []; }, function () { return jq.Deferred().resolve([]).promise(); });
		var finderSafe = finderReq.then(function (t) { return t; }, function () { return jq.Deferred().resolve('').promise(); });

		scanReq.always(function () {
			finderSafe.then(function (finderText) {
				subsReq.then(function (subs) {
					var scan;
					if (scanReq.state() === 'resolved') {
						scan = scanReq.responseJSON || {};
					} else {
						scan = (scanReq.responseJSON) || { miniservers: {}, error: 'internal' };
					}
					var topics = {};
					try {
						var finder = finderText ? JSON.parse(finderText) : {};
						Object.keys((finder && finder.incoming) || {}).forEach(function (t) {
							topics[t] = finder.incoming[t].p || '';
						});
					} catch (e) {}
					Object.keys(scan.v1topics || {}).forEach(function (t) {
						if (!(t in topics)) topics[t] = scan.v1topics[t];
					});
					cur.scan = scan;
					cur.topics = topics;
					cur.subs = subs || [];
					if (document.getElementById('mqttgw-scan-popup').open) render();
				});
			});
		});
	}

	function apply() {
		var picked = [];
		$('#scan_body .scan-pick:checked').each(function () {
			var row = cur.result.rows[parseInt($(this).data('idx'), 10)];
			var entry = row.entry;
			if (row.state === 'guess') {
				var topic = String($('#scan_body .mqttgw-scan-guess[data-idx="' + $(this).data('idx') + '"]').val() || '').trim();
				if (!topic) return;
				entry = { topic: topic, path: row.guess.path, value: '' };
			}
			picked.push({ row: row, entry: entry });
		});
		var unsub = $('#scan_opt_unsub').prop('checked') && !$('#scan_opt_unsub').prop('disabled');
		if (!picked.length && !unsub) return;

		var res = applyRows(cur.subs, picked, cur.result.orphans, unsub,
			{ defaultMS: cur.opts.defaultMS, flags: (cur.scan && cur.scan.v1flags) || {} });
		res.undo = JSON.parse(JSON.stringify(cur.subs));
		res.unsubCount = unsub ? cur.result.orphans.length : 0;
		res.resend = !!(cur.opts.allowResend && $('#scan_opt_resend').prop('checked'));
		document.getElementById('mqttgw-scan-popup').close();
		if (cur.opts.onApply) cur.opts.onApply(res);
	}

	var bound = false;
	function bind() {
		if (bound) return;
		bound = true;
		$('#scan_btn_close').on('click', function (e) {
			e.preventDefault();
			document.getElementById('mqttgw-scan-popup').close();
		});
		$('#scan_btn_retry').on('click', function (e) {
			e.preventDefault();
			load();
		});
		$('#scan_btn_apply').on('click', function (e) {
			e.preventDefault();
			if ($(this).hasClass('lb-disabled')) return;
			apply();
		});
		$('#mqttgw-scan-popup').on('click keydown', '.scan-chip', function (e) {
			if (e.type === 'keydown' && e.key !== 'Enter' && e.key !== ' ') return;
			e.preventDefault();
			cur.filter = $(this).data('filter');
			applyFilter();
		});
		$('#mqttgw-scan-popup').on('change', '.scan-pick, #scan_opt_unsub', updateApply);
		$('#mqttgw-scan-popup').on('click', '.scan-select', function (e) {
			e.preventDefault();
			var sel = selection(cur.result.rows, $(this).data('select'));
			var wanted = {};
			sel.check.forEach(function (idx) { wanted[idx] = true; });
			$('#scan_body .scan-pick').each(function () {
				var idx = parseInt($(this).data('idx'), 10);
				if (wanted[idx]) $(this).prop('checked', true);
				else if (sel.clearOthers) $(this).prop('checked', false);
			});
			updateApply();
		});
		// Wer einen Vorschlag bearbeitet, will ihn übernehmen
		$('#mqttgw-scan-popup').on('input', '.mqttgw-scan-guess', function () {
			$('#scan_body .scan-pick[data-idx="' + $(this).data('idx') + '"]').prop('checked', true);
			updateApply();
		});
	}

	// opts: { defaultMS, useUdp, allowResend, getSubscriptions(), onApply(result) }
	S.open = function (opts) {
		cur = { opts: opts || {}, filter: 'all', scan: null, topics: {}, subs: [], result: null };
		bind();
		document.getElementById('mqttgw-scan-popup').showModal();
		load();
	};

	S.resend = function (vis, udpinport) {
		vis.forEach(function (vi) {
			root.jQuery.post('ajax/ajax-mqtt.php', { ajax: 'resend_one', udpinport: udpinport, vi: vi });
		});
	};

	// Für Tests und Wiederverwendung
	S.fmt = fmt;
	S.escHtml = escHtml;
	S.viName = viName;
	S.walkJson = walkJson;
	S.normalize = normalize;
	S.candidates = candidates;
	S.guessEntry = guessEntry;
	S.selection = selection;
	S.build = build;
	S.applyRows = applyRows;
	S.rowHtml = rowHtml;
	S.applyLabel = applyLabel;

	if (typeof module !== 'undefined' && module.exports) {
		module.exports = S;
	} else {
		root.MqttgwScan = S;
	}
})(typeof window !== 'undefined' ? window : this);
