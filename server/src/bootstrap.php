<?php

declare(strict_types=1);

require_once __DIR__ . '/ApiException.php';
require_once __DIR__ . '/Request.php';
require_once __DIR__ . '/Response.php';
require_once __DIR__ . '/Router.php';
require_once __DIR__ . '/Auth.php';
require_once __DIR__ . '/Database.php';
require_once __DIR__ . '/BreedRepository.php';
require_once __DIR__ . '/BreedController.php';

/**
 * Handles one API request from start to finish.
 */
function pawpedia_run(string $appRoot): void
{
    // Errors go to the server log, never into a response body where they would
    // corrupt the JSON and leak file paths.
    ini_set('display_errors', '0');
    ini_set('log_errors', '1');
    error_reporting(E_ALL);

    try {
        $config = pawpedia_load_config($appRoot);

        Response::configure(
            (string) ($config['cors_origin'] ?? '*'),
            (int) ($config['cache_max_age'] ?? 300)
        );

        $request = Request::fromGlobals();

        if (!empty($config['require_https']) && !$request->isSecure()) {
            throw ApiException::httpsRequired();
        }

        // Connect lazily: a 404, 405 or 401 never needs the database.
        $controller = null;
        $breeds = static function () use (&$controller, $config): BreedController {
            if ($controller === null) {
                $pdo = Database::connect((array) ($config['db'] ?? []));
                $controller = new BreedController(
                    new BreedRepository($pdo, (string) ($config['table'] ?? 'breeds'))
                );
            }

            return $controller;
        };

        $router = new Router();
        $router->get('#^/breeds$#', static function (Request $request) use ($breeds): void {
            $breeds()->index($request);
        });
        $router->post('#^/breeds$#', static function (Request $request) use ($breeds): void {
            $breeds()->store($request);
        });
        $router->get('#^/breeds/(?P<id>[^/]+)$#', static function (Request $request, array $params) use ($breeds): void {
            $breeds()->show($request, $params);
        });
        $router->put('#^/breeds/(?P<id>[^/]+)$#', static function (Request $request, array $params) use ($breeds): void {
            $breeds()->update($request, $params);
        });
        $router->delete('#^/breeds/(?P<id>[^/]+)$#', static function (Request $request, array $params) use ($breeds): void {
            $breeds()->destroy($request, $params);
        });

        $auth = new Auth((string) ($config['api_token'] ?? ''));
        $router->dispatch($request, [$auth, 'authenticate']);
    } catch (ApiException $error) {
        Response::error($error);
    } catch (Throwable $error) {
        error_log('PawPedia API: unhandled ' . get_class($error) . ': ' . $error->getMessage()
            . ' in ' . $error->getFile() . ':' . $error->getLine());
        Response::error(ApiException::internal());
    }
}

/**
 * @return array<string, mixed>
 */
function pawpedia_load_config(string $appRoot): array
{
    $path = getenv('PAWPEDIA_CONFIG');
    if ($path === false || $path === '') {
        $path = $appRoot . '/config/config.php';
    }

    if (!is_file($path)) {
        error_log('PawPedia API: config file not found at ' . $path);
        throw ApiException::serverMisconfigured();
    }

    $config = require $path;
    if (!is_array($config)) {
        error_log('PawPedia API: config file must return an array');
        throw ApiException::serverMisconfigured();
    }

    return $config;
}
