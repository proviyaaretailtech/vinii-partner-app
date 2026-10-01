# VINII Partner and the Proviyaa Platform Contract: alignment

**Date:** 2026-09-28 · **Applies to:** `vinii_partner/` (the Flutter restaurant app: delivery orders, phone POS, Storefront Studio) · **Status:** rules adopted for the app; database changes proposed, not applied

**Inputs.** The architecture note the founder shared on 28 Sep (*"multiple clients consuming one platform"*). Decisions already on record: One Local's `docs/PLATFORM_FOUNDATIONS.md` (D1–D15) and the POS decision record (D01–D10). The founder notebook (asked 2026-09-28; its answers are AI summaries and are treated as context). The actual migrations in `Repo-1-/supabase/migrations` and `OL-ui/db/migrations`.

---

## In plain words

Most of the architecture note is **already our decided direction**. The shared records already cover one login per person, access through memberships, data scoped by business, no app owning another app's tables, and one migration ledger. VINII Partner's code follows those decisions.

The gaps are in the **shared database**, and VINII Partner is the first app that would hit them:

1. **A person who works for two restaurants sees the wrong one.** The database decides "your organization" by picking any one of your memberships, so it can show the wrong restaurant's data.
2. **The database checks membership, not role.** A kitchen login can change menu prices or order status if it goes around the app. Today only the app's hidden buttons stop it.
3. **Orders have no single front door yet.** One Local creates orders through a proper database function. The phone POS was about to write order rows itself, which would make it a second, different definition of "an order".
4. **Order rows cannot tell a retry from a new order.** A phone that retries after a network drop could create the same order twice.
5. **The restaurant owner role cannot publish its own storefront.** The database only lets the "org admin" role change organization settings.

**What changes now:** the app's rules are set out below, so its live data layer is built through front-door functions rather than direct table writes. The database fixes go to the founder as one proposed migration in the Repo-1- ledger (D7).

---

## 1. The contract, principle by principle

| # | Principle (architecture note) | Already decided as | VINII Partner today | Status |
| --- | --- | --- | --- | --- |
| 1 | Apps are experiences; the platform is the truth | D5, D6; notebook: *"all apps write only through services/api"* | Delivery actions go through One Local's `/api/partner/*` → `ol_partner_act`. The phone POS and Storefront live data layer are not written yet | **Rules set below (R1–R4)** |
| 2 | Only the domain owner changes authoritative data | D6 (each app owns its tables), rule *Always 1* (ownership by prefix) | Wants to write POS `orders`, `menu_items` (POS-owned) and `organizations.settings` (Master-owned) | **Gap: G3, G5.** R1, R4 |
| 3 | The database enforces sanity: foreign keys, uniques, checks, allowed status moves | Foreign keys, status value checks, running numbers per org exist | — | **Gap G4:** no idempotency on `orders`; status *moves* not enforced for direct writers |
| 4 | Idempotency keys on critical writes | Architecture §79; POS D-record: *"every offline transaction needs an idempotency identity"* | One Local orders have it (`ol_orders.idempotency_key`); POS `orders` do not | **Gap G4.** R1 |
| 5 | Event contract | `order_events` is append-only and live (Realtime) | Reads `order_events.kind` for the timeline | **Aligned in practice.** Registry in §4.3 |
| 6 | One global identity, many memberships | D1, D2 | `StaffUser` is thin; `Membership` per organization; an organization picker | App aligned. **Database gap G1** |
| 7 | Permissions, not "access to an app" | Action-level permissions (founder architecture), `role_module_access` | `Capability` table; screens ask `can(...)`, never the role | App aligned. **Database gap G2**: roles not checked by the database |
| 8 | Master Admin goes through the same authorization | D13, D14 | n/a (VINII Partner has no admin surface) | Master's own gap is on record in Repo-1- `docs/one-latur-workspace.md` |
| 9 | Impersonation with an audit trail | Notebook: PAGE-MST-003 *"impersonate with controlled audit"* | none | **Decided in One Local's D23:** support gets read-only "view as" with a banner, never the merchant's password. The Master builds it; app duty in R8 |
| 10 | React vs Flutter doesn't matter; contracts do | D11 (One Local stays Expo; VINII family is Flutter) | Flutter | **Aligned.** The PRD still said Expo; corrected |
| 11 | Stop API contract drift: schema, errors, versions, contract tests | D10 (support every version in the field; 426 = update) | Hand-written JSON parsing; typed failures (`conflict`, `forbidden`, `notReady`…) | **Partial.** R6 adds a shared fixture test |
| 12 | Offline is special to the POS | POS D02, D05 (PowerSync; no second sync queue) | Online only | **Open question Q1** |
| 13 | Versioning: API, app, runtime, config, schema, event | D8, D10, release plan | Update gate reads `organizations.settings.app.min_app_version`; `configVersion`; storefront `schema_version` | **Aligned for now.** Min version moves to Master's `apps` table when it exists (R5) |
| 14 | Roles scoped by location as well as organization | Notebook: PAGE-MST-005 *"scope by location, scope by hub"*; `org_users` has no location yet | Organization-level only | **Platform gap.** Waits for `org_users.location_id` |

