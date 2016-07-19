<?php
#####################################################################################################
# Loxberry Plugin zum Wandeln der HTTP-Authentifizierung einer Trendnet TV-IP310PI Kamera von       
# Digest auf Basic für die Verwendung in Verbindung mit dem Loxone Türsteuerungs-Baustein.          
# Version: 18.07.2016 16:44:25                                                                      
# Aufruf mit:                                                                                       
# http://loxberry/plugins/cam-connect/?kamera=kamera-vorgarten/Streaming/channels/1/picture&user=Loxberry&pass=loxberry 
#####################################################################################################

//Error Reporting aus
error_reporting(E_ALL);

//Kompletter Standbild-URL der Kamera
$url='http://'.addslashes($_GET['kamera']); 
$user='http://'.addslashes($_GET['user']); 
$pass='http://'.addslashes($_GET['pass']); 
sleep(1);
$curl=curl_init();
curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
curl_setopt($curl, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST);
curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "GET");
curl_setopt($curl, CURLOPT_USERPWD, $_GET['user'].":".$_GET['pass']);
curl_setopt($curl, CURLOPT_URL, $url);
$picture = curl_exec($curl);
curl_close($curl);
if(mb_strlen($picture) < 500) 
{
  //Wenn Bild zu klein
  header ("Content-type: image/png");
  $im = @ImageCreate (320, 240)
        or die ("Fehler bei Kamerazugriff");
  $background_color = ImageColorAllocate ($im, 255, 240, 240);
  $text_color = ImageColorAllocate ($im, 255, 64, 64);
  ImageString ($im, 20, 50, 110, "Fehler beim Kamerazugriff", $text_color);
  ImagePNG ($im);
}
else 
{
  //Wenn Bild scheinbar okay
  $type = 'image/jpeg';
  header('Content-Type:'.$type);
  //header('Content-Length: ' . mb_strlen($picture));
  echo $picture;
}
