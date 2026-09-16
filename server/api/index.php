<?php

declare(strict_types=1);

// Buffer from the very first byte so nothing printed by accident can precede
// the JSON body. Response::send discards this buffer before writing.
ob_start();

// src/ and config/ are expected next to this api/ folder. To keep them out of
// the web root entirely, set PAWPEDIA_APP_ROOT or edit this line to point at
// wherever you uploaded them.
$appRoot = getenv('PAWPEDIA_APP_ROOT') ?: dirname(__DIR__);

require $appRoot . '/src/bootstrap.php';

pawpedia_run($appRoot);
