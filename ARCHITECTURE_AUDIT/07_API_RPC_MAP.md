# 07 — API and RPC map

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`.

**All network access is confined to `lib/data/`.** A search of `lib/presentation/` and `lib/application/` for `.from(`, `.rpc(`, `.channel(`, `.stream(`, `storage.from`, `functions.invoke` and `http.` found no other database or network calls. The one exception is the Cashfree web SDK script loader (`data/payments/cashfree_checkout_web.dart`), which is not reachable today (04 §3).

Two transports are used:
1. The **Supabase client** (`supabase_flutter`), with the publishable key and the staff member's session.
2. **One Local's partner HTTP API**, at `PARTNER_API_BASE_URL` + `/api/partner`.

Both go through `CallerClient` (`data/live/caller_client.dart`), which adds these headers to **every** request:
- `x-app: vinii-partner`
- `x-app-version`, `x-platform`, `x-runtime`
- a fresh `x-request-id` (`live_backend.dart:48-55`)

## 1. Supabase Auth

| Call | Code |
| --- | --- |
| `signInWithPassword(email, password)`, PKCE flow | `live_auth.dart:33`, `live_backend.dart:93-95` |
| `resetPasswordForEmail(email)`: errors are hidden except offline or rate-limit, so the reset form cannot reveal which accounts exist | `live_auth.dart:51-61` |
| `signOut(scope: local or global)` | `live_auth.dart:64-76` |
| `onAuthStateChange` (signed-out events only) | `live_auth.dart:23-25` |
| `currentSession.accessToken`, sent as the bearer token to the partner API | `partner_api_inbox.dart:39` |

## 2. PostgREST table queries (every query filters `organization_id` explicitly, except the reads of `roles` and of a person's own `org_users` rows)

| Repository | Method | Operation |
| --- | --- | --- |
| `LiveWorkspace` | `memberships` | `GET org_users?user_id=eq.<uid>&select=status,role:roles(slug,name),organization:organizations(id,name,slug,type,status,theme,settings)` |
| | `appDefinition` | `GET org_modules?organization_id=eq.<org>`; `GET role_module_access?…roles!inner(slug)&role.slug=eq.<slug>&or=(organization_id.is.null,organization_id.eq.<org>)` |
| `LiveMenu` | `load` | `GET menu_categories`, `GET menu_items` |
| | `saveCategory` | `POST menu_categories` / `PATCH menu_categories?id&organization_id` |
| | `deleteCategory` | `DELETE menu_categories?id&organization_id` (returns ids; zero rows = error) |
| | `reorderCategories` | **one `PATCH` per category**, in sequence, not in one transaction (`live_menu.dart:108-120`) |
| | `saveItem` | `POST menu_items` / `PATCH menu_items?id&organization_id` |
| | `setItemAvailable` | `PATCH menu_items {is_available}` |
| `LivePos` | `tables` | `GET dining_tables` (+ `dining_areas.name`), `GET orders.table_id` where status is not in (`paid`, `cancelled`) |
| | `billCharges` | `GET org_bill_settings` (4 columns) |
| | `openOrders` | `GET orders` (+ `dining_tables`, `order_items`, `payments.amount`) for today, status not in (`paid`, `cancelled`), limit 100 |
| | `refresh` | `GET orders?id&organization_id` (same embed) |
| `LiveBillSettings` | `load` / `save` | `GET org_bill_settings`; `POST … on_conflict=organization_id` (ignore duplicates) / `PATCH …&updated_at=eq.<loaded>` |
| `LiveChannels` | `list` / `setAccepting` | `GET channel_integrations`; `PATCH channel_integrations {is_accepting, next_open_at: null}` |
| `LiveTeam` | `members` / `roles` / `setRole` / `setStatus` | `GET org_users` (+ `roles`); `GET roles`; `PATCH org_users {role_id}` or `{status}` |
| `LiveTables` | `list` | `GET dining_tables` (+ `dining_areas`) |
| `LiveStorefront` | `load` / `saveDraft` / `discardDraft` | `GET vinii_storefronts`, `GET vinii_storefront_versions` (limit 20); `POST vinii_storefronts on_conflict=organization_id`; `PATCH vinii_storefronts {draft:null}` (**both tables exist only in an unapplied draft migration**, see 15) |

## 3. RPC (PostgREST `/rpc/<name>`)

| RPC | Called from | Payload (`p`) | Defined? |
| --- | --- | --- | --- |
| `pos_place_order` | `LivePos.placeOrder` ← `SellCart.place` ← TicketView; `PosGuestGateway.place` ← `GuestSession.place` | see 02 §A7 | **No** |
| `pos_record_payment` | `LivePos.recordPayment` ← `PaymentCard` | `order_id, method, amount, idempotency_key, reference, expected_updated_at` | **No** |
| `pos_set_order_status` | `LivePos.setStatus` (no caller) | `order_id, to, expected_updated_at, reason?` | **No** |
| `pos_adjust_bill` | `LivePos.adjustBill` ← `PosOrderScreen._adjust` | `order_id, expected_updated_at, waive_service_charge, waive_reason?` | **No** |
| `pos_issue_table_qr` | `LiveTables.issueCode` ← table codes screen | `table_id, replace?` | **No** |
| `vinii_publish_storefront` | `LiveStorefront.publish` ← Studio | `organization_id, definition, expected_version` | **Draft only, not applied** (Repo-1- `feat/experience-cms` 0021) |

The call shapes are documented as a proposal in `docs/PLATFORM_CONTRACT_ALIGNMENT.md` §4.1, §4.4 and §4.5.

## 4. Storage

| Call | Code |
| --- | --- |
| `storage.from('item-images').uploadBinary('<orgId>/<itemId>-<ms>.<ext>', bytes, contentType, upsert:false)`, then `getPublicUrl` | `live_menu.dart:213-222`. The app enforces a 5 MB limit before uploading |

## 5. One Local partner API (`PARTNER_API_BASE_URL/api/partner`)

**Headers:** `Authorization: Bearer <Supabase access token>`, JSON, plus the caller headers. Writes also carry a new `idempotency-key` on each request.

**Status mapping** (`partner_api_inbox.dart:92-125`):

| HTTP status | Shown as |
| --- | --- |
| 401 | auth |
| 403 | forbidden |
| 404, 400, 413 | rejected |
| 409 | conflict |
| 426, 503 | not ready |

| Method · path | Phone code | Server handler → database ([ledger] OL-ui) |
| --- | --- | --- |
| `GET /me` | `outlet()`, which also refuses if the server's organization differs from the one chosen in the app (`:135-148`) | `requirePartnerAuth` reads `org_users`; outlet from `ol_merchant_channels` |
| `PATCH /outlet` | `setAccepting` | update `ol_merchant_channels` |
| `GET /orders?tab=new\|preparing\|ready\|past` | `list` (polled) | `rpc ol_expire_unanswered(org)`, then `ol_orders` ⋈ `orders` ⋈ `order_items` |
| `GET /orders/<posOrderId>` | `detail` | `ol_orders` + `order_events` |
| `POST /orders/<id>/accept\|reject\|ready\|out\|delivered` | `accept`, `reject`, `markReady`, `markOut`, `markDelivered` | `rpc ol_partner_act(...)`, plus dispatch hooks on accept and reject |
| `POST /test-order` | `sendTestOrder` | `rpc ol_create_restaurant_order(...)`, then push |

**Partner endpoints this app does not call:**
- `GET`/`PATCH /items`: One Local channel availability.
- `PUT /devices`: push registration.

## 6. Edge functions

**None.** `functions.invoke` does not appear anywhere in `lib/`.

## 7. Third-party endpoints

The Cashfree JS SDK (`https://sdk.cashfree.com/js/v3/cashfree.js`) is loaded only by the web build's checkout. That checkout is unreachable today, as no gateway supplies `payments` (04 §3).
