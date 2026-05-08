/* LoxBerry table sort — opt-in via class "lb-table-sortable" on <table>.
   Detects numeric / size-with-unit / date-DDMMYYYY columns automatically;
   falls back to localized string compare. Add class "lb-th-nosort" on a
   <th> to exclude that column from sorting. */

(function() {
	'use strict';

	function getCellValue(tr, idx) {
		var cell = tr.children[idx];
		if (!cell) return '';
		return (cell.innerText || cell.textContent || '').trim();
	}

	function parseSize(v) {
		var m = v.match(/^([\d.,]+)\s*([KMGTP])?B$/i);
		if (!m) return null;
		var units = { '': 1, K: 1024, M: 1048576, G: 1073741824, T: 1099511627776, P: 1125899906842624 };
		return parseFloat(m[1].replace(',', '.')) * units[(m[2] || '').toUpperCase()];
	}

	function parseDate(v) {
		var m = v.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?/);
		if (!m) return null;
		return new Date(+m[3], +m[2] - 1, +m[1], +m[4] || 0, +m[5] || 0, +m[6] || 0).getTime();
	}

	function compare(a, b, idx, dir) {
		var va = getCellValue(a, idx);
		var vb = getCellValue(b, idx);
		var sa = parseSize(va), sb = parseSize(vb);
		if (sa !== null && sb !== null) return dir * (sa - sb);
		var da = parseDate(va), db = parseDate(vb);
		if (da !== null && db !== null) return dir * (da - db);
		var fa = parseFloat(va.replace(',', '.'));
		var fb = parseFloat(vb.replace(',', '.'));
		if (!isNaN(fa) && !isNaN(fb) && /^-?[\d.,]+$/.test(va) && /^-?[\d.,]+$/.test(vb)) {
			return dir * (fa - fb);
		}
		return dir * va.localeCompare(vb, undefined, { numeric: true, sensitivity: 'base' });
	}

	function sortTable(table, idx, dir) {
		var tbody = table.tBodies[0];
		if (!tbody) return;
		var rows = Array.prototype.slice.call(tbody.rows);
		rows.sort(function(a, b) { return compare(a, b, idx, dir); });
		rows.forEach(function(r) { tbody.appendChild(r); });
	}

	function makeSortable(table) {
		if (table.dataset.lbSortInitialized === '1') return;
		table.dataset.lbSortInitialized = '1';
		var thead = table.tHead;
		if (!thead) return;
		var ths = thead.rows[0] ? thead.rows[0].cells : [];
		Array.prototype.forEach.call(ths, function(th, idx) {
			if (th.classList.contains('lb-th-nosort')) return;
			th.classList.add('lb-th-sortable');
			th.addEventListener('click', function() {
				var current = th.getAttribute('data-sort');
				var newDir = current === 'asc' ? -1 : 1;
				Array.prototype.forEach.call(ths, function(t) { t.removeAttribute('data-sort'); });
				th.setAttribute('data-sort', newDir === 1 ? 'asc' : 'desc');
				sortTable(table, idx, newDir);
			});
		});
	}

	function init() {
		var tables = document.querySelectorAll('table.lb-table-sortable');
		Array.prototype.forEach.call(tables, makeSortable);
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', init);
	} else {
		init();
	}
})();