---

## 2. Rules VINII Partner follows (binding for `vinii_partner/`)

**R1. Orders go through one front door.** The phone never inserts or updates `orders`, `order_items`, `kot_tickets`, `payments` or `order_events` rows itself. It calls POS-owned database functions (§4). The same functions will serve the Windows POS upload path, the guest storefront and, later, One Local. `PosRepository.placeOrder`, `recordPayment` and `setStatus` map one-to-one onto `pos_place_order`, `pos_record_payment` and `pos_set_order_status`.

**R2. The phone sends intent, the server decides facts.** The phone sends item ids, quantities, notes, service type and table. The function reads prices from `menu_items`, the GST rate from the organization's bill settings, the order number from `next_org_seq` and the organization from the membership. It never trusts a price, total, organization or role the phone sends (foundations rule *Never 4*). The phone's bill is a preview only.

**R3. Every write that can be retried carries an idempotency key.** The phone creates a UUID when the cashier confirms the cart and keeps it until the server answers, even across an app restart. A second call with the same key returns the first order, not a new one. Payments work the same way.

**R4. The app writes only what VINII owns.**
- *Delivery orders:* only through One Local's partner API (already the case).
- *Menu:* `menu_items` and `menu_categories` belong to the POS "Item Master". The phone may edit them only once the database checks the role (G2). Until then, live menu editing is limited to `org_owner`, `org_admin` and `manager`, and that limit is a known soft spot.
- *Storefront:* it is not stored inside `organizations.settings`. That column belongs to the Master (it holds `app.min_app_version` and the tab order). A phone rewriting the whole column can silently undo a Master change. The storefront gets its own VINII-owned table, with append-only published versions (§4.4).

**R5. The app reads configuration and never writes it.** Tabs, modules and the minimum version come from the Master's rows (`org_modules`, `role_module_access`, `organizations.settings.app` for now, and the `apps` table once it exists). The phone never writes them.

**R6. One vocabulary per owner, pinned by a test.** Delivery orders use One Local's status words (`placed`, `accepted`, `packed`, `out`, `delivered`, `cancelled`). The kitchen uses the POS words (`new`, `sent_to_kitchen`, `ready`…). The partner API sends both (`status`, `pos_status`), and the app never translates one into the other. A saved sample response from One Local's server lives in the app's tests, and `DeliveryOrder.fromJson` must parse it. One Local's server test uses the same file, so a renamed field breaks a test instead of breaking phones.

**R7. Every request carries the platform envelope (foundations D21).** On partner API calls, and as global headers on the Supabase client:
- `x-app: vinii-partner`, `x-app-version`, `x-platform` (`android`, `ios`, `web`), `x-runtime` (build number).
- `x-request-id`: a new UUID per request, so one problem can be traced across One Local, the POS and this app.
- On partner API writes, an `idempotency-key` header. RPC writes carry the key inside `p`.

The server works out organization, role and scopes from memberships and never from the request body.

**R8. The server is the authority on permissions (foundations D22).** `capabilityRoles` in `lib/domain/staff.dart` only decides which buttons show. It must match the server. The aim is to receive the person's allowed actions (named like `order.accept`, from the kernel's action catalogue) from `GET /api/partner/me`. When support uses "view as" (D23: read-only, 30 minutes, with a reason), the app shows a visible banner and allows no changes. It never receives or stores the merchant's password.

