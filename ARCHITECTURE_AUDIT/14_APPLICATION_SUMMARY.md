# 14 — Application summary

**Application.** VINII Partner (`vinii_partner/`), a Flutter app for restaurant staff: phone POS, the One Local delivery inbox, menu, storefront studio, bill settings, team and table QR codes.

**Audited at:** commit `da0a823`, 2026-10-02. Read-only. No code, migration or data was changed.

**Evidence:**
- this app's source;
- migration files in `Repo-1-/supabase/migrations` (OS and POS tables) and `OL-ui/db/migrations` (One Local);
- One Local's partner API source;
- the production column snapshot of 2026-09-22.

**Shape in one paragraph.** The app is an **online-only client** of the shared Supabase database. It has no local database, outbox, realtime subscription, edge function or hardware driver.
- It **writes directly** only to configuration-type tables: menu, bill settings, channel switches, team roles and status. It also uploads photos to storage.
- **Every transactional write** (create order, take payment, change status, adjust bill, issue a table code, publish the storefront) goes to a database function **that no applied migration defines**. The five `pos_*` functions are not written anywhere; the storefront publish function is in an unapplied draft. Those actions currently end in "Not available yet".
- **The only working transaction path is One Local delivery orders.** The phone calls One Local's partner API, whose server runs the existing `ol_partner_act` with the service role.

---

## Answers

**What creates an order?**
- **Today:** only One Local's `ol_create_restaurant_order`, run by One Local's server. For this app that means Settings → "Send test order" (`POST /api/partner/test-order`). Real One Local checkouts happen outside this app.
- **Not working:** the phone POS ("Send to kitchen" or "Save & hold") and a guest on a handed-over phone both call `pos_place_order`, which does not exist. No order is created.

**What changes an order?**
- One Local's `ol_partner_act`, reached from the phone's Accept, Reject, Ready, Out and Delivered buttons.
- `ol_expire_unanswered`, which runs on every inbox poll, cancels late orders.
- On the phone POS, `pos_adjust_bill` and `pos_record_payment` would change orders, but both are missing. `pos_set_order_status` is defined in the code but no screen calls it.
- The database itself would also let any member update `orders` directly (10 §3). This app never does.

**What creates a KOT?**
- `ol_partner_act` on **accept** of a One Local order: `next_org_seq(org,'kot')`, an insert into `kot_tickets`, and `order_items.kot_ticket_id` set.
- The phone POS's `fire_kot: true` would ask `pos_place_order`, which is missing.
- This app never writes `kot_tickets` itself.

**What changes a KOT?**
`ol_partner_act`: **ready** sets `ready`; **out** sets `delivered`. Nothing in this app or in One Local sets `preparing`. No KOT can be cancelled or reprinted.

**What marks food ready?**
"Mark ready" on a One Local order (`delivery_order_screen.dart:207`) → `ol_partner_act(ready)`. It sets `kot_tickets` and `order_items` to `ready`, `orders` to `ready`, and `ol_orders` to `packed`. Phone POS orders have no ready step.

**What creates a payment?**
- One Local "Delivered" → `ol_partner_act(delivered)` inserts one `payments` row: cash, `amount = orders.total`, `reference = 'onelocal:<id>'`.
- The phone POS's "Charge" (single or split) calls `pos_record_payment`, which is missing.
- Guest online payment (Cashfree) exists in code but is not connected.

**What completes a payment?**
- **One Local:** the same `delivered` step. It sets `orders.payment_method = 'cash'`, `paid_at`, status `delivered`, and `ol_orders.payment_status = 'paid'`.
- **Phone POS:** the missing `pos_record_payment` would be expected to set `status = paid`. The phone counts an order as paid when `status = 'paid'` or the payments cover the total.

**When is inventory changed?**
**Never.** No inventory or stock table exists in the app, either ledger or the production snapshot. The only related writes are on/off availability flags (`menu_items.is_available`).

