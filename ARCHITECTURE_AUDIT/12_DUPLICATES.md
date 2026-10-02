# 12 — Duplicates and conflicts

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`. Each item is something observed in code or migrations, not a risk inferred in general.

## 1. Orders

1. **One Local orders appear in two places on the phone.**
   - The Orders tab reads them through the partner API, keyed by `ol_orders.status`.
   - The Sell tab's "Open orders" sheet reads `orders` directly: today, status not in (`paid`, `cancelled`) (`live_pos.dart:180-201`). That includes One Local's kitchen-side rows (`channel = 'online'`).
   - **The same order therefore shows in both lists.** The Sell side shows it as a POS order: `channel 'online'` falls through to `ServiceType.delivery` (`live_pos.dart:321-325`).
   - A **delivered** One Local order ends with `orders.status = 'delivered'`, not `paid` (OL-ui 0023, delivered branch). So it **stays in "Open orders" for the rest of the day**, even though it is paid in full.
2. **Two order-number streams share one counter.** One Local's function prints `OL-` + 5 digits from `next_org_seq(org,'order')`. Any other writer of `orders` draws from the same per-organization counter. Numbers cannot collide (unique `(organization_id, order_no)`), but each channel's displayed numbers will have gaps.
3. **No idempotency on `orders`.** The phone sends keys (06), but the `orders` table has no column for them, and `external_ref` is **not unique** (Repo-1- 0010). One Local's test order sends no key at all. Pressing "Send test order" twice creates two orders, by design.
4. **Different "order created" logic.**
   - `ol_create_restaurant_order` hard-codes GST at 5% and adds the delivery fee into `orders.total`.
   - The phone's estimate reads `org_bill_settings` (SGST + CGST, service charge, rounding) (`sell_cart.dart`, `domain/billing.dart`).
   - The phone POS's pricing is meant to be the missing `pos_place_order`.
   - So there are already **two pricing rules** for rows in the same `orders` table.

## 2. Customers
**No customer entity exists on this app's side.** The same customer is stored as free text on every order (`orders.customer_name` and `customer_phone`). On One Local's side the same person is `ol_orders.customer_hash` or `user_id`. Nothing links the two.

## 3. Products
- **Two availability switches** with overlapping meaning:
  - `menu_items.is_available`, which applies everywhere and is written by this app;
  - `item_channel_status` for `one_local`, written by One Local's `/items` and **not visible in this app**.
  - An item can be "available" on the phone and "off" for One Local, or the reverse. Nothing on the phone shows the second switch.
- **Several editors of `menu_items`:** this app, the Repo-1- web console, and [unverified] the Windows POS. None of them uses a version check, so the last write wins (06).
- **Variants:** `menu_item_variants` defines prices that the phone never reads. The phone always uses `menu_items.price`, which the table comment calls the "starts at" price when variants exist.

## 4. Inventory
No inventory exists (05), so there are no duplicates.

## 5. Payments
- **No idempotency in the database.** `payments` has no key column and `reference` is not unique. Duplicate protection depends entirely on the missing `pos_record_payment` (phone) or on `ol_partner_act`'s state check (One Local delivery).
- **Two ways to mark "paid":**
  - One Local's delivered path sets `orders.payment_method = 'cash'`, `paid_at`, status `delivered`, and inserts a payment row.
  - The phone treats an order as paid when `status = 'paid'` or the payments add up to the total (`domain/pos_order.dart:228`).
  - Neither path sets the other's marker.
- **The cash-on-delivery row's `amount` equals `orders.total`**, which includes One Local's delivery fee. Restaurant takings counted from `payments` therefore include money that belongs to the delivery fee.

## 6. KOTs
- **Two status fields for the same kitchen work:** `kot_tickets.status` and `order_items.status`, plus `orders.status` and `ol_orders.status`. One Local's function updates all of them together. Nothing in the database keeps them consistent for other writers (no trigger).
- **`order_events.kind` repeats state** already held in the status columns. It has no check list, so any string is accepted.

## 7. Identity and organization choice
**Two different rules for "which organization is this person in":**
- the database's `current_org_id()`: `limit 1`, no order;
- One Local's partner API: earliest active membership.

For a person with two memberships they can disagree. The app then refuses the delivery inbox (`partner_api_inbox.dart:135-148`).

## 8. Configuration
- **Module availability is read two ways.**
  - The `org_modules` table comment says "Absence of a row means the module is not available to the org at all" (Repo-1- 0007).
  - The app treats a missing row for `dashboard`, `orders`, `pos` or `menu` as **on** (`domain/app_definition.dart:77-81`).
- **The storefront draft can live in two places:** the `vinii_storefronts.draft` column (if it existed) and SharedPreferences `storefront_draft:<orgId>`. `load` prefers the database and falls back to the phone (`live_storefront.dart:61-67`).
