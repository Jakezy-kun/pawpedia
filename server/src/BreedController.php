<?php

declare(strict_types=1);

/**
 * The /breeds resource.
 *
 *   GET /breeds          collection, filterable and paginated
 *   GET /breeds/{id}     one breed
 */
final class BreedController
{
    public const DEFAULT_PER_PAGE = 50;
    public const MAX_PER_PAGE = 100;
    private const MAX_SEARCH_LENGTH = 100;
    private const MAX_LIST_VALUES = 20;

    private BreedRepository $breeds;

    public function __construct(BreedRepository $breeds)
    {
        $this->breeds = $breeds;
    }

    /**
     * GET /breeds?search=golden&group=Toy,Sporting&country=Scotland&page=1&per_page=50
     */
    public function index(Request $request): void
    {
        $search = $request->query('search');
        if ($search !== null && self::length($search) > self::MAX_SEARCH_LENGTH) {
            throw ApiException::badRequest('search must be at most ' . self::MAX_SEARCH_LENGTH . ' characters.');
        }

        $groups = self::parseList($request, 'group');
        $countries = self::parseList($request, 'country');
        $page = self::parsePositiveInt($request, 'page', 1, PHP_INT_MAX);
        $perPage = self::parsePositiveInt($request, 'per_page', self::DEFAULT_PER_PAGE, self::MAX_PER_PAGE);

        $result = $this->breeds->search($search, $groups, $countries, $perPage, ($page - 1) * $perPage);
        $total = $result['total'];
        $totalPages = max(1, (int) ceil($total / $perPage));

        // Filters are echoed into every link, so following `next` never
        // silently drops the user's search.
        $filters = array_filter([
            'search' => $search,
            'group' => $groups === [] ? null : implode(',', $groups),
            'country' => $countries === [] ? null : implode(',', $countries),
        ], static function ($value): bool {
            return $value !== null;
        });

        $link = static function (int $targetPage) use ($request, $filters, $perPage): string {
            $query = array_merge($filters, ['page' => $targetPage, 'per_page' => $perPage]);

            return $request->basePath() . '/breeds?' . http_build_query($query, '', '&', PHP_QUERY_RFC3986);
        };

        Response::ok($request, [
            'data' => array_map([self::class, 'present'], $result['items']),
            'meta' => [
                'total' => $total,
                'count' => count($result['items']),
                'page' => $page,
                'per_page' => $perPage,
                'total_pages' => $totalPages,
            ],
            'links' => [
                'self' => $link($page),
                'first' => $link(1),
                'last' => $link($totalPages),
                'prev' => $page > 1 ? $link(min($page - 1, $totalPages)) : null,
                'next' => $page < $totalPages ? $link($page + 1) : null,
            ],
        ]);
    }

    /**
     * GET /breeds/{id}
     *
     * @param array<string, string> $params
     */
    public function show(Request $request, array $params): void
    {
        $raw = $params['id'] ?? '';
        if (preg_match('/^[1-9][0-9]{0,9}$/', $raw) !== 1 || (int) $raw > 2147483647) {
            throw ApiException::badRequest('Breed id must be a positive integer.');
        }

        $id = (int) $raw;
        $breed = $this->breeds->find($id);

        if ($breed === null) {
            throw ApiException::notFound('breed_not_found', "Breed {$id} was not found.");
        }

        Response::ok($request, [
            'data' => self::present($breed),
            'links' => [
                'self' => $request->basePath() . '/breeds/' . $id,
                'collection' => $request->basePath() . '/breeds',
            ],
        ]);
    }

    /**
     * The public shape of a breed. Types are normalised here so clients get an
     * integer id and real nulls whatever the database driver hands back.
     *
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    public static function present(array $row): array
    {
        return [
            'id' => (int) $row['id'],
            'breed_name' => self::text($row['breed_name'] ?? null),
            'breed_group' => self::text($row['breed_group'] ?? null),
            'origin_country' => self::text($row['origin_country'] ?? null),
            'average_lifespan' => self::text($row['average_lifespan'] ?? null),
            'temperament' => self::text($row['temperament'] ?? null),
            'picture' => self::text($row['picture'] ?? null),
        ];
    }

    /**
     * @param mixed $value
     */
    private static function text($value): ?string
    {
        if ($value === null) {
            return null;
        }

        $text = trim((string) $value);

        return $text === '' ? null : $text;
    }

    /**
     * Comma-separated values, trimmed and de-duplicated.
     *
     * @return list<string>
     */
    private static function parseList(Request $request, string $key): array
    {
        $raw = $request->query($key);
        if ($raw === null) {
            return [];
        }

        $values = [];
        foreach (explode(',', $raw) as $part) {
            $part = trim($part);
            if ($part !== '' && !in_array($part, $values, true)) {
                $values[] = $part;
            }
        }

        if (count($values) > self::MAX_LIST_VALUES) {
            throw ApiException::badRequest("{$key} accepts at most " . self::MAX_LIST_VALUES . ' values.');
        }

        return $values;
    }

    private static function parsePositiveInt(Request $request, string $key, int $default, int $max): int
    {
        $raw = $request->query($key);
        if ($raw === null) {
            return $default;
        }

        if (preg_match('/^[1-9][0-9]{0,8}$/', $raw) !== 1 || (int) $raw > $max) {
            throw ApiException::badRequest("{$key} must be an integer between 1 and {$max}.");
        }

        return (int) $raw;
    }

    private static function length(string $value): int
    {
        return function_exists('mb_strlen') ? mb_strlen($value, 'UTF-8') : strlen($value);
    }
}
