# 01 — Database

**Scope.** VINII Partner, the Flutter mobile POS in `vinii_partner/`, at commit `da0a823`. Read-only audit, 2026-10-02. Nothing was changed.

**Evidence labels**
- **[code]**: read in this repository's source.
- **[ledger]**: read in a migration file.
  - `Repo-1-/supabase/migrations/` holds the OS and POS tables.
  - `OL-ui/db/migrations/` holds One Local's tables.
- **[snapshot]**: matches the production column list in `OL-ui/docs/CENTRAL_DB_MAP.md`, taken 2026-09-22.
- **[unverified]**: could not be checked.

**This app has no database of its own.** It has no migrations, no SQL files, no local SQLite, no Drift and no sqflite (`vinii_partner/pubspec.yaml`). It is a client of the shared Supabase project.

The only SQL in the repository is local-development tooling:
- `vinii_partner/tool/local_db/emulate_production_rls.sql` (and its `_undo`) copies production's member policies onto a local Docker replica.
- It is never run against production. Its header says so (lines 1–15).

---

## 1. Tables the app reads or writes directly (signed-in staff session, publishable key)

| Table | Defined in | App access | Code |
| --- | --- | --- | --- |
| `organizations` | [ledger] Repo-1- 0001 (+ `theme` in 0009) · [snapshot] | read, through the `org_users` embed: `id, name, slug, type, status, theme, settings` | `lib/data/live/live_workspace.dart:32-37` |
| `org_users` | [ledger] 0004 · [snapshot] | read; **update** `role_id`, `status` | `live_workspace.dart:32`, `live_team.dart:26,68-73` |
| `roles` | [ledger] 0004 (rows seeded in 0004 and 0019) · [snapshot] | read | `live_team.dart:45`, embedded in `live_workspace.dart:35` |
| `org_modules` | [ledger] 0007 · [snapshot] | read `module_key, enabled` | `live_workspace.dart:86-89` |
| `role_module_access` | [ledger] 0008 · [snapshot] | read `organization_id, module_key, visible, roles!inner(slug)` | `live_workspace.dart:101-107` |
| `menu_categories` | [ledger] 0006 | read; **insert, update, delete** | `live_menu.dart:30,64-79,90-95,111-115` |
| `menu_items` | [ledger] 0006 (+ columns in 0010) | read; **insert, update** (including `is_available`) | `live_menu.dart:35,154-165,175-180` |
| `dining_tables` | [ledger] 0006 (+ `area_id`, `qr_token`, `min_capacity` in 0010) | read | `live_pos.dart:31-37`, `live_tables.dart:24-30` |
| `dining_areas` | [ledger] 0010 | read (embedded) | `live_pos.dart:33`, `live_tables.dart:28` |
| `orders` | [ledger] 0006 + 0010 · [snapshot] | read only | `live_pos.dart:38-43,189-196,206-211` |
| `order_items` | [ledger] 0006 + 0010 · [snapshot] | read only (embedded in `orders`) | `live_pos.dart:24` |
| `payments` | [ledger] 0010 · [snapshot] | read only (embedded `amount`) | `live_pos.dart:24` |
| `org_bill_settings` | [ledger] 0010 · [snapshot] | read; **upsert** (ignore duplicates); **update** guarded by `updated_at` | `live_pos.dart:69-73`, `live_bill_settings.dart:26-67` |
| `channel_integrations` | [ledger] 0010 | read; **update** `is_accepting`, `next_open_at` | `live_channels.dart:24-51` |
| `vinii_storefronts` | **draft only, not applied**: Repo-1- branch `feat/experience-cms`, `0021_vinii_storefronts.sql` | read; **upsert** `draft`, `updated_by`; **update** `draft = null` | `live_storefront.dart:28-32,81-85,99-102` |
| `vinii_storefront_versions` | **draft only, not applied**: Repo-1- branch `feat/experience-cms`, `0021_vinii_storefronts.sql` | read | `live_storefront.dart:33-38` |

**Storage:** bucket `item-images` ([ledger] 0006; [snapshot] "Storage bucket: item-images (public)").
- The app uploads to `<organization_id>/<itemId>-<epoch ms>.<ext>` with `upsert: false` and stores the public URL in `menu_items.image_url` (`live_menu.dart:213-222`).
- Files are never deleted.

## 2. Tables written on the phone's behalf by One Local's server (service role)

