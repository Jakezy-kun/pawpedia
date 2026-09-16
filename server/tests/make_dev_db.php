<?php

declare(strict_types=1);

/**
 * Creates a local SQLite copy of the breed catalogue and a matching config, so
 * the API can run on your machine without MySQL:
 *
 *   php server/tests/make_dev_db.php
 *   set PAWPEDIA_CONFIG=<path printed below>          (cmd)
 *   $env:PAWPEDIA_CONFIG="<path printed below>"       (PowerShell)
 *   php -S 127.0.0.1:8080 -t server server/tests/dev-router.php
 *
 * Then call http://127.0.0.1:8080/api/breeds with
 *   Authorization: Bearer dev-token
 */

$serverRoot = dirname(__DIR__);
$outDir = $argv[1] ?? ($serverRoot . DIRECTORY_SEPARATOR . 'database' . DIRECTORY_SEPARATOR . 'dev');
$token = $argv[2] ?? 'dev-token';

if (!is_dir($outDir) && !mkdir($outDir, 0777, true)) {
    fwrite(STDERR, "Could not create {$outDir}\n");
    exit(1);
}

$dbPath = $outDir . DIRECTORY_SEPARATOR . 'breeds.sqlite';
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

$seed = json_decode((string) file_get_contents(dirname($serverRoot) . '/assets/seed/breeds.json'), true);
$insert = $pdo->prepare('INSERT INTO breeds VALUES (:id, :breed_name, :breed_group, :origin_country, :average_lifespan, :temperament, :picture)');
foreach ($seed as $row) {
    $insert->execute($row);
}

$configPath = $outDir . DIRECTORY_SEPARATOR . 'config.php';
file_put_contents($configPath, '<?php return ' . var_export([
    'db' => ['dsn' => 'sqlite:' . $dbPath],
    'table' => 'breeds',
    'api_token' => $token,
    'require_https' => false,
    'cors_origin' => '*',
    'cache_max_age' => 0,
], true) . ';');

echo "Seeded " . count($seed) . " breeds.\n";
echo "Config: {$configPath}\n";
