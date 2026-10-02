# VINII Partner

The restaurant staff app on the Proviyaa platform: marketplace **delivery orders** (ring, accept, ready, out, delivered), a **phone POS**, the **menu**, and **Storefront Studio** for the guest swipe-to-order experience. One Flutter runtime serves every organization; each restaurant's look and features are data.

Plan, flows and screens: [`../docs/PLAN_VINII_PARTNER_FLUTTER.md`](../docs/PLAN_VINII_PARTNER_FLUTTER.md). Binding data rules: [`../docs/PLATFORM_CONTRACT_ALIGNMENT.md`](../docs/PLATFORM_CONTRACT_ALIGNMENT.md).

## Run

```bash
cp .env.local.example .env.local   # fill SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY
./tool/run_local.sh                # add -d chrome, -d <simulator id>, …
```

The launcher passes only whitelisted keys as `--dart-define` and refuses anything else, so a service-role key can never be compiled into the app. There is no sample data: the app shows only what is in the Supabase project it points at.

Against the local One Local dev database (docker; start OrbStack, then the One Local stack): `VINII_ENV_FILE=.env.localdb ./tool/run_local.sh`, or the `vinii-partner-local` entry in `.claude/launch.json` (port 8094). `python3 tool/local_db/seed_test_logins.py` creates one login per staff role there (owner, admin, manager, cashier, captain, kitchen, viewer, and one with no restaurant); the shared test password is `TEST_PASSWORD` in that file. The default `.env.local` points at the live database: do not use the test logins there. That replica has no row-level-security policies; `tool/local_db/emulate_production_rls.sql` copies production's member policies onto it (local only; undo script alongside).

## Design gallery

`tool/gallery/main.dart` mounts the guest storefront on clearly synthetic fixtures (dishes and prices copied from the two reference boards in `docs/reference/`), with no login, no database and no network. It is how guest screens are reviewed without touching any restaurant's data, and it is never part of a shipped build.

```bash
flutter run -d web-server --web-port 8091 -t tool/gallery/main.dart
```

Open `http://localhost:8091/?t=bistro` (also `artisan`, `fresh`). Optional: `table=12` (stands for scanning that table's QR code), `pay=0` (hide online payment), `coupons=0`, `nearby=0` and `similar=0` (hide those three), `fakecf=1` (run the real web checkout code against a pretend Cashfree script instead of the simulated dialog). The gallery's pretend coupon codes are `SAVE10` (10% off from ₹300), `FLAT50` (₹50 off from ₹250) and `WELCOME` (₹30 off).

The invented restaurants and the stand-in order and payment services live in `tool/gallery/gallery_kit.dart` (plain Dart, so the test runner can load it too); `main.dart` only adds the browser-only part.

### Pictures without a browser

When a browser is not to hand, two test files draw the real screens to PNG files with the bundled Inter font and the Material icons. Neither writes anything unless `VISUAL_OUT` names a folder, so a normal `flutter test` skips them.

```bash
# guest storefront: dark bistro and cream bakery, phone and wide screen
VISUAL_OUT=/tmp/guest-shots flutter test tool/gallery/guest_review_test.dart
# staff app: orders, sell, payment, bill settings, team, table codes; each role
VISUAL_OUT=/tmp/staff-shots flutter test tool/gallery/staff_review_test.dart
```

Remote fonts are off in tests, so headings show in Inter rather than the display face a storefront picked (and the bakery's handwritten headline is plain). Layout, colour and hierarchy are true to the app; type personality is not.

## Check

```bash
flutter analyze
flutter test
```

## Layout

- `lib/config` build settings · `lib/domain` models and pure maths (bill parity with the OS, storefront definition, guest catalog, application definition)
- `lib/data` the `Backend` contract and `live/` (Supabase + One Local partner API)
- `lib/application` session lifecycle, inbox and ring, guest gateway, feature controllers
- `lib/presentation` screens by feature (`orders`, `pos`, `menu`, `studio`, `guest`, …), theme, shared widgets
- `test/support/fake_backend.dart` an empty test double, used only by tests
