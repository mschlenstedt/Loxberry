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

$plugin_config_file = "../../../../config/plugins/cam-connect/cam-connect.cfg";
$plugin_cfg         = parse_ini_file($plugin_config_file, FALSE);
$watermark          = $plugin_cfg["WATERMARK"];

// Read Plugin configuration file to get the strings for the right language
$phrase_file = "../../../../templates/plugins/cam-connect/$lang/language.dat";
$phrases     = parse_ini_file($phrase_file);

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
$picture = curl_exec($curl);curl_close($curl);

// If the result has less than 500 byte, it's no picture.
if(mb_strlen($picture) < 500) 
{
	// Image too small, raise error 0001
  error_image($phrases,"TXT0001");
}
else 
{
  // Seems to be ok - Display the picture
  header('Content-type: image/jpeg');
  header('Content-Disposition: inline; filename="snapshot.jpeg"');
  if ($watermark == 1) 
  {
  	// Create Cam Image Object
		$watermarked_picture = imagecreatefromstring($picture);
		list($ix, $iy, $type, $attr) = getimagesizefromstring($picture);
		if ($type <> 2) error_image($phrases,"TXT0002");
		
		// Create Watermark Image
		$stamp = imagecreatefrompng("../../../../webfrontend/html/plugins/cam-connect/watermark.png");
		$sx    = imagesx($stamp);
		$sy    = imagesy($stamp);
		
		// Wanted Logo Size
		$logo_width  = 120;
		$logo_height = 86;
		
		// Borders for Watermark
		$margin_right  = $ix - $logo_width - 20;
		$margin_bottom = 20;
		
		// Mix the images together
		ImageCopyResized($watermarked_picture, $stamp, $ix - $logo_width - $margin_right, $iy - $logo_height - $margin_bottom, 0, 0, $logo_width, $logo_height, $sx, $sy);
    ImageJPEG   ($watermarked_picture);
		ImageDestroy($stamp);
		ImageDestroy($watermarked_picture);
  }
  else
  {
    echo $picture;
  }
  exit;
}

function error_image ($phrases,$error_code) 
{
  // Read error string
  $error_msg   = $phrases[$error_code];
  (strlen($error_msg) > 0)?$error_msg=$error_msg:$error_msg="Plugin-Error: [$error_code]";   

  // Display an Error-Picture
  header ("Content-type: image/jpeg");
  $error_image = @ImageCreate (320, 240) or die ($error_msg);
  $background_color = ImageColorAllocate ($error_image, 255, 240, 240);
  $text_color = ImageColorAllocate ($error_image, 255, 64, 64);
  ImageString ($error_image, 20, 50, 110, $error_msg, $text_color);
  ImageJPEG ($error_image);
  ImageDestroy($error_image);
  exit;
}

