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
    /** Largest request body accepted. A breed is well under 2 KB of JSON. */
    public const MAX_BODY_BYTES = 16384;

    /** Methods a POST may stand in for via X-HTTP-Method-Override. */
    private const OVERRIDABLE = ['PUT', 'PATCH', 'DELETE'];

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

    /** The raw request body, read at most MAX_BODY_BYTES + 1 bytes deep. */
    private string $body;

    /**
     * @param array<string, mixed>  $query
     * @param array<string, string> $headers
     */
    public function __construct(string $method, string $path, string $basePath, array $query, array $headers, bool $secure, string $body = '')
    {
        $this->method = self::effectiveMethod(strtoupper($method), $headers);
        $this->path = $path;
        $this->basePath = $basePath;
        $this->query = $query;
        $this->headers = $headers;
        $this->secure = $secure;
        $this->body = $body;
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

        // One byte past the limit is enough to know the body is too large,
        // without buffering whatever a client chooses to send.
        $body = (string) file_get_contents('php://input', false, null, 0, self::MAX_BODY_BYTES + 1);

        return new self(
            (string) ($server['REQUEST_METHOD'] ?? 'GET'),
            $routePath,
            $basePath,
            $_GET,
            self::collectHeaders($server),
            self::detectHttps($server),
            $body
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
     * The body as a JSON object.
     *
     * @return array<string, mixed>
     */
    public function jsonBody(): array
    {
        if (strlen($this->body) > self::MAX_BODY_BYTES) {
            throw ApiException::payloadTooLarge(self::MAX_BODY_BYTES);
        }

        // "application/json" with or without parameters such as charset.
        $type = strtolower(trim(explode(';', (string) $this->header('Content-Type'))[0]));
        if ($type !== 'application/json') {
            throw ApiException::unsupportedMediaType();
        }

        $decoded = json_decode($this->body, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw ApiException::badRequest('The request body is not valid JSON.', 'invalid_json');
        }

        // An empty object decodes to [], which is still an object for our
        // purposes. A list or a scalar is not.
        if (!is_array($decoded) || ($decoded !== [] && array_keys($decoded) === range(0, count($decoded) - 1))) {
            throw ApiException::badRequest('The request body must be a JSON object.', 'invalid_json');
        }

        return $decoded;
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
     * Some shared hosts and firewalls drop PUT and DELETE. Clients stuck behind
     * one can send POST with `X-HTTP-Method-Override: PUT` (or DELETE) instead.
     * Only POST may be overridden, so a GET can never be turned into a write.
     *
     * @param array<string, string> $headers
     */
    private static function effectiveMethod(string $method, array $headers): string
    {
        if ($method !== 'POST') {
            return $method;
        }

        $override = strtoupper(trim($headers['x-http-method-override'] ?? ''));

        return in_array($override, self::OVERRIDABLE, true) ? $override : $method;
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

        // PHP files these two outside the HTTP_ prefix.
        foreach (['CONTENT_TYPE' => 'content-type', 'CONTENT_LENGTH' => 'content-length'] as $key => $name) {
            if (!isset($headers[$name]) && isset($server[$key]) && is_string($server[$key]) && $server[$key] !== '') {
                $headers[$name] = $server[$key];
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
