# PawPedia

A friendly dog-breeds directory for iOS and Android, built with Flutter.

Browse, add, edit and delete breeds from a PHP/MySQL catalogue served by a custom
REST API, search and filter them, and keep a list of favourites. Live dog photos
come from the [Dog CEO API](https://dog.ceo/dog-api/). Accounts, profiles and
favourites are stored in Supabase. Sign-in is email and password, with a fully
working guest mode.

## Features

- **Explore** breeds by group, with a Random Dog card
- **Search** by name with group and country filters
- **Breed detail** with a photo gallery from Dog CEO
- **Add, edit and delete** breeds through the REST API
- **Favourites**, synced to your account or saved on the device in guest mode
- **Profile** with avatar, name, email and password changes, and account deletion

---

## Quick start

```bash
flutter pub get
cp .env.example .env
flutter run
```

The app runs even with an empty `.env`. Without a breed API token it shows nine
sample breeds from `assets/seed/breeds.json` (with a banner saying so), and
without Supabase keys it offers guest mode only.

Requires Flutter 3.27+ / Dart 3.6+.

---

## Configuration

`.env` is gitignored; `.env.example` is the template.

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key

BREED_API_BASE_URL=http://dogbreeds.mooo.com/api
BREED_API_TOKEN=your-static-bearer-token
```

> Only use the Supabase **anon** key here. Everything in `.env` ships inside the
> app, so the `service_role` key must never go in it.

---

## APIs

### Breed REST API

A PHP API in [`server/`](server/), hosted on Freehostia with MySQL. Every
request needs `Authorization: Bearer <token>`.

| Method | Path | Does |
| --- | --- | --- |
| `GET` | `/breeds` | List breeds (supports `search`, `group`, `country`, `page`, `per_page`) |
| `GET` | `/breeds/{id}` | Read one breed |
| `POST` | `/breeds` | Create a breed |
| `PUT` | `/breeds/{id}` | Update a breed |
| `DELETE` | `/breeds/{id}` | Delete a breed |

Full reference, deployment steps, local setup and Postman collection:
**[server/README.md](server/README.md)**.

### Dog CEO (third-party)

A free public API of dog photos, with no key needed.

| Endpoint | Used for |
| --- | --- |
| `GET /breeds/image/random` | Random Dog card on Explore |
| `GET /breeds/list/all` | Matching our breed names to Dog CEO's |
| `GET /breed/{breed}/images/random/{n}` | Photo gallery on Breed Detail and photo suggestions on the breed form |

---

## Supabase setup

1. Create a project at [supabase.com](https://supabase.com) and copy the project
   URL and **anon** key into `.env`.
2. Run [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql)
   in the SQL editor. It creates the `profiles` and `favorites` tables with Row
   Level Security, a trigger that creates a profile on sign-up, and the
   `avatars` storage bucket.
3. Deploy the delete-account function (it needs the `service_role` key, which
   must stay on the server):
   ```bash
   supabase login
   supabase link --project-ref your-project-ref
   supabase functions deploy delete-account
   ```

If *Confirm email* is turned on in Supabase, new users see a "Check your inbox"
screen after signing up.

---

## Architecture

Feature-first structure, with `provider` for state management.

```
lib/
  core/        config, theme, validators, networking, error handling
  models/      Breed, BreedDraft, DogPhoto, Profile, FavoriteBreed
  services/    breed API, dog photos, auth, profile, favourites
  providers/   auth, breed, favorites, profile, stats
  screens/     one folder per screen
  widgets/     shared components
server/        PHP REST API for breeds
supabase/      database migration and delete-account Edge Function
```

| | Breeds | Users and favourites | Dog photos |
| --- | --- | --- | --- |
| Backend | PHP + MySQL (Freehostia) | Supabase | Dog CEO |
| Access | Full CRUD, bearer token | Per-user login | Read-only, no key |

---

## Tests

```bash
flutter analyze
flutter test                       # models, API clients, widgets
php server/tests/run_tests.php     # API end-to-end checks
```

To run the app's client tests against a real API server:

```powershell
$env:PAWPEDIA_API_BASE_URL="http://127.0.0.1:8080/api"; $env:PAWPEDIA_API_TOKEN="dev-token"
flutter test test/breed_api_live_test.dart
```

This creates, updates and deletes one temporary breed.

---

## Icons and splash screens

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## Known limitations

- **The breed API token ships inside the app**, so anyone who extracts it can
  change the catalogue. A production version would require per-user login for
  writes.
- **iOS has not been built or tested.** It was developed on Windows; iOS builds
  need a Mac with Xcode.
- **Onboarding illustrations are low resolution** and should be replaced with
  full-size exports.
- **No Google or Apple sign-in.** The project specification rules out social
  login, so "Continue as Guest" takes their place.
- **Notifications, Privacy, About and Help** open simple dialogs rather than
  full screens.
