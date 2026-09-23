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
     * Extra members merged into the error body, e.g. per-field messages.
     *
     * @var array<string, mixed>
     */
    private array $details;

    /**
     * @param array<string, string> $headers
     * @param array<string, mixed>  $details
     */
    public function __construct(int $status, string $errorCode, string $message, array $headers = [], array $details = [])
    {
        parent::__construct($message);
        $this->status = $status;
        $this->errorCode = $errorCode;
        $this->headers = $headers;
        $this->details = $details;
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

    /** @return array<string, mixed> */
    public function details(): array
    {
        return $this->details;
    }

    public static function badRequest(string $message, string $code = 'invalid_parameter'): self
    {
        return new self(400, $code, $message);
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
            'Allowed methods for this resource: ' . implode(', ', $allowed) . '.',
            ['Allow' => implode(', ', $allowed)]
        );
    }

    public static function conflict(string $code, string $message): self
    {
        return new self(409, $code, $message);
    }

    public static function payloadTooLarge(int $maxBytes): self
    {
        return new self(413, 'payload_too_large', "The request body must be at most {$maxBytes} bytes.");
    }

    public static function unsupportedMediaType(): self
    {
        return new self(415, 'unsupported_media_type', 'Send the request body as JSON with Content-Type: application/json.');
    }

    /**
     * The body parsed, but its values break the resource's rules. `fields`
     * names each offending member so a client can show the message beside the
     * right input.
     *
     * @param array<string, string> $fields field name => message
     */
    public static function validationFailed(array $fields): self
    {
        return new self(422, 'validation_failed', 'Some fields are invalid.', [], ['fields' => $fields]);
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
