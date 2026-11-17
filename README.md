# StockQR

Offline-first inventory management app built with Flutter, Dart and SQLite.
Each user manages their own stock, every product gets a unique QR code, and an
administrator supervises accounts and permissions. No network is ever needed.

**Status: Part 1 complete.** Camera scanning, stock movements and sales are
reserved for Part 2 (the database and permission checks are already prepared).

The interface is in French.

## Run it

Requirements: Flutter 3.47+ / Dart 3.13+, and an Android device or emulator
(the target platform).

```bash
flutter pub get
flutter run            # pick your Android device
flutter analyze
flutter test           # 69 tests, runs on the host, no device needed
```

Default administrator (created the first time the database is opened):

| Username | Password    |
|----------|-------------|
| `admin`  | `Admin@123` |

Change it from **Profil → Changer le mot de passe**. Only a salted hash is stored.

Desktop (Windows/Linux/macOS) also works for development: `main.dart` switches
`sqflite` to its FFI backend there. Windows additionally needs the Visual Studio
C++ workload.

## Architecture

```
lib/
  main.dart               composition root: database, repositories, services
  app.dart                MaterialApp + AuthGate (login vs. signed-in shell)
  core/
    constants/            colours, spacing tokens, app constants
    theme/                the single ThemeData built from the palette
    errors/               AppException hierarchy (user-facing French messages)
    utils/                validators, formatters, PBKDF2 password hasher
  data/
    database/             AppDatabase: schema, versioned migrations, admin seed
    models/               AppUser, UserPermissions, Product, stats
    repositories/         SQL access (user, product, stats); every product query
                          is scoped by user_id
  services/               business rules: auth, permissions, products, admin,
                          QR payload + printable label rendering
  providers/              ChangeNotifier state (Provider): auth, products,
                          dashboard, admin
  screens/                auth, dashboard, products, movements, profile, admin,
                          shell (bottom navigation)
  widgets/                reusable UI: buttons, fields, stat tiles, empty states
```

Rules worth knowing:

- **Business rules live in services, not widgets.** `ProductService` re-reads
  the account and permissions from SQLite on every write, so a stale screen
  cannot bypass a quota or an expired subscription. `AdminService` verifies
  that the caller is an administrator on every call.
- **Per-session state.** `HomeShell` creates the product/dashboard/admin
  providers and owns a nested `Navigator`; logging out disposes all of it.
- **Sessions.** Only the user id is stored in `shared_preferences`. On launch
  the account is reloaded and the session dropped if it was deactivated.

### Database (SQLite, schema version 1)

`users`, `user_permissions`, `products`, `stock_movements`, `sales`, `alerts`,
with foreign keys (`ON`), CHECK constraints, and indexes. A product SKU is
unique per user (case-insensitive); `qr_identifier` is globally unique.

Migrations: bump `AppDatabase.schemaVersion` and add the next function to
`_migrations`. `onUpgrade` replays only the missing steps, so existing data is
preserved. Dates are stored as UTC ISO-8601 text.

Design choices: `sales.product_id` is `ON DELETE SET NULL` so deleting a product
never erases revenue already earned. `sales` also has a `status`
(`completed`/`cancelled`) so only completed sales count as income.

### QR codes

The QR encodes `stockqr:v1:<uuid>`: a versioned payload with a random,
stable identifier, never product data. Editing a product never invalidates a
printed label; Part 2 resolves the scanned id with
`ProductRepository.getByQrIdentifier`. The QR screen can share a printable PNG
label (QR, quiet zone, name, SKU).

### Permissions and account states

| Situation              | Behaviour |
|------------------------|-----------|
| Account deactivated    | Cannot sign in; an open session is refused on writes. **Data is kept.** |
| Subscription expired   | Signs in, read-only, explanatory banner; writes are refused by the services. |
| Product quota reached  | Creating is refused (atomically, inside the insert transaction). Editing and deleting still work. |
| Scan disabled          | `PermissionService.assertCanScan` refuses (to be called by Part 2). |
| Administrator          | Never limited by quota, subscription or scan flag; cannot be deactivated. |

New accounts get 50 products, scanning enabled and a 365-day subscription
(constants in `app_constants.dart`); the administrator edits them per user.

### Dashboard figures

All computed in SQL from the real rows (`StatsRepository`):

- **Revenus du mois**: completed sales of the current calendar month (actual).
- **Valeur du stock**: Σ quantity × purchase price (what the stock cost).
- **Revenu potentiel**: Σ quantity × selling price (if everything sold).
- **Quantité totale**, **En stock** (quantity > 0), **Manquants** (quantity = 0).

With no sales the income is `0`, nothing is invented.

## Design

Palette (the only colours used, plus lighter/darker tints of them for borders
and secondary text): forest `#203A34`, apricot `#D68C65`, parchment `#F2EBDD`,
moss `#A7B59A`, charcoal `#252B28`. Headlines and key figures use the platform
serif; body text the platform sans. Corner radius is 6/10 px, one icon family
(Material outlined) used only in navigation and inputs. The QR code itself is
drawn charcoal on pure white for scanner contrast.

## Tests

`flutter test` runs 69 tests over an in-memory SQLite database
(`sqflite_common_ffi`):

- `auth_test`: hashing, default admin, registration, duplicates, login,
  password change, **session persistence across a restart**.
- `permissions_test`: quota, expiry, deactivation, scan gate, admin-only
  operations.
- `product_test`: CRUD, validation, SKU uniqueness, **user data isolation**,
  search/filter/sort, **QR uniqueness and stability**.
- `stats_database_test`: **dashboard figures from real rows**, month
  boundaries, **admin global statistics**, constraints, cascade, reopening a
  database file.
- `app_flow_test`: widget tests driving the real UI (login errors, admin and
  user sign-in, registration, creating a product and seeing the dashboard
  update, restart and logout).

## Implemented in Part 1

- Registration, login (username or e-mail), show/hide password, validation,
  duplicate prevention, persistent session, logout, change password.
- Default administrator with hashed password.
- Bottom navigation: Accueil, Produits, Mouvements, Profil (+ Admin).
- Dashboard with the six figures, recent products, empty states, add shortcut.
- Product CRUD, search by name/code/barcode, category filter, sorting,
  stock status, delete confirmation, per-user isolation, quota display.
- Unique QR per product, QR view, shareable PNG label, copy payload.
- Administration: global statistics, searchable account list, per-user
  figures, activate/deactivate, scan permission, product maximum,
  subscription end date.
- Versioned migrations; tables for movements, sales and alerts already created.

## Reserved for Part 2

- Camera QR/barcode scanning (`mobile_scanner`) and the scan screen.
- Recording stock movements (entries, exits, adjustments) and sales.
- Alerts generation and display (low stock, out of stock).
- CSV export (the `csv` package is already a dependency).
- The Mouvements tab currently shows an informational empty state only.

## Known limitations

- Only the Android build and the test suite were verified in the environment
  used to write this (a debug APK compiles). No emulator or physical device
  was available, so the UI was not exercised on a real screen; the Windows
  desktop build needs the Visual Studio C++ toolchain, which was not installed.
- The "Share" button uses the platform share sheet and was not run on a device.
- Authentication is local (university project): there is no password reset
  flow and no server-side verification.
