# 10 — Row security and permission enforcement

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`. Policies were read in the migration files ([ledger]). The snapshot only gives policy *counts*, so production's policy text is [unverified].

## 1. Who the app is, to the database
- **Supabase client:** the **publishable (anon) key** plus the staff member's signed-in session, so the database role is `authenticated`.
- **No service-role key in the app.** `tool/run_local.sh` refuses any build setting outside a short allow-list: `APP_ENV`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `PARTNER_API_BASE_URL`, `STOREFRONT_BASE_URL`, `MEDIA_BASE_URL`.
- **Partner API:** sent the same session's access token as a bearer token. One Local's server then acts with **its own service role** (`OL-ui/frontend/server/partner.ts`, `db()`).

## 2. "Your organization" in the database
- `current_org_id()` ([ledger] Repo-1- 0004) is security definer: `select organization_id from org_users where user_id = auth.uid() and status = 'active' limit 1`.
- There is **no `order by`**, so for a person with several active memberships the result is **one arbitrary organization**.
- Almost every member policy compares `organization_id = current_org_id()`. The app adds explicit `organization_id` filters (`live_backend.dart:35-37`). Those filters can narrow the result but never widen it.
- **Partner API uses a different rule:** the **earliest** active membership by `created_at` (`partner.ts:29-35`). The two choices can differ. The app detects that and refuses to show delivery orders (`partner_api_inbox.dart:135-148`).

## 3. Policies on the tables this app touches ([ledger])

| Table | Select | Insert | Update | Delete | Role checked by the database? |
| --- | --- | --- | --- | --- | --- |
| `organizations` | platform admin; **member of the org (any active membership)** (0004) | platform admin | platform admin; `is_org_admin(id)` | — | update only: slug `org_admin` (**not `org_owner`**) |
| `org_users` | platform admin; `organization_id = current_org_id()` | `is_org_admin` | `is_org_admin` | `is_org_admin` | **yes**, writes: `org_admin` only |
| `roles` | everyone signed in (`using (true)`) | — | — | — | — |
| `org_modules` | `current_org_id()` | platform admin | platform admin | platform admin | — |
| `role_module_access` | `organization_id is null or = current_org_id()` | platform admin | platform admin | platform admin | — |
| `menu_categories`, `menu_items`, `dining_tables` | member | member | member | **member** | **no**: any member, including `kitchen` and `viewer` |
| `orders` | member | member | member | platform admin only | **no** |
| `order_items` | member (through parent order) | member | member | **member** | **no** |
| `kot_tickets` | member | member | member | **member** | **no** |
| `dining_areas`, `order_events`, `payments`, `org_bill_settings`, `channel_integrations`, `item_channel_status` (`apply_org_rls`, 0010) | member | member | member | **no policy, so denied** (delete is granted, but no policy allows it) | **no** |
| `org_counters` | member | no policy | no policy | — | writes only through `next_org_seq` |
| `vinii_storefronts`, `vinii_storefront_versions` | **not applied.** The draft `0021_vinii_storefronts.sql` defines member select, editor insert and update, versions written only by the publish function | | | | draft checks roles (`vinii_can_edit_storefront`, `vinii_can_publish_storefront`) |

"Member" means `organization_id = current_org_id()`. Platform admins have an `… for all` policy on every one of these tables.

**Database-level consequences (as written in the ledger)**
- **Any member** can call the REST API directly to:
  - insert, update or cancel an order;
  - change its totals or move its status backwards;
  - insert payments;
  - change menu prices;
  - change GST or service-charge rates;
  - switch channels on or off.
- Nothing in the database ties these to a role. The 0006 header says so: role checks are "enforced at the application layer for now".
- The CHECK lists limit status **values**, but nothing limits status **moves**. No trigger exists.

## 4. Functions
- `next_org_seq(org, kind)` is **security definer and executable by `authenticated`** (0006). It does **not** check that the caller belongs to `org`, so any signed-in user can advance any organization's order or KOT counter. [ledger]; whether this has been exploited is [unverified].
- `ol_create_restaurant_order`, `ol_partner_act` and `ol_expire_unanswered` are `revoke all … from public, anon, authenticated` and granted to `service_role` only (OL-ui 0023). The phone can reach them only through One Local's API.
- The `pos_*` functions the app calls do not exist on any branch, so their checks cannot be audited. `vinii_publish_storefront` exists only in the unapplied draft (Repo-1- `feat/experience-cms` 0021).

## 5. Storage: `item-images` ([ledger] Repo-1- 0006)
- Public read.
- Insert, update and delete are allowed for **any signed-in user, anywhere in the bucket**: the policy checks only `bucket_id = 'item-images'`.
- The app writes under `<orgId>/…` with `upsert: false`. That is a convention, not something the database enforces: one organization's member could overwrite or delete another organization's photos through the API.

## 6. Enforcement in the app: shows or hides buttons only

`lib/domain/staff.dart:136-175`, `capabilityRoles`. Screens call `session.can(Capability.x)`. Tabs also follow `org_modules` and `role_module_access` (`domain/app_definition.dart`).

| Capability (app) | Roles in the app | Actual enforcement |
| --- | --- | --- |
| `acceptOrders` | owner, admin, manager, location manager, operations manager, biller | **Server-enforced** by the partner API's `CAN.accept` and `CAN.reject` (`partner.ts:10-18`), with the same list |
| `markReady` | the above + `kitchen` | server `CAN.ready`: same |
| `dispatchOrders` (out, delivered) | the above, without `kitchen` | server `CAN.out` and `CAN.delivered`: same |
| `toggleOutlet` | owner, admin, manager, location manager, operations manager | server `CAN.outlet`: same |
| `sendTestOrder` | the above + `biller` | **Not enforced by the server.** `POST /test-order` checks only that the caller is signed-in staff; it has no `require()` (`app/api/partner/test-order+api.ts:5`) |
| `viewOrders` | most roles | server `view` → any active staff |
| `editMenu`, `toggleAvailability` | owner, admin, manager | **App only.** The database allows any member (§3) |
| `editBillSettings` | owner, admin | **App only.** The database allows any member |
| `toggleChannels` | owner, admin, manager | **App only.** The database allows any member |
| `manageTeam` | `org_admin` | **Database-enforced** (`is_org_admin`): same |
| `sell`, `takePayment`, `waiveServiceCharge`, `issueTableCodes`, `publishStorefront` | various | Meant for the missing RPCs; the database would have to check them. Today the calls fail before any check runs |

## 7. Personal data on the phone
- **Customer phone and full address:** the partner API returns them only while an order is active (`accepted`, `packed`, `out`). Otherwise it returns the area only and the first name only (`restaurant.ts`, `shape()`).
- **Phone POS:** for takeaway and delivery it sends the customer's name and phone as free text. On a database built from the ledgers nothing is stored, because the RPC is missing.
- **Guest delivery:** the address is folded into the order notes (`guest_session.dart:425-431`).
