#!/usr/bin/node

'use strict';

console.log("Content-type: text/html\n");

const jayson = require('jayson/promise');
const client = jayson.client.http('http://localhost:80/admin/system/jsonrpc.php');

// Using Promises in batch mode from jayson to get all JsonRpc requests done before writing the user interface

const batch = [
	client.request('LBWeb::get_lbheader', [ "Squeezelite Plugin", "https://loxwiki.eu", "helptemplate.html" ], undefined, false),
	client.request('LBWeb::get_lbfooter', [], undefined, false),
	client.request('LBWeb::mslist_select_html', [ { LABEL: 'Select your Miniserver', FORMID: 'MSNR', SELECTED: '1' }], undefined, false),
	client.request('getdirs', [ "squeezelite" ], undefined, false),
	
	// client.request('LBSystem::get_localip', [], undefined, false),
	// client.request('LBWeb::loglist_url', [ {'PACKAGE': 'squeezelite' } ], undefined, false),
	// client.request('LBWeb::logfile_button_html', [ { PACKAGE:'squeezelite', NAME:'daemon' } ], undefined, false),
	// client.request('LBSystem::get_miniservers', [], undefined, false),
 ];
  
 client.request(batch).then(function(responses) {
	var lbdirs = responses[3].result;
	console.log(responses[0].result);
	console.log("<h1>Demo with Node.js and LoxBerry JsonRpc</h1>");
	console.log("<p>Plugin config dir is ", lbdirs.lbpconfigdir, ", the data dir is ", lbdirs.lbpdatadir, ".</p>");
	console.log(responses[2].result);
	console.log(responses[1].result);
	
 });
 