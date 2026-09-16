<?php

declare(strict_types=1);

/**
 * End-to-end tests for the PawPedia REST API.
 *
 * Starts PHP's built-in server against a throwaway SQLite database seeded from
 * the app's own assets/seed/breeds.json, fires real HTTP requests at it, and
 * checks status codes, headers and bodies.
 *
 *   php server/tests/run_tests.php
 *
 * Needs the pdo_sqlite extension (bundled with XAMPP). Exits non-zero on any
 * failure.
 */

const TOKEN = 'test-token-3f9a';

$serverRoot = dirname(__DIR__);
$projectRoot = dirname($serverRoot);
$work = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'pawpedia-api-tests-' . getmypid();
@mkdir($work, 0777, true);

// --- fixture database -------------------------------------------------------

$dbPath = $work . DIRECTORY_SEPARATOR . 'breeds.sqlite';
@unlink($dbPath);
$pdo = new PDO('sqlite:' . $dbPath, null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$pdo->exec('CREATE TABLE breeds (
    id INTEGER PRIMARY KEY,
    breed_name TEXT NOT NULL,
    breed_group TEXT,
    origin_country TEXT,
    average_lifespan TEXT,
    temperament TEXT,
    picture TEXT
)');

$seed = json_decode((string) file_get_contents($projectRoot . '/assets/seed/breeds.json'), true);
// One extra row whose name contains LIKE wildcards, to prove they are escaped.
$seed[] = [
    'id' => 10, 'breed_name' => 'Test 100%_Pup!', 'breed_group' => 'Test Group',
    'origin_country' => 'Nowhere', 'average_lifespan' => '1 year',
    'temperament' => 'Suspicious', 'picture' => '',
];

$insert = $pdo->prepare('INSERT INTO breeds VALUES (:id, :breed_name, :breed_group, :origin_country, :average_lifespan, :temperament, :picture)');
foreach ($seed as $row) {
    $insert->execute($row);
}
$pdo = null;

$configPath = $work . DIRECTORY_SEPARATOR . 'config.php';
file_put_contents($configPath, '<?php return ' . var_export([
    'db' => ['dsn' => 'sqlite:' . $dbPath],
    'table' => 'breeds',
    'api_token' => TOKEN,
    'require_https' => false,
    'cors_origin' => '*',
    'cache_max_age' => 300,
], true) . ';');

// --- start the server -------------------------------------------------------

$port = findFreePort();
$env = array_merge(getenv(), ['PAWPEDIA_CONFIG' => $configPath]);
$process = proc_open(
    [PHP_BINARY, '-S', '127.0.0.1:' . $port, '-t', $serverRoot, $serverRoot . '/tests/dev-router.php'],
    [0 => ['pipe', 'r'], 1 => ['file', $work . '/server.out', 'w'], 2 => ['file', $work . '/server.err', 'w']],
    $pipes,
    $serverRoot,
    $env
);
if (!is_resource($process)) {
    fwrite(STDERR, "Could not start the PHP built-in server.\n");
    exit(1);
}

$base = 'http://127.0.0.1:' . $port;
waitForServer('127.0.0.1', $port);

$passed = 0;
$failures = [];

function check(string $name, bool $condition, string $detail = ''): void
{
    global $passed, $failures;
    if ($condition) {
        $passed++;
        echo "  ok    {$name}\n";
    } else {
        $failures[] = $name;
        echo "  FAIL  {$name}" . ($detail !== '' ? " — {$detail}" : '') . "\n";
    }
}

$auth = ['Authorization: Bearer ' . TOKEN];

try {
    echo "\nAuthentication\n";
    $r = call('GET', '/api/breeds');
    check('missing token is 401', $r['status'] === 401, "got {$r['status']}");
    check('missing token challenges with Bearer realm', strpos((string) $r['h']['www-authenticate'], 'Bearer realm="PawPedia"') === 0);
    check('missing token does not claim invalid_token', strpos((string) $r['h']['www-authenticate'], 'invalid_token') === false);
    check('error body has status/code/message', ($r['json']['error']['code'] ?? null) === 'unauthorized' && ($r['json']['error']['status'] ?? null) === 401);

    $r = call('GET', '/api/breeds', ['Authorization: Bearer wrong']);
    check('wrong token is 401', $r['status'] === 401);
    check('wrong token names invalid_token', strpos((string) $r['h']['www-authenticate'], 'error="invalid_token"') !== false);

    $r = call('GET', '/api/breeds', ['Authorization: Basic dXNlcjpwYXNz']);
    check('non-Bearer scheme is 401', $r['status'] === 401);

    echo "\nCollection: GET /api/breeds\n";
    $r = call('GET', '/api/breeds', $auth);
    check('200 OK', $r['status'] === 200, "got {$r['status']}");
    check('Content-Type is application/json; charset=utf-8', $r['h']['content-type'] === 'application/json; charset=utf-8', (string) $r['h']['content-type']);
    check('body is pure JSON (no prefix)', $r['body'] !== '' && $r['body'][0] === '{' && $r['json'] !== null);
    check('X-Powered-By is not sent', !isset($r['h']['x-powered-by']));
    check('nosniff header present', ($r['h']['x-content-type-options'] ?? '') === 'nosniff');
    check('ETag present', isset($r['h']['etag']));
    check('private cache header', strpos((string) ($r['h']['cache-control'] ?? ''), 'private') === 0);
    check('CORS advertises read methods only', ($r['h']['access-control-allow-methods'] ?? '') === 'GET, HEAD, OPTIONS');
    check('returns all 10 rows', count($r['json']['data'] ?? []) === 10);
    check('meta.total is 10', ($r['json']['meta']['total'] ?? null) === 10);
    check('sorted by name (Beagle first)', ($r['json']['data'][0]['breed_name'] ?? null) === 'Beagle');
    check('id is an integer', is_int($r['json']['data'][0]['id'] ?? null));
    check('empty picture becomes null', findByName($r['json']['data'], 'Test 100%_Pup!')['picture'] === null);
    check('links.next is null on the only page', array_key_exists('next', $r['json']['links']) && $r['json']['links']['next'] === null);

    echo "\nPagination\n";
    $r = call('GET', '/api/breeds?per_page=4', $auth);
    check('per_page=4 returns 4', count($r['json']['data']) === 4);
    check('total_pages is 3', $r['json']['meta']['total_pages'] === 3);
    check('next link', $r['json']['links']['next'] === '/api/breeds?page=2&per_page=4', (string) $r['json']['links']['next']);
    check('prev is null on page 1', $r['json']['links']['prev'] === null);
    $r = call('GET', '/api/breeds?page=3&per_page=4', $auth);
    check('last page has 2 rows', count($r['json']['data']) === 2);
    check('last page has no next', $r['json']['links']['next'] === null);
    check('last page prev', $r['json']['links']['prev'] === '/api/breeds?page=2&per_page=4');
    $r = call('GET', '/api/breeds?page=9&per_page=4', $auth);
    check('page past the end is 200 and empty', $r['status'] === 200 && $r['json']['data'] === []);

    echo "\nFiltering\n";
    $r = call('GET', '/api/breeds?search=golden', $auth);
    check('search=golden finds Golden Retriever', count($r['json']['data']) === 1 && $r['json']['data'][0]['breed_name'] === 'Golden Retriever');
    $r = call('GET', '/api/breeds?search=GOLDEN', $auth);
    check('search is case-insensitive', count($r['json']['data']) === 1);
    foreach (['%', '_', '!'] as $wildcard) {
        $r = call('GET', '/api/breeds?search=' . rawurlencode($wildcard), $auth);
        check("search for literal '{$wildcard}' matches only the row containing it", count($r['json']['data']) === 1, 'got ' . count($r['json']['data']));
    }
    $r = call('GET', '/api/breeds?group=Sporting', $auth);
    check('group=Sporting returns 2', count($r['json']['data']) === 2);
    $r = call('GET', '/api/breeds?group=toy,SPORTING', $auth);
    check('comma list + case-insensitive group returns 4', count($r['json']['data']) === 4);
    $r = call('GET', '/api/breeds?group=Toy&country=France', $auth);
    check('group AND country narrows to Papillon', count($r['json']['data']) === 1 && $r['json']['data'][0]['breed_name'] === 'Papillon');
    $r = call('GET', '/api/breeds?group=Toy&per_page=1', $auth);
    check('links keep the filter', strpos((string) $r['json']['links']['next'], 'group=Toy') !== false, (string) $r['json']['links']['next']);
    $r = call('GET', '/api/breeds?search=zzz-no-such-breed', $auth);
    check('no matches is 200 with empty data', $r['status'] === 200 && $r['json']['data'] === [] && $r['json']['meta']['total'] === 0);

    echo "\nSingle resource: GET /api/breeds/{id}\n";
    $r = call('GET', '/api/breeds/1', $auth);
    check('200 OK', $r['status'] === 200);
    check('returns Golden Retriever', ($r['json']['data']['breed_name'] ?? null) === 'Golden Retriever');
    check('links.self', ($r['json']['links']['self'] ?? null) === '/api/breeds/1');
    $r = call('GET', '/api/breeds/999', $auth);
    check('unknown id is 404 breed_not_found', $r['status'] === 404 && $r['json']['error']['code'] === 'breed_not_found');
    foreach (['abc', '0', '-1', '1.5', '99999999999'] as $bad) {
        $r = call('GET', '/api/breeds/' . $bad, $auth);
        check("id '{$bad}' is 400", $r['status'] === 400, "got {$r['status']}");
    }

    echo "\nValidation\n";
    foreach (['per_page=0', 'per_page=101', 'page=0', 'page=-2', 'page=abc', 'group[]=Toy'] as $query) {
        $r = call('GET', '/api/breeds?' . $query, $auth);
        check("{$query} is 400 invalid_parameter", $r['status'] === 400 && ($r['json']['error']['code'] ?? '') === 'invalid_parameter', "got {$r['status']}");
    }
    $r = call('GET', '/api/breeds?search=' . str_repeat('a', 101), $auth);
    check('over-long search is 400', $r['status'] === 400);

    echo "\nMethods, routing and caching\n";
    foreach (['POST', 'PUT', 'PATCH', 'DELETE'] as $method) {
        $r = call($method, '/api/breeds/1', $auth);
        check("{$method} is 405", $r['status'] === 405, "got {$r['status']}");
        check("{$method} 405 sends Allow", ($r['h']['allow'] ?? '') === 'GET, HEAD, OPTIONS');
    }
    $r = call('OPTIONS', '/api/breeds');
    check('OPTIONS preflight is 204 without a token', $r['status'] === 204);
    check('OPTIONS sends Allow', ($r['h']['allow'] ?? '') === 'GET, HEAD, OPTIONS');
    $r = call('GET', '/api/nothing-here', $auth);
    check('unknown route is 404 route_not_found', $r['status'] === 404 && $r['json']['error']['code'] === 'route_not_found');
    $r = call('GET', '/api/breeds/', $auth);
    check('trailing slash is tolerated', $r['status'] === 200);
    $r = call('HEAD', '/api/breeds', $auth);
    check('HEAD is 200 with no body', $r['status'] === 200 && $r['body'] === '');

    $first = call('GET', '/api/breeds', $auth);
    $etag = (string) $first['h']['etag'];
    $r = call('GET', '/api/breeds', array_merge($auth, ['If-None-Match: ' . $etag]));
    check('matching If-None-Match is 304', $r['status'] === 304, "got {$r['status']}");
    check('304 has no body', $r['body'] === '');
    $r = call('GET', '/api/breeds?group=Toy', array_merge($auth, ['If-None-Match: ' . $etag]));
    check('different representation ignores stale ETag', $r['status'] === 200);

    $r = call('GET', '/api/index.php/breeds/1', $auth);
    check('works without mod_rewrite via /api/index.php/...', $r['status'] === 200);
    check('links follow the form the client used', ($r['json']['links']['self'] ?? '') === '/api/index.php/breeds/1', (string) ($r['json']['links']['self'] ?? ''));
    echo "\nServer configuration failures\n";
    $validConfig = [
        'db' => ['dsn' => 'sqlite:' . $dbPath],
        'table' => 'breeds',
        'api_token' => TOKEN,
    ];

    $r = isolated($work, array_merge($validConfig, ['api_token' => 'change-me']), $auth);
    check('placeholder api_token refuses to serve (500)', $r['status'] === 500 && ($r['json']['error']['code'] ?? '') === 'server_misconfigured', "got {$r['status']}");

    $r = isolated($work, array_merge($validConfig, ['db' => ['dsn' => 'sqlite:' . $work . '/missing-dir/nope/db.sqlite']]), $auth);
    check('unreachable database is 503', $r['status'] === 503 && ($r['json']['error']['code'] ?? '') === 'database_unavailable', "got {$r['status']}");
    check('503 does not leak the driver message', strpos($r['body'], 'SQLSTATE') === false && strpos($r['body'], 'missing-dir') === false);

    $r = isolated($work, array_merge($validConfig, ['table' => 'breeds; DROP TABLE breeds']), $auth);
    check('unsafe table name is rejected (500)', $r['status'] === 500);

    // Reproduces the bug in the old endpoint: text outside <?php in an included
    // file. Here the config file starts with it.
    $r = isolated($work, $validConfig, $auth, '/*  */');
    check('stray output before <?php is discarded', $r['status'] === 200 && $r['body'] !== '' && $r['body'][0] === '{', substr($r['body'], 0, 20));
} finally {
    proc_terminate($process);
    proc_close($process);
    $stderr = @file_get_contents($work . '/server.err');
}

$total = $passed + count($failures);
echo "\n{$passed}/{$total} checks passed.\n";
if ($failures !== []) {
    echo "Failed:\n  - " . implode("\n  - ", $failures) . "\n";
    if (!empty($stderr)) {
        echo "\nServer log:\n" . $stderr . "\n";
    }
    exit(1);
}
exit(0);

// --- helpers ----------------------------------------------------------------

/**
 * @param list<string> $headers
 * @return array{status: int, h: array<string, string>, body: string, json: mixed}
 */
function call(string $method, string $path, array $headers = []): array
{
    global $base;
    $context = stream_context_create(['http' => [
        'method' => $method,
        'header' => implode("\r\n", $headers),
        'ignore_errors' => true,
        'timeout' => 10,
    ]]);

    $body = @file_get_contents($base . $path, false, $context);
    $raw = $http_response_header ?? [];

    $status = 0;
    $parsed = [];
    foreach ($raw as $line) {
        if (preg_match('#^HTTP/\S+\s+(\d{3})#', $line, $m) === 1) {
            $status = (int) $m[1];
            $parsed = [];
        } elseif (strpos($line, ':') !== false) {
            [$name, $value] = explode(':', $line, 2);
            $parsed[strtolower(trim($name))] = trim($value);
        }
    }
    $parsed += ['www-authenticate' => null, 'content-type' => null, 'etag' => null];

    $body = $body === false ? '' : $body;

    return ['status' => $status, 'h' => $parsed, 'body' => $body, 'json' => json_decode($body, true)];
}

/**
 * Runs one request through api/index.php in a separate PHP process with its own
 * config, for failure cases that need a different configuration from the
 * shared test server.
 *
 * @param array<string, mixed> $config
 * @param list<string>         $headers
 * @return array{status: int, body: string, json: mixed}
 */
function isolated(string $work, array $config, array $headers, string $configPrefix = ''): array
{
    static $counter = 0;
    $counter++;

    $configPath = $work . "/isolated-config-{$counter}.php";
    file_put_contents($configPath, $configPrefix . '<?php return ' . var_export($config, true) . ';');

    $server = [
        'REQUEST_METHOD' => 'GET',
        'REQUEST_URI' => '/api/breeds',
        'SCRIPT_NAME' => '/api/index.php',
    ];
    foreach ($headers as $header) {
        [$name, $value] = explode(':', $header, 2);
        $server['HTTP_' . strtoupper(str_replace('-', '_', trim($name)))] = trim($value);
    }

    $driver = $work . "/isolated-driver-{$counter}.php";
    file_put_contents($driver, '<?php
$_SERVER = array_merge($_SERVER, ' . var_export($server, true) . ');
$_GET = [];
register_shutdown_function(static function () { echo "\n__STATUS__" . http_response_code(); });
require ' . var_export(dirname(__DIR__) . '/api/index.php', true) . ';
');

    $process = proc_open(
        [PHP_BINARY, $driver],
        [1 => ['pipe', 'w'], 2 => ['pipe', 'w']],
        $pipes,
        null,
        array_merge(getenv(), ['PAWPEDIA_CONFIG' => $configPath])
    );
    $output = (string) stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    proc_close($process);

    $marker = strrpos($output, "\n__STATUS__");
    $body = $marker === false ? $output : substr($output, 0, $marker);
    $status = $marker === false ? 0 : (int) substr($output, $marker + strlen("\n__STATUS__"));

    return ['status' => $status, 'body' => $body, 'json' => json_decode($body, true)];
}

/**
 * @param list<array<string, mixed>> $rows
 * @return array<string, mixed>
 */
function findByName(array $rows, string $name): array
{
    foreach ($rows as $row) {
        if ($row['breed_name'] === $name) {
            return $row;
        }
    }
    return ['picture' => 'not found'];
}

function findFreePort(): int
{
    $socket = stream_socket_server('tcp://127.0.0.1:0');
    $name = stream_socket_get_name($socket, false);
    fclose($socket);
    return (int) substr((string) $name, strrpos((string) $name, ':') + 1);
}

function waitForServer(string $host, int $port): void
{
    for ($i = 0; $i < 100; $i++) {
        $connection = @fsockopen($host, $port, $errno, $errstr, 0.1);
        if ($connection !== false) {
            fclose($connection);
            return;
        }
        usleep(100000);
    }
    fwrite(STDERR, "The PHP built-in server did not start.\n");
    exit(1);
}
