<?php
$new_url = '/admin/system/tools/filemanager/index.html';
if (!empty($_GET['p'])) {
    $p = $_GET['p'];
    // Translate old path format: system/storage/... → media/...
    if (strpos($p, 'system/storage/') === 0) {
        $p = 'media/' . substr($p, strlen('system/storage/'));
    }
    $new_url .= '?p=' . $p;
}
header('Location: ' . $new_url, true, 301);
exit;
