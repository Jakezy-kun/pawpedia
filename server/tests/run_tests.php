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
// Every column NOT NULL, like the live Freehostia table: an INSERT carrying a
// NULL fails there, so the tests must fail the same way.
$pdo->exec('CREATE TABLE breeds (
    id INTEGER PRIMARY KEY,
    breed_name TEXT NOT NULL,
    breed_group TEXT NOT NULL,
    origin_country TEXT NOT NULL,
    average_lifespan TEXT NOT NULL,
    temperament TEXT NOT NULL,
    picture TEXT NOT NULL
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
    check('CORS advertises the CRUD methods', ($r['h']['access-control-allow-methods'] ?? '') === 'GET, HEAD, POST, PUT, DELETE, OPTIONS');
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
    foreach (['POST', 'PATCH'] as $method) {
        $r = call($method, '/api/breeds/1', $auth);
        check("{$method} /breeds/1 is 405", $r['status'] === 405, "got {$r['status']}");
        check("{$method} /breeds/1 405 sends Allow", ($r['h']['allow'] ?? '') === 'GET, HEAD, PUT, DELETE, OPTIONS', (string) ($r['h']['allow'] ?? ''));
    }
    foreach (['PUT', 'PATCH', 'DELETE'] as $method) {
        $r = call($method, '/api/breeds', $auth);
        check("{$method} /breeds is 405", $r['status'] === 405, "got {$r['status']}");
        check("{$method} /breeds 405 sends Allow", ($r['h']['allow'] ?? '') === 'GET, HEAD, POST, OPTIONS', (string) ($r['h']['allow'] ?? ''));
    }
    $r = call('OPTIONS', '/api/breeds');
    check('OPTIONS preflight is 204 without a token', $r['status'] === 204);
    check('OPTIONS sends Allow', ($r['h']['allow'] ?? '') === 'GET, HEAD, POST, OPTIONS');
    check('OPTIONS narrows CORS methods to the route', ($r['h']['access-control-allow-methods'] ?? '') === 'GET, HEAD, POST, OPTIONS');
    $r = call('OPTIONS', '/api/breeds/1');
    check('OPTIONS on an item allows PUT and DELETE', ($r['h']['allow'] ?? '') === 'GET, HEAD, PUT, DELETE, OPTIONS');
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

    echo "\nCreate: POST /api/breeds\n";
    $json = array_merge($auth, ['Content-Type: application/json']);
    $newBreed = [
        'breed_name' => '  Shiba Inu ',
        'breed_group' => 'Non-Sporting',
        'origin_country' => 'Japan',
        'average_lifespan' => '12-15 years',
        'temperament' => 'Alert, Bold, Loyal',
        'picture' => 'https://images.dog.ceo/breeds/shiba/shiba-1.jpg',
    ];

    $r = call('POST', '/api/breeds', ['Content-Type: application/json'], json_encode($newBreed));
    check('POST without a token is 401', $r['status'] === 401, "got {$r['status']}");

    $r = call('POST', '/api/breeds', $json, json_encode($newBreed));
    check('201 Created', $r['status'] === 201, "got {$r['status']} " . $r['body']);
    $newId = (int) ($r['json']['data']['id'] ?? 0);
    check('returns the new integer id', $newId > 10, (string) $newId);
    check('Location points at the new breed', ($r['h']['location'] ?? '') === '/api/breeds/' . $newId, (string) ($r['h']['location'] ?? ''));
    check('values are trimmed', ($r['json']['data']['breed_name'] ?? '') === 'Shiba Inu');
    check('201 is not cacheable', ($r['h']['cache-control'] ?? '') === 'no-store');
    $r = call('GET', '/api/breeds/' . $newId, $auth);
    check('the new breed can be read back', $r['status'] === 200 && $r['json']['data']['origin_country'] === 'Japan');
    $r = call('GET', '/api/breeds', $auth);
    check('the collection now has 11 rows', ($r['json']['meta']['total'] ?? 0) === 11);

    $r = call('POST', '/api/breeds', $json, json_encode(['breed_name' => 'Minimal Mutt']));
    check('only breed_name is required', $r['status'] === 201, "got {$r['status']} " . $r['body']);
    $minimalId = (int) ($r['json']['data']['id'] ?? 0);
    check('omitted fields read back as null', array_key_exists('picture', $r['json']['data'] ?? []) && $r['json']['data']['picture'] === null);

    $r = call('POST', '/api/breeds', $json, json_encode(['breed_name' => 'GOLDEN RETRIEVER']));
    check('duplicate name (any case) is 409 breed_exists', $r['status'] === 409 && ($r['json']['error']['code'] ?? '') === 'breed_exists', "got {$r['status']}");

    $r = call('POST', '/api/breeds', $json, json_encode(['breed_group' => 'Toy']));
    check('missing breed_name is 422 validation_failed', $r['status'] === 422 && ($r['json']['error']['code'] ?? '') === 'validation_failed', "got {$r['status']}");
    check('422 names the field', isset($r['json']['error']['fields']['breed_name']));

    $r = call('POST', '/api/breeds', $json, json_encode(['breed_name' => '   ']));
    check('blank breed_name is 422', $r['status'] === 422);

    $r = call('POST', '/api/breeds', $json, json_encode([
        'breed_name' => str_repeat('a', 121),
        'picture' => 'javascript:alert(1)',
        'breed_group' => 7,
        'colour' => 'red',
    ]));
    check('every bad field is reported at once', $r['status'] === 422
        && array_keys($r['json']['error']['fields'] ?? []) == ['colour', 'breed_name', 'breed_group', 'picture'],
        implode(',', array_keys($r['json']['error']['fields'] ?? [])));

    $r = call('POST', '/api/breeds', $json, '{"breed_name": "Oops",');
    check('malformed JSON is 400 invalid_json', $r['status'] === 400 && ($r['json']['error']['code'] ?? '') === 'invalid_json', "got {$r['status']}");
    $r = call('POST', '/api/breeds', $json, '["Beagle"]');
    check('a JSON list is 400 invalid_json', $r['status'] === 400 && ($r['json']['error']['code'] ?? '') === 'invalid_json');
    $r = call('POST', '/api/breeds', array_merge($auth, ['Content-Type: application/x-www-form-urlencoded']), 'breed_name=Form+Dog');
    check('a non-JSON body is 415', $r['status'] === 415, "got {$r['status']}");
    $r = call('POST', '/api/breeds', $json, json_encode(['breed_name' => str_repeat('a', 20000)]));
    check('an oversized body is 413', $r['status'] === 413, "got {$r['status']}");

    echo "\nUpdate: PUT /api/breeds/{id}\n";
    $changed = array_merge($newBreed, ['breed_name' => 'Shiba', 'average_lifespan' => '13-16 years']);
    $r = call('PUT', '/api/breeds/' . $newId, $json, json_encode($changed));
    check('200 OK', $r['status'] === 200, "got {$r['status']} " . $r['body']);
    check('returns the updated breed', ($r['json']['data']['breed_name'] ?? '') === 'Shiba' && $r['json']['data']['average_lifespan'] === '13-16 years');
    $r = call('GET', '/api/breeds/' . $newId, $auth);
    check('the change is stored', ($r['json']['data']['breed_name'] ?? '') === 'Shiba');

    $r = call('PUT', '/api/breeds/' . $newId, $json, json_encode(array_merge($changed, ['id' => $newId])));
    check('keeping its own name (and echoing id) is allowed', $r['status'] === 200, "got {$r['status']} " . $r['body']);
    $r = call('PUT', '/api/breeds/' . $newId, $json, json_encode(['breed_name' => 'Shiba']));
    check('PUT replaces: omitted fields are cleared', $r['status'] === 200 && $r['json']['data']['origin_country'] === null);
    $r = call('PUT', '/api/breeds/' . $newId, $json, json_encode(['breed_name' => 'beagle']));
    check('renaming onto another breed is 409', $r['status'] === 409, "got {$r['status']}");
    $r = call('PUT', '/api/breeds/' . $newId, $json, json_encode(['breed_name' => '']));
    check('invalid PUT is 422', $r['status'] === 422, "got {$r['status']}");
    $r = call('PUT', '/api/breeds/999', $json, json_encode(['breed_name' => 'Ghost']));
    check('PUT to an unknown id is 404', $r['status'] === 404 && ($r['json']['error']['code'] ?? '') === 'breed_not_found', "got {$r['status']}");
    $r = call('PUT', '/api/breeds/abc', $json, json_encode(['breed_name' => 'Ghost']));
    check('PUT to a non-integer id is 400', $r['status'] === 400, "got {$r['status']}");
    $r = call('PUT', '/api/breeds/' . $newId, ['Content-Type: application/json'], json_encode($changed));
    check('PUT without a token is 401', $r['status'] === 401, "got {$r['status']}");
    $r = call('POST', '/api/breeds/' . $newId, array_merge($json, ['X-HTTP-Method-Override: PUT']), json_encode($newBreed));
    check('POST + X-HTTP-Method-Override: PUT updates', $r['status'] === 200 && ($r['json']['data']['breed_name'] ?? '') === 'Shiba Inu', "got {$r['status']}");
    $r = call('GET', '/api/breeds/' . $newId, array_merge($auth, ['X-HTTP-Method-Override: DELETE']));
    check('GET cannot be overridden into a write', $r['status'] === 200);

    echo "\nDelete: DELETE /api/breeds/{id}\n";
    $r = call('DELETE', '/api/breeds/' . $newId);
    check('DELETE without a token is 401', $r['status'] === 401, "got {$r['status']}");
    $r = call('DELETE', '/api/breeds/' . $newId, $auth);
    check('204 No Content', $r['status'] === 204, "got {$r['status']}");
    check('204 has no body', $r['body'] === '');
    $r = call('GET', '/api/breeds/' . $newId, $auth);
    check('the deleted breed is gone (404)', $r['status'] === 404);
    $r = call('DELETE', '/api/breeds/' . $newId, $auth);
    check('deleting it again is 404', $r['status'] === 404);
    $r = call('POST', '/api/breeds/' . $minimalId, array_merge($auth, ['X-HTTP-Method-Override: DELETE']));
    check('POST + X-HTTP-Method-Override: DELETE deletes', $r['status'] === 204, "got {$r['status']}");
    $r = call('GET', '/api/breeds', $auth);
    check('the collection is back to 10 rows', ($r['json']['meta']['total'] ?? 0) === 10);

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

    // The most likely setup mistake: 'table' in config.php naming a table that
    // is not there.
    $r = isolated($work, array_merge($validConfig, ['table' => 'dog_breeds']), $auth);
    check('wrong table name is 500 server_misconfigured', $r['status'] === 500 && ($r['json']['error']['code'] ?? '') === 'server_misconfigured', "got {$r['status']} " . ($r['json']['error']['code'] ?? ''));
    check('wrong table name leaks no SQL detail', strpos($r['body'], 'dog_breeds') === false && strpos($r['body'], 'SQLSTATE') === false);

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
function call(string $method, string $path, array $headers = [], ?string $body = null): array
{
    global $base;
    $options = [
        'method' => $method,
        'header' => implode("\r\n", $headers),
        'ignore_errors' => true,
        'timeout' => 10,
    ];
    if ($body !== null) {
        $options['content'] = $body;
    }
    $context = stream_context_create(['http' => $options]);

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