The Orders tab calls One Local's partner API (`/api/partner/*`, §5 of `07_API_RPC_MAP.md`). That server runs database functions with the service role. The phone never touches these tables itself.

| Table | Defined in | Written by |
| --- | --- | --- |
| `ol_orders` | OL-ui 0021, columns added in 0022 | `ol_create_restaurant_order` (test order), `ol_partner_act` |
| `ol_merchant_channels` | OL-ui 0022 | `PATCH /outlet` (server code), `ol_partner_act` (`missed_in_a_row`, auto-pause) |
| `orders`, `order_items`, `kot_tickets`, `order_events`, `payments` | Repo-1- 0006, 0010 | `ol_create_restaurant_order`, `ol_partner_act` |
| `org_counters` | Repo-1- 0006 | `next_org_seq()` (order and KOT numbers) |
| `delivery_jobs` (and related) | OL-ui 0029 | One Local `server/dispatch.ts` on accept or reject. [unverified] whether 0029 is applied in production |

## 3. Columns of the POS transaction tables

### `orders` ([ledger] 0006 + 0010; [snapshot] identical column list)

| Column | Type / constraint |
| --- | --- |
| `id` | uuid PK, `gen_random_uuid()` |
| `organization_id` | uuid not null → `organizations(id)` on delete cascade |
| `order_no` | bigint not null; **unique (`organization_id`, `order_no`)** |
| `display_no` | text not null |
| `channel` | text, default `dine_in`, check in (`dine_in`, `delivery`, `pickup`, `online`, `swiggy`, `zomato`, `other`) |
| `status` | text, default `new`, check in (`new`, `in_billing`, `sent_to_kitchen`, `ready`, `awaiting_payment`, `paid`, `delivered`, `cancelled`) (0010 replaced the 0006 check) |
| `table_id` | uuid → `dining_tables(id)` on delete set null |
| `customer_name`, `customer_phone`, `captain_name` | text |
| `subtotal`, `gst_amount`, `total` | numeric(10,2) default 0 |
| `gst_pct` | numeric(4,2) default 5 |
| `payment_method` | text, null or in (`cash`, `upi`, `card`, `split`) |
| `created_by` | uuid → `auth.users` on delete set null |
| `created_at`, `updated_at` | timestamptz; trigger `orders_set_updated_at` |
| `session_id` | uuid → `table_sessions(id)` on delete set null (0010) |
| `placed_by` | text not null default `pos`, check in (`pos`, `captain`, `guest`, `integration`) (0010) |
| `guest_count` | int default 1 (0010) |
| `discount`, `service_charge`, `round_off` | numeric(10,2) default 0 (0010) |
| `paid_at` | timestamptz (0010) |
| `notes`, `external_ref` | text (0010). `external_ref` has **no unique constraint** |

- **Indexes:** `orders_organization_id_idx`, `orders_org_status_idx (organization_id, status)`, `orders_table_id_idx`, `orders_created_at_idx (created_at desc)`, `orders_session_id_idx`.
- **There is no** `location_id`, customer id, device id, idempotency key or payment-status column.

### `order_items` ([ledger] 0006 + 0010; [snapshot])
- **Base columns (0006):** `id` uuid PK; `order_id` → `orders` on delete cascade; `menu_item_id` → `menu_items` on delete set null; `name` text; `qty` int check > 0; `unit_price` numeric check ≥ 0; `add_ons` jsonb default `[]`; `notes`; `created_at`.
- **Added in 0010:** `variant_name`; `status` text default `pending`, check in (`pending`, `preparing`, `ready`, `delivered`, `cancelled`); `kot_ticket_id` → `kot_tickets` on delete set null; `course` default `eat`; `station` default `main`.
- **Indexes:** `order_id`, `menu_item_id`, `kot_ticket_id`.
- **No `organization_id`.** Row security goes through the parent order.

### `kot_tickets` ([ledger] 0006; [snapshot])
- `id`; `organization_id` → orgs (cascade); `order_id` → `orders` (cascade).
- `kot_no` bigint, **unique (`organization_id`, `kot_no`)**.
- `station` default `main`.
- `status` check in (`new`, `preparing`, `ready`, `delivered`). There is **no `cancelled` value**.
- `priority` check in (`normal`, `urgent`).
- `created_at`, `updated_at`, with trigger `kot_tickets_set_updated_at`.
- **Indexes:** `organization_id`, `order_id`, `(organization_id, status)`.

