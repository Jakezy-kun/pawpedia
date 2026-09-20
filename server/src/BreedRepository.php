<?php

declare(strict_types=1);

/**
 * All SQL for the breeds table lives here and nowhere else.
 *
 * Every value from the request is bound as a parameter. The only thing ever
 * interpolated into SQL text is the table name, which comes from config and is
 * validated against a strict pattern first.
 */
final class BreedRepository
{
    private const COLUMNS = 'id, breed_name, breed_group, origin_country, average_lifespan, temperament, picture';

    private PDO $pdo;
    private string $table;

    public function __construct(PDO $pdo, string $table)
    {
        if (preg_match('/^[A-Za-z_][A-Za-z0-9_]{0,63}$/', $table) !== 1) {
            error_log('PawPedia API: invalid table name in config.php');
            throw ApiException::serverMisconfigured();
        }

        $this->pdo = $pdo;
        $this->table = $table;
    }

    /**
     * @return array<string, mixed>|null
     */
    public function find(int $id): ?array
    {
        try {
            $statement = $this->pdo->prepare(
                'SELECT ' . self::COLUMNS . ' FROM `' . $this->table . '` WHERE id = :id LIMIT 1'
            );
            $statement->bindValue(':id', $id, PDO::PARAM_INT);
            $statement->execute();
        } catch (PDOException $exception) {
            throw self::translate($exception);
        }

        $row = $statement->fetch();

        return $row === false ? null : $row;
    }

    /**
     * @param list<string> $groups    matched case-insensitively, any of
     * @param list<string> $countries matched case-insensitively, any of
     * @return array{items: list<array<string, mixed>>, total: int}
     */
    public function search(?string $search, array $groups, array $countries, int $limit, int $offset): array
    {
        $where = [];
        $params = [];

        if ($search !== null) {
            // "!" rather than backslash as the LIKE escape character, because
            // backslash inside an SQL string literal means different things in
            // MySQL and SQLite, and the tests run against SQLite.
            $where[] = "LOWER(breed_name) LIKE :search ESCAPE '!'";
            $params[':search'] = '%' . self::escapeLike(self::lower($search)) . '%';
        }

        if ($groups !== []) {
            $where[] = 'LOWER(breed_group) IN (' . self::placeholders('group', $groups, $params) . ')';
        }

        if ($countries !== []) {
            $where[] = 'LOWER(origin_country) IN (' . self::placeholders('country', $countries, $params) . ')';
        }

        $whereSql = $where === [] ? '' : ' WHERE ' . implode(' AND ', $where);

        try {
            $count = $this->pdo->prepare('SELECT COUNT(*) FROM `' . $this->table . '`' . $whereSql);
            foreach ($params as $name => $value) {
                $count->bindValue($name, $value, PDO::PARAM_STR);
            }
            $count->execute();
            $total = (int) $count->fetchColumn();

            $select = $this->pdo->prepare(
                'SELECT ' . self::COLUMNS . ' FROM `' . $this->table . '`' . $whereSql
                . ' ORDER BY breed_name ASC, id ASC LIMIT :limit OFFSET :offset'
            );
            foreach ($params as $name => $value) {
                $select->bindValue($name, $value, PDO::PARAM_STR);
            }
            $select->bindValue(':limit', $limit, PDO::PARAM_INT);
            $select->bindValue(':offset', $offset, PDO::PARAM_INT);
            $select->execute();
        } catch (PDOException $exception) {
            throw self::translate($exception);
        }

        return ['items' => $select->fetchAll(), 'total' => $total];
    }

    /**
     * Turns a driver error into the right HTTP failure.
     *
     * A wrong `table` or a renamed column in config.php is a setup mistake, not
     * an outage, and saying so in the log is the difference between a five
     * minute fix and an afternoon. The client still sees no driver detail.
     */
    private static function translate(PDOException $exception): ApiException
    {
        $sqlState = (string) $exception->getCode();
        $message = $exception->getMessage();

        $missingTable = $sqlState === '42S02'
            || strpos($message, 'no such table') !== false
            || strpos($message, "doesn't exist") !== false;
        $missingColumn = $sqlState === '42S22'
            || strpos($message, 'no such column') !== false
            || strpos($message, 'Unknown column') !== false;

        if ($missingTable || $missingColumn) {
            error_log(
                'PawPedia API: the breeds table or its columns do not match config.php. '
                . 'Expected columns: ' . self::COLUMNS . '. Driver said: ' . $message
            );
            return ApiException::serverMisconfigured();
        }

        error_log('PawPedia API: query failed: ' . $message);
        return ApiException::databaseUnavailable();
    }

    /**
     * @param list<string>          $values
     * @param array<string, string> $params filled in place
     */
    private static function placeholders(string $prefix, array $values, array &$params): string
    {
        $names = [];
        foreach (array_values($values) as $index => $value) {
            $name = ':' . $prefix . $index;
            $names[] = $name;
            $params[$name] = self::lower($value);
        }

        return implode(', ', $names);
    }

    private static function escapeLike(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }

    private static function lower(string $value): string
    {
        return function_exists('mb_strtolower') ? mb_strtolower($value, 'UTF-8') : strtolower($value);
    }
}
