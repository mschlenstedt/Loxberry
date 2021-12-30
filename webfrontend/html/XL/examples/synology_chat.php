<?php
// #!/usr/bin/env php
require_once "loxberry_XL.php";

$ch = curl_init();

$post = 'payload=' . curl_escape($ch, json_encode( array( "text" => $_GET['text'] ) ) );

curl_setopt($ch, CURLOPT_URL, 'https://DS_IP/webapi/entry.cgi?api=SYNO.Chat.External&XXXXX');
curl_setopt($ch, CURLOPT_POSTFIELDS, $post );
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
curl_setopt($ch, CURLOPT_POST, 1);

$result = curl_exec($ch);
if (curl_errno($ch)) {
    echo 'Error:' . curl_error($ch);
}
curl_close($ch);
