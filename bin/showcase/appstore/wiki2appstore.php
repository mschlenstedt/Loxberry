<?php
/**
 * wiki2appstore.php — Liest die DokuWiki-struct.sqlite3 und pusht das
 * daraus erzeugte plugins.json via GitHub Contents API in das LoxBerry-Repo.
 *
 * Verwendung (manuell):
 *   php wiki2appstore.php
 *
 * Cron (stündlich):
 *   0 * * * * php /opt/loxberry_wiki/scripts/wiki2appstore.php >> /var/log/wiki2appstore.log 2>&1
 *
 * Konfiguration: Datei config.php im selben Verzeichnis (wird nicht im Repo gespeichert):
 *   <?php
 *   define('CFG_DB_PATH',      '/path/to/struct.sqlite3');
 *   define('CFG_GITHUB_TOKEN', 'github_pat_...');
 *
 * GitHub-Token: Fine-Grained PAT (https://github.com/settings/tokens?type=beta)
 *   Repository: mschlenstedt/Loxberry — Contents: Read & Write
 *   Alle anderen Berechtigungen: None
 */

declare(strict_types=1);

// ---------------------------------------------------------------------------
// Konfiguration
// ---------------------------------------------------------------------------

$config_file = __DIR__ . '/config.php';
if (file_exists($config_file)) {
    require $config_file;
}

define('GITHUB_OWNER',  'mschlenstedt');
define('GITHUB_REPO',   'Loxberry');
define('GITHUB_FILE',   'data/system/appstore/plugins.json');
define('GITHUB_BRANCH', 'master');
define('WIKI_MEDIA',    'https://wiki.loxberry.de/lib/exe/fetch.php?media=');
define('WIKI_PAGE',     'https://wiki.loxberry.de/');

// Pfad zur SQLite-Datenbank: config.php > Umgebungsvariable > Fallback
if (!defined('CFG_DB_PATH')) {
    define('CFG_DB_PATH', getenv('WIKI_DB_PATH') ?: '/opt/loxberry_wiki/data/struct.sqlite3');
}

// GitHub-Token: config.php > Umgebungsvariable
if (!defined('CFG_GITHUB_TOKEN')) {
    $env_token = getenv('GITHUB_TOKEN');
    if (!$env_token) {
        fatal('Kein GitHub-Token. config.php anlegen oder GITHUB_TOKEN setzen.');
    }
    define('CFG_GITHUB_TOKEN', $env_token);
}

// ---------------------------------------------------------------------------
// Hilfsfunktionen
// ---------------------------------------------------------------------------

function fatal(string $msg): never
{
    fwrite(STDERR, date('[Y-m-d H:i:s] ') . "FEHLER: $msg\n");
    exit(1);
}

function log_info(string $msg): void
{
    echo date('[Y-m-d H:i:s] ') . $msg . "\n";
}

/** DokuWiki-Mediareferenz ":plugins:ns:img.png" -> vollständige Fetch-URL */
function logo_url(string $col2): string
{
    $c = ltrim(trim($col2), ':');
    return $c !== '' ? WIKI_MEDIA . $c : '';
}

/** DokuWiki-PID "plugins:foo:start" -> Wiki-Seiten-URL */
function wiki_url(string $pid): string
{
    $p = ltrim(trim($pid), ':');
    return $p !== '' ? WIKI_PAGE . str_replace(':', '/', $p) : '';
}

/** Whitespace und Windows-Zeilenenden bereinigen */
function clean(?string $s): string
{
    return trim(str_replace(["\r\n", "\r", "\n"], ' ', $s ?? ''));
}

// ---------------------------------------------------------------------------
// Plugin-Katalog aus SQLite aufbauen
// ---------------------------------------------------------------------------

function build_catalog(PDO $db): array
{
    // col4  = min_lb_version (historisch auch Versions-Feld in älteren Einträgen)
    // col11 = version (ab Schema 14 eigenständiges Feld; bevorzugt wenn nicht leer)
    // d.rev = Unix-Timestamp der letzten Wiki-Bearbeitung -> updated_ts + Fallback-Datum
    $sql = "
        SELECT
            d.pid,
            t.title,
            d.col1  AS author,
            d.col2  AS logo,
            d.col3  AS status,
            d.col4  AS min_lb_version,
            CASE WHEN TRIM(COALESCE(d.col11,'')) != ''
                 THEN TRIM(d.col11)
                 ELSE TRIM(COALESCE(d.col4,''))
            END     AS version,
            d.col5  AS url_release,
            d.col7  AS description,
            d.col8  AS languages,
            d.col9  AS forum,
            d.col10 AS lastmodified,
            d.rev
        FROM data_pluginuebersicht d
        LEFT JOIN titles t ON t.pid = d.pid
        WHERE d.latest = 1
          AND d.pid LIKE 'plugins:%:start'
          AND TRIM(COALESCE(d.col4,'')) != ''
          AND d.rev = (
              SELECT MAX(d2.rev)
              FROM data_pluginuebersicht d2
              WHERE d2.pid = d.pid AND d2.latest = 1
          )
        GROUP BY d.pid
        ORDER BY LOWER(TRIM(COALESCE(t.title, d.pid)))
    ";

    $stmt = $db->query($sql);
    if ($stmt === false) {
        fatal('SQL-Fehler: ' . implode(' ', $db->errorInfo()));
    }

    $plugins = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $url_release = clean($row['url_release']);
        $is_zip      = str_ends_with(strtolower($url_release), '.zip');
        $updated_ts  = (int)($row['rev'] ?? 0);

        // lastmodified: Aus Wiki-Feld, sonst aus rev ableiten
        $modtext = clean($row['lastmodified']);
        if ($modtext === '' && $updated_ts > 0) {
            $modtext = gmdate('Y-m-d', $updated_ts);
        }

        $plugins[] = [
            'pid'         => $row['pid'],
            'title'       => clean($row['title']) ?: $row['pid'],
            'author'      => clean($row['author']),
            'logo'        => logo_url($row['logo']),
            'status'      => strtoupper(clean($row['status'])),
            'version'     => clean($row['version']),
            'zip'         => $is_zip ? $url_release : '',
            'repo'        => $is_zip ? '' : $url_release,
            'description' => clean($row['description']),
            'languages'   => clean($row['languages']),
            'forum'       => clean($row['forum']),
            'wiki'        => wiki_url($row['pid']),
            'lastmodified'=> $modtext,
            'updated_ts'  => $updated_ts,
        ];
    }

    return [
        'generated' => gmdate('Y-m-d\TH:i:s\Z'),
        'source'    => 'loxberry-wiki/struct',
        'plugins'   => $plugins,
    ];
}

