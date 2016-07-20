<?php
#####################################################################################################
# Loxberry Plugin to change the HTTP-Authentication of a Trendnet TV-IP310PI Surveillance IP-Cam
# from Digest to Basic to be used in the Loxone Door-Control-Object.          
# Version: 20.07.2016 07:47:37
# Call via:                                                                                       
# http://loxberry/plugins/cam-connect/?kamera=Kamera-Hostname:80/Streaming/channels/1/picture&user=Benutzername&pass=Passwort 
#####################################################################################################

// Error Reporting off
error_reporting(E_ALL);

// Read LoxBerry configuration file to get the used language
$config_file = "../../../../config/system/general.cfg";
$cfg         = parse_ini_file($config_file, TRUE);
$lang        = $cfg["BASE"]["LANG"];
// $lang="en";  // To override the Loxberry Base-Language uncomment this line.

// Read Plugin configuration file to get the strings for the right language
$phrase_file = "../../../../templates/plugins/cam-connect/$lang/language.dat";
$phrases     = parse_ini_file($phrase_file);
$error_msg   = $phrases["TXT0001"];
(strlen($error_msg) > 0)?$error_msg=$error_msg:$error_msg="Plugin-Error: Errortext N/A";   

// Read IP-CAM connection details from URL 
$url  = 'http://'.addslashes($_GET['kamera']); 
$user = 'http://'.addslashes($_GET['user']); 
$pass = 'http://'.addslashes($_GET['pass']); 

// Wait a second to be sure the image is available.
sleep(1);

// Init and config cURL
$curl = curl_init();
curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
curl_setopt($curl, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST);
curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "GET");
curl_setopt($curl, CURLOPT_USERPWD, $_GET['user'].":".$_GET['pass']);
curl_setopt($curl, CURLOPT_URL, $url);

// Read picture from IP-Cam and close connection to Cam
$picture = curl_exec($curl);
curl_close($curl);

// If the result has less than 500 byte, it's no picture.
if(mb_strlen($picture) < 500) 
{
  // Display an Error-Picture instead.
  header ("Content-type: image/png");
  $image = @ImageCreate (320, 240) or die ($error_msg);
  $background_color = ImageColorAllocate ($image, 255, 240, 240);
  $text_color = ImageColorAllocate ($image, 255, 64, 64);
  ImageString ($image, 20, 50, 110, $error_msg, $text_color);
  ImagePNG ($image);
  ImageDestroy($image);
}
else 
{
  // Seems to be ok - Display the received picture.
  list($width, $height, $type, $attr) = getimagesizefromstring($picture);
  header('Content-Type: '.$type);
  header('Content-length: '.strlen($picture));
  header('Content-Disposition: inline; filename="snapshot.jpg"');
  echo $picture;
}