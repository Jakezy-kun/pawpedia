<?php

// Copy this file to config.php and fill in real values.
// config.php holds credentials: never commit it, and never upload it anywhere
// it can be downloaded. The .htaccess in this folder blocks web access, but
// the safest place is outside public_html altogether.

return [
    'db' => [
        // The same database the current connection.php uses.
        'host' => 'localhost',
        'port' => 3306,
        'name' => 'your_database_name',
        'user' => 'your_database_user',
        'password' => 'your_database_password',

        // Overrides host/port/name when set. The automated tests use SQLite.
        // 'dsn' => 'sqlite:/absolute/path/to/breeds.sqlite',
    ],

    // Table holding the breeds. Columns expected:
    // id, breed_name, breed_group, origin_country, average_lifespan,
    // temperament, picture
    'table' => 'breeds',

    // The static bearer token clients must send as
    //   Authorization: Bearer <token>
    // Reuse the token the Flutter app and Postman already have. The API refuses
    // to serve anything while this is empty or still "change-me".
    'api_token' => 'change-me',

    // Set to true once HTTPS works for the domain. Plain-HTTP requests are then
    // rejected with 403 instead of sending the token unencrypted.
    'require_https' => false,

    // Mobile apps ignore CORS. Tighten this if a browser app ever calls the API.
    'cors_origin' => '*',

    // How long clients may reuse a response before asking again (seconds).
    'cache_max_age' => 300,
];
