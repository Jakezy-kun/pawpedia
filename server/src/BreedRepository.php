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

    /** Every column a client may write. `id` is assigned by the database. */
    public const WRITABLE = ['breed_name', 'breed_group', 'origin_country', 'average_lifespan', 'temperament', 'picture'];

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
     * Inserts a breed and returns its new id.
     *
     * @param array<string, string|null> $fields one value per WRITABLE column
     */
    public function create(array $fields): int
    {
        $columns = implode(', ', self::WRITABLE);
        $placeholders = ':' . implode(', :', self::WRITABLE);

        try {
            $statement = $this->pdo->prepare(
                'INSERT INTO `' . $this->table . '` (' . $columns . ') VALUES (' . $placeholders . ')'
            );
            self::bindFields($statement, $fields);
            $statement->execute();
        } catch (PDOException $exception) {
            throw self::translate($exception);
        }

        return (int) $this->pdo->lastInsertId();
    }

    /**
     * Replaces every writable column of one breed.
     *
     * @param array<string, string|null> $fields one value per WRITABLE column
     */
    public function update(int $id, array $fields): void
    {
        $assignments = implode(', ', array_map(static function (string $column): string {
            return $column . ' = :' . $column;
        }, self::WRITABLE));

        try {
            $statement = $this->pdo->prepare(
                'UPDATE `' . $this->table . '` SET ' . $assignments . ' WHERE id = :id'
            );
            self::bindFields($statement, $fields);
            $statement->bindValue(':id', $id, PDO::PARAM_INT);
            $statement->execute();
        } catch (PDOException $exception) {
            throw self::translate($exception);
        }
    }

    /**
     * @return bool false when no breed had this id
     */
    public function delete(int $id): bool
    {
        try {
            $statement = $this->pdo->prepare('DELETE FROM `' . $this->table . '` WHERE id = :id');
            $statement->bindValue(':id', $id, PDO::PARAM_INT);
            $statement->execute();
        } catch (PDOException $exception) {
            throw self::translate($exception);
        }

        return $statement->rowCount() > 0;
    }

    /**
     * Whether another breed already uses this name, ignoring case.
     *
     * @param int|null $exceptId the breed being renamed, which may keep its own name
     */
    public function nameTaken(string $name, ?int $exceptId = null): bool
    {
        try {
            $statement = $this->pdo->prepare(
                'SELECT 1 FROM `' . $this->table . '` WHERE LOWER(breed_name) = :name AND id <> :id LIMIT 1'
            );
            $statement->bindValue(':name', self::lower($name), PDO::PARAM_STR);
            $statement->bindValue(':id', $exceptId ?? 0, PDO::PARAM_INT);
            $statement->execute();
        } catch (PDOException $exception) {
            throw self::translate($exception);
        }

        return $statement->fetchColumn() !== false;
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

        // A value longer than the column. The controller's limits follow
        // schema.sql, so this means the live table is narrower than that.
        if ($sqlState === '22001' || strpos($message, 'Data too long') !== false) {
            error_log('PawPedia API: a value exceeded its column size. Driver said: ' . $message);
            return ApiException::validationFailed(['_' => 'A value is longer than the database allows.']);
        }

        // A NOT NULL column this code does not write, or a schema change that
        // made one stricter. A setup problem, not an outage.
        if (strpos($message, 'cannot be null') !== false || strpos($message, 'NOT NULL constraint failed') !== false) {
            error_log('PawPedia API: a NOT NULL column rejected a write. Driver said: ' . $message);
            return ApiException::serverMisconfigured();
        }

        // INSERT without an id only works when the column is AUTO_INCREMENT.
        if (strpos($message, "Field 'id' doesn't have a default value") !== false) {
            error_log('PawPedia API: breeds.id must be AUTO_INCREMENT for POST /breeds. See database/schema.sql.');
            return ApiException::serverMisconfigured();
        }

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
     * A missing optional value is stored as '' rather than NULL. The live
     * table declares every column NOT NULL, and MySQL rejects a NULL in an
     * INSERT outright. Reads already turn '' back into null (see
     * BreedController::present), so clients never see the difference.
     *
     * @param array<string, string|null> $fields
     */
    private static function bindFields(PDOStatement $statement, array $fields): void
    {
        foreach (self::WRITABLE as $column) {
            $statement->bindValue(':' . $column, $fields[$column] ?? '', PDO::PARAM_STR);
        }
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
