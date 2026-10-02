# 08 — Realtime

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`.

## Database configuration ([ledger] Repo-1-)

| Table | Added to `supabase_realtime` | Migration |
| --- | --- | --- |
| `orders` | yes | 0006, line 448 |
| `kot_tickets` | yes | 0006, line 449 |
| `order_items` | yes | 0010, line 397 |
| `order_events` | yes | 0010, line 398 |
| `service_requests` | yes | 0010, line 399 |
| `table_sessions` | yes | 0010, line 400 |

[unverified] Whether production's publication matches. The snapshot does not list publication members.

## App usage: none

- `lib/` contains no `.channel(`, `.stream(`, `onPostgresChanges` or Realtime subscription. This was confirmed with a full search.
- Every "live" behaviour is **polling over HTTP**:

| Screen | Mechanism | Interval | Evidence |
| --- | --- | --- | --- |
| Delivery inbox (new orders, ringing) | `Timer` → `GET /api/partner/orders?tab=new` | 5 s while accepting, 30 s while not | `application/inbox_controller.dart:77-88` |
| Guest live tracking | `Future.delayed` loop → `LivePos.refresh` | 5 s while the order is open | `application/guest_gateway.dart:82-94` |
| POS order screen, open orders, menu, tables | **no refresh**: read on open, or when the user pulls or taps | — | — |

**Side effects of polling**
- Each inbox poll makes One Local's server run `ol_expire_unanswered(org)` first (`restaurant.ts:49`). So **the phone's poll is what times out unanswered orders and triggers auto-pause.** This matches the controller's own comment at `inbox_controller.dart:16-19`.
- Both pollers stop on sign-out or organization switch (`_reset`) and when the guest order closes.

**Push notifications:** none received. No push package is in `pubspec.yaml`, and the app never registers with `PUT /api/partner/devices`.
