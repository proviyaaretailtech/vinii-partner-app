# VINII Partner

The restaurant staff app on the Proviyaa platform: marketplace **delivery orders** (ring, accept, ready, out, delivered), a **phone POS**, the **menu**, and **Storefront Studio** for the guest swipe-to-order experience. One Flutter runtime serves every organization; each restaurant's look and features are data.

Plan, flows and screens: [`../docs/PLAN_VINII_PARTNER_FLUTTER.md`](../docs/PLAN_VINII_PARTNER_FLUTTER.md). Binding data rules: [`../docs/PLATFORM_CONTRACT_ALIGNMENT.md`](../docs/PLATFORM_CONTRACT_ALIGNMENT.md).

## Run

```bash
cp .env.local.example .env.local   # fill SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY
./tool/run_local.sh                # add -d chrome, -d <simulator id>, …
```

The launcher passes only whitelisted keys as `--dart-define` and refuses anything else, so a service-role key can never be compiled into the app. There is no sample data: the app shows only what is in the Supabase project it points at.

Against the local One Local dev database (docker): `VINII_ENV_FILE=.env.localdb ./tool/run_local.sh`. That replica has no row-level-security policies; `tool/local_db/emulate_production_rls.sql` copies production's member policies onto it (local only; undo script alongside).

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
