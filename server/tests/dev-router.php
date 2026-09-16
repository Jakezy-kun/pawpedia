<?php

// Router for PHP's built-in web server, which does not read .htaccess.
// Reproduces what api/.htaccess does on Apache:
//
//   php -S 127.0.0.1:8080 -t server server/tests/dev-router.php
//
// then call http://127.0.0.1:8080/api/breeds

$path = (string) parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);

if ($path === '/api' || strpos($path, '/api/') === 0) {
    $_SERVER['SCRIPT_NAME'] = '/api/index.php';
    require __DIR__ . '/../api/index.php';
    return true;
}

http_response_code(404);
header('Content-Type: text/plain');
echo "Only /api/* is served by the dev router.\n";
return true;
