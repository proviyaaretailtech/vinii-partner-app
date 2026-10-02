# 15 — Migrations not applied (complete register)

**Scope.** Every database change that VINII Partner, or a service it talks to, depends on, and that is not applied to the shared database.

**How this was found**
- Every `.sql` file on **every branch** of `Repo-1-`, `OL-ui` and `proviyaa-pos` was listed and read.
- Applied status comes from each file's header and from the repositories' own journals.
- **Production was not queried.** "Applied" and "not applied" are as recorded, not checked live.
- Per the founder's standing instruction, **no SQL was written**. Section C lists names and shapes only.

## A. Applied (for reference)

| Migrations | Where | Status | Evidence |
| --- | --- | --- | --- |
| `0001`–`0020` | Repo-1- `supabase/migrations` (the single ledger, foundations D7) | **Applied** | Listed in production `schema_migrations` (snapshot 2026-09-22) |
| `0021_one_local_core`, `0022_partner_orders`, `0023_partner_order_functions`, `0024_order_items_audit_refunds` | OL-ui `db/migrations` (branch `feat/expo-router-api`) | **Applied, but not recorded** | One Local journal: "0021–0024 are confirmed live in production". Not in `schema_migrations` and not copied into the Repo-1- ledger (foundations D7) |

## B. Migration files that are written but NOT applied

| # | File | Repo · branch | What it creates | Needed by | Status evidence |
| --- | --- | --- | --- | --- | --- |
| B1 | `0021_vinii_storefronts.sql` | Repo-1- · `feat/experience-cms` (worktree `Repo-1--experience-cms`) | Tables `vinii_storefronts`, `vinii_storefront_versions` (an append-only trigger blocks updates). Functions `vinii_is_member`, `vinii_can_edit_storefront`, `vinii_can_publish_storefront`, `vinii_publish_storefront(p)`. A private bucket `storefront-media` (5 MB). Row security by role | **VINII Partner** Studio (save draft, publish), Master storefront CMS, guest QR page | Header: "STATUS: DRAFT, NOT APPLIED. Needs the founder's approval … and a final number" |
| B2 | `0025_ol_payments.sql` | OL-ui · `feat/expo-router-api` | Table `ol_payment_events`; Razorpay columns on `ol_orders` | One Local online payments | One Local journal 2026-09-27: "written but not applied" |
| B3 | `0026_ol_checkouts.sql` | OL-ui · `feat/expo-router-api` | Table `ol_checkouts`; function `ol_checkout_payment_to_orders`; columns on `ol_orders`, `ol_coupons`, `ol_payment_events` | One Local multi-store checkout | Header: "DRAFT … NOT APPLIED". **Needs B2 first** |
| B4 | `0027_ol_privacy.sql` | OL-ui · `feat/expo-router-api` | Tables `ol_consents` (append-only, via function `ol_consents_append_only`) and `ol_privacy_requests` | One Local DPDP consent and requests | Header: "DRAFT … NOT APPLIED" |
| B5 | `0028_ol_marketplace_listings.sql` | OL-ui · `feat/expo-router-api` | On `ol_stores`: `status` (draft, pending, live, paused), `location_id`, `cover_image`, `lat`, `lng`, `delivery_radius_km`, `approved_by`, `approved_at`, `updated_at` (+ trigger); a unique live-listing index; a city/status index | Master "One Latur" listings (which answer "Apply migration 0028 first" until then) | Header: "DRAFT … NOT APPLIED to any database" |
| B6 | `0029_ol_dispatch.sql` | OL-ui · `feat/expo-router-api` | Tables `riders`, `rider_store_links`, `rider_availability`, `push_tokens`, `org_dispatch_settings`, `delivery_jobs`, `delivery_assignments`, `delivery_events`. Functions `dispatch_km`, `dispatch_create_job`, `dispatch_release`, `dispatch_offer_next`, `dispatch_answer`, `dispatch_cancel`, `dispatch_due_jobs` | Rider dispatch. One Local's accept and reject hooks call it, but when it is missing the hook skips quietly (`dispatch.ts:346-352`), so the phone is unaffected | Header: "DRAFT: applied nowhere". **Needs B2 and B3 first** |
| B7 | `20260918_create_online_orders.sql` | proviyaa-pos · `main` | Table `online_orders` with **anonymous full read and write** (`using (true)`) | Windows POS online-orders screen | Not in production (checked by the One Local session, 2026-09-28). One Local journal: "must not be applied as written" |

**Numbering clash.**
- Repo-1-'s draft B1 is numbered `0021`.
- One Local's applied `0021_one_local_core` and its drafts `0022`–`0029` use the same range.
- Under foundations D7 the Repo-1- ledger assigns the real numbers; every OL-ui number is a placeholder.

**Other SQL found, not part of this platform's ledger**
- `OL-ui` branch `main`: `backend/schema.sql`. An older One Local schema with its own `users` table, from before the shared-database plan. Superseded.
- `Repo-1-` remote branch `backup/remote-before-restore`: `saas_mobile_app/supabase/migrations/2026051x…` and `20260630_meeting_room_booking_comment.sql`. These belong to a different application (meeting-room booking).

## C. Changes the phone app needs that have NO migration written (founder to write)

