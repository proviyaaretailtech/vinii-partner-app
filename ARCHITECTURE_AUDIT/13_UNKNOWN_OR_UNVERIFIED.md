# 13 — Unknown or unverified

**Scope.** `vinii_partner/` at `da0a823`. This audit read source code and migration files. It did **not** connect to any database, run the app, or call any API. Everything below is either unknown or was not checked.

## Production database
1. **Whether production matches the ledgers.** The only production evidence is the column-list snapshot of 2026-09-22 (`OL-ui/docs/CENTRAL_DB_MAP.md`). It matches the ledger columns for `orders`, `order_items`, `kot_tickets`, `order_events`, `payments`, `org_bill_settings`, `org_users`, `roles`, `role_module_access` and `org_modules`. It gives policy **counts** only, not policy text.
2. **Production functions after 2026-09-22.** The snapshot reports 29 functions without naming them. No migration on any branch defines `pos_place_order`, `pos_record_payment`, `pos_set_order_status`, `pos_adjust_bill` or `pos_issue_table_qr`. `vinii_publish_storefront` exists only in the unapplied draft (item 3). Whether someone created any of them by hand in production is unknown.
3. **Whether `vinii_storefronts` and `vinii_storefront_versions` exist in production.** Only the unapplied draft `0021_vinii_storefronts.sql` (Repo-1- branch `feat/experience-cms`) creates them.
4. **Which One Local migrations (OL-ui 0021–0029) are applied in production.**
   - Earlier documents say 0021–0024 are live and 0028 was pending.
   - 0025–0027 and 0029 (dispatch, `delivery_jobs`) are unknown.
   - The snapshot's `ol_orders` column list (2026-09-22) predates 0022's added columns. Whether production now has `organization_id`, `restaurant_deadline`, `prep_minutes`, `gst` and `cancel_reason` is unknown.
5. **The members of the realtime publication in production.**
6. **The `organizations.type` enum in production.**
   - The ledger defines `org_type` as (`franchise`, `investor`).
   - The app treats `type` as a business kind and falls back to `'restaurant'` (`live_workspace.dart:53`).
   - Whether production's enum was widened is unknown.
7. **The `item-images` storage policies in production** (ledger: any signed-in user, whole bucket).

## Other applications that write the same tables (not audited)
8. **The Windows POS** (`proviyaa-pos`): how and whether it writes `orders`, `order_items`, `kot_tickets` and `payments` in the shared database (its own decision records mention PowerSync and an outbox). It is the most likely writer of KOT `preparing` and of dine-in status moves. **Not inspected in this audit.**
9. **The Repo-1- web console** (`apps/web/src/lib/pos.ts`, for example `setKotStatus` and `settleOrder`): its writes to the same tables were noted in earlier alignment work but not re-read here.
10. **One Local's dispatch code** (`OL-ui/frontend/server/dispatch.ts`): only the function names called on accept and reject were confirmed, not their database effects.
11. **One Local's partner API at runtime:**
    - The route-to-function mapping was read in source (`restaurant.ts`, `partner.ts`, `app/api/partner/*`).
    - The deployed version, and whether it matches source, is unknown.
    - `PATCH /outlet` (`restaurant.ts:105-115`) and `notifyNewOrder` were read only in outline.

## Behaviour that depends on missing server functions
12. Everything after "Send to kitchen", "Save & hold", "Charge", "Remove service charge", "Issue code" and "Publish" on the phone. The app's expected response shapes are documented (`live_pos.dart:287-348`; `docs/PLATFORM_CONTRACT_ALIGNMENT.md` §4), but what the database would do cannot be verified.
13. Whether a server would honour `coupon_code`, `waive_service_charge`, `scheduled_for` and `fire_kot` (sent in `pos_place_order`). The `orders` table has no columns for a coupon, a waiver or `scheduled_for`.

## Client details not exercised
14. **Where `supabase_flutter` persists the session on each platform.** Not checked.
15. **Cashfree checkout.** Its own comment says it was "not yet run against Cashfree's sandbox" (`cashfree_checkout_web.dart:19-22`). It is unreachable today in any case.
16. **Tests.** `vinii_partner/test/` was not run for this audit. It uses a fake backend (`test/support/fake_backend.dart`) and does not touch a database.
