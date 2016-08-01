<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/transitional.dtd">
<HTML lang="de">
 <HEAD>
  <META http-equiv="Content-Type" content="text/html; charset=utf-8">
  <META name="robots"             content="noindex,nofollow">
  <TITLE>LoxBerry  - Error :-(</TITLE>
  <LINK rel="shortcut icon"              href="/system/images/favicon.ico">
 </HEAD>
 <BODY bgColor="#FAF8FB" leftmargin="5px" topMargin="0px" marginheight="0px" marginwidth="5px">
 <center>
  <font face="Verdana, Arial, sans-serif" font-size="14px" color="#FF5A00">
  <br>
  <img src="/system/images/apache_error.png">
   <br>
	  <b><big>Fehler <?php echo $_SERVER["REDIRECT_STATUS"] ?>
	  <br><br></big></b>
     <?php
			switch($_SERVER["REDIRECT_STATUS"])
        {
     			case ("400"):
           {
							echo "Bad Request";
              break;
           }
    			case ("401"):
           {
							echo "Anmeldung erforderlich.";
              break;
           }
    			case ("402"):
           {
							echo "Payment Required";
              break;
           }
    			case ("403"):
           {
							echo "Zugriff verweigert.";
              break;
           }
    			case ("404"):
           {
							echo "Die Adresse ".$_SERVER["REDIRECT_URL"]." gibt es hier leider nicht.";
              break;
           }
    			case ("405"):
           {
							echo "Method Not Allowed";
              break;
           }
    			case ("406"):
           {
							echo "Not Acceptable";
              break;
           }
    			case ("407"):
           {
							echo "Proxy Authentication Required";
              break;
           }
    			case ("408"):
           {
							echo "Request Timeout";
              break;
           }
    			case ("409"):
           {
							echo "Conflict";
              break;
           }
    			case ("410"):
           {
							echo "Gone";
              break;
           }
    			case ("411"):
           {
							echo "Length Required";
              break;
           }
    			case ("412"):
           {
							echo "Precondition Failed";
              break;
           }
    			case ("413"):
           {
							echo "Request Entity Too Large";
              break;
           }
    			case ("414"):
           {
							echo "Request-URI Too Long";
              break;
           }
    			case ("415"):
           {
							echo "Unsupported Media Type";
              break;
           }
    			case ("416"):
           {
							echo "Requested Range Not Satisfiable";
              break;
           }
    			case ("417"):
           {
							echo "Expectation Failed";
              break;
           }
  				case ("500"):
           {
							echo "Internal Server Error";
              break;
           }
  				case ("501"):
           {
							echo "Not Implemented";
              break;
           }
  				case ("502"):
           {
							echo "Bad Gateway";
              break;
           }
  				case ("503"):
           {
							echo "Service Unavailable";
              break;
           }
  				case ("504"):
           {
							echo "Gateway Timeout";
              break;
           }
  				case ("505"):
           {
							echo "HTTP Version Not Supported";
              break;
           }
			  }
		 ?>
         <br><br><br>
         <a href="javascript:window.history.back();">Zurück</a>
	 </font>
	</center>
 </BODY>
</HTML>