// ---------------------------------------------------------------------------
// GitHub Contents API
// ---------------------------------------------------------------------------

/** GitHub-API-Anfrage via cURL. Gibt dekodiertes JSON-Array zurück. */
function github_api(string $method, string $path, ?array $body, string $token): array
{
    $url = 'https://api.github.com' . $path;
    $ch  = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_HTTPHEADER     => [
            'Authorization: Bearer ' . $token,
            'Accept: application/vnd.github+json',
            'X-GitHub-Api-Version: 2022-11-28',
            'User-Agent: loxberry-wiki2appstore/1.0',
            'Content-Type: application/json',
        ],
        CURLOPT_TIMEOUT        => 30,
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    }
    $response  = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curl_err  = curl_error($ch);
    curl_close($ch);

    if ($curl_err) {
        fatal("cURL-Fehler bei $method $url: $curl_err");
    }
    $data = json_decode($response, true);
    if (!is_array($data)) {
        fatal("Ungültige GitHub-API-Antwort (HTTP $http_code): $response");
    }
    return ['code' => $http_code, 'data' => $data];
}

/** Aktuellen SHA und Inhalt der Zieldatei lesen (für Update notwendig). */
function get_file_sha(string $token): string
{
    $path   = '/repos/' . GITHUB_OWNER . '/' . GITHUB_REPO . '/contents/' . GITHUB_FILE
            . '?ref=' . GITHUB_BRANCH;
    $result = github_api('GET', $path, null, $token);

    if ($result['code'] === 404) {
        // Datei existiert noch nicht — erster Upload ohne SHA
        return '';
    }
    if ($result['code'] !== 200) {
        fatal('GitHub GET fehlgeschlagen (HTTP ' . $result['code'] . '): '
              . ($result['data']['message'] ?? 'unbekannter Fehler'));
    }
    return $result['data']['sha'] ?? '';
}

/** JSON-Inhalt via GitHub Contents API hochladen/aktualisieren. */
function push_to_github(string $json_content, string $token): void
{
    log_info('SHA der aktuellen Datei abrufen…');
    $sha = get_file_sha($token);

    $body = [
        'message' => 'chore(appstore): update plugin catalog from wiki [bot]',
        'content' => base64_encode($json_content),
        'branch'  => GITHUB_BRANCH,
    ];
    if ($sha !== '') {
        $body['sha'] = $sha;
    }

    $api_path = '/repos/' . GITHUB_OWNER . '/' . GITHUB_REPO . '/contents/' . GITHUB_FILE;
    log_info('Datei nach GitHub pushen…');
    $result = github_api('PUT', $api_path, $body, $token);

    if (!in_array($result['code'], [200, 201])) {
        fatal('GitHub PUT fehlgeschlagen (HTTP ' . $result['code'] . '): '
              . ($result['data']['message'] ?? 'unbekannter Fehler'));
    }
    $commit_url = $result['data']['commit']['html_url'] ?? '(kein URL)';
    log_info("Erfolgreich. Commit: $commit_url");
}

// ---------------------------------------------------------------------------
// Hauptprogramm
// ---------------------------------------------------------------------------

// --dry-run [datei]  Kein GitHub-Upload; Ausgabe in Datei oder stdout
$dry_run    = false;
$dry_output = null;
for ($i = 1; $i < $argc; $i++) {
    if ($argv[$i] === '--dry-run') {
        $dry_run    = true;
        $dry_output = $argv[$i + 1] ?? null;
    }
}

log_info('wiki2appstore gestartet' . ($dry_run ? ' (dry-run)' : ''));

if (!file_exists(CFG_DB_PATH)) {
    fatal('Datenbank nicht gefunden: ' . CFG_DB_PATH);
}

log_info('Datenbank öffnen: ' . CFG_DB_PATH);
try {
    $db = new PDO('sqlite:' . CFG_DB_PATH, options: [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} catch (PDOException $e) {
    fatal('SQLite-Fehler: ' . $e->getMessage());
}

log_info('Plugin-Katalog aufbauen…');
$catalog = build_catalog($db);
$count   = count($catalog['plugins']);
log_info("$count Plugins gefunden.");

if ($count === 0) {
    fatal('Keine Plugins gefunden — Upload abgebrochen.');
}

$json = json_encode($catalog, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n";

if ($dry_run) {
    if ($dry_output) {
        file_put_contents($dry_output, $json) !== false
            or fatal("Kann nicht schreiben: $dry_output");
        log_info("Dry-run: JSON geschrieben nach $dry_output");
    } else {
        echo $json;
    }
    log_info('Dry-run abgeschlossen. Kein GitHub-Upload.');
    exit(0);
}

push_to_github($json, CFG_GITHUB_TOKEN);

log_info('Fertig.');
exit(0);
