<?php

require_once "loxberry_web.php";
require_once "loxberry_storage.php";

$template_title = "Top Plugin";
$helplink = "http://www.loxwiki.eu:80/x/2wzL";
$helptemplate = "help.html";

LBWeb::lbheader($template_title, $helplink, $helptemplate);

?>
<p>This is the get_storage_html test for php</p>

<?php

$params = array(
    "formid" => "mystorage",
    "currentpath" => "/opt/loxberry",
    "readwriteonly" => 1,
    "label" => "Please enter the destination",
);

echo get_storage_html($params);


LBWeb::lbfooter();
?>
