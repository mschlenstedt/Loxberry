// Run with node, or supply templateSource when running in another JS engine.
var template = typeof require === 'function'
	? require('fs').readFileSync(require('path').join(__dirname,
		'../../../../templates/system/plugininstall_log.html'), 'utf8')
	: templateSource;
var source = template.match(/function updatestatus\(\)[\s\S]*?\n}/)[0];
var response, networkError, elements, cleared, logUpdates;
var status_in_progress = 0;
var interval = 1;
var interval2 = 2;

function assert(condition, message) {
	if (!condition) {
		throw new Error(message);
	}
}

function $(selector) {
	if (!elements[selector]) {
		elements[selector] = {
			disabled: true,
			scrollHeight: 0,
			addClass: function() { this.disabled = true; return this; },
			removeClass: function() { this.disabled = false; return this; },
			scrollTop: function() { return this; },
			prop: function() { return this; },
			is: function() { return false; }
		};
		elements[selector][0] = elements[selector];
	}
	return elements[selector];
}

$.get = function(url, callback) {
	if (!networkError) {
		callback(response);
	}
	return {
		fail: function(callback) { if (networkError) { callback(); } return this; },
		always: function(callback) { callback(); return this; }
	};
};
var document = { getElementById: function() { return $('#pstatus'); } };
var console = { log: function() {} };
function clearInterval(id) { cleared.push(id); }
function setTimeout() {}
function updatelog() { logUpdates++; }

eval(source);

function update(value, error, failure) {
	elements = {};
	cleared = [];
	logUpdates = 0;
	response = { message: value, error: error };
	networkError = failure;
	updatestatus();
	assert(status_in_progress === 0, 'polling guard must always be reset');
}

[1, 4].forEach(function(status) {
	update(String(status), 0, false);
	assert(cleared.length === 0, 'active operation must continue polling');
	assert($('#btnnext').disabled, 'active operation must keep Next disabled');
	assert($('#pstatus').innerHTML.indexOf(status === 4 ? 'DOWNLOAD' : 'TITLE') >= 0,
		'download and installation must have distinct labels');
});

[0, 2, 3].forEach(function(status) {
	update(String(status), 0, false);
	assert(cleared.length === 2, 'terminal status must stop both timers');
	assert(!$('#btnnext').disabled, 'terminal status must enable Next');
	assert(logUpdates === 1, 'terminal status must request final log');
	var label = status === 0 ? 'SUCCESS' : status === 2 ? 'ERROR' : 'REBOOTREQUIRED';
	assert($('#pstatus').innerHTML.indexOf('UI_INSTALL_LABEL_' + label) >= 0,
		'terminal status must display the correct result');
	assert($('#btnreboot').disabled === (status !== 3), 'only status 3 enables reboot');
});

['File not found', '', null, undefined, '0garbage', '00', '0.0', '5'].forEach(function(status) {
	update(status, 0, false);
	assert(cleared.length === 0, 'invalid status must not stop polling');
	assert($('#btnnext').disabled, 'invalid status must not enable Next');
	assert($('#pstatus').textContent.indexOf('STATUS_ERROR') >= 0,
		'invalid status must show a retrieval error, never success');
});

update('0', -1, false);
assert(cleared.length === 0, 'API errors must not stop polling');
assert($('#pstatus').textContent.indexOf('STATUS_ERROR') >= 0, 'API errors must be visible');
update('0', 0, true);
assert(cleared.length === 0, 'network errors must not stop polling');
assert($('#pstatus').textContent.indexOf('STATUS_ERROR') >= 0, 'network errors must be visible');
