<?php

declare(strict_types=1);

/**
 * Maps a method and path onto a handler.
 *
 * Distinguishes the three REST outcomes that a flat PHP script cannot:
 *   - the path exists and the method is allowed  -> run the handler
 *   - the path exists but the method is not      -> 405 with an Allow header
 *   - the path does not exist                    -> 404
 */
final class Router
{
    /** @var list<array{pattern: string, handler: callable}> */
    private array $routes = [];

    /**
     * Registers a read route. HEAD and OPTIONS are served for it automatically.
     *
     * @param string $pattern regex matched against the whole route path;
     *                        named groups become handler parameters
     */
    public function get(string $pattern, callable $handler): void
    {
        $this->routes[] = ['pattern' => $pattern, 'handler' => $handler];
    }

    /**
     * @param callable(Request): void $authenticate run before any handler
     */
    public function dispatch(Request $request, callable $authenticate): void
    {
        $allowed = ['GET', 'HEAD', 'OPTIONS'];

        foreach ($this->routes as $route) {
            if (preg_match($route['pattern'], $request->path(), $matches) !== 1) {
                continue;
            }

            $method = $request->method();

            // CORS preflight carries no credentials by design, so it must be
            // answered before authentication.
            if ($method === 'OPTIONS') {
                Response::options($allowed);
                return;
            }

            if ($method !== 'GET' && $method !== 'HEAD') {
                throw ApiException::methodNotAllowed($allowed);
            }

            $authenticate($request);

            $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
            ($route['handler'])($request, $params);
            return;
        }

        throw ApiException::notFound('route_not_found', 'No resource exists at ' . $request->path() . '.');
    }
}
