<?php

declare(strict_types=1);

/**
 * An immutable view of the incoming HTTP request.
 *
 * Built once from PHP's superglobals so the rest of the API never touches
 * $_SERVER or $_GET directly — which is also what makes it testable.
 */
final class Request
{
    private string $method;

    /** The route path, e.g. "/breeds/5". Always starts with "/", no trailing "/". */
    private string $path;

    /**
     * Everything in the URL before the route path, e.g. "/api" or
     * "/api/index.php". Used to build links that work whichever form the
     * client called.
     */
    private string $basePath;

    /** @var array<string, mixed> */
    private array $query;

    /** @var array<string, string> lower-cased header name => value */
    private array $headers;

    private bool $secure;

    /**
     * @param array<string, mixed>  $query
     * @param array<string, string> $headers
     */
    public function __construct(string $method, string $path, string $basePath, array $query, array $headers, bool $secure)
    {
        $this->method = strtoupper($method);
        $this->path = $path;
        $this->basePath = $basePath;
        $this->query = $query;
        $this->headers = $headers;
        $this->secure = $secure;
    }

    public static function fromGlobals(): self
    {
        $server = $_SERVER;
        $uriPath = (string) (parse_url((string) ($server['REQUEST_URI'] ?? '/'), PHP_URL_PATH) ?? '/');
        $script = str_replace('\\', '/', (string) ($server['SCRIPT_NAME'] ?? ''));
        $scriptDir = rtrim(str_replace('\\', '/', dirname($script)), '/');

        // Two ways to reach the API:
        //   /api/breeds/5            (mod_rewrite routes it to index.php)
        //   /api/index.php/breeds/5  (PATH_INFO — works even without mod_rewrite)
        if ($script !== '' && strpos($uriPath, $script) === 0) {
            $basePath = $script;
            $routePath = substr($uriPath, strlen($script));
        } elseif ($scriptDir !== '' && strpos($uriPath, $scriptDir) === 0) {
            $basePath = $scriptDir;
            $routePath = substr($uriPath, strlen($scriptDir));
        } else {
            $basePath = '';
            $routePath = $uriPath;
        }

        $routePath = '/' . trim(rawurldecode((string) $routePath), '/');

        return new self(
            (string) ($server['REQUEST_METHOD'] ?? 'GET'),
            $routePath,
            $basePath,
            $_GET,
            self::collectHeaders($server),
            self::detectHttps($server)
        );
    }

    public function method(): string
    {
        return $this->method;
    }

    public function path(): string
    {
        return $this->path;
    }

    public function basePath(): string
    {
        return $this->basePath;
    }

    public function isSecure(): bool
    {
        return $this->secure;
    }

    public function header(string $name): ?string
    {
        $key = strtolower($name);

        return $this->headers[$key] ?? null;
    }

    /**
     * A single query-string value, trimmed. Empty strings count as absent.
     *
     * Rejects array syntax such as `group[]=Toy`: the API documents
     * comma-separated lists, and silently accepting a second format is how
     * clients end up depending on accidents.
     */
    public function query(string $key): ?string
    {
        if (!array_key_exists($key, $this->query)) {
            return null;
        }

        $value = $this->query[$key];
        if (!is_string($value)) {
            throw ApiException::badRequest("Query parameter '{$key}' must be a single value.");
        }

        $value = trim($value);

        return $value === '' ? null : $value;
    }

    /**
     * The bearer token, or null when no Authorization header was sent.
     * Returns an empty string when a header was sent but is not a Bearer token,
     * so the caller can tell "missing" from "wrong".
     */
    public function bearerToken(): ?string
    {
        $header = $this->header('Authorization');
        if ($header === null || trim($header) === '') {
            return null;
        }

        if (preg_match('/^\s*Bearer\s+(\S+)\s*$/i', $header, $matches) !== 1) {
            return '';
        }

        return $matches[1];
    }

    /**
     * @param array<string, mixed> $server
     * @return array<string, string>
     */
    private static function collectHeaders(array $server): array
    {
        $headers = [];

        foreach ($server as $key => $value) {
            if (!is_string($value)) {
                continue;
            }
            if (strpos($key, 'HTTP_') === 0) {
                $name = strtolower(str_replace('_', '-', substr($key, 5)));
                $headers[$name] = $value;
            }
        }

        // Shared hosts that run PHP as CGI/FastCGI strip Authorization before
        // PHP sees it. The .htaccess puts it back under one of these names.
        foreach (['HTTP_AUTHORIZATION', 'REDIRECT_HTTP_AUTHORIZATION'] as $key) {
            if (!isset($headers['authorization']) && isset($server[$key]) && is_string($server[$key])) {
                $headers['authorization'] = $server[$key];
            }
        }

        if (!isset($headers['authorization']) && function_exists('apache_request_headers')) {
            foreach ((array) apache_request_headers() as $name => $value) {
                if (is_string($name) && strtolower($name) === 'authorization' && is_string($value)) {
                    $headers['authorization'] = $value;
                }
            }
        }

        return $headers;
    }

    /**
     * @param array<string, mixed> $server
     */
    private static function detectHttps(array $server): bool
    {
        $https = strtolower((string) ($server['HTTPS'] ?? ''));
        if ($https !== '' && $https !== 'off') {
            return true;
        }

        // Behind a TLS-terminating proxy the original scheme arrives as a header.
        return strtolower((string) ($server['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
    }
}