### `payments` ([ledger] 0010; [snapshot])
- `id`; `organization_id` (cascade); `order_id` → `orders` (cascade).
- `method` check in (`cash`, `upi`, `card`, `wallet`, `due`, `other`).
- `amount` numeric check **> 0**.
- `reference` text; `created_by` → `auth.users`; `created_at`.
- **Indexes:** `order_id`, `(organization_id, created_at desc)`.
- **No idempotency key, no status, no unique reference.**

### `order_events` ([ledger] 0010; [snapshot])
- `id`; `organization_id`; `order_id` (cascade); `kind` text **with no check**; `message` text not null; `actor` text; `meta` jsonb; `created_at`.
- **Indexes:** `(order_id, created_at)`, `(organization_id, created_at desc)`.
- The comment calls it "append-only", but nothing enforces that: there is no trigger, and an update policy exists through `apply_org_rls`.

### `org_counters` ([ledger] 0006; [snapshot])
- PK (`organization_id`, `kind`); `value` bigint.
- Only changed through `next_org_seq(org, kind)`, which is security definer and atomic: `insert … on conflict do update set value = value + 1`.
- Kinds in use: `order`, `kot`.

### Menu, tables and settings
- **`menu_categories` (0006):** `id`, `organization_id`, `name` (not blank), `sort_order`, `created_at`. Index on `organization_id`. No `updated_at` and no trigger.
- **`menu_items`:**
  - 0006: `id`, `organization_id`, `category_id` → `menu_categories` on delete set null, `name` (not blank), `sku`, `price` numeric ≥ 0, `image_url`, `is_available` default true, `sort_order`, `created_at`, `updated_at` (trigger).
  - Added in 0010: `description`, `food_type` check in (`veg`, `non_veg`, `egg`), `course` check in (`eat`, `drink`), `is_recommended`, `prep_minutes` default 10, `station` default `main`.
- **`dining_tables`:**
  - 0006: `id`, `organization_id`, `label` with unique (org, label), `seats` > 0, `is_active`, `sort_order`, `created_at`.
  - Added in 0010: `area_id` → `dining_areas` set null, `qr_token` **globally unique**, `min_capacity`.
- **`dining_areas` (0010):** `id`, `organization_id`, `name` with unique (org, name), `sort_order`, `created_at`.
- **`org_bill_settings` (0010):**
  - Columns: PK `organization_id` → orgs; `legal_name`, `address`, `gstin`, `fssai`, `phone`; `sgst_pct` and `cgst_pct` (default 2.5 each); `service_charge_pct` (default 0); `round_off_enabled`; `footer_note`; `updated_at`.
  - Trigger `org_bill_settings_set_updated_at`.
  - Check: each percentage between 0 and 50.
- **`channel_integrations` (0010):**
  - Columns: `id`, `organization_id`, `channel` check in (`swiggy`, `zomato`, `ondc`, `website`, `whatsapp`, `qr`), unique (org, channel); `display_name`, `is_connected`, `is_accepting`, `next_open_at`, `auto_accept`, `commission_pct`, `config`, `updated_at`.
  - Trigger on `updated_at`.

### Kernel
- **`organizations` (0001 + 0009):** `id`, `name`, `slug` (unique index), `type` **enum `org_type` (`franchise`, `investor`)**, `status` **enum `org_status` (`onboarding`, `active`, `suspended`)**, `legal_name`, `gstin`, contact fields, `settings` jsonb, `theme` jsonb (0009), `created_by`, `created_at`, `updated_at` (trigger). [snapshot] adds `source_lead_id`, `onboarding_stage`, `onboarding_owner` and `lifecycle_stage`.
- **`org_users` (0004):** `id`, `organization_id`, `user_id` → `auth.users`, `role_id` → `roles`, `email`, `full_name`, `status` **enum `member_status` (`active`, `suspended`)**, timestamps (trigger). **Unique (`organization_id`, `user_id`)**: one person may belong to several organizations.
- **`roles` (0004):** `id`, `slug` unique, check `^[a-z0-9]+(_[a-z0-9]+)*$`, `name`, `description`, `is_system`, `created_at`.
- **`org_modules` (0007):** PK (`organization_id`, `module_key` → `modules`), `enabled`, `config`, timestamps (trigger). The table comment says "Absence of a row means the module is not available".
- **`role_module_access` (0008):** `id`, `organization_id` (nullable; null = platform default), `role_id`, `module_key`, `visible`; unique nulls not distinct (org, role, module).

