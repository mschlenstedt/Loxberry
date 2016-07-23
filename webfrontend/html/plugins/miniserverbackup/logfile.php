<?php
if (isset($_GET['ajax'])) 
{
  session_start();
  $handle = fopen('../../../../log/plugins/miniserverbackup/backuplog.log', 'r');
  if (isset($_SESSION['offset'])) {
    $data = stream_get_contents($handle, -1, $_SESSION['offset']);
		echo nl2br($data);
  $_SESSION['offset'] = ftell($handle);
  } else {
    fseek($handle, 0, SEEK_END);
    $_SESSION['offset'] = ftell($handle);
  } 
 exit();
} 
