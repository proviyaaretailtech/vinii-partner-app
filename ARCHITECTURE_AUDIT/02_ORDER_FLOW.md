# 02 — Order flow

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`. Paths are relative to `vinii_partner/lib/` unless they say otherwise.

The app has **three separate order flows**. They share no code path for writing.

| Flow | Screens | Who writes the database |
| --- | --- | --- |
| **A. Phone POS** (dine-in, takeaway, delivery taken at the counter) | Sell → Checkout → Order | Would be the RPC `pos_place_order`, which **does not exist** in any migration (01 §6) |
| **B. Guest on a handed-over phone** | Guest runtime (`/guest`) | The same RPC as A, with `placed_by = guest` |
| **C. Marketplace delivery** (One Local) | Orders tab, new-order alert | One Local's server, through `ol_partner_act` (exists, OL-ui 0023) |

---

## A. Phone POS

### A1. LOGIN
- **Screen:** `presentation/auth/sign_in_screen.dart` (route `/sign-in`).
- **User action:** enters an email and password, then taps Sign in.
- **Code:** `SessionController.signIn` (`application/session_controller.dart:119`) → `LiveAuth.signIn` (`data/live/live_auth.dart:28-48`).
- **API:** Supabase Auth `signInWithPassword`; the client uses the PKCE flow (`live_backend.dart:89-96`).
- **Tables:** `auth.users` (Supabase-managed; the app writes nothing).
- **Insert / update:** none by the app.
- **Status:** the session stage (`SessionStage`, `session_controller.dart:14-35`) moves from `signedOut` to `noAccess`, `choosingOrg`, `updateRequired` or `ready`. A failure goes to `bootError`.
- **Side effect:** supabase_flutter persists the session.
- **Then, in `_loadWorkspace` (`session_controller.dart:132-158`):**
  - It reads `org_users` with `roles` and `organizations` (`live_workspace.dart:32-37`).
  - It writes `last_org:<userId>` to SharedPreferences.
  - It reads `org_modules` and `role_module_access` (`live_workspace.dart:82-125`).
  - If the app version is below `organizations.settings.app.min_app_version`, it opens the update-required gate (`:153`).
- **Event:** none.

### A2. LOCATION: **not implemented**

The app has no location or branch step and no `location_id` anywhere. The step it does have is **organization selection**:
- It opens the remembered organization, or the only one, automatically.
- Otherwise it shows `OrgPickerScreen` (`/organizations`).
- `WorkspaceRepository.activate` only sets `activeOrganization` in memory (`live_workspace.dart:77-79`). Nothing is written to the database.
- **Database limit:** `org_users_member_select` filters by `current_org_id()`, which returns one membership (`limit 1`). A person in two organizations therefore sees only one of them in the picker. The code acknowledges this at `live_workspace.dart:28-31`.

### A3. TABLE / ORDER TYPE
- **Screens:** `presentation/pos/sell_screen.dart` and `presentation/pos/ticket_view.dart`. TicketView sits beside the menu on wide screens and on `/sell/checkout` on phones (`checkout_screen.dart:29`).
- **User action:** picks Dine-in, Takeaway or Delivery, then picks a table for Dine-in.
- **Code:** `SellCart.setServiceType`, `setTable`, `setGuestCount` (`application/sell_cart.dart:194-208`).
- **API, for the table list:** `LivePos.tables()` (`live_pos.dart:27-64`) runs two reads:
  - `dining_tables` where `is_active`, ordered by `sort_order` and `label`, with `dining_areas.name`.
  - `orders.table_id` where `status not in (paid, cancelled)`, to mark tables as occupied.
- **Insert / update:** none. **Status:** none.
- **Mapping:** Dine-in → `dine_in`, Takeaway → `pickup`, Delivery → `delivery` (`domain/pos_order.dart:4-13`).

### A4. CUSTOMER
- **Screen:** TicketView text fields.
- **User action:** types a name and phone. These only matter for takeaway and delivery; for dine-in they are not sent (`sell_cart.dart:278-279`).
- **Code:** `SellCart.setCustomerName` and `setCustomerPhone`. A delivery order is blocked until the phone has at least 10 digits (`sell_cart.dart:255-258`).
- **Tables:** none. **There is no customer entity or customer ID.** The name and phone travel as free text in the RPC payload, as `customer_name` and `customer_phone`.

### A5. PRODUCT
- **Screen:** `sell_screen.dart`, a menu grid with category chips.
- **User action:** taps Add, or long-presses to set quantity and a note.
- **Code:** `SellCart.load` (`sell_cart.dart:71-92`) → `LiveMenu.load` (`live_menu.dart:25-48`) and `LivePos.billCharges` (`live_pos.dart:67-83`).
- **Tables read:**
  - `menu_categories`
  - `menu_items`
  - `org_bill_settings`, for `sgst_pct`, `cgst_pct`, `service_charge_pct` and `round_off_enabled`. Defaults are used when the table or row cannot be read.
- **Rules:**
  - An item with `is_available = false` cannot be added (`sell_cart.dart:124`).
  - Variants (`menu_item_variants`) are never read.
  - Per-channel availability (`item_channel_status`) is not consulted.

### A6. CART
- **State:** `SellCart`, a `ChangeNotifier` held **in memory only** and not persisted. It is discarded on sign-out and on organization switch.
- **User actions:** change quantity, add a note, clear the order (`ticket_view.dart` `_clear`), and remove the service charge before sending (`setServiceChargeWaived`, for owner, admin and manager).
- **Bill:** `BillSummary.of(...)` gives an **estimate** only (`sell_cart.dart:290-306`). Its own comment says the server prices the order.
- **Tables:** none.

### A7. ORDER (the only write in the POS flow)
- **Screen:** TicketView, with two buttons: **Save & hold** (`_send(fire: false)`) and **Send to kitchen** (`_send(fire: true)`) (`ticket_view.dart:445-460`).
- **Code path:**
  - `_send` sets `placed_by` to `captain` when the role slug is `captain`, and `pos` otherwise (`ticket_view.dart:77-81`).
  - `SellCart.place` (`sell_cart.dart:317-345`).
  - `PendingKeys.run('order:<orgId>')` (`application/sell_keys.dart:36-49`). The idempotency key is a UUID v4, **saved to SharedPreferences before the request is sent**.
  - `LivePos.placeOrder` (`live_pos.dart:86-139`).
- **RPC:** `pos_place_order(p)` with:
  - `organization_id`, `idempotency_key`, `service_type`
  - `table_id`, `guest_count`, `customer_name`, `customer_phone`, `notes`, `scheduled_for`
  - `placed_by`, `fire_kot`
  - `waive_service_charge` and `waive_reason` (only when waived)
  - `coupon_code` (only when set)
  - `lines[{menu_item_id, qty, notes}]`
  - **No prices, totals or variants are sent.**
- **Tables, insert, update and status:** whatever the server function does. The function **is not defined in any migration**, so on a database built from the ledgers there is **no write at all**.
- **Expected response:** an order row (`live_pos.dart:287-348`) with `id`, `display_no`, `status`, `channel`, `updated_at`, the money fields, `lines` or `order_items`, and `paid`.
- **Today's actual outcome:**
  - PostgREST `PGRST202` or `42883` becomes `FailureKind.notReady`.
  - A dialog says "Taking orders from the phone needs the POS order functions … take this order at the POS counter" (`live_pos.dart:16-18`).
  - The key **stays saved**: only `rejected` and `forbidden` clear it (`sell_keys.dart:44-46`).
- **On success:**
  - If the returned lines match the cart, the cart is cleared and the app opens `/sell/order/<id>`.
  - If they differ, the server returned an earlier order for that key. The dialog "An earlier order went through" appears and the cart is kept (`ticket_view.dart:116-142`).
- **Event:** none by the app. The contract expects the server to write `order_events` (`placed`, `kot_fired`); not verifiable.

### A8. ORDER ITEMS: not written by the app
The lines exist only inside the RPC payload. The app reads `order_items` back, embedded in `orders` (`live_pos.dart:24`), and **hides lines whose status is `cancelled`** (`live_pos.dart:292`).

### A9. KOT → KITCHEN → READY: **not implemented for phone POS orders**
- The app has no kitchen display and no "mark ready" for POS orders.
- `PosRepository.setStatus` → `pos_set_order_status` exists (`live_pos.dart:218-245`), but **no screen or controller calls it**. A search of `presentation/` and `application/` found only `TeamRepository.setStatus` callers.
- The only KOT intent is the `fire_kot` flag in A7. See `03_KOT_FLOW.md`.

### A10. BILL
- **Screen:** `presentation/pos/pos_order_screen.dart` (`/sell/order/<id>`).
- **Reads:** `LivePos.refresh` (`live_pos.dart:203-216`) fetches `orders` with `dining_tables`, `order_items` and `payments(amount)`. The screen shows the **stored** figures (`subtotal`, `discount`, `service_charge`, `gst_amount`, `round_off`, `total`) and never recomputes them (`live_pos.dart:329-341`).
- **User action:** remove the service charge from a saved, unpaid order, or put it back.
- **Code:** `_adjust` (`pos_order_screen.dart:210-240`) → `LivePos.adjustBill` (`live_pos.dart:247-275`).
- **RPC:** `pos_adjust_bill(p {order_id, expected_updated_at, waive_service_charge, waive_reason})`. **It does not exist**, so the app shows "Not available yet".
- **Local side effect:** the cashier's keep-or-remove answer to the final-order prompt is remembered in SharedPreferences (`service_charge_choice:<orderId>`, `local_prefs.dart:59-62`).
- **No bill printing exists** (see `09_HARDWARE.md`).

### A11. PAYMENT
Done in `presentation/pos/payment_card.dart`, which calls `pos_record_payment`. That function **does not exist**. Full detail is in `04_PAYMENT_FLOW.md`.

### A12. COMPLETION: no separate step
- The app treats an order as finished when the server returns `status = paid`, or when the amount due is at most 0.009 (`domain/pos_order.dart`, `PlacedOrder.isPaid`).
- The "Open orders" sheet (`presentation/pos/open_orders_sheet.dart:48`) lists **today's orders not in (`paid`, `cancelled`)**, newest first, up to 100 (`live_pos.dart:180-201`).
- Completed or cancelled orders cannot be reopened from the phone.

---

## B. Guest on a handed-over phone

- **Entry:** the Sell screen's hand-to-guest button, for a chosen table (`sell_screen.dart:84-85` → `/guest?table=<id>`).
- **Code:**
  - `GuestSession.place` (`application/guest_session.dart:435-470`) builds a `PosOrderDraft` with `placed_by = guest`.
  - Delivery details are folded into `notes` as `"Deliver to: …"` (`:425-431`).
  - It sends through `PosGuestGateway.place` (`application/guest_gateway.dart:60-79`), which calls the same `pos_place_order` as A7, **under the staff member's session**.
- **Idempotency key:** UUID v4 held **in memory only**, in `GuestSession.pendingKey` (`guest_session.dart:437`). Unlike A7 it is **not saved on the phone**, so killing the app loses it.
- **Tracking:** `PosGuestGateway.watch` polls `LivePos.refresh` every 5 s while the order is open (`guest_gateway.dart:82-94`).
- **Studio preview:** `PreviewGuestGateway` returns a local stand-in order numbered `PREVIEW` and writes nothing (`guest_gateway.dart:100-127`).

---

## C. Marketplace delivery orders (One Local)

The phone only calls One Local's HTTP API (`data/live/partner_api_inbox.dart`). One Local's server code is in `OL-ui/frontend/server/restaurant.ts` and `partner.ts`. It runs the database functions with the service role. Function bodies were read in `OL-ui/db/migrations/0023_partner_order_functions.sql`.

| Step | Screen / user action | Phone call | Server and database effect ([ledger] OL-ui 0023 and `restaurant.ts`) | Event rows |
| --- | --- | --- | --- | --- |
| Order arrives | none: a poll every 5 s while accepting, every 30 s otherwise (`application/inbox_controller.dart:77-88`) | `GET /api/partner/orders?tab=new` | First runs `ol_expire_unanswered(org)` (`restaurant.ts:49`), which can **cancel** orders past their deadline (C7). Then reads `ol_orders` joined to `orders` and `order_items` | none on a plain read |
| Alert | `presentation/orders/new_order_alert_screen.dart` rings and vibrates (`application/ring_player.dart`) | — | — | — |
| Accept | Accept with a prep time (`new_order_alert_screen.dart:173`, `delivery_order_screen.dart:181`) | `POST /orders/<posOrderId>/accept {version, prep_minutes}` | **Checks:** role (`require(staff,'accept')`), organization (`restaurant.ts:81-82`), version (`OL_STALE`). **Writes:** `kot_no = next_org_seq(org,'kot')`; **INSERT** `kot_tickets` (station `main`, status `new`); **UPDATE** `order_items.kot_ticket_id` for pending lines; **UPDATE** `orders.status` `new` → `sent_to_kitchen`; **UPDATE** `ol_orders` (`accepted`, `prep_minutes`, `eta_minutes`); **UPDATE** `ol_merchant_channels.missed_in_a_row = 0`. **Then:** dispatch `onRestaurantAccepted` touches `delivery_jobs` | `accepted`, `kot_fired` |
| Reject | Reject with a reason (`new_order_alert_screen.dart:181`, `delivery_order_screen.dart:92`) | `POST …/reject {version, reason}` | `orders` → `cancelled`; `order_items` → `cancelled`; `ol_orders` → `cancelled` with `cancel_reason`; missed counter reset; dispatch `onRestaurantRejected` | `rejected` |
| Ready | Mark ready (`delivery_order_screen.dart:207`) | `POST …/ready {version}` | `kot_tickets` → `ready`; `order_items` → `ready`; `orders` → `ready`; `ol_orders` → `packed` | `kot_ready` |
| Out | Slide to confirm (`delivery_order_screen.dart:216`) | `POST …/out {version}` | `kot_tickets` → `delivered`; `order_items` → `delivered`; `orders.updated_at` bumped (**status stays `ready`**); `ol_orders` → `out` | `out_for_delivery` |
| Delivered | Slide to confirm (`delivery_order_screen.dart:226`) | `POST …/delivered {version}` | `orders` → `delivered`, with `payment_method = cash` and `paid_at`; **INSERT** `payments` (cash, `amount = orders.total`, `reference = 'onelocal:<ol_orders.id>'`); `ol_orders` → `delivered` with `payment_status = paid` | `delivered`, `paid` |
| Time-out | none (server side) | (any list call) | `ol_partner_act(…,'timeout')`: orders and items → `cancelled`; `ol_orders` → `cancelled` with "did not respond in time"; `missed_in_a_row + 1`; **auto-pause** (`accepting = false`) at `auto_pause_after` | `timed_out` |
| Outlet on/off | Outlet bar (`presentation/orders/outlet_bar.dart:69`) | `PATCH /outlet {accepting, back_at?}` | Updates `ol_merchant_channels` (`restaurant.ts:105-115`) | none |
| Test order | Settings → Send test order | `POST /test-order` | `ol_create_restaurant_order` with 1–2 random available items, **no idempotency key**: INSERT `orders` (`channel online`, `placed_by integration`, `display_no 'OL-'` + 5 digits, GST fixed at 5%), `order_items`, `order_events`, `ol_orders`; then a push notification to `ol_partner_devices` (`restaurant.ts:177-191`) | `placed` |

**Status words.** The phone shows One Local's status words (`placed`, `accepted`, `packed`, `out`, `delivered`, `cancelled`) and receives the POS word separately as `pos_status` (`domain/delivery_order.dart`, `restaurant.ts:26-31`).

**Version check.** The `version` the phone sends back is `orders.updated_at`.

**Push notifications.** This app **never registers a device**: it never calls `PUT /api/partner/devices`. So One Local's push for new orders cannot reach it. New orders are found only by polling while the app is open.