**What happens offline?**
- Nothing is saved. Sending an order, taking a payment, or any other write fails with an "offline" message.
- The in-memory cart and the saved idempotency key are kept, so a later tap retries the same request.
- The inbox keeps its last list and keeps polling. Sign-out still works.

**How does sync work?**
**There is no sync.** Every action is a live request. "Live" screens poll:
- the delivery inbox every 5 s while accepting, every 30 s while not;
- guest order tracking every 5 s.

No realtime channel is used, even though `orders`, `kot_tickets`, `order_items`, `order_events`, `service_requests` and `table_sessions` are in the realtime publication.

**What IDs are generated locally?**
- Idempotency keys (UUID v4):
  - `order:<orgId>` and `payment:<orderId>` (plus `:2` for a split), saved in SharedPreferences;
  - the guest order key, in memory only;
  - a new `idempotency-key` on each partner API write.
- An `x-request-id` (UUID v4) for every HTTP request.
- Storage file names: `<orgId>/<itemId>-<epoch ms>.<ext>`.
- The Studio preview's stand-in order id `preview-<key>`, never stored.
- **No entity id** (order, line, KOT or payment) is generated on the phone.

**What IDs come from Supabase?**
All entity ids, through `gen_random_uuid()` defaults: organizations, memberships, menu, tables, orders, lines, KOTs, payments and events. Also:
- order numbers (`order_no`) and KOT numbers (`kot_no`), from `org_counters` through `next_org_seq`;
- `display_no`, made by the creating function (One Local uses `OL-00024`);
- the user id, from Supabase Auth;
- the version tokens (`orders.updated_at`, `org_bill_settings.updated_at`).

**What tables are written?**
- **Directly by the app:**
  - `menu_categories` (insert, update, delete)
  - `menu_items` (insert, update)
  - `org_bill_settings` (upsert, update)
  - `channel_integrations` (update)
  - `org_users` (update role and status)
  - `vinii_storefronts` (upsert and update; the table is only in an unapplied draft)
  - the storage bucket `item-images`
- **Indirectly, through One Local's API:**
  - `orders`, `order_items`, `kot_tickets`, `order_events`, `payments`
  - `ol_orders`, `ol_merchant_channels`, `org_counters`
  - `delivery_jobs` and the related dispatch tables (applied status unverified)

**What tables are read?**
- **Directly:**
  - `org_users`, `roles`, `organizations`, `org_modules`, `role_module_access`
  - `menu_categories`, `menu_items`
  - `dining_tables`, `dining_areas`
  - `orders`, `order_items`, `payments`
  - `org_bill_settings`, `channel_integrations`
  - `vinii_storefronts` and `vinii_storefront_versions` (both only in an unapplied draft)
- **Through One Local's API:** `ol_orders`, `orders`, `order_items`, `order_events`, `ol_merchant_channels`, `org_users`.

**What events are emitted?**
- **The app emits none itself.** It writes no `order_events` rows and publishes nothing.
- One Local's functions, triggered by the phone, write these `order_events` kinds: `placed` (test order), `accepted`, `kot_fired`, `rejected`, `kot_ready`, `out_for_delivery`, `delivered`, `paid` and `timed_out`.
- The missing `pos_*` functions would be expected to emit others; not verifiable.

**What entities appear duplicated?**
- **Orders:** One Local orders show in both the Orders tab and the Sell tab's "Open orders". Delivered One Local orders stay "open" all day there, because their final status is `delivered`, not `paid`.
- **Pricing rules:** One Local uses a fixed 5% GST and adds the delivery fee into the total; the phone POS uses `org_bill_settings`.
- **Availability:** two flags, `menu_items.is_available` and `item_channel_status`.
- **Status:** the same kitchen state is held in four places: `kot_tickets`, `order_items`, `orders` and `ol_orders`.
- **Customers:** free text on each order, with no shared record.
- **Organization choice:** two rules, `current_org_id()` with `limit 1` versus the partner API's earliest membership.
- **Payments:** no idempotency column, and a non-unique `reference`.
- **Storefront draft:** in the database (if present) and on the phone.

Details are in `12_DUPLICATES.md`.
