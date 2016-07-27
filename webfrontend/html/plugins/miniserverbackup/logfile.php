<?php
if (isset($_GET['new_session'])) 
{
	if (isset($_SESSION['offset']))
	{ 
		unset ($_SESSION['offset']);
		echo("OK");
	  exit;
	}
	else
	{
		die("Failed");
	}
}
if (isset($_GET['ajax'])) 
{
  session_start();
  $handle = fopen('../../../../log/plugins/miniserverbackup/backuplog.log', 'r');
  if (isset($_SESSION['offset'])) {
    $data = stream_get_contents($handle, -1, $_SESSION['offset']);
		$data = str_replace ("<ERROR>","<div id='logrt'>",$data);
		$data = str_replace ("<OK>","<div id='loggn'>",$data);
		$data = str_replace ("<MS#>","<div id='logms'>",$data);
		$data = str_replace ("</ERROR>\n","</DIV>",$data);
		$data = str_replace ("</OK>\n","</DIV>",$data);
		$data = str_replace ("</MS#>\n","</DIV>",$data);
    $search  = array('ERRORCODE', 'ERRORS', 'ERROR', 'FAILED', 'REFUSED');
    $replace = array('<FONT color=red><b>ERRORCODE</b></FONT>', '<FONT color=red><b>ERRORS</b></FONT>', '<FONT color=red><b>ERROR</b></FONT>', '<FONT color=red><b>FAILED</b></FONT>','<FONT color=red><b>REFUSED</b></FONT>');
    $data = str_ireplace($search, $replace, $data);
    $data = nl2br($data);
    echo $data;
		 $_SESSION['offset'] = ftell($handle);
  } else {
    fseek($handle, 0, SEEK_END);
    $_SESSION['offset'] = ftell($handle);
  } 
 exit();
} 
