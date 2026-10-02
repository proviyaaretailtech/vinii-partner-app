# 03 — KOT (kitchen order ticket) flow

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`.

**Summary.**
- **This app never reads or writes `kot_tickets` directly.** No `.from('kot_tickets')` appears anywhere in `lib/`.
- KOTs come from two places:
  - **Marketplace (One Local) orders:** One Local's `ol_partner_act` creates and advances them when the phone accepts, marks ready or sends out an order. This exists ([ledger] OL-ui 0023).
  - **Phone POS orders:** the `fire_kot: true` flag sent to `pos_place_order`. That function **does not exist** in any migration, so no KOT is created today.

## Creation

| Path | Trigger | What is written | Evidence |
| --- | --- | --- | --- |
| One Local order accepted | Accept on the phone → `POST /api/partner/orders/<id>/accept` → `ol_partner_act(…,'accept')` | Number from `next_org_seq(org,'kot')`; **INSERT** `kot_tickets` (`organization_id`, `order_id`, `kot_no`, `station = 'main'`, `status = 'new'`); **UPDATE** `order_items` set `kot_ticket_id` where `order_id` matches and `status = 'pending'`; **INSERT** `order_events` `kot_fired` ("KOT n fired for …") | OL-ui 0023, accept branch |
| Phone POS "Send to kitchen" | `ticket_view.dart:458` → `SellCart.place(fireKitchenTicket: true)` → `pos_place_order(p.fire_kot = true)` | Unknown: the function is not defined | `live_pos.dart:114`; 01 §6 |
| Phone POS "Save & hold" | `ticket_view.dart:445` → `fire_kot: false` | Intended: no KOT | `live_pos.dart:114` |

**Not in this audit:** the Windows POS repository (`proviyaa-pos`) and the web counter in Repo-1- may also create KOTs. Repo-1-'s `apps/web/src/lib/pos.ts` contains `setKotStatus`. Neither is part of this app.

## Numbering
- `kot_no` is a per-organization running number from `org_counters` (kind `kot`), through the security-definer function `next_org_seq`. It is atomic (`insert … on conflict do update value + 1`) ([ledger] Repo-1- 0006).
- `kot_tickets` has **unique (`organization_id`, `kot_no`)**.
- There is no display prefix. The event message uses the bare number.

## Order → KOT relationship
- `kot_tickets.order_id` → `orders(id)` on delete cascade. **One order can have many KOTs**: there is no unique rule on `order_id`.
- Today's only creator (accept) makes **one KOT per accept**. Accept is allowed only from `new`, so in practice there is one KOT per One Local order.

## KOT ↔ item relationship
- `order_items.kot_ticket_id` → `kot_tickets(id)` on delete set null (0010). It is set only for lines in `pending` status at accept time.
- `kot_tickets.station` and `order_items.station` default to `main`. `kitchen_stations` exists (0010), but nothing in this flow routes lines to stations: accept always uses `'main'`.

## Kitchen status
- **Allowed values** (`kot_tickets.status`): `new` → `preparing` → `ready` → `delivered`.
- **Who sets which value** (in the code read for this audit):

| Value | Set by |
| --- | --- |
| `new` | `ol_partner_act` accept |
| `preparing` | **nothing**. Neither this app nor `ol_partner_act` sets it. The event kind `kot_preparing` is shown as "Kitchen started" in the phone's timeline labels (`domain/delivery_order.dart`), but no writer exists in either codebase |
| `ready` | `ol_partner_act` ready, which updates tickets in (`new`, `preparing`) |
| `delivered` | `ol_partner_act` out, which updates **all** tickets of the order |

- **Order-line status runs alongside:** `order_items.status` goes `pending` → `ready` (on ready) → `delivered` (on out), or `cancelled`.
- **The phone has no kitchen display.** It cannot set `preparing` and cannot mark a phone POS order ready (no caller of `setStatus`, see 02 §A9).

## Ready
"Mark ready" exists only for One Local orders: `delivery_order_screen.dart:207` → `ol_partner_act(ready)`. It updates three tables:
- `kot_tickets` → `ready`
- `order_items` → `ready`
- `orders.status` → `ready`

It also sets `ol_orders.status` → `packed` and writes the event `kot_ready`.

## Cancellation
- `kot_tickets.status` has **no `cancelled` value**.
- Reject and time-out happen only while `orders.status = 'new'`, which is **before** a KOT exists on the One Local path. They cancel `orders` and `order_items` and do not touch `kot_tickets`.
- No path cancels a KOT that has already fired: not in the app, and not in `ol_partner_act`.

## Reprint
**Not implemented.** The app has no KOT or bill printing at all (see `09_HARDWARE.md`). The only printing is the table QR-code PDF sheet.
