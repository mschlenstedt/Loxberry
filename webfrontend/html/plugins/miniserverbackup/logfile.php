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
    $data = nl2br($data);
    $data = stream_get_contents($handle, -1, $_SESSION['offset']);
		$data = str_replace ("<ERROR>","<div id='logrt'>",$data);
		$data = str_replace ("<OK>","<div id='loggn'>",$data);
		$data = str_replace ("<DWL>","<div id='logge'>",$data);
		$data = str_replace ("</ERROR>","</DIV>",$data);
		$data = str_replace ("</OK>","</DIV>",$data);
		$data = str_replace ("</DWL>","</DIV>",$data);
    echo $data;
		 $_SESSION['offset'] = ftell($handle);
  } else {
    fseek($handle, 0, SEEK_END);
    $_SESSION['offset'] = ftell($handle);
  } 
 exit();
} 
