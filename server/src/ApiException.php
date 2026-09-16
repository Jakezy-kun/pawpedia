<?php

declare(strict_types=1);

/**
 * A failure that maps directly onto an HTTP error response.
 *
 * Everything that can go wrong in a request is expressed as one of these, so
 * the error body always has the same shape and the status code is decided in
 * one place rather than scattered through controllers.
 */
final class ApiException extends RuntimeException
{
    private int $status;
    private string $errorCode;

    /** @var array<string, string> */
    private array $headers;

    /**
     * @param array<string, string> $headers
     */
    public function __construct(int $status, string $errorCode, string $message, array $headers = [])
    {
        parent::__construct($message);
        $this->status = $status;
        $this->errorCode = $errorCode;
        $this->headers = $headers;
    }

    public function status(): int
    {
        return $this->status;
    }

    public function errorCode(): string
    {
        return $this->errorCode;
    }

    /** @return array<string, string> */
    public function headers(): array
    {
        return $this->headers;
    }

    public static function badRequest(string $message): self
    {
        return new self(400, 'invalid_parameter', $message);
    }

    /**
     * RFC 6750: a request with no credentials gets a bare challenge; a request
     * with bad credentials also names the error.
     */
    public static function unauthorized(string $message, bool $credentialsPresent): self
    {
        $challenge = 'Bearer realm="PawPedia"';
        if ($credentialsPresent) {
            $challenge .= ', error="invalid_token"';
        }

        return new self(401, 'unauthorized', $message, ['WWW-Authenticate' => $challenge]);
    }

    public static function httpsRequired(): self
    {
        return new self(403, 'https_required', 'This API must be called over HTTPS.');
    }

    public static function notFound(string $code, string $message): self
    {
        return new self(404, $code, $message);
    }

    /**
     * @param list<string> $allowed
     */
    public static function methodNotAllowed(array $allowed): self
    {
        return new self(
            405,
            'method_not_allowed',
            'This resource is read-only. Allowed methods: ' . implode(', ', $allowed) . '.',
            ['Allow' => implode(', ', $allowed)]
        );
    }

    public static function serverMisconfigured(): self
    {
        return new self(500, 'server_misconfigured', 'The API is not configured correctly.');
    }

    public static function internal(): self
    {
        return new self(500, 'internal_error', 'Something went wrong on our side.');
    }

    public static function databaseUnavailable(): self
    {
        return new self(503, 'database_unavailable', 'The breed database is temporarily unavailable.', ['Retry-After' => '30']);
    }
}
