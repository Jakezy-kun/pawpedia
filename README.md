# PawPedia

A friendly dog-breeds directory for iOS and Android, built with Flutter.

Browse breeds from a read-only PHP/MySQL catalogue, search and filter them, and
keep a shortlist. Accounts, profiles and favourites are backed by Supabase.
There is no Firebase and no social login — email and password only, plus a
fully working guest mode.

---

## Contents

- [Quick start](#quick-start)
- [Breed REST API](#breed-rest-api) — endpoints, server structure, deploying to Freehostia, Postman
- [Configuration (`.env`)](#configuration-env)
- [Supabase setup](#supabase-setup)
- [Deploying the delete-account Edge Function](#deploying-the-delete-account-edge-function)
- [Running on the emulators from VS Code](#running-on-the-emulators-from-vs-code)
- [Architecture](#architecture)
- [Tests](#tests)
- [Regenerating icons and splash screens](#regenerating-icons-and-splash-screens)
- [Known limitations](#known-limitations)

---

## Quick start

```bash
flutter pub get
cp .env.example .env
flutter run
```

**The app runs with an empty `.env`.** With no `BREED_API_TOKEN` it serves nine
breeds from `assets/seed/breeds.json`, and with no Supabase keys it offers guest
mode only. That means every screen is reviewable before any credentials exist.
A banner on Explore says plainly when sample data is in use, so a demo is never
mistaken for the live catalogue.

Requires Flutter 3.27+ / Dart 3.6+ (developed against Flutter 3.47.4, Dart 3.13.3).

---

## Breed REST API

The breed catalogue is served by a small PHP REST API in [`server/`](server/),
deployed to Freehostia next to the MySQL database it reads. It replaces the
original single-script `dogbreeds.php` endpoint, which returned JSON labelled as
`text/html`, prefixed every body with `/*  */`, answered a missing token with
400 and let PUT/DELETE reach the handler.

### Endpoints

Base URL: `http://dogbreeds.mooo.com/api` (switch to `https://` once SSL is on).
Every request except `OPTIONS` needs `Authorization: Bearer <token>`.

| Method | Path | Returns |
| --- | --- | --- |
| `GET` | `/breeds` | Paginated collection |
| `GET` | `/breeds/{id}` | One breed |
| `HEAD` | either of the above | Headers only |
| `OPTIONS` | either of the above | `204`, `Allow`, CORS preflight — no token needed |

Query parameters for `GET /breeds` — all optional, all combinable:

| Parameter | Example | Meaning |
| --- | --- | --- |
| `search` | `search=golden` | Breed name contains, case-insensitive (max 100 chars) |
| `group` | `group=Toy,Sporting` | Breed group is any of, case-insensitive (max 20) |
| `country` | `country=Scotland` | Origin country is any of, case-insensitive (max 20) |
| `page` | `page=2` | 1-based page number (default 1) |
| `per_page` | `per_page=25` | 1–100 (default 50) |

**Collection response**

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

Links keep any `search`/`group`/`country` filters, so following `next` never
drops them. `GET /breeds/{id}` returns `{ "data": { ...breed }, "links": {...} }`.

**Errors** always have the same shape, with the HTTP status repeated in the body:

```json
{ "error": { "status": 404, "code": "breed_not_found", "message": "Breed 99 was not found." } }
```

| Status | `code` | When |
| --- | --- | --- |
| 200 | — | Success |
| 304 | — | `If-None-Match` matches the current `ETag` (no body) |
| 400 | `invalid_parameter` | Bad `page`, `per_page`, `search`, list length, or a non-integer id |
| 401 | `unauthorized` | Token missing or wrong. Sends `WWW-Authenticate: Bearer realm="PawPedia"` |
| 403 | `https_required` | Plain HTTP while `require_https` is on |
| 404 | `breed_not_found` / `route_not_found` | No such breed / no such path |
| 405 | `method_not_allowed` | `POST`, `PUT`, `PATCH`, `DELETE`. Sends `Allow: GET, HEAD, OPTIONS` |
| 500 | `server_misconfigured` / `internal_error` | Config missing or placeholder token; unexpected error (logged, never shown) |
| 503 | `database_unavailable` | MySQL unreachable. Sends `Retry-After` |

Every response is `Content-Type: application/json; charset=utf-8` with
`X-Content-Type-Options: nosniff` and no `X-Powered-By`. Successful reads carry
a weak `ETag` and `Cache-Control: private, max-age=300`.

### How the server is structured

```
server/
  .htaccess                 domain root: no directory listing, hide X-Powered-By
  api/
    .htaccess               routes /api/* to index.php, keeps the Authorization header
    index.php               front controller
  src/                      web access denied
    bootstrap.php           wires config → request → auth → router → controller
    Request.php             parsed method, path, query, headers
    Response.php            the only code that writes output; discards stray output first
    Router.php              404 vs 405 vs dispatch; OPTIONS preflight
    Auth.php                constant-time bearer token check
    Database.php            PDO with real prepared statements
    BreedRepository.php     all SQL; every value bound
    BreedController.php     /breeds and /breeds/{id}, validation, pagination, links
    ApiException.php        one exception type per HTTP error
  config/
    config.example.php      copy to config.php (gitignored); web access denied
  database/schema.sql       reference schema and recommended indexes
  postman/                  collection + Local and Freehostia environments
  tests/
    run_tests.php           end-to-end checks against a real server
    make_dev_db.php         SQLite copy of the catalogue for local work
    dev-router.php          .htaccess equivalent for php -S
```

Written for **PHP 7.4**, which is what Freehostia runs (7.4.33). No PHP 8 syntax.

### Deploying to Freehostia

1. **Create the config.** Copy `server/config/config.example.php` to
   `server/config/config.php`. Fill in the MySQL details (the same ones the
   current `connection.php` uses), the table name, and `api_token` — reuse the
   token the app and Postman already have. The API refuses to serve anything
   while `api_token` is empty or still `change-me`.
2. **Upload** through Freehostia's File Manager or FTP, into the domain's web
   root, so it sits alongside the existing files:
   ```
   public_html/            (the dogbreeds.mooo.com document root)
     .htaccess             ← server/.htaccess — merge if one already exists
     api/                  ← server/api/
     src/                  ← server/src/
     config/               ← server/config/  (config.php + .htaccess)
     auth.php  connection.php  dogbreeds.php   (old files, leave for now)
   ```
   Safer still: put `src/` and `config/` **outside** `public_html` and point
   `$appRoot` in `api/index.php` at them.
3. **Check it** from a terminal (or with the Postman collection below):
   ```bash
   curl -i -H "Authorization: Bearer YOUR_TOKEN" http://dogbreeds.mooo.com/api/breeds
   ```
   Expect `200`, `Content-Type: application/json; charset=utf-8`, and a body
   that starts with `{`.
4. **If `/api/breeds` returns 404** but `/api/index.php/breeds` works,
   `mod_rewrite` is unavailable on the plan. Set
   `BREED_API_BASE_URL=http://dogbreeds.mooo.com/api/index.php` — the API and
   the app both handle that form.
   **If the whole site returns 500** after uploading `.htaccess`, the host does
   not allow `Options` overrides; delete the `Options -Indexes` line.
5. **Retire the old endpoint** once the app works against the new one: delete
   `dogbreeds.php` and `auth.php`, and `connection.php` once nothing else uses it.
   (`auth.php` is also the likely source of the old `/*  */` prefix — it returns
   exactly that text, which suggests it sits outside the `<?php` tag.)
6. **Turn on HTTPS** when Freehostia allows it: uncomment the redirect in the
   root `.htaccess`, set `'require_https' => true`, and change the app's
   `BREED_API_BASE_URL` to `https://`. Until then the bearer token travels
   unencrypted, which is the API's biggest remaining weakness.

### Fixing the photo links

Every `picture` in the live database points at `via.placeholder.com`, a service
that shut down — the domain no longer resolves, so no client can load those
images. The app degrades to a paw placeholder, which is correct behaviour but
not what you want on screen.

[`server/database/fix_breed_data.sql`](server/database/fix_breed_data.sql)
replaces all ten with free dog.ceo photos (each URL verified to return a real
JPEG) and corrects row 9's name from "DChihuahua" to "Chihuahua". Paste it into
phpMyAdmin's SQL tab. It writes only the `picture` and `breed_name` columns of
rows matched by id, and adds or deletes nothing.

### DNS: FreeDNS → Freehostia

`dogbreeds.mooo.com` needs an **A record** in FreeDNS pointing at the Freehostia
server's IP (currently `162.210.102.232`), and the domain must be added as a
hosted domain in Freehostia's control panel. Both are already in place — the
host serves the site. If Freehostia ever moves the account to another server,
update the A record.

### Running the API locally

Uses XAMPP's PHP and a SQLite copy of the catalogue; no MySQL needed.

```bash
php server/tests/make_dev_db.php
```

```powershell
$env:PAWPEDIA_CONFIG="$PWD\server\database\dev\config.php"
php -S 127.0.0.1:8080 -t server server/tests/dev-router.php
```

Then `GET http://127.0.0.1:8080/api/breeds` with `Authorization: Bearer dev-token`.
To point the app on the Android emulator at it, set
`BREED_API_BASE_URL=http://10.0.2.2:8080/api` and `BREED_API_TOKEN=dev-token`
(`10.0.2.2` is the emulator's name for your computer; debug builds allow
cleartext to it, release builds do not).

### Postman

Import everything in [`server/postman/`](server/postman/): the collection and
both environments. Pick **PawPedia - Local** or **PawPedia - Freehostia**, set
`token` on the Freehostia one (it is a *secret* variable — do not export or
share the environment once it holds the real value), and run the collection.
Its tests check status codes, the `{data, meta, links}` shape, the error shape,
`Content-Type`, that nothing precedes the JSON, 304 on a repeated request, and
401/404/400/405 on the error cases.

### Why the app still filters on the device

`BreedProvider` fetches the whole catalogue once — following `links.next` across
pages — and filters in memory. The Explore chips show a count per group, which
needs every breed anyway; the catalogue is small and static; and local filtering
makes the debounced search instant. The API's `search`/`group`/`country`
parameters exist for Postman and any other client.

---

## Configuration (`.env`)

`.env` is gitignored. `.env.example` is the committed template.

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key

BREED_API_BASE_URL=http://dogbreeds.mooo.com/api
BREED_API_TOKEN=your-static-bearer-token
```

Loaded at startup by `flutter_dotenv` via
[`AppConfig`](lib/core/app_config.dart). `.env` is declared as an asset in
`pubspec.yaml`, which is what makes it readable on a real device.

**One mechanism, not two.** `flutter_dotenv` is used *instead of*
`--dart-define-from-file`, so there is exactly one place configuration comes
from and nothing to keep in sync between the launch configs and the CLI.

> **Never put the `service_role` key in `.env`.** Everything in this file ships
> inside the app bundle and can be read by anyone who downloads it. The
> `service_role` key belongs only in the Edge Function's server-side
> environment. Use the **anon** / publishable key here.

---

## Supabase setup

1. Create a project at [supabase.com](https://supabase.com).
2. Copy the project URL and the **anon** key from *Project Settings → API* into
   `.env`.
3. Run [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql)
   in the SQL editor. It creates:
   - `public.profiles` (1:1 with `auth.users`) and `public.favorites`
   - the `handle_new_user` trigger that seeds a profile row on sign-up
   - **Row Level Security enabled on both tables, with all four policies each**
   - the public-read `avatars` storage bucket with owner-only write policies

`favorites.breed_id` is deliberately **not** a foreign key: breeds live in MySQL
on another host. Each row stores a display snapshot (name, group, picture) so
the Favorites grid renders from one query instead of N calls to the breed API.

### Verifying RLS actually works

This is worth doing once, by hand — RLS is the only thing standing between the
public anon key and every user's data.

1. Sign up as `a@example.com` on one emulator and save a favourite.
2. Sign up as `b@example.com` on a second emulator (or after logging out).
3. As user B, confirm the Favorites tab is empty and Profile shows B's name.

If B can see A's rows, RLS is not enabled — re-run the migration.

### Email confirmation

If *Authentication → Providers → Email → Confirm email* is on, `signUp` returns
no session and the app shows a **Check your inbox** screen. Turn it off for
faster local testing.

---

## Deploying the delete-account Edge Function

A client cannot delete its own auth user — that needs the `service_role` key,
which must never ship in an app. The function verifies the caller's own JWT and
deletes only that user; `profiles` and `favorites` then cascade.

```bash
supabase login
supabase link --project-ref your-project-ref
supabase functions deploy delete-account
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected by the platform, so
no secrets need setting by hand. Until this is deployed, the Delete Account
screen shows a clear error rather than failing silently.

---

## Running on the emulators from VS Code

### Launching an emulator

Command Palette (`Ctrl+Shift+P`) → **Flutter: Launch Emulator** → pick
**Pixel 6**. The *Devices & AVDs* sidebar extension can start it too, without
opening Android Studio.

From the terminal:

```bash
flutter emulators --launch Pixel_6
```

### Switching the active device

Click the device name in the **bottom-right of the VS Code status bar**, or use
Command Palette → **Flutter: Select Device**.

### Run configurations

`F5` runs the last-used configuration. Pick one from the Run and Debug panel:

| Configuration | Use it for |
| --- | --- |
| **PawPedia (debug)** | Day-to-day work. Hot reload. |
| **PawPedia (profile)** | Breed-list scroll performance. Debug builds are not representative — profile on the Pixel 6, which is the slower target. |
| **PawPedia (release)** | Final check before handing a build over. |

### About the "iPhone 15 Pro" emulator

The AVD named `iPhone_15_Pro` on this machine is **an Android emulator**
(API 34), not an iOS simulator, and its `hw.lcd` is set to 393×852 *pixels* at
460 dpi — which yields roughly a 137×297 dp viewport, far smaller than a real
iPhone 15 Pro. Layouts will overflow there.

To make it emulate the real device, set in its `config.ini`:

```ini
hw.lcd.width = 1179
hw.lcd.height = 2556
hw.lcd.density = 460
```

That gives the correct 393×852 dp logical viewport.

**Real iOS builds need macOS with Xcode.** See
[Known limitations](#known-limitations).

---

## Architecture

Feature-first, with `provider` (`ChangeNotifier`) for state throughout.

```
lib/
  core/        config, theme, validators, networking, error mapping, Supabase bootstrap
  models/      Breed, Profile, FavoriteBreed  (fromJson / toJson)
  services/    breed_api, auth, profile, favorites, local_favorites_store
  providers/   auth, breed, favorites, profile, stats
  screens/     one folder per screen
  widgets/     shared components
supabase/
  migrations/0001_init.sql
  functions/delete-account/index.ts
server/        PHP REST API for breeds (see "Breed REST API")
```

### Two data sources, kept separate

| | Breeds | Users, auth, favourites |
| --- | --- | --- |
| Backend | PHP REST API + MySQL on Freehostia | Supabase (PostgreSQL) |
| Access | Read-only, static bearer token | Supabase Auth, per-user JWT |
| Entry point | `BreedApiClient` | `SupabaseBootstrap` |

### Navigation

[`AuthGate`](lib/screens/auth_gate.dart) is the only place navigation depends on
auth. `AuthProvider` is driven by `supabase.auth.onAuthStateChange`, so a
session expiring — or a sign-out on another device — moves the app without any
screen pushing or popping.

```
splash (restoring session)
  ├── signed out + never onboarded → Onboarding → Login / Sign Up
  ├── signed out + onboarded       → Login / Sign Up
  └── signed in OR guest           → Main shell
                                       Explore · Search · Favorites · Profile
```

### Guest mode

Guests get the real feature set, not a disabled one. Browsing works (it only
needs the breed token) and favourites are saved to `SharedPreferences` in the
same JSON shape as the Supabase rows, so `FavoritesProvider` treats the two
stores interchangeably. Every surface that shows guest favourites says they live
on one device.

### Security notes

- Anon key only in the app; `service_role` lives solely in the Edge Function.
- RLS on both tables, all four policies each.
- Cleartext HTTP scoped to one domain, never global (debug builds add `10.0.2.2`
  for a local API).
- The breed client only follows pagination links on the same scheme, host and
  port, so a misbehaving server cannot redirect the bearer token elsewhere.
- `changePassword` re-verifies the current password with `signInWithPassword`
  first. `updateUser(password:)` alone will change the password of anyone
  holding a live session without asking for the old one — on an unlocked phone
  that is an account takeover.
- `updateEmail` does not take effect until the link in the new mailbox is
  clicked, and the UI says so rather than implying it is done.

---

## Tests

```bash
flutter analyze
flutter test                       # app: models, API client, widgets
php server/tests/run_tests.php     # API: end-to-end HTTP checks
```

**App.** `Breed.fromJson` against string-typed ids, null columns, the literal
string `"null"` and messy temperaments; the breed client's paths, bearer header,
pagination, same-origin link check and status-code handling (against a mocked
server); widget tests at 2× text scale.

**API.** Starts PHP's built-in server on a throwaway SQLite database and checks
authentication and challenges, JSON content type and clean bodies, pagination
and links, filtering (including literal `%`, `_` and `!` in searches), 400/404
cases, 405 with `Allow` for every write method, OPTIONS preflight, HEAD, ETag and
304, the `/api/index.php/...` form, a placeholder token (500), an unreachable
database (503, no driver message leaked), and stray output before `<?php` being
discarded.

**Client against the real API.** Skipped unless pointed at a server:

```powershell
$env:PAWPEDIA_API_BASE_URL="http://127.0.0.1:8080/api"; $env:PAWPEDIA_API_TOKEN="dev-token"
flutter test test/breed_api_live_test.dart
```

Use the Freehostia URL and your token to check the deployed API the same way.

### What was verified on the Pixel 6 emulator

Every screen was walked in guest mode with seed data: onboarding, login, Explore,
Breed Detail, Search (including multi-select filters), Favorites and Profile.
Favouriting, removing, filtering and the stat counters all work end to end.

Re-run at **1.5× system font** (`adb shell settings put system font_scale 1.5`):
**zero `RenderFlex` overflows** anywhere in the app. Long captions wrap, the
favourites tile lets the photo shrink so the caption always fits, and the
bottom-nav labels hold.

Scroll performance, measured in profile mode from the VM service timeline over
ten full-list swipes:

| | median | p90 | p99 | max | frames over 16.67 ms |
| --- | --- | --- | --- | --- | --- |
| UI thread | 3.0 ms | 7.1 ms | 11.1 ms | 15.6 ms | **0 (0%)** |
| Raster thread | 15.1 ms | 20.1 ms | 28.1 ms | 30.3 ms | 31% |

The UI thread never misses a frame — widget build is 0.11 ms median, which is
`ListView.builder` doing its job. The raster figures are the **emulator's
software GL renderer**, not a real GPU, and should not be read as device
performance; re-measure on physical hardware before drawing conclusions.

Decoding images at their displayed size (`memCacheWidth` in
[`NetworkBreedImage`](lib/widgets/network_breed_image.dart)) measurably helped
even so — raster p99 fell from 34.2 ms to 28.1 ms, max from 43.2 ms to 30.3 ms,
and `saveLayer` calls halved. Without it, a 1600×1200 photo was being decoded in
full to paint a 68 dp thumbnail, once per card.

---

## Regenerating icons and splash screens

Source art is in `assets/icon/` and `assets/splash/`.

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## Known limitations

- **iOS is unverified.** This was developed on Windows, where no iOS simulator
  exists. All iOS configuration ships and is correct by inspection — ATS
  exception, camera and photo-library usage strings, Cupertino page transitions
  (which also restore swipe-from-left back), launcher icons, splash — but none
  of it has been built or run. Do that on a Mac with Xcode before shipping.
- **Onboarding illustrations are low resolution.** They were extracted from the
  supplied design PDF at roughly 330×250, so they are soft on a 3× screen.
  Replace the three files in `assets/illustrations/` with full-resolution
  exports when they are available.
- **The design mockups show Google and Apple sign-in buttons.** These are
  deliberately not implemented: the written specification rules out social login
  entirely. "Continue as Guest" sits where they were.
- **Notifications, Privacy, About and Help** are informational dialogs, not
  full screens. The specification lists them as settings rows without defining
  destinations.
