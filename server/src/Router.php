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
    /** The order methods are listed in Allow headers. */
    private const METHOD_ORDER = ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'];

    /**
     * pattern => [method => handler]
     *
     * @var array<string, array<string, callable>>
     */
    private array $routes = [];

    /**
     * Registers a read route. HEAD and OPTIONS are served for it automatically.
     *
     * @param string $pattern regex matched against the whole route path;
     *                        named groups become handler parameters
     */
    public function get(string $pattern, callable $handler): void
    {
        $this->add('GET', $pattern, $handler);
    }

    public function post(string $pattern, callable $handler): void
    {
        $this->add('POST', $pattern, $handler);
    }

    public function put(string $pattern, callable $handler): void
    {
        $this->add('PUT', $pattern, $handler);
    }

    public function delete(string $pattern, callable $handler): void
    {
        $this->add('DELETE', $pattern, $handler);
    }

    /**
     * @param callable(Request): void $authenticate run before any handler
     */
    public function dispatch(Request $request, callable $authenticate): void
    {
        foreach ($this->routes as $pattern => $handlers) {
            if (preg_match($pattern, $request->path(), $matches) !== 1) {
                continue;
            }

            $method = $request->method();
            $allowed = self::allowed(array_keys($handlers));

            // CORS preflight carries no credentials by design, so it must be
            // answered before authentication.
            if ($method === 'OPTIONS') {
                Response::options($allowed);
                return;
            }

            $handler = $handlers[$method === 'HEAD' ? 'GET' : $method] ?? null;
            if ($handler === null) {
                throw ApiException::methodNotAllowed($allowed);
            }

            $authenticate($request);

            $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
            $handler($request, $params);
            return;
        }

        throw ApiException::notFound('route_not_found', 'No resource exists at ' . $request->path() . '.');
    }

    private function add(string $method, string $pattern, callable $handler): void
    {
        $this->routes[$pattern][$method] = $handler;
    }

    /**
     * @param list<string> $registered
     * @return list<string>
     */
    private static function allowed(array $registered): array
    {
        $methods = $registered;
        if (in_array('GET', $methods, true)) {
            $methods[] = 'HEAD';
        }
        $methods[] = 'OPTIONS';

        return array_values(array_filter(self::METHOD_ORDER, static function (string $method) use ($methods): bool {
            return in_array($method, $methods, true);
        }));
    }
}
