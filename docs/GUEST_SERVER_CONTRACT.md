# Guest server contract: nearby orders, tables like yours, coupon codes

**Date:** 2026-10-02 · **Applies to:** the guest storefront in `vinii_partner/` · **Status:** the app side is built and shown against pretend services in the design gallery. **Nothing here is applied, and no migration was written.** Database changes and server functions are the founder's to write; this page is the exact shape the app will call.

**Why these three:** the founder asked for (1) "what someone else is ordering around you, so you can quickly add it", (2) "copy the order of a table with similar seating, see it as a preview, order that", and (3) coupon codes at checkout.

## 0. Rules that apply to all three

- **The phone sends intent, the server decides** (contract R1). The phone never computes a coupon discount, never reads another table's order rows itself, and never holds a secret.
- **Functions take one `p jsonb`** like the rest of the POS functions, and check that the caller may act for `organization_id`: a staff session today (a phone handed to a table), a table-session token later (rule R10). A guest must never be able to read rows of another restaurant or any customer detail.
- **Anonymous by design.** What leaves the server about other tables is: a dish, a quantity, a time, a label the SERVER chose ("Table 7" or "A table near you"), and, for tables like yours, the party size. Never a name, phone, note, payment, total, address or order number.
- **Off unless the restaurant turns it on.** One switch per feature on the organization (suggested `org_guest_settings`: `nearby_orders_enabled`, `similar_tables_enabled`, `coupons_enabled`, all default false). The Master CMS needs a place to set them (Storefront, Features).
- **The app shows nothing until the function exists.** `GuestOrderGateway.nearby`, `.similarTables` and `.coupons` are `null` on every live gateway today, so no coupon row, no alert and no "tables like yours" appear. When a function exists, the live adapter is written against it and the matching getter returns it.

## 1. `guest_nearby_orders(p jsonb)`: what the tables around are ordering

| `p` key | Meaning |
| --- | --- |
| `organization_id` | The restaurant |
| `table_id` | The guest's own table (from the QR code). Its own orders are never returned |
| `since` | Optional cursor (timestamptz): only events after it |
| `limit` | At most 20 |

**Returns** `[{ id, menu_item_id, qty, who, ordered_at }]`, oldest first. `id` is unique per event (an order line), so the app never shows one twice.

**What the server does:** "around you" = tables in the same area as `table_id` (`area` / zone; if tables have no areas, the same outlet). Takes order lines placed in the last 10 minutes at those tables whose order is not cancelled or void, and whose dish is on sale and visible to guests. `who` is `"Table 7"` only if `show_table_labels` is on for the restaurant, otherwise `"A table near you"`.

**Delivery:** the app listens to a stream. The first adapter can poll every 10 seconds with `since`; a Realtime channel with the same payload is better later. The app shows at most one alert per 20 seconds, never for a dish already in the guest's order, and drops anything older than 30 seconds.

## 2. `guest_similar_table_orders(p jsonb)`: tables like yours

| `p` key | Meaning |
| --- | --- |
| `organization_id` | The restaurant |
| `table_id` | The guest's own table (excluded from the answer) |
| `party_size` | How many are at the guest's table (the app asks them at the start) |
| `limit` | At most 4 |

**Returns** `[{ id, who, party_size, ordered_at, lines: [{ menu_item_id, qty }] }]`, newest first, one per table.

**What the server does:** recent orders (last 3 hours) that were served or are in progress, from other tables whose party was within one person of `party_size` (or the same seat class), at most one per table, with at least one dish still on sale. `who` is `"Table 5"` or, to hide numbers, `"A table of 4"`. No totals: the app prices every line from the live menu, and shows a dish that is no longer on sale as "No longer available".

## 3. Coupon codes

### 3.1 `guest_validate_coupon(p jsonb)`

| `p` key | Meaning |
| --- | --- |
| `organization_id` | The restaurant |
| `code` | What the guest typed (the app sends it trimmed and in upper case; match case-insensitively) |
| `service_type` | `dine_in`, `takeaway` or `delivery` |
| `lines` | `[{ menu_item_id, qty }]`: ids and quantities only |
| `table_id` | Optional |

**Returns** `{ valid, code, discount, label, message }`. `discount` is rupees off the food, worked out by the server from its own menu prices, two decimals. `label` is a short line for the guest ("10% off, up to ₹100"). `message` is the plain reason when `valid` is false ("Add ₹50 more to use SAVE10", "This code has expired", "That code isn't valid"). Do not reveal which other codes exist.

The app asks again, a third of a second after each change to the cart, while a coupon is applied, so the discount on screen never outlives the cart it was worked out for. A code that stops fitting is taken off with the server's message.

**Rules the server owns:** active window, channels, minimum order, maximum discount, percent or flat, total and per-customer limits, scope (categories or dishes), and no stacking. All of them again at placement.

### 3.2 `pos_place_order` gains an optional `coupon_code`

Sent only when the guest applied one. The server validates it again, applies the discount **before** service charge and GST (the OS bill order: food minus discount, then service charge, then GST, then round-off), stores it on the order (`discount`, and which coupon), and records a redemption keyed to the order and its idempotency key so a retry never redeems twice. If the code no longer applies it refuses with a plain message; the app shows it and the guest can place the order without the code. The preview bill in the app is only an estimate; the server's figure on the order wins.

### 3.3 Tables (founder to design; this is the shape the functions assume)

- `coupons`: `id`, `organization_id`, `code` (unique per organization, case-insensitive), `kind` (`percent` | `flat`), `value`, `max_discount`, `min_order`, `channels text[]`, `starts_at`, `ends_at`, `usage_limit`, `per_customer_limit`, `category_ids uuid[]`, `item_ids uuid[]`, `active`, audit columns.
- `coupon_redemptions`: `coupon_id`, `order_id` (unique), `customer_ref`, `discount`, `created_at`.
- Row security: staff of the organization read; only the service role writes redemptions.
- The Master needs a **Coupons** page (create, pause, see redemptions). It is outside this repository.

## 4. What the app does today

- `lib/application/guest_social.dart` and `guest_coupons.dart` hold the seams. The gallery (`tool/gallery/`) has pretend services (`GalleryCoupons`: SAVE10, FLAT50, WELCOME; invented nearby orders and tables) so the screens can be seen and tried; the live gateways return `null`.
- `PosOrderDraft` carries `couponCode` and `couponDiscount`; `LivePos.placeOrder` adds `coupon_code` to `pos_place_order` only when it is set, which is harmless against the function as it is today.
- Studio's preview shows none of the three (it has no server to ask).

## 5. How to test each function (suggested)

For each one: (1) a guest of restaurant A gets nothing of restaurant B; (2) the switch off returns nothing; (3) no personal field is ever in the answer; (4) the guest's own table never appears; (5) a retry or a repeat call changes nothing. Coupons add: expired, not yet started, wrong channel, below minimum, over the usage limit, and the same code used twice on one order (idempotency).