**R9. No second offline queue.** If the phone POS must work offline (Q1), it uses the POS's PowerSync path and its idempotency keys. It does not get its own outbox. POS decision D05 forbids a second, competing sync queue for the same records.

**R10. Guests never write tables.** The guest storefront (`vinii.app/s/<slug>`) places orders through the same front-door function, with a table-session token or through a server. It never uses public insert rules. The POS repo's `online_orders` table, which is open to anyone holding the public key, is the example not to repeat.

---

## 3. Gaps found in the shared database

Each gap was checked in the migration files. The files are the ledger; production may differ, so check it read-only before fixing.

| # | Gap | Evidence | Effect | Fix (proposed, in the Repo-1- ledger) |
| --- | --- | --- | --- | --- |
| **G1** | `current_org_id()` returns *any one* active membership (`limit 1`). Every organization-scoped policy compares against it | `Repo-1-/supabase/migrations/0004_roles_and_org_users.sql:93`; `org_users` allows several organizations per person (`:66`); `apply_org_rls` in `0010_restaurant_operations.sql:33` | Someone on staff at two restaurants sees one of them at random, and writes to the other are refused. This breaks "one person, many memberships" (D1, D2) | Add `is_org_member(org uuid)`. Policies become `organization_id` *is one of mine* (`is_org_member(organization_id)`). Keep `current_org_id()` for old callers |
| **G2** | The database checks membership only, not role | `0006_pos_domain.sql:9-12` (*"per-role restrictions … enforced at the application layer for now"*); `orders_member_update` at `:288` | A kitchen or viewer login can change prices, mark orders paid, or move status backwards by calling the API directly | Add `has_org_role(org uuid, roles text[])`. Write policies on menu, orders and payments name their roles. Order and payment writes move behind the §4 functions |
| **G3** | No POS-owned function for creating a POS order | Only One Local's `ol_create_restaurant_order` exists (`OL-ui/db/migrations/0023_partner_order_functions.sql:13`) | Each new client would write its own version of "place an order" | §4.1 |
| **G4** | `orders` has no idempotency key. The only unique rule is the running number | `0006_pos_domain.sql:258` | A retried request makes a duplicate order | `orders.idempotency_key text`, unique per organization when present |
| **G5** | Only the `org_admin` role may update `organizations`; `org_owner` may not | `is_org_admin` checks `slug = 'org_admin'` (`0004:106-121`); policy `0004:178`; `org_owner` added in `0019_day1_completion.sql:113` | The app offers owners "Publish". The database would refuse it | Solved by R4: the storefront moves to its own table, with owners and admins allowed |
| **G6** | The role name format forbids dots, but the foundations propose `ol.city_ops` and `ol.catalog` | `0004:28` (`^[a-z0-9]+(_[a-z0-9]+)*$`); `PLATFORM_FOUNDATIONS.md:111` | Inserting those roles would fail | **Fixed in OL-ui (cd05ac3):** the slugs are now `ol_city_ops` and `ol_catalog`; the check was not widened |
| **G7** | The Master's KOT status change uses the service key and updates by ticket id, with no organization filter and no role check | `Repo-1-/apps/web/src/lib/pos.ts:277-289` (`setKotStatus`) | Any signed-in Master user who has a ticket id can change any restaurant's kitchen ticket | Call a POS-owned function, or at least filter by the caller's organization and role |
| **G8** | The Master's "settle order" marks any order paid with the service key and no state or version check | `Repo-1-/apps/web/src/lib/pos.ts:483-497` (`settleOrder`) | A cancelled order can become "paid", and no payment row is written | Replace with `pos_record_payment` (§4.1) |

The POS repo's `online_orders` table (`20260918_create_online_orders.sql`) gives anyone with the public key full read and write access. One Local checked on 2026-09-28 that it is **not in production**. One Local proposes that the Windows POS read `orders` where `channel = 'online'` instead, and that the table never be applied.

---

## 4. The order contract (for the POS owner to confirm)

