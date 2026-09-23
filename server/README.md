# PawPedia Breed API

A small PHP REST API for the breed catalogue, deployed to Freehostia next to the
MySQL database it reads and writes. Written for **PHP 7.4** (Freehostia runs
7.4.33), so there is no PHP 8 syntax.

---

## Endpoints

Base URL: `http://dogbreeds.mooo.com/api` (switch to `https://` once SSL is on).
Every request except `OPTIONS` needs `Authorization: Bearer <token>`.

| Method | Path | Does | Success |
| --- | --- | --- | --- |
| `GET` | `/breeds` | List breeds (paginated, filterable) | `200` |
| `GET` | `/breeds/{id}` | Read one breed | `200` |
| `POST` | `/breeds` | Create a breed | `201` + `Location` + the new breed |
| `PUT` | `/breeds/{id}` | Update (replace) a breed | `200` + the updated breed |
| `DELETE` | `/breeds/{id}` | Delete a breed | `204`, no body |
| `HEAD` | either `GET` path | Headers only | `200` |
| `OPTIONS` | either path | CORS preflight (no token needed) | `204` + `Allow` |

Query parameters for `GET /breeds` (all optional and combinable):

| Parameter | Example | Meaning |
| --- | --- | --- |
| `search` | `search=golden` | Breed name contains, case-insensitive (max 100 chars) |
| `group` | `group=Toy,Sporting` | Breed group is any of, case-insensitive (max 20) |
| `country` | `country=Scotland` | Origin country is any of, case-insensitive (max 20) |
| `page` | `page=2` | 1-based page number (default 1) |
| `per_page` | `per_page=25` | 1–100 (default 50) |

### Responses

A list returns `data`, `meta` and `links`:

```json
{
  "data": [
    {
      "id": 1,
      "breed_name": "Golden Retriever",
      "breed_group": "Sporting",
      "origin_country": "Scotland",
      "average_lifespan": "10-12 years",
      "temperament": "Friendly, Intelligent, Devoted, Gentle",
      "picture": "https://images.dog.ceo/breeds/retriever-golden/mori_1.jpg"
    }
  ],
  "meta":  { "total": 9, "count": 1, "page": 1, "per_page": 1, "total_pages": 9 },
  "links": {
    "self":  "/api/breeds?page=1&per_page=1",
    "first": "/api/breeds?page=1&per_page=1",
    "last":  "/api/breeds?page=9&per_page=1",
    "prev":  null,
    "next":  "/api/breeds?page=2&per_page=1"
  }
}
```

Links keep any `search`/`group`/`country` filters. A single breed (`GET`, `POST`
or `PUT`) returns `{ "data": { ...breed }, "links": {...} }`.

### Create and update bodies

JSON with `Content-Type: application/json`:

| Field | Rule |
| --- | --- |
| `breed_name` | **Required.** At most 120 characters. Unique, ignoring case. |
| `breed_group` | Optional, at most 60 |
| `origin_country` | Optional, at most 80 |
| `average_lifespan` | Optional, at most 40 |
| `temperament` | Optional, at most 255; comma-separated traits |
| `picture` | Optional, at most 500; must be an `http://` or `https://` URL |

Values are trimmed and blank optional fields are stored as `null`. `PUT`
replaces the whole record. Unknown fields are rejected.

If the host blocks `PUT` or `DELETE`, send `POST /breeds/{id}` with
`X-HTTP-Method-Override: PUT` (or `DELETE`) instead.

### Errors

Every error has the same shape:

```json
{ "error": { "status": 404, "code": "breed_not_found", "message": "Breed 99 was not found." } }
```

| Status | `code` | When |
| --- | --- | --- |
| 304 | — | `If-None-Match` matches the current `ETag` |
| 400 | `invalid_parameter` / `invalid_json` | Bad query parameter or id / body is not a JSON object |
| 401 | `unauthorized` | Token missing or wrong |
| 403 | `https_required` | Plain HTTP while `require_https` is on |
| 404 | `breed_not_found` / `route_not_found` | No such breed / no such path |
| 405 | `method_not_allowed` | Method not supported on that path. Sends `Allow` |
| 409 | `breed_exists` | Another breed already has that name |
| 413 | `payload_too_large` | Body over 16 KB |
| 415 | `unsupported_media_type` | Body sent without `Content-Type: application/json` |
| 422 | `validation_failed` | A field breaks a rule. `error.fields` lists each one |
| 500 | `server_misconfigured` / `internal_error` | Missing config or placeholder token / unexpected error |
| 503 | `database_unavailable` | MySQL unreachable. Sends `Retry-After` |

