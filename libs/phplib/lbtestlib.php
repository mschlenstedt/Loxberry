<html>
<body>
<br>
This is a test library of LoxBerry.<br>
If you could include this file with<br>
require_once('lbtestlib.php');<br>
(without specifying any path), the library<br>
was included successfully.<br>
<br>
Here are some of LoxBerry's global environment variables, requested by getenv()<br>
(All variables should show pathes)<br>
<?php
echo "<br>LBHOMEDIR: " . getenv('LBHOMEDIR');
echo "<br>LBPCGI: " . getenv('LBPCGI');
echo "<br>LBPHTML: " . getenv('LBPHTML');
echo "<br>LBPTEMPL: " . getenv('LBPTEMPL');
echo "<br>LBPDATA: " . getenv('LBPDATA');	
echo "<br>LBPLOG: " . getenv('LBPLOG');
echo "<br>LBPCONFIG: " . getenv('LBPCONFIG');
?>
<br>
<br>
See LoxBerry Wiki <a href="http://www.loxwiki.eu:80/x/qgFmAQ">http://www.loxwiki.eu:80/x/qgFmAQ</a>.
<body>
</html>