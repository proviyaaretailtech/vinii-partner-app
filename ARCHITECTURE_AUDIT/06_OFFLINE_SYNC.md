# 06 — Offline and sync

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`.

## Summary: online-only, with no sync engine

The app cannot take an order, record a payment or change anything while offline. Every write is a live network call.

| Item | Finding | Evidence |
| --- | --- | --- |
| SQLite | **None.** No `sqflite`, `drift` or `powersync` dependency | `vinii_partner/pubspec.yaml` dependencies |
| Local tables | **None.** The only on-device store is SharedPreferences (key/value) | `lib/data/local_prefs.dart` |
| Local IDs | Only idempotency keys (UUID v4) and the request id. No local order, line or payment ids exist | below |
| Server IDs | Every entity id comes from the database (`gen_random_uuid()` defaults) or from the missing RPCs | 01 §3 |
| Outbox | **None.** Nothing queues a write for later | — |
| Sync | **None.** No background sync, no replication, no pull-on-reconnect | — |
| Retries | **Manual only.** A failed write shows an error and the user taps again. There is no automatic retry loop. The partner API call has a 15 s timeout (`partner_api_inbox.dart:69`) | — |

## What SharedPreferences holds (`lib/data/local_prefs.dart`)

| Key | Purpose |
| --- | --- |
| `intro_seen` | first-launch intro shown |
| `last_org:<userId>` | the organization opened last |
| `theme_mode`, `ring_enabled` | device preferences |
| `pending_key:<scope>` | **idempotency keys waiting for a server answer**: `order:<orgId>`, `payment:<orderId>`, `payment:<orderId>:2` |
| `last_service_charge:<orgId>` | the last non-zero service charge percentage, for switching it back on |
| `service_charge_choice:<orderId>` | the cashier's keep-or-remove answer to the final-order prompt |
| `storefront_draft:<orgId>` | the storefront draft, **only when the `vinii_storefronts` table is missing** (`live_storefront.dart:79-93`) |

The Supabase session is persisted by `supabase_flutter` itself (`local_prefs.dart:6-7` says so). This audit did not check where.

## Idempotency (duplicate prevention for writes)

| Write | Key | Lifetime | Reused on retry? | Evidence |
| --- | --- | --- | --- | --- |
| Phone POS order (`pos_place_order`) | UUID v4, scope `order:<orgId>` | **Saved before the request is sent**; cleared on success, `rejected` or `forbidden`; **kept** on offline, not-ready or unknown errors | Yes, even after an app restart | `application/sell_keys.dart:36-49` |
| Phone POS payment (`pos_record_payment`) | UUID v4, scope `payment:<orderId>` (and `:2` for the second part of a split) | Same rules | Yes | `payment_card.dart:196-198,234-240,271-273` |
| Guest order on a handed-over phone | UUID v4 in `GuestSession.pendingKey` | **Memory only**; cleared on success | Yes, but only within the same app run | `guest_session.dart:437,460` |
| Partner API writes (accept, reject, ready, out, delivered, outlet, test order) | `idempotency-key` header, **a new UUID on every request** | per request | **No.** A retry sends a different key | `partner_api_inbox.dart:38-52` |
| Every request | `x-request-id`, a new UUID per HTTP request | per request | No (tracing only) | `data/live/caller_client.dart:16-20` |

**Server side**
- The `pos_*` functions that would honour the order and payment keys **do not exist** (01 §6).
- The `orders` and `payments` tables have **no column** to hold an idempotency key.
- One Local's partner API server **does not read** the `idempotency-key` header. A search of `OL-ui/frontend/server/{http,partner,restaurant}.ts` and `app/api/partner/` found no handling.
- One Local's own idempotency exists only for customer checkouts, on `ol_orders (customer_hash, idempotency_key)` in `ol_create_restaurant_order`. The partner test order sends no key.

**Client-side double-send guards**
- `SellCart.placing` (`sell_cart.dart:321-323`).
- `PaymentCard._paying`.
- `InboxController.busy` per order (`inbox_controller.dart:169-196`).

## Conflict resolution (optimistic concurrency)

| Write | Version token | On conflict |
| --- | --- | --- |
| POS RPCs | `expected_updated_at` = `orders.updated_at` as last read | The server is expected to raise `POS_STALE`, which the app maps to `conflict` (`errors.dart:23-26`). Not verifiable: the functions are missing |
| One Local actions | `version` = `orders.updated_at` | `ol_partner_act` raises `OL_STALE`, the API answers 409, and the app shows a conflict and re-polls New (`inbox_controller.dart:184-190`) |
| Bill settings | `update … where organization_id = ? and updated_at = <loaded>` (`live_bill_settings.dart:58-67`) | Zero rows triggers a reload. A newer `updated_at` means conflict; otherwise it reports "not permitted". First save uses `upsert(ignoreDuplicates)` |
| Storefront publish | `expected_version` | The server is expected to raise `POS_STALE`. Not verifiable |
| Menu, channels, team | **none**: last write wins | — |

## What happens offline

| Action | Behaviour |
| --- | --- |
| Boot, sign-in | Auth errors map to "You are offline …" (`errors.dart:144-148`); the session stage goes to `bootError` with a retry option |
| Sell → Send | The order **is not saved anywhere**. The error is shown, the in-memory cart stays, and the pending key stays in SharedPreferences, so the next tap reuses it |
| Payment | Not recorded; the key stays; tap again |
| Delivery inbox poll | The list keeps showing the last results; the failure is stored per tab; polling continues (`inbox_controller.dart:101-119`) |
| Guest tracking | Offline errors are swallowed and polling continues (`guest_gateway.dart:90-92`) |
| Storefront draft save | Kept on the phone **only** when the error is "table missing" (`notReady`). An offline error is thrown to the screen (`live_storefront.dart:87-92`) |
| Sign out | Always clears the local session, even offline (`live_auth.dart:69-75`) |