Successful reads carry a weak `ETag` and `Cache-Control: private, max-age=300`;
writes are `Cache-Control: no-store`.

---

## Structure

```
server/
  .htaccess                 domain root: no directory listing, hide X-Powered-By
  api/
    .htaccess               routes /api/* to index.php, keeps the Authorization header
    index.php               front controller
  src/                      web access denied
    bootstrap.php           wires config → request → auth → router → controller
    Request.php             parsed method, path, query, headers
    Response.php            the only code that writes output
    Router.php              routes, 404 vs 405, OPTIONS preflight
    Auth.php                constant-time bearer token check
    Database.php            PDO with real prepared statements
    BreedRepository.php     all SQL; every value bound
    BreedController.php     validation, pagination, links, CRUD
    ApiException.php        one exception type per HTTP error
  config/
    config.example.php      copy to config.php (gitignored)
  database/
    schema.sql              reference schema and indexes
    fix_breed_data.sql      replaces dead placeholder photo links with dog.ceo photos
  postman/                  collection + Local and Freehostia environments
  tests/
    run_tests.php           end-to-end checks against a real server
    make_dev_db.php         SQLite copy of the catalogue for local work
    dev-router.php          .htaccess equivalent for php -S
```

---

## Deploying to Freehostia

1. **Create the config.** Copy `config/config.example.php` to
   `config/config.php` and fill in the MySQL details, the table name and
   `api_token`. The API refuses to serve anything while `api_token` is empty or
   still `change-me`.
2. **Upload** `.htaccess`, `api/`, `src/` and `config/` into the domain's web
   root (`public_html/`). Safer still: put `src/` and `config/` outside
   `public_html` and point `$appRoot` in `api/index.php` at them.
3. **Check it:**
   ```bash
   curl -i -H "Authorization: Bearer YOUR_TOKEN" http://dogbreeds.mooo.com/api/breeds
   ```
   Expect `200` and a JSON body. Then run the **CRUD** folder of the Postman
   collection to check writes.
4. **Turn on HTTPS** when available: uncomment the redirect in the root
   `.htaccess`, set `'require_https' => true`, and change the app's
   `BREED_API_BASE_URL` to `https://`.

`dogbreeds.mooo.com` points at Freehostia through an A record in FreeDNS. If
Freehostia moves the account to another server, update that record.

### Troubleshooting

| Symptom | Fix |
| --- | --- |
| `/api/breeds` is 404 but `/api/index.php/breeds` works | `mod_rewrite` is unavailable. Set `BREED_API_BASE_URL=http://dogbreeds.mooo.com/api/index.php` |
| Whole site returns 500 after uploading `.htaccess` | Delete the `Options -Indexes` line |
| `POST` returns 500 and the log says `Field 'id' doesn't have a default value` | `ALTER TABLE breeds MODIFY id INT UNSIGNED NOT NULL AUTO_INCREMENT;` |
| Writes return 503 | Grant the MySQL user `INSERT, UPDATE, DELETE` on the table |
| `PUT`/`DELETE` return an HTML 403/405 page | The host blocks those methods; use `X-HTTP-Method-Override` |
| Breed photos don't load | Run `database/fix_breed_data.sql` in phpMyAdmin |

---

## Running locally

Uses PHP and a SQLite copy of the catalogue, so no MySQL is needed.

```bash
php server/tests/make_dev_db.php
```

```powershell
$env:PAWPEDIA_CONFIG="$PWD\server\database\dev\config.php"
php -S 127.0.0.1:8080 -t server server/tests/dev-router.php
```

Then call `http://127.0.0.1:8080/api/breeds` with `Authorization: Bearer dev-token`.
From the Android emulator, set `BREED_API_BASE_URL=http://10.0.2.2:8080/api` and
`BREED_API_TOKEN=dev-token` in the app's `.env`.

---

## Postman

Import the collection and both environments from [`postman/`](postman/), pick
**PawPedia - Local** or **PawPedia - Freehostia**, set `token`, and run the
collection. It checks status codes, response shapes, caching, a full
create → read → update → delete round trip, and the error cases.

Don't export or share the Freehostia environment once it holds the real token.

---

## Tests

```bash
php server/tests/run_tests.php
```

Starts PHP's built-in server on a throwaway SQLite database and checks
authentication, pagination, filtering, all CRUD operations and their error
cases, method override, CORS preflight, ETags, and database failure handling.
