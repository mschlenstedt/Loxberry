<?php
header("Expires; 0");
header("Expires: Tue, 01 Jan 1980 1:00:00 GMT");
header("Cache-Control: no-cache, must-revalidate, post-check=0, pre-check=0");   
header("Cache-Control: max-age=0");
header("Pragma: no-cache");
require_once "loxberry_system.php";
$ini = parse_ini_file(LBSCONFIGDIR . "/general.cfg",TRUE,INI_SCANNER_RAW);
if ( lbfriendlyname() === "") {
	$lbname = lbhostname();
} else {
	$lbname = lbfriendlyname() . " (" . lbhostname() . ")";
}
?>
<?xml version="1.0" encoding="utf-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:HVAC_System:1</deviceType>
    <friendlyName><?php echo $lbname; ?></friendlyName>
    <manufacturer>M.Schlenstedt</manufacturer>
    <manufacturerURL>http://www.loxwiki.eu/</manufacturerURL>
    <modelDescription>Loxberry</modelDescription>
    <modelName>Loxberry</modelName>
    <modelNumber><?php echo $ini['BASE']['VERSION']; ?></modelNumber>
    <modelURL>http://www.loxwiki.eu</modelURL>
    <UDN>uuid:<?php echo $ini['SSDP']['UUID']; ?></UDN>
    <iconList>
      <icon>
        <mimetype>image/png</mimetype>
        <width>16</width>
        <height>16</height>
        <depth>24</depth>
        <url>/system/images/LB03-Icon16.png</url>
      </icon>
      <icon>
        <mimetype>image/png</mimetype>
        <width>32</width>
        <height>32</height>
        <depth>24</depth>
        <url>/system/images/LB03-Icon32.png</url>
      </icon>
      <icon>
        <mimetype>image/png</mimetype>
        <width>48</width>
        <height>48</height>
        <depth>24</depth>
        <url>/system/images/LB03-Icon48.png</url>
      </icon>
      <icon>
        <mimetype>image/png</mimetype>
        <width>64</width>
        <height>64</height>
        <depth>24</depth>
        <url>/system/images/LB03-Icon64.png</url>
      </icon>
      <icon>
        <mimetype>image/png</mimetype>
        <width>256</width>
        <height>256</height>
        <depth>24</depth>
        <url>/system/images/LB03-Icon256.png</url>
      </icon>
    </iconList>
    <presentationURL>http://<?php echo LBSystem::get_localip(); if (lbwebserverport() != 80) { echo ":".lbwebserverport(); } ?>/</presentationURL>
  </device>
</root>
