<?php

declare(strict_types=1);

/**
 * Checks the static bearer token.
 */
final class Auth
{
    private string $expectedToken;

    public function __construct(string $expectedToken)
    {
        $this->expectedToken = $expectedToken;
    }

    public function authenticate(Request $request): void
    {
        // Refuse to run open. An empty or placeholder token in config would
        // otherwise make every request "authenticated".
        if ($this->expectedToken === '' || $this->expectedToken === 'change-me') {
            error_log('PawPedia API: api_token is not set in config.php');
            throw ApiException::serverMisconfigured();
        }

        $provided = $request->bearerToken();

        if ($provided === null) {
            throw ApiException::unauthorized('An Authorization: Bearer <token> header is required.', false);
        }

        // hash_equals compares in constant time, so response timing reveals
        // nothing about how much of a guessed token was correct.
        if ($provided === '' || !hash_equals($this->expectedToken, $provided)) {
            throw ApiException::unauthorized('The bearer token is not valid.', true);
        }
    }
}
