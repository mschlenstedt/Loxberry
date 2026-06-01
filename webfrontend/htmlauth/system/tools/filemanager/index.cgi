#!/usr/bin/perl
use strict;
use warnings;
use LoxBerry::System;
use HTML::Template;
use CGI;

my $cgi = CGI->new;

# Minimal empty template just to feed readlanguage()
my $tmpl_str = '';
my $template = HTML::Template->new(
    scalarref    => \$tmpl_str,
    global_vars  => 1,
    die_on_bad_params => 0,
);
my %SL = LoxBerry::System::readlanguage($template);

sub sl { return $SL{$_[0]} // $_[1] // '' }

my $title      = sl('COMMON.LOXBERRY_MAIN_TITLE','LoxBerry') . ': ' . sl('FILEMANAGER.WIDGETLABEL','File Manager');
my $label_pin  = sl('FILEMANAGER.LABEL_SECUREPIN',  'Please enter your SecurePIN to authorize yourself:');
my $warn_title = sl('FILEMANAGER.WARNING_TITLE',    'Warning');
my $warn_text  = sl('FILEMANAGER.WARNING_TEXT',     'Be VERY careful! You can destroy your LoxBerry!');
my $wrong_pin  = sl('FILEMANAGER.WRONGPIN_TEXT',    'The entered SecurePIN was wrong. Please try again.');
my $btn_ok     = sl('COMMON.BUTTON_OK',             'OK');
my $checking   = sl('SECUREPIN.CHECK_WAIT',         '...');
my $conn_err   = sl('SECUREPIN.ERROR_GENERIC',      'Connection error. Please try again.');

sub js_esc {
    my $s = shift // '';
    $s =~ s/\\/\\\\/g;
    $s =~ s/"/\\"/g;
    $s =~ s/\n/\\n/g;
    $s =~ s/\r//g;
    return $s;
}

print $cgi->header(-type => 'text/html', -charset => 'utf-8');
print <<"HTML";
<!DOCTYPE html>
<html>
	<head>
		<meta charset="utf-8">
		<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
		<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=2">
		<style>
			html, body { height: 100%; margin: 0; padding: 0; overflow: hidden; }
			#elfinder { height: 100vh; }
		</style>
		<title>$title</title>

		<!-- SecurePIN overlay styles -->
		<style>
			#securepin_overlay {
				position: fixed; top: 0; left: 0; width: 100%; height: 100%;
				background: #ebebeb;
				z-index: 9999;
				display: flex; align-items: center; justify-content: center;
				font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
				font-size: 14px;
			}
			#securepin_content {
				width: 320px;
				max-width: 95vw;
				text-align: center;
			}
			#securepin_content > p {
				margin: 0 0 10px 0;
				color: #333;
				font-size: 14px;
				line-height: 1.4;
			}
			#securepin_row {
				display: flex;
				gap: 8px;
				align-items: center;
				margin: 10px;
			}
			#securepin {
				flex: 1;
				min-width: 0;
				padding: 7px 10px;
				border: 1px solid #aaa;
				font-size: 14px;
				outline: none;
			}
			#check_securepin {
				padding: 7px 16px;
				background: #fff;
				color: #333;
				border: 1px solid #aaa;
				font-size: 13px;
				cursor: pointer;
				white-space: nowrap;
			}
			#check_securepin:hover:not(:disabled) { background: #f0f0f0; }
			#check_securepin:disabled { opacity: 0.5; cursor: default; }
			#check_hint {
				min-height: 18px;
				font-size: 13px;
				padding: 4px 0;
				color: #555;
			}
			#securepin_warning {
				margin-top: 20px;
				background: #FF8080;
				border: 1px solid #000;
				padding: 8px 12px;
				font-size: 13px;
				color: #000;
				text-align: center;
				line-height: 1.45;
			}
			#securepin_warning b {
				display: block;
				margin-bottom: 6px;
			}
		</style>

		<!-- Require JS (REQUIRED) -->
		<script data-main="./main.default.js" src="//cdnjs.cloudflare.com/ajax/libs/require.js/2.3.7/require.min.js"></script>
		<script>
			// Compute elFinder startPathHash from URL ?p= parameter for direct folder navigation
			var _elFinderStartHash = (function() {
				try {
					var p = new URLSearchParams(window.location.search).get('p');
					if (p) {
						p = p.replace(/^\\//, '');
						return 'l1_' + btoa('/' + p).replace(/\\+/g, '-').replace(/\\//g, '_').replace(/=+\$/g, '');
					}
				} catch(e) {}
				return null;
			})();

			define('elFinderConfig', {
				defaultOpts : {
					url : 'php/connector.minimal.php',
					startPathHash : _elFinderStartHash,
					height : window.innerHeight,
					commandsOptions : {
						edit : {
							extraOptions : {
								creativeCloudApiKey : '',
								managerUrl : ''
							}
						},
						quicklook : {
							sharecadMimes : ['image/vnd.dwg', 'image/vnd.dxf', 'model/vnd.dwf', 'application/vnd.hp-hpgl', 'application/plt', 'application/step', 'model/iges', 'application/vnd.ms-pki.stl', 'application/sat', 'image/cgm', 'application/x-msmetafile'],
							googleDocsMimes : ['application/pdf', 'image/tiff', 'application/vnd.ms-office', 'application/msword', 'application/vnd.ms-word', 'application/vnd.ms-excel', 'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.openxmlformats-officedocument.presentationml.presentation', 'application/postscript', 'application/rtf'],
							officeOnlineMimes : ['application/vnd.ms-office', 'application/msword', 'application/vnd.ms-word', 'application/vnd.ms-excel', 'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.openxmlformats-officedocument.presentationml.presentation', 'application/vnd.oasis.opendocument.text', 'application/vnd.oasis.opendocument.spreadsheet', 'application/vnd.oasis.opendocument.presentation']
						}
					},
					bootCallback : function(fm, extraObj) {
						fm.bind('init', function() {
							fm.resize(window.innerWidth, window.innerHeight);
						});
						window.addEventListener('resize', function() {
							fm.resize(window.innerWidth, window.innerHeight);
						});
						var title = document.title;
						fm.bind('open', function() {
							var path = '', cwd = fm.cwd();
							if (cwd) { path = fm.path(cwd.hash) || null; }
							document.title = (path && path !== '/') ? path + ':' + title : title;
						}).bind('destroy', function() {
							document.title = title;
						});
					}
				},
				managers : { 'elfinder': {} }
			});
		</script>
	</head>
	<body>

		<!-- SecurePIN overlay -->
		<div id="securepin_overlay">
			<div id="securepin_content">
				<p>$label_pin</p>
				<div id="securepin_row">
					<input id="securepin" type="password" placeholder="SecurePIN" autocomplete="off">
					<button id="check_securepin">$btn_ok</button>
				</div>
				<div id="check_hint">&nbsp;</div>
				<div id="securepin_warning">
					<b>$warn_title</b>
					$warn_text
				</div>
			</div>
		</div>

		<!-- Element where elFinder will be created (REQUIRED) -->
		<div id="elfinder"></div>

		<!-- SecurePIN logic -->
		<script>
		(function() {
			var overlay = document.getElementById('securepin_overlay');
			var input   = document.getElementById('securepin');
			var btn     = document.getElementById('check_securepin');
			var hint    = document.getElementById('check_hint');

			function checkPin() {
				var pin = input.value;
				if (!pin) { return; }
				btn.disabled = true;
				hint.style.color = '#3182ce';
				hint.textContent = "@{[js_esc($checking)]}";

				var data = new FormData();
				data.append('secpin', pin);

				fetch('securepin_check.cgi', { method: 'POST', body: data })
					.then(function(r) { return r.json(); })
					.then(function(data) {
						if (data.error && data.error !== 0) {
							hint.style.color = '#e53e3e';
							hint.textContent = "@{[js_esc($wrong_pin)]}";
							btn.disabled = false;
							input.select();
							return;
						}
						sessionStorage.setItem('securePIN', pin);
						overlay.style.display = 'none';
					})
					.catch(function() {
						hint.style.color = '#e53e3e';
						hint.textContent = "@{[js_esc($conn_err)]}";
						btn.disabled = false;
					});
			}

			btn.addEventListener('click', checkPin);
			input.addEventListener('keypress', function(e) {
				if (e.key === 'Enter') { checkPin(); }
			});

			var stored = sessionStorage.getItem('securePIN');
			if (stored) {
				input.value = stored;
				checkPin();
			} else {
				input.focus();
			}
		})();
		</script>

	</body>
</html>
HTML
