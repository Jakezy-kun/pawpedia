# PawPedia

A friendly dog-breeds directory for iOS and Android, built with Flutter.

Browse breeds from a read-only PHP/MySQL catalogue, search and filter them, and
keep a shortlist. Accounts, profiles and favourites are backed by Supabase.
There is no Firebase and no social login — email and password only, plus a
fully working guest mode.

---

## Contents

- [Quick start](#quick-start)
- [Breed API reality check](#breed-api-reality-check) — **read this before debugging network issues**
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

## Breed API reality check

The original specification described the catalogue as
`GET https://dogbreeds.mooo.com/api/breeds`. That is not how the deployed server
behaves. Verified against the live host:

| Expected | Actual |
| --- | --- |
| `https://` on port 443 | **Port 443 does not answer.** The connection times out; only port 80 serves. |
| `/api/breeds` | **404.** The document root exposes `auth.php`, `connection.php` and `dogbreeds.php`. The endpoint is `/dogbreeds.php`. |
| Clean JSON body | Every response is **prefixed with `/*  */`**, injected by Freehostia's free tier. `jsonDecode` throws on it. |

The app is built against the server as it actually is:

- `BREED_API_BASE_URL` defaults to `http://dogbreeds.mooo.com` and
  `BREED_API_BREEDS_PATH` to `/dogbreeds.php`.
- [`JsonSanitizer`](lib/core/network/json_sanitizer.dart) trims each body back to
  its first `{` or `[` before decoding. This is covered by tests, because it is
  the single most likely runtime failure and its symptom (a `FormatException`)
  points nowhere near its cause.
- Cleartext HTTP is permitted **for that one host only** — via
  [`network_security_config.xml`](android/app/src/main/res/xml/network_security_config.xml)
  on Android and a scoped `NSExceptionDomains` entry on iOS. A blanket
  `usesCleartextTraffic` / `NSAllowsArbitraryLoads` would have weakened every
  other connection the app makes, including Supabase.

Auth behaves as specified: a missing header returns
`400 {"error":"Authorization header is missing"}` and a bad token returns `401`.

### If you fix the server

Set `Options -Indexes` in `.htaccess` (the document root is currently browsable,
which publicly lists your PHP filenames), add HTTPS, and route `/api/breeds`.
Then update `.env`:

```env
BREED_API_BASE_URL=https://dogbreeds.mooo.com
BREED_API_BREEDS_PATH=/api/breeds
```

and delete the two cleartext exceptions. No Dart changes are needed.

### Why filtering happens on the device

`BreedProvider` fetches the whole catalogue once and filters in memory. This is
not a shortcut:

- The Explore chips show a count per group, which needs the full catalogue anyway.
- Whether `dogbreeds.php` honours `?search=`, `?group=` and `?country=` could not
  be verified without a token, so depending on it would make correctness rest on
  an unknown.
- A breeds directory is a small, static dataset, and local filtering makes the
  debounced search instant.

Server-side parameters are still implemented in `BreedApiClient` and used for
`?id=` on Breed Detail, falling back to the cache if the server ignores them.

---

## Configuration (`.env`)

`.env` is gitignored. `.env.example` is the committed template.

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key

BREED_API_BASE_URL=http://dogbreeds.mooo.com
BREED_API_BREEDS_PATH=/dogbreeds.php
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
```

### Two data sources, kept separate

| | Breeds | Users, auth, favourites |
| --- | --- | --- |
| Backend | PHP + MySQL on Freehostia | Supabase (PostgreSQL) |
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
- Cleartext HTTP scoped to one domain, never global.
- `changePassword` re-verifies the current password with `signInWithPassword`
  first. `updateUser(password:)` alone will change the password of anyone
  holding a live session without asking for the old one — on an unlocked phone
  that is an account takeover.
- `updateEmail` does not take effect until the link in the new mailbox is
  clicked, and the UI says so rather than implying it is done.

---

## Tests

```bash
flutter test
flutter analyze
```

Covers the two places most likely to break against a real backend: the
`/*  */` prefix stripping, and `Breed.fromJson` against string-typed ids, null
columns, the literal string `"null"`, and messy comma-separated temperaments.
Widget tests check a breed card at 2× system text scale.

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
