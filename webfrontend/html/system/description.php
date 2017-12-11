<?php
require_once "loxberry_system.php";
$ini = parse_ini_file(LBSCONFIGDIR . "/general.cfg",TRUE);
?>
<?xml version="1.0" encoding="utf-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:HVAC_System:1</deviceType>
    <friendlyName><?php echo lbfriendlyname() . " (" . lbhostname() . ")"; ?></friendlyName>
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
    <presentationURL>http://<?php echo LoxBerry\System\get_localip();?>/</presentationURL>
  </device>
</root>
