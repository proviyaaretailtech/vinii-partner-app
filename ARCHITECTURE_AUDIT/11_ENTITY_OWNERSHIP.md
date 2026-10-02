# 11 — Entity ownership

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`.

**How to read the columns**
- **Created / Updated / Read here** describe what *this app* does.
- **"via API"** means the phone asks One Local's partner API, and that server writes with its service role.
- **"via RPC (missing)"** means the app calls a database function that no migration defines (01 §6), so nothing happens today.

| Entity | Table | Created here? | Updated here? | Read here? | Source of truth | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Person (login) | `auth.users` | No | No (password reset email only) | Yes (session) | Supabase Auth | One login across apps |
| Membership | `org_users` | No (invites are not possible from the app) | **Yes**: `role_id`, `status` | Yes | Database | Database allows only `org_admin` to write (`is_org_admin`) |
| Role | `roles` | No | No | Yes | Database (Repo-1- seeds) | — |
| Organization | `organizations` | No | No | Yes: id, name, slug, type, status, theme, settings | Database / Master | `settings.app.min_app_version` and `settings.app.tabs` drive the update gate and tab order |
| Module switches | `org_modules`, `role_module_access` | No | No | Yes | Database / Master | — |
| Location / branch | `locations` | No | No | **No** | Database | Not used anywhere in the app |
| Menu category | `menu_categories` | **Yes** | **Yes**: name, sort order, delete | Yes | Database | Reordering is one update per row, not atomic |
| Menu item | `menu_items` | **Yes** | **Yes**: every editable field, `is_available` | Yes | Database | Also edited by the Repo-1- web console and possibly the Windows POS (not audited) |
| Item photo | storage `item-images` | **Yes** (upload) | No (new file per upload) | Yes (public URL) | Storage | Old files are never deleted |
| Item variant | `menu_item_variants` | No | No | **No** | Database | Invisible to the phone |
| Item availability per channel | `item_channel_status` | No | No | No | Database | Written by One Local's `/items`, which this app does not call |
| Dining table | `dining_tables` | No | No | Yes | Database | — |
| Table QR code | `dining_tables.qr_token` | via RPC (missing) `pos_issue_table_qr` | via RPC (missing) | Yes | Database | Globally unique column |
| Dining area | `dining_areas` | No | No | Yes | Database | — |
| Phone POS order | `orders` | via RPC (missing) `pos_place_order` | via RPC (missing) `pos_adjust_bill`, `pos_record_payment`; `pos_set_order_status` has no caller | Yes (open orders, order screen, table occupancy) | Database | Today the phone cannot create one |
| One Local order (kitchen side) | `orders` (`channel online`, `placed_by integration`) | No (One Local; test order via API) | via API (`ol_partner_act`) | via API; **also directly**, in the Open-orders read (12 §1) | Database | — |
| One Local order (customer side) | `ol_orders` | No | via API | via API | Database (One Local) | The phone shows `ol_orders.status`, not `orders.status` |
| Order line | `order_items` | via RPC (missing) / One Local | via API (status, `kot_ticket_id`) | Yes (embedded) | Database | — |
| KOT | `kot_tickets` | via API (accept) | via API (ready, out) | **No** | Database | — |
| Order timeline | `order_events` | via API (One Local functions) | No | via API (`GET /orders/<id>`) | Database | — |
| Payment | `payments` | via RPC (missing) `pos_record_payment`; via API (delivered → cash row) | No | Yes (`amount`, embedded) | Database | — |
| Bill settings | `org_bill_settings` | **Yes** (first save, upsert) | **Yes** (version-checked update) | Yes | Database | The phone's bill estimate uses them; the server is meant to price |
| Sales channel switch | `channel_integrations` | No | **Yes**: `is_accepting`, `next_open_at = null` | Yes | Database | The Repo-1- control panel writes the same columns |
| One Local outlet switch | `ol_merchant_channels` | No | via API (`PATCH /outlet`); auto-pause by server | via API (`GET /me`) | Database (One Local) | — |
| Delivery dispatch job | `delivery_jobs` | No | indirectly (accept or reject hooks on One Local's server) | No | Database (One Local 0029) | [unverified] whether applied in production |
| Storefront (draft and published versions) | `vinii_storefronts`, `vinii_storefront_versions` | **Yes** (upsert), if the table existed | **Yes** (draft); publish via RPC (missing) | Yes, if the table existed | **The phone's SharedPreferences, while the tables are missing** | Tables are not in any migration |
| Customer | **none** | No | No | No | **None.** Free-text `customer_name` and `customer_phone` on the order | No customer table or id. One Local has `ol_orders.customer_hash` and `user_id` on its side |
| Device | **none** | No | No | No | — | No device id is generated or sent. `x-platform` and `x-runtime` headers only. The app never registers in `ol_partner_devices` |
| Idempotency key | SharedPreferences `pending_key:*` | **Yes** (UUID v4) | cleared on a definite answer | Yes | The phone | Never stored in the database: no column exists |
| Cart | memory (`SellCart`) | Yes | Yes | Yes | The phone, until sent | Lost on restart, sign-out or organization switch |