The exact call shapes are in `docs/PLATFORM_CONTRACT_ALIGNMENT.md` (§4.1, §4.5), `docs/GUEST_SERVER_CONTRACT.md`, `docs/PAYMENTS_CASHFREE.md` and `docs/RIDER_DISPATCH_CONTRACT.md` (the last is not yet committed by the session that wrote it). Each function takes one `jsonb` argument `p` and raises `POS_<CODE>: message`.

### C1. Order functions (POS-owned)

| Function | `p` (keys) | Phone today (what staff see) |
| --- | --- | --- |
| `pos_place_order` | `organization_id`, `idempotency_key`, `service_type`, `table_id?`, `guest_count?`, `customer_name?`, `customer_phone?`, `notes?`, `scheduled_for?`, `placed_by`, `fire_kot`, `lines[{menu_item_id, qty, notes?, variant_id?}]`, `waive_service_charge?`, `waive_reason?`, `coupon_code?`. **Service role only:** `sales_channel`, `display_prefix`, `external_ref`, `actor_user_id`, `request_id`, `app` | "Send to kitchen" / "Save & hold" → *Not available yet* |
| `pos_record_payment` | `order_id`, `method`, `amount`, `idempotency_key`, `reference?`, `expected_updated_at` (`method 'online'` service role only) | "Charge" (single and split) → *Not available yet* |
| `pos_set_order_status` | `order_id`, `to`, `expected_updated_at`, `reason?` | No screen calls it yet |
| `pos_adjust_bill` | `order_id`, `expected_updated_at`, `waive_service_charge`, `waive_reason?` | "Remove service charge" on a saved order → *Not available yet* |
| `pos_issue_table_qr` | `table_id`, `replace?` | "Issue code" / "Replace code" → *Not available yet* |
| `pos_mark_handed_over` | `order_id`, `expected_updated_at`, `request_id?`, `actor_user_id?` | Not called by the phone. Needed by One Local's server for "out for delivery" |

### C2. Columns and value lists

| Change | Why |
| --- | --- |
| `orders.idempotency_key`, unique per organization when present | A retried order must not create a second order (gap G4) |
| `payments.idempotency_key`, unique per organization when present | A retried payment must not be recorded twice |
| `orders.service_charge_waived` (boolean, default false) and the waived amount | The phone reads `service_charge_waived` and `service_charge_waived_amount` (`live_pos.dart:339-340`) |
| Which coupon was used, on the order | Guest coupon codes (C4) |
| Add `online` to `payments.method` and to `orders.payment_method` | Gateway payments (C5) |

### C3. Access-rule fixes found by the audit (10_RLS_SECURITY.md)

| Change | Gap |
| --- | --- |
| `is_org_member(org)`, used in place of `current_org_id()` in member policies | G1: a person in two restaurants sees only one, chosen arbitrarily |
| `has_org_role(org, roles[])`, with role-aware write policies on `menu_*`, `orders`, `order_items`, `kot_tickets`, `payments`, `org_bill_settings`, `channel_integrations` | G2: any member can change prices, orders and payments directly |
| `next_org_seq` checks that the caller belongs to `org` | Any signed-in user can advance another restaurant's counters |
| `item-images` storage policies limited to the caller's `<organization_id>/` folder | Any signed-in user can replace or delete any restaurant's photos |
| A status-move guard on `orders` (after the POS owner confirms the allowed moves) | Nothing stops a status moving backwards |
| `org_owner` allowed where `org_admin` is (decision Q3) | G5: owners cannot update their organization or team |

### C4. Guest features (`GUEST_SERVER_CONTRACT.md`)
- **Functions:**
  - `guest_nearby_orders(p {organization_id, table_id, since?, limit})`
  - `guest_similar_table_orders(p {organization_id, table_id, party_size, limit})`
  - `guest_validate_coupon(p {organization_id, code, service_type, lines, table_id?})`
- **Tables:**
  - `org_guest_settings` (`nearby_orders_enabled`, `similar_tables_enabled`, `coupons_enabled`)
  - `coupons`
  - `coupon_redemptions`
- **Phone today:** none of the three features is shown.

### C5. Online payments (`PAYMENTS_CASHFREE.md`)
- **Functions:** `pos_start_online_payment(p)` and `pos_online_payment_status(p {attempt_id})`.
- **Table:** `online_payments` (`attempt_id` unique, `provider_order_id` unique, `order_ids uuid[]`, `amount`, `status`, `payer_phone`, …). Only the service role writes it.
- **Server:** a signed webhook endpoint (server code, not a migration).
- **Phone today:** no Pay button; the bill tells guests to pay staff.

### C6. Rider dispatch, beyond draft B6 (`RIDER_DISPATCH_CONTRACT.md`)
- **Tables:** `delivery_proofs`, `delivery_exceptions`, `rider_cash_ledger`, `rider_earnings`.
- **Columns:** `delivery_jobs.idempotency_key` (unique), `delivery_events.v`.
- **Server endpoints:** `/api/dispatch/jobs`, `release`, `cancel`, `GET`.
- **Phone today:** unaffected.

## D. Dependencies between them
- B3 needs B2. B6 needs B2 and B3.
- C1 needs the two key columns in C2 to keep its idempotency promise.
- The phone's coupon and waiver fields need C2's columns to be stored.
- B1 is independent of everything else.
- Applying any of them is the founder's decision. This audit only records the dependencies.