### 4.1 Front-door functions (POS-owned; one transaction each; they check role themselves)

**Agreed call shapes (2026-09-28).** The VINII Partner live data layer is coded against these. Change them only additively (new optional fields), and update this section in the same change. Each is a PostgREST RPC taking one `jsonb` argument `p`, with snake_case keys.

| Function | `p` | Returns | Does |
| --- | --- | --- | --- |
| `pos_place_order` | `organization_id`, `idempotency_key`, `service_type` (`dine_in` \| `pickup` \| `delivery`), `table_id?`, `guest_count?`, `customer_name?`, `customer_phone?`, `notes?`, `scheduled_for?` (ISO, pre-orders), `placed_by` (`pos` \| `captain` \| `guest`), `lines[{menu_item_id, qty, notes?}]` | order: `{id, display_no, status, channel, updated_at, created_at, subtotal, gst_pct, gst_amount, service_charge, round_off, total, table_id, lines[{menu_item_id, name, qty, unit_price, notes}]}` | Checks membership and role for *that* `organization_id` (the phone names the organization; the server checks it, per R2), then item availability. Prices come from the menu, GST from `org_bill_settings`, the number from `next_org_seq`. Writes the order, its lines, the kitchen ticket and the `placed` event. `scheduled_for` goes into the `placed` event's `meta` until `orders` has a column for it. The same `idempotency_key` returns the first order |
| `pos_record_payment` | `order_id`, `method` (`cash` \| `upi` \| `card`), `amount`, `idempotency_key`, `expected_updated_at` | the order shape plus `paid` (sum of payments) | Adds the payment and the `paid` event. The order becomes `paid` when fully settled. The same key returns the same result |
| `pos_set_order_status` | `order_id`, `to`, `expected_updated_at` | the order shape | Checks the move is allowed (§4.2) and that the version is current, then writes the event |

**Errors:** `raise exception 'POS_<CODE>: <plain message>'`. The app maps them as follows:
- `STALE` and `WRONG_STATE` become a conflict.
- `FORBIDDEN` becomes forbidden.
- `ITEM_UNAVAILABLE`, `EMPTY`, `BAD_REQUEST` and `OVERPAY` become rejected.
- A missing function (PostgREST `PGRST202` or Postgres `42883`) becomes "not ready yet, needs the database update".

**Additions open to every caller (optional; the phone may ignore them):**
- `lines[].variant_id?`: when given, the price comes from `menu_item_variants.price`. The item's own price is only the "starts at" price once it has variants.
- `fire_kot?` (default `true`): `false` creates the order without a kitchen ticket. The ticket is then created on `new → sent_to_kitchen`.
- `reference?` on `pos_record_payment`: the UPI or gateway reference, kept in the existing `payments.reference` column.
- The return shape gains `replayed` (true when an idempotency key matched an earlier call) and `lines[].variant_id`. **Every caller gets one return shape and reads `id`.** There is no separate `order_id` for One Local.

