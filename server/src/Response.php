<?php

declare(strict_types=1);

/**
 * Writes JSON responses with consistent headers.
 *
 * This is the only place in the API that emits output. It throws away anything
 * that was printed earlier — a stray BOM, a PHP notice, or text sitting outside
 * a `<?php` tag in an included file — so the body is always exactly the JSON
 * document and nothing else. That is what the old endpoint got wrong: its
 * responses began with `/*  *\/`, which is not valid JSON.
 */
final class Response
{
    private static string $corsOrigin = '*';
    private static int $cacheMaxAge = 300;

    public static function configure(string $corsOrigin, int $cacheMaxAge): void
    {
        self::$corsOrigin = $corsOrigin;
        self::$cacheMaxAge = max(0, $cacheMaxAge);
    }

    /**
     * A successful read. Adds a weak ETag and honours If-None-Match, so a
     * client re-requesting an unchanged catalogue gets a body-less 304.
     *
     * @param array<string, mixed>  $payload
     * @param array<string, string> $headers
     */
    public static function ok(Request $request, array $payload, array $headers = []): void
    {
        $body = self::encode($payload);
        $etag = 'W/"' . md5($body) . '"';

        $headers = array_merge([
            'ETag' => $etag,
            'Cache-Control' => 'private, max-age=' . self::$cacheMaxAge,
        ], $headers);

        if (self::matchesEtag($request->header('If-None-Match'), $etag)) {
            self::send(304, null, $headers);
            return;
        }

        self::send(200, $body, $headers);
    }

    /**
     * @param list<string> $allowed
     */
    public static function options(array $allowed): void
    {
        self::send(204, null, [
            'Allow' => implode(', ', $allowed),
            'Access-Control-Max-Age' => '86400',
            'Cache-Control' => 'no-store',
        ]);
    }

    public static function error(ApiException $error): void
    {
        $body = self::encode([
            'error' => [
                'status' => $error->status(),
                'code' => $error->errorCode(),
                'message' => $error->getMessage(),
            ],
        ]);

        self::send(
            $error->status(),
            $body,
            array_merge(['Cache-Control' => 'no-store'], $error->headers())
        );
    }

    /**
     * @param array<string, string> $headers
     */
    private static function send(int $status, ?string $body, array $headers): void
    {
        while (ob_get_level() > 0) {
            ob_end_clean();
        }

        if (!headers_sent()) {
            http_response_code($status);
            header_remove('X-Powered-By');

            $base = [
                'Content-Type' => 'application/json; charset=utf-8',
                'X-Content-Type-Options' => 'nosniff',
                // Responses differ per token, so shared caches must not mix them.
                'Vary' => 'Authorization',
                'Access-Control-Allow-Origin' => self::$corsOrigin,
                // Read-only API: advertise only what it actually supports.
                'Access-Control-Allow-Methods' => 'GET, HEAD, OPTIONS',
                'Access-Control-Allow-Headers' => 'Authorization, Content-Type, If-None-Match',
                'Access-Control-Expose-Headers' => 'ETag',
            ];

            foreach (array_merge($base, $headers) as $name => $value) {
                header($name . ': ' . $value);
            }
        }

        $method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));
        if ($body !== null && $method !== 'HEAD') {
            echo $body;
        }
    }

    /**
     * @param array<string, mixed> $payload
     */
    private static function encode(array $payload): string
    {
        return json_encode(
            $payload,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR
        );
    }

    private static function matchesEtag(?string $ifNoneMatch, string $etag): bool
    {
        if ($ifNoneMatch === null) {
            return false;
        }

        foreach (explode(',', $ifNoneMatch) as $candidate) {
            $candidate = trim($candidate);
            // Weak comparison: W/"x" and "x" are equivalent for If-None-Match.
            if ($candidate === '*' || self::stripWeak($candidate) === self::stripWeak($etag)) {
                return true;
            }
        }

        return false;
    }

    private static function stripWeak(string $etag): string
    {
        return strpos($etag, 'W/') === 0 ? substr($etag, 2) : $etag;
    }
}
