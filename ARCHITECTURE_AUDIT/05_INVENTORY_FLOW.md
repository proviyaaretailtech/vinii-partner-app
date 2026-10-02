# 05 — Inventory flow

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`.

## Finding: inventory never changes

There is no inventory or stock data anywhere in the system this app uses:
- **[code]:** nothing in `vinii_partner/lib/` reads or writes a stock, inventory, recipe, ingredient, wastage, GRN or purchase table.
  - A search for `stock|inventor|recipe|ingredient` found only display text ("Item out of stock" as a reject reason), the role name `inventory_manager`, and the storefront's guest-facing ingredient list (marketing copy stored in the storefront definition, not stock).
- **[ledger]:** neither `Repo-1-/supabase/migrations` nor `OL-ui/db/migrations` creates any such table.
- **[snapshot]:** the 2026-09-22 production map (72 tables) contains no stock or inventory table.
- **Triggers:** none on `orders`, `order_items`, `kot_tickets` or `payments` other than `set_updated_at` (01 §5).

| Relationship | Finding |
| --- | --- |
| ORDER → INVENTORY | None. Creating an order (a phone POS RPC, or One Local's `ol_create_restaurant_order`) writes no stock row |
| KOT → INVENTORY | None. Firing, readying or delivering a KOT writes no stock row |
| PAYMENT → INVENTORY | None |

## The nearest thing: availability switches (not quantities)

| Write | Table / column | Where | Effect |
| --- | --- | --- | --- |
| Item sold-out switch | `menu_items.is_available` | `LiveMenu.setItemAvailable` (`live_menu.dart:172-190`); also the full item save (`saveItem`) | The item can no longer be added on the phone (`sell_cart.dart:124`). `ol_create_restaurant_order` also refuses it (`OL_ITEM_UNAVAILABLE`) |
| One Local channel availability | `item_channel_status` (channel `one_local`) | **Not written by this app.** One Local's partner items endpoint writes it (`restaurant.ts:136-155`), but this app does not call `/api/partner/items` | — |

Both are on/off flags with no count. Nothing decrements them, and nothing switches an item off automatically when an order is placed.
