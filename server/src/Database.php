<?php

declare(strict_types=1);

final class Database
{
    /**
     * @param array<string, mixed> $config the "db" section of config.php
     */
    public static function connect(array $config): PDO
    {
        $dsn = isset($config['dsn']) && is_string($config['dsn']) && $config['dsn'] !== ''
            ? $config['dsn']
            : sprintf(
                'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
                (string) ($config['host'] ?? 'localhost'),
                (int) ($config['port'] ?? 3306),
                (string) ($config['name'] ?? '')
            );

        try {
            return new PDO(
                $dsn,
                isset($config['user']) ? (string) $config['user'] : null,
                isset($config['password']) ? (string) $config['password'] : null,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    // Real server-side prepared statements, so user input is
                    // never spliced into SQL text.
                    PDO::ATTR_EMULATE_PREPARES => false,
                    PDO::ATTR_STRINGIFY_FETCHES => false,
                ]
            );
        } catch (PDOException $exception) {
            // Log the real reason; never send it to the client, since driver
            // messages can include host names and user names.
            error_log('PawPedia API: database connection failed: ' . $exception->getMessage());
            throw ApiException::databaseUnavailable();
        }
    }
}