## 4. Enums

There are three Postgres enums: `org_type`, `org_status` and `member_status` (above). Every other status on a POS table is `text` with a `check` list.

## 5. Triggers

**Only `set_updated_at` triggers exist** on the tables above. They are on:
- `organizations`, `org_users`, `org_modules`, `role_module_access`
- `menu_items`, `orders`, `kot_tickets`
- `org_bill_settings`, `channel_integrations`, `item_channel_status`
- `ol_merchant_channels`

There is **no** trigger on `menu_categories`, `dining_tables`, `order_items`, `payments` or `order_events`.

There are **no business triggers**:
- no status-transition guard
- no totals check
- no stock or inventory trigger
- no event-emitting trigger

## 6. Functions

| Function | Defined in | Called by this app? |
| --- | --- | --- |
| `set_updated_at()` | Repo-1- 0001 | trigger only |
| `current_org_id()` | Repo-1- 0004: `select organization_id from org_users where user_id = auth.uid() and status = 'active' limit 1` | indirectly, through every policy |
| `is_org_admin(org)` | Repo-1- 0004: role slug = `org_admin` only | indirectly (`org_users` writes) |
| `is_platform_admin()` | Repo-1- 0001 | indirectly |
| `next_org_seq(org, kind)` | Repo-1- 0006 | no (the server functions call it) |
| `apply_org_rls(regclass)` | Repo-1- 0010 (helper that creates policies) | no |
| `ol_create_restaurant_order(p jsonb)` | OL-ui 0023 (service role only) | indirectly: `POST /api/partner/test-order` |
| `ol_partner_act(order, action, actor, actor_name, expected, prep, reason)` | OL-ui 0023 (service role only) | indirectly: accept, reject, ready, out, delivered |
| `ol_expire_unanswered(org)` | OL-ui 0023 (service role only) | indirectly: every `GET /api/partner/orders` |
| `pos_place_order(p)` | **none in any ledger** | **yes**, `live_pos.dart:100` |
| `pos_record_payment(p)` | **none** | **yes**, `live_pos.dart:156` |
| `pos_set_order_status(p)` | **none** | defined in `live_pos.dart:225` but **no screen calls it** |
| `pos_adjust_bill(p)` | **none** | **yes**, `live_pos.dart:254` |
| `pos_issue_table_qr(p)` | **none** | **yes**, `live_tables.dart:76` |
| `vinii_publish_storefront(p)` | **draft only, not applied** (Repo-1- branch `feat/experience-cms`, `0021_vinii_storefronts.sql`) | **yes**, `live_storefront.dart:117` |

**No migration on any branch of Repo-1-, OL-ui or proviyaa-pos defines the five `pos_*` functions.** This was confirmed by searching every `.sql` file on every branch (corrected 2026-10-02).

`vinii_publish_storefront` and the two storefront tables are defined in **one draft migration that is not applied**: `Repo-1-/supabase/migrations/0021_vinii_storefronts.sql`, on branch `feat/experience-cms` (worktree `Repo-1--experience-cms`). Its header says "DRAFT, NOT APPLIED". The first version of this audit missed it, because it searched only the checked-out branches. The full register is in `15_MIGRATIONS_NOT_APPLIED.md`.

Against a database built from these ledgers, each call fails with PostgREST `PGRST202` or Postgres `42883`. The app maps that to `FailureKind.notReady` and shows the "Not available yet" dialog (`live/errors.dart:33-41`). [unverified] Production's function list after 2026-09-22: the snapshot reports 29 functions but does not name them.

## 7. Views

None. Neither ledger contains a `create view` or `create materialized view`.

## 8. Realtime publication ([ledger])

- `supabase_realtime` includes `orders` and `kot_tickets` (0006: 448-449).
- It also includes `order_items`, `order_events`, `service_requests` and `table_sessions` (0010: 397-400).
- **The app subscribes to none of them.** See `08_REALTIME.md`.

## 9. Present in the database, not used by this app

These exist in the ledgers but the app never reads or writes them directly:
- `kot_tickets`, `order_events`, `org_counters`
- `table_sessions`, `service_requests`
- `menu_item_variants`, `kitchen_stations`, `item_channel_status`
- `locations` (0018; 0 rows in the snapshot), `org_invites`

Variants are not read anywhere, so a menu item's variants are invisible to the phone.