**Additions accepted only from the service role (One Local's server, foundations D17).** A signed-in phone that sends any of these gets `POS_FORBIDDEN`.

| Field | Function | Meaning |
| --- | --- | --- |
| `service_type = 'online'`, `placed_by = 'integration'` | `pos_place_order` | Writes `orders.channel = 'online'` |
| `external_ref = 'onelocal:<ol_orders id>'` | `pos_place_order` | Unique; the same id is the idempotency key |
| `sales_channel = 'one_local'` | `pos_place_order` | Items switched off for that channel in `item_channel_status` (off with no end time, or off until a future time) raise `POS_ITEM_UNAVAILABLE`. Named `sales_channel` because `channel` in the return is the service mode (`orders.channel`); one name, one meaning |
| `display_prefix = 'OL'` | `pos_place_order` | Changes only the label (`OL-00024`). The number still comes from the restaurant's single sequence, so numbers never collide |
| `actor_user_id`, `request_id`, `app` | all three | Stamped into `order_events.meta` (D21). For phone callers the server takes them itself: the user from the login, and `x-request-id` and `x-app` from the request headers. The actor is `system` for timeouts |
| `reason` | `pos_set_order_status` | Stored as `meta.reason` (`rejected`, `timed_out` or free text). Open to phones too when cancelling |
| `method = 'online'` | `pos_record_payment` | Gateway payments (Razorpay) with `reference` = the gateway payment id. The migration adds `'online'` to both `payments.method` and `orders.payment_method`; the value lists only grow |

**Money rule.** `orders.total` is the restaurant's bill: subtotal + GST (+ service charge and round-off for dine-in). A marketplace **delivery fee never goes on the kitchen order.** It belongs to One Latur (`ol_orders`, `ol_checkouts`). Today's `ol_create_restaurant_order` adds it (`OL-ui 0023:83`); the new function does not. GST comes from `org_bill_settings`, not a hard-coded 5%. One Local copies the POS's returned prices and GST, so the customer pays exactly what the restaurant billed. **No delivery address on the kitchen side.** `customer_phone` is sent only if the founder decides restaurants need it (DPDP minimisation, Q5).

**Handing the food over:** `pos_mark_handed_over(p)` with `{order_id, expected_updated_at, request_id?, actor_user_id?}` returns the order shape. It marks the kitchen ticket and lines delivered, writes the `out_for_delivery` event, and leaves `orders.status` at `ready` (as `ol_partner_act` does today, `OL-ui 0023:186-189`). It is a named POS action, not a generic "add event" call. A generic event writer would let any caller write any history. Letting the rider's pickup define it lost too: the kitchen releasing the food is a kitchen fact, and the rider app does not exist yet. When OnLatur arrives, its pickup is its own event in its own outbox.

**Payment timing for One Local orders.**
- *Cash on delivery:* `pos_place_order` at checkout. On delivery, `pos_set_order_status(delivered)`, then `pos_record_payment` with `method 'cash'` and key `onelocal:<id>:cod`.
- *Online:* `pos_place_order` only after the gateway confirms, so restaurants never see unpaid orders. Then `pos_record_payment` with `method 'online'`, key = the gateway payment id and `reference` = the same id.

One Local keeps its own checks (outlet accepting, accept window, city) and runs them before calling.

**The migration also needs:** `orders.idempotency_key` and `payments.idempotency_key`, each unique per organization when present (G4). `payments` has no such column today.

One Local's `ol_partner_act` already follows this pattern (expected version, allowed moves, event rows). The new functions copy its shape. `ol_partner_act` becomes a caller of `pos_set_order_status` and `pos_mark_handed_over`.

### 4.2 Allowed status moves

Observed in `ol_partner_act`: `new → sent_to_kitchen` (accept), `new → cancelled` (reject or time-out), `sent_to_kitchen → ready`, `ready → delivered`.

Proposed invariants for every client, to be enforced by a trigger on `orders` so they hold whoever writes:
- `paid` and `cancelled` are final.
- Nothing returns to `new`.
- Cancelling a paid order is a refund, not a status change.

The rest of the dine-in path (`in_billing`, `awaiting_payment`, `delivered` meaning "served") must be confirmed by the POS owner before the trigger is written. The move list is not guessed here.

### 4.3 Event registry

`order_events` rows are written **in the same transaction** as the change. That is the "outbox" the architecture note asks for, and it is already live over Realtime. Existing kinds are **not renamed**, because One Local and the Windows POS read them. When an event bus arrives, it publishes the canonical name from each row:

| `order_events.kind` | Canonical event (v1) | Written by |
| --- | --- | --- |
| `placed` | `order.created` | `pos_place_order` (replacing `ol_create_restaurant_order`) |
| `accepted` | `order.accepted` | `pos_set_order_status` (`new → sent_to_kitchen`) |
| `kot_fired` | `kot.created` | `pos_place_order` (when `fire_kot`), `pos_set_order_status` (on accept) |
| `kot_preparing` / `kot_ready` | `kot.preparing` / `kot.ready` | kitchen (Windows POS) |
| `out_for_delivery` | `delivery.picked_up` | `pos_mark_handed_over` |
| `delivered` | `order.fulfilled` | `pos_set_order_status` |
| `paid` | `payment.completed` | `pos_record_payment` |
| `rejected` / `timed_out` | `order.cancelled` (`meta.reason`) | `pos_set_order_status` (`→ cancelled` with `reason`) |

Every row's `meta` carries `request_id`, `app` and `actor_user_id` (D21). One Latur's customer-side events live in its own outbox, `ol_order_events` (One Local D20), with the same envelope and no personal data.

New kinds are only ever added, and each one is added to this table in the same change. Each row's `meta` gains `"v": 1` when its shape first changes.

### 4.4 Storefront storage (VINII-owned)

- `vinii_storefronts`: `organization_id` (primary key), `draft jsonb`, `published_version int`, `updated_by uuid`, `updated_at`. The phone saves drafts with a plain upsert. The table's own row security lets org members with a storefront-editing role write only their own organization's row.
- `vinii_storefront_versions`: `organization_id`, `version int`, `definition jsonb`, `published_by uuid`, `published_by_name text`, `published_at`; unique `(organization_id, version)`; **append-only** (no update or delete for anyone but the platform). Rollback means pointing back to an older version.
- Publishing goes only through `vinii_publish_storefront(p jsonb)` with `{organization_id, definition, expected_version}`, which returns `{version, published_at}`. The function numbers the versions and checks for owner or admin (`org_owner`, `org_admin`), so G5 does not apply here. A stale `expected_version` raises `VINII_STALE` (refusals: `VINII_FORBIDDEN`, `VINII_BAD_REQUEST`). The phone maps `POS_`, `OL_` and `VINII_` prefixes the same way.
- **Draft migration written (2026-10-02):** `Repo-1-/supabase/migrations/0021_vinii_storefronts.sql` on branch `feat/experience-cms`. Not applied; it needs approval (Q2) and its final ledger number. It also adds the helper checks `vinii_is_member`, `vinii_can_edit_storefront` and `vinii_can_publish_storefront`, which are multi-organization safe (they never use `current_org_id()`).
- The guest runtime reads only the published version.
- `organizations.settings` is left to the Master.
- Until these exist, the app keeps the draft on the phone and says publishing waits for the database update.

#### 4.4.1 Storefront CMS fields (added 2026-10-02, schema_version stays 1)

The founder asked for a CMS in the Master to set the guest storefront's colours, pictures, text and buttons. Editors are the Proviyaa team (all restaurants) and each restaurant's owner and admin (their own only); managers and marketing may edit drafts but not publish. The CMS edits the **same definition** as the phone's Studio. Every editor changes only its own sections and passes all other keys through untouched, so neither side wipes the other.

| Key | Shape | Edited in |
| --- | --- | --- |
| `theme.colors` | `on_accent`, `background`, `surface`, `text`, `muted`, `success`, `danger` as `#RRGGBB`; absent means the template's colour | Master CMS |
| `theme.buttons` | `shape`: `pill`, `rounded` or `square`; `style`: `filled` or `outline` | Master CMS |
| `theme.fonts` | `heading` and `body` font ids from one shared catalogue; script faces are for headings only | Master CMS |
| `brand.logo_url`, `brand.cover_url`, `media.hero`, `media.categories{category_id}` | picture references | Master CMS |
| `copy{en,hi,mr}{key}` and `default_language` | guest text by key, from one registry (`apps/web/src/lib/storefront-copy.ts`; the phone keeps a copy of the same keys); fallback order is the guest's language, then English, then the registry default | Master CMS |

**Pictures** live in the private bucket `storefront-media` under `<organization_id>/`. They are uploaded only by the Master, after `vinii_can_edit_storefront` is checked. Guests and phones load them from the Master's own address, `/media/<path>`, so no Supabase address reaches a browser. A stored picture reference is a bucket path; full `https` URLs from older data are still accepted.

**Who reads what:** the table-QR page (`/t/<token>`) and the phone's guest runtime render the published version. The Master's `/t/preview/<organization_id>` shows the draft, to editors only. `organizations.theme` stays the staff apps' look.

### 4.5 Proposed additions for the founder's migration (staff operations)

**Status:** proposed on 2026-10-02, **not applied**. The staff screens for Bill & GST, the final-order service charge, the store status and sales channels, the Team and the Table QR codes were built against the shapes below. Each function is called through the same pattern as §4.1 (one `jsonb` argument `p`, snake_case keys, errors as `raise exception 'POS_<CODE>: <plain message>'`), and the phone maps a missing function (`PGRST202` / `42883`) to `FailureKind.notReady`, which staff see as "Not available yet" with the reason. Nothing is written around them. Change these only additively, and update this section in the same change.

#### New functions

| Function | `p` | Returns | Who may call it | Does |
| --- | --- | --- | --- | --- |
| `pos_adjust_bill` | `order_id`, `expected_updated_at`, `waive_service_charge` (bool), `waive_reason?` (text, at most 120; kept only when waiving) | the order shape of §4.1 plus `service_charge_waived` (bool) and `service_charge_waived_amount` (numeric: what was taken off, 0 when none) | `org_owner`, `org_admin`, `manager` of the order's organization (`has_org_role`, gap G2). A biller or captain gets `POS_FORBIDDEN` | Takes the service charge off a saved order, or puts it back. Checks the version, then that the order is open and **has no payments yet**. Recomputes the bill from the stored lines, the discount and the organization's `org_bill_settings`, with the same maths as §4.1 (items − discount, + service charge unless waived, + SGST + CGST, + round-off). Updates `orders.service_charge`, the GST amounts, `round_off` and `total`. Writes one `order_events` row, `kind = 'bill_adjusted'`, in the same transaction, with the actor and `meta { service_charge_waived, reason, total_before, total_after }`. Because the version moves, a repeated call is refused as stale, never applied twice |
| `pos_issue_table_qr` | `table_id`, `replace?` (bool, default false) | the table row: `{id, label, area_id, qr_token, is_active, sort_order, seats}` | `org_admin`, `manager` (the Master's `QR_MANAGER_ROLES`) | Gives a table its guest code. The server generates the token (ten characters, `a–z` and `0–9`, from a cryptographic source, at least 40 bits), retries when the global unique rule on `qr_token` is hit, and records who did it. If the table already has a code and `replace` is not true it refuses with `POS_WRONG_STATE: This table already has a code.`, so a stale screen can never replace a code by accident. With `replace = true` the old code stops working: the phone asks first ("Printed stickers will stop working") |

**Errors for both:** `POS_FORBIDDEN`, `POS_STALE` (`pos_adjust_bill`), `POS_WRONG_STATE`, `POS_NOT_FOUND`, `POS_BAD_REQUEST`. The phone's existing mapping (§4.1) applies unchanged: `STALE` and `WRONG_STATE` become a conflict, `FORBIDDEN` becomes forbidden, the rest become rejected.

#### Additions to `pos_place_order`

- `p.waive_service_charge` (bool, default false) and `p.waive_reason` (text, optional). **The phone sends them only when the service charge was removed**, so every older caller is unaffected. Only the roles that may call `pos_adjust_bill` are honoured; for anyone else the function raises `POS_FORBIDDEN`, because the phone's hidden Remove button is not a permission.
- When waived, the service charge is 0 on the stored order. Record it on `orders` as `service_charge_waived boolean not null default false` (with the amount, so the bill can show it struck through) and in the `placed` event's `meta` (`service_charge_waived`, `reason`, actor).
- The return shape gains `service_charge_waived` and `service_charge_waived_amount`, exactly as in `pos_adjust_bill`. The phone reads both when present and falls back to working the amount out from the order's own figures when they are not.

#### Writes the phone makes directly today (the same soft role limit as menu editing, gap G2)

| Table | What the phone writes | App limit today | Suggested database rule once `has_org_role` exists |
| --- | --- | --- | --- |
| `org_bill_settings` | An upsert on `organization_id`: the first save inserts (nothing in the Master creates this row today); later saves are `update … where updated_at = <the version loaded>`, so two people cannot overwrite each other. A save that changes no row is read back to tell "someone saved first" (conflict) from "not allowed" | `org_owner`, `org_admin` edit; owners, admins, managers (and the other lead roles) and billers may view | write policies limited to `org_owner`, `org_admin`; read stays open to members |
| `channel_integrations` | `is_accepting` (and `next_open_at = null`) for one row, to switch Swiggy, Zomato and the other channels ON or OFF | `org_owner`, `org_admin`, `manager` | update policy limited to the same three roles |
| `org_users` | `role_id` and `status` of one member | `org_admin` only, which is exactly what `is_org_admin` allows. An `org_owner` sees the team read-only (the same fact as G5 and Q3) | unchanged |

Invitations are **not** created from the phone: `org_invites` has no policy for signed-in users, so the Team screen says plainly that invitations are sent from the VINII control panel, under Users & Roles.

#### Facts about `org_bill_settings` the phone relies on

- One row per organization, `service_charge_pct = 0` means the service charge is off, and each of `sgst_pct`, `cgst_pct`, `service_charge_pct` is `numeric(5,2)` between 0 and 50. The phone sets SGST and CGST to half of the chosen GST rate (presets 0, 5, 12, 18, or a custom rate in steps of 0.1 so the halves are exact) and writes both.
- GSTIN is validated on the phone as the standard 15-character shape (state code, PAN, entity number, `Z`, check character) and stored upper-case. FSSAI is 14 digits. Neither is checked by the database.
- `pos_place_order` and `pos_adjust_bill` must read the rates from this row at the moment of the call (rule R2), never from a number the phone sends.

#### Event registry

When these functions exist, add one row to §4.3: `bill_adjusted` → canonical event `order.bill_adjusted`, written by `pos_adjust_bill`.

#### What the store status control does, and does not, need from the database

Open, Paused and Closed for today use One Local's partner API as it is: `accepting` and `back_at`. There is no third value, so **Closed for today is stored as "not accepting until exactly 9:00 AM"** (today if it is still ahead, otherwise tomorrow), and a pause ends at a time counted from the moment it was set. Every phone reads the same answer the same way. No change is proposed.

#### Questions for the founder

1. May a **biller** remove a service charge? The app says no (owner, admin and manager only); the founder's documents are silent.
2. Is "Closed for today means off until 9:00 AM" acceptable, or should One Local gain a real closed state?
3. Does anything other than the Master's Channels page read `channel_integrations.is_accepting`? If Swiggy and Zomato orders are not filtered by it yet, the phone's switch is accurate but has no effect on those orders.
4. Should every member see the Team list, as the database allows today? The app shows it to every role, read-only.

---

## 5. Left for other owners (not changed here)

- **Master (Repo-1-):**
  - "View as" (D23).
  - `org_users.location_id` and location-scoped roles.
  - The server-side section checks noted in `Repo-1-/docs/one-latur-workspace.md`.
  - G7 and G8.
  - The `apps` table for minimum versions (foundations step 3).
  - The kernel's action catalogue (D22).
- **One Local (OL-ui):** aligned in cd05ac3 (foundations §6, D16–D25), which adopts §4 and fixes G6. 3817d71 switched its plan to this document's names (`sales_channel`, `pos_mark_handed_over`, one return shape), and its foundations §6.3 points here as the source. Still to do: publish the partner API sample response for R6, and add allowed actions to `GET /api/partner/me` for R8.
- **Windows POS (proviyaa-pos):** confirm §4.2. When PowerSync uploads, it calls §4.1, not raw table writes.

## 6. Open questions for the founder

- **Q1. Must the phone POS work offline?** The notebook says offline is required on every POS surface, phones included. That is an AI summary, and the part about phones had no source shown. The 26 Sep brief still listed it as open for captains. If yes, the phone joins the POS's PowerSync path (R9), which is weeks of work, not days.
- **Q2.** Approve one proposed Repo-1- migration covering G1, G2, G4 and the §4 functions? It is additive only, with a backup first, following the foundations rules.
- **Q3.** Should the restaurant **owner** be able to do everything the org admin can? The database says no today (G5).
- **Q4.** The notebook's plan names a separate central API service (`services/api`). This alignment uses database functions as that front door instead. No such service exists today, functions give one-transaction safety, and One Local already works this way. The One Local alignment reached the same answer independently: database functions plus each owner's server, with no separate gateway until outside partners call us. Is that acceptable?
- **Q5.** Should the restaurant see a One Local customer's **phone number**? The partner PRD shows it during an order so staff can call. Data-minimisation under DPDP says send it only if needed. Proposed: send it only while the order is live, which is what the partner API already does, and never store it on the kitchen order.
