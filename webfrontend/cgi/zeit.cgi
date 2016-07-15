#!/usr/bin/perl
use strict;
use warnings;
use CGI;

my $serverzeit = time()*1000;
my $timezone = qx(date +"%Z");
chomp($timezone);

print STDOUT CGI->new->header(-charset=>'utf-8').<<HTML_DOC
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
<title>Test Uhrzeit mit JS über Offset</title>
<script>
function uhrzeitanzeige(szeit) {
	var czeit = new Date();
	var offset = czeit.getTime()-szeit;
	var gib_zeit = function(dateobj) {
		var d = dateobj.getDate();
		if (d < 10) { d = '0'+d; }
		var mo = dateobj.getMonth();
		if (mo < 10) { mo = '0'+mo; }
		var y = dateobj.getFullYear();
		var h = dateobj.getHours();
		if (h < 10) { h = '0'+h; }
		var m = dateobj.getMinutes();
		if (m < 10) { m = '0'+m; }
		var s = dateobj.getSeconds();
		if (s < 10) { s = '0'+s; }
		return d+'.'+mo+'.'+y+' um '+h+':'+m+':'+s+' $timezone';
	};
	var zeit_aktualisieren = function(offset) {
		czeit = new Date();
		czeit.setTime(czeit.getTime()+offset);
		document.getElementById('zeit').innerHTML = gib_zeit(czeit);
		window.setTimeout(function () {zeit_aktualisieren(offset);},1000);
	};
	zeit_aktualisieren(offset);
}
</script>
</head>

<body onload="uhrzeitanzeige('$serverzeit');">

<div id="zeit"></div>
</body>

</html>
HTML_DOC
;
