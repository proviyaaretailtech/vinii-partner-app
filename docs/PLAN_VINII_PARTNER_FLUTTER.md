# VINII Partner (Flutter): plan of action

**Date:** 2026-09-28 · **App:** `vinii_partner/` (Flutter: Android, iOS, web) · **Database:** Supabase project `ywylhzcxuoeilygzdonx` (VinniPos) · **Binding rules:** `docs/PLATFORM_CONTRACT_ALIGNMENT.md` (R1–R10)

---

## 0. The answer on one page

VINII Partner is **one phone app for a restaurant's staff** with three jobs, plus the guest experience it publishes:

| Job | What staff do | Where the data lives |
|---|---|---|
| **Orders** (delivery accepting) | A One Local order rings on every signed-in phone. Staff accept it with a prep time or reject it with a reason within 60 s, then mark it ready, out for delivery and delivered. | One Local's partner API (`/api/partner/*`), which owns those orders |
| **Sell** (mobile POS) | Pick a table, add dishes, send to the kitchen or save and hold, take cash, UPI or card | POS tables, written only through the POS "front-door" functions |
| **Menu** | Categories, dishes, prices, photos, veg or non-veg, availability | POS Item Master (`menu_categories`, `menu_items`, `item-images` bucket) |
| **Storefront Studio** ("customise your website") | Choose a template, colour, wording, how guests order, which features are on, which dishes to highlight. Preview it live, publish, roll back. | VINII-owned `vinii_storefronts` and `vinii_storefront_versions` (proposed) |
| **Guest experience** (the two reference boards) | Guests swipe through dishes, set a group budget, order, track live and see the bill | Rendered from the published storefront and the real menu. Orders go through the same POS front door |

**The rule that shapes everything:** one Flutter runtime serves every organization. What makes Vinii Bistro look dark and gold, and The Windough cream and handwritten, is **data** (a storefront definition), never code. The app has **no sample data**. Every screen shows the organization's real rows or an honest empty state.

**Works today.** Built, with 101 automated checks passing. It was also tried in a browser against a copy of the database that holds the pilot restaurant's real menu:
- the full staff lifecycle: loader → intro → sign in → forgot password → no access, choose organization or update required → tabs → switch organization → sign out of this phone or of every device;
- tabs per organization and role;
- Orders: the inbox, the full-screen ringing alert and order detail;
- Sell: the POS, checkout and payment screens;
- Menu: the editor with photos and categories;
- Storefront Studio: eight sections, live preview and publish;
- the guest swipe-to-order experience, all 17 steps;
- bill maths that match the OS to the paisa.

Anything blocked by the approvals below says so plainly on screen.

**Waiting for approvals (not code):**
- the POS front-door functions and storefront tables (the architecture session's proposed migration, Q2);
- the multi-organization database fix (G1);
- a working One Local partner server: its sign-in check reads columns that do not exist (§11);
- a Firebase project for push notifications on a locked phone.

---

## 1. Principles

1. **One runtime, many organizations.** No `if (client == …)` anywhere. Tabs come from `org_modules`, `role_module_access` and the role's capabilities. Look and behaviour come from the storefront definition.
2. **Sanity of data.** No demo, seed or sample rows in the app. Empty means empty. A missing database piece shows "not available yet" with the reason; it is never faked.
3. **Apps are experiences; the platform owns truth.** The phone sends intent (item ids, quantities, table). The server prices, taxes and numbers the order (R1, R2).
4. **Every retryable write carries an idempotency key.** The key is kept across restarts, so a retry never creates a second order (R3).
5. **Each owner's words stay its own.** One Local status (`placed`, `accepted`, `packed`…) and POS status (`new`, `sent_to_kitchen`, `ready`…) are never translated into each other (R6).
6. **Every request says who is calling.** The headers are `x-app`, `x-app-version`, `x-platform`, `x-runtime` and `x-request-id` (R7).

---

## 2. End-to-end flow: staff lifecycle ("loader to sign out")

```
Native splash
  → S01 Loader ─ missing SUPABASE_URL/KEY ─────────► "This build is not connected"
       │         ─ offline / server error ──────────► "No connection" + Try again (+ Sign out)
       │ first launch on this phone
       ├──────────► S02 Intro (3 pages: orders ring · take table orders · your storefront) ─┐
       │ no session                                                                      │
       ├──────────► S03 Sign in (email + password) ⇄ S04 Forgot password (reset email) ◄──┘
       │ signed in
       ├─ 0 active memberships ─────────► S05 No restaurant yet (check again · sign out)
       ├─ 2+ memberships, none remembered ► S06 Choose a restaurant (role shown, paused ones locked)
       ├─ build older than org's min_app_version ► S07 Update required
       └─ ready ─► S10 Home: tabs from the application definition
                    Orders · Sell · Menu · Storefront · More
                    (a kitchen login sees Orders · Menu · More)
S20 More → profile · organization (switch) · new-order alerts (ring on/off, test ring, send test order)
         · appearance (auto/light/dark) · About (version, database, config version, tabs)
         · Sign out → "this phone" or "every device" (confirm sheet)
Session ended elsewhere → back to S03 with "You were signed out. Sign in again to continue."
```

| Stage (`SessionStage`) | Screen | Leaves when |
|---|---|---|
| booting | S01 Loader shows the step ("Finding your restaurants…") | memberships and definition are loaded |
| notConfigured / bootError | S01 with a plain explanation | Try again |
| intro | S02 | Skip or Get started (once per phone) |
| signedOut | S03 / S04 | the email and password are accepted |
| noAccess | S05 | an admin adds the person; Check again |
| choosingOrg | S06 | an organization is chosen (it is remembered per person) |
| updateRequired | S07 | the app is updated |
| ready | S10 tabs | sign out, or switch organization (back to S06) |

Switching organization or signing out wipes every organization-scoped controller: inbox, ring, cart, studio draft. One restaurant's data never shows under another.

---

## 3. End-to-end flow: delivery orders (One Local → restaurant)

```
Customer orders on One Local ─► One Local server creates the POS order (placed)
  ─► every signed-in VINII Partner phone of the restaurant: FULL-SCREEN ALERT + RING (60 s ring countdown)
       ├─ Accept + prep time (10/15/20/30/45) ─► accepted  → kitchen ticket created
       ├─ Reject + reason ─────────────────────► cancelled (customer told)
       └─ no answer in 60 s ─► cancelled "did not respond"; 3 misses in a row pause the restaurant
  accepted ─(slide) Mark ready─► packed ─(slide) Out for delivery─► out ─(slide) Delivered · cash ₹X─► delivered
```

- **Orders tab:**
  - the restaurant name;
  - an **Accepting orders** switch; pausing asks "back at?" (30 min, 1 h, 2 h, tomorrow 9 AM, until I turn it on);
  - a missed-orders warning;
  - tabs **New · Preparing · Ready · Past**.
- **Order detail:** items and notes, the bill, the customer's first name and area, the phone number only while the order is live, the timeline, and the next action as slide-to-confirm.
- **Another phone answers first:** the server refuses the stale version (409) and this phone stops ringing.
- **How it works:** the phone polls every 5 s while accepting, which is also what makes One Local expire unanswered orders. **Locked-phone push** needs Firebase and a server change (§9).

---

## 4. End-to-end flow: phone POS (Sell)

```
Sell ─ Dine-in | Takeaway | Delivery ─ (Dine-in) choose table ─ categories + search ─ tap to add / long-press for qty & note
  ─► Review: lines, notes, guests / customer, ESTIMATED bill (org's GST + service charge + round-off)
       ├─ Send to kitchen  (pos_place_order, fire_kot: true)
       └─ Save & hold      (pos_place_order, fire_kot: false)
  ─► Order screen: stored bill · Take payment (cash with change / UPI with reference / card) (pos_record_payment)
  ─► Paid · New order
Open orders (today, unpaid) · Hand to guest (the phone becomes the guest menu for that table)
```

- **Idempotency:** the key is created when the order is confirmed and saved on the phone **before** sending. A retry after the app closes reuses it (`PendingKeys`).
- **Until the POS front-door functions exist:** Sell and payment say plainly "Taking orders from the phone needs the POS order functions, a database update waiting for approval. Until then, take this order at the POS counter." The cart is kept. Nothing is written around the rule.

---

## 5. End-to-end flow: Storefront Studio ("customise your website")

```
Storefront tab ─ status (Live v3 · published 2 Oct by Aarav / Not published yet / unpublished changes)
  ─ live phone preview (the real guest runtime, with this draft and the real menu; nothing is sent)
  ─ Sections:
      Look          template (Bistro Night · Artisan Day · Fresh Minimal) · accent colour · category style (tiles | wheel)
      Brand         display name · tagline · location line · welcome headline & text (template wording only as hints)
      How guests order  Dine-in · Takeaway · Pre-order · Delivery (≥1) · table label · pre-order days, hours, slot length, notice
      Guest features    swipe deck · budget (default/min/max) · split between people · save for later · chef's picks ·
                        limited today · discover while waiting · live tracking · split bill · feedback · ingredients ·
                        allergens · nutrition
      Menu on storefront  category visibility, order, emoji
      Highlights    chef's picks (≤6) · limited-today offers with end times
      Share         storefront address + QR code for tables and counter
      Versions      history; restore = publish an older version as a new number
  ─ Save draft (per organization) · Publish (owners and admins) · Discard changes
Menu item editor also writes guest-only details into the draft: tags, ingredients, allergens, calories, hide from storefront
```

**Starting point:** a never-published organization starts **blank**. Only its real name, city and brand colour are filled in.

**Storage and publishing:**
- Drafts and published versions live in `vinii_storefronts` and `vinii_storefront_versions`.
- Publishing is one server function (`vinii_publish_storefront`) that numbers the version and checks the role.
- Until those exist, drafts are kept on the phone and Studio says why. `organizations.settings` belongs to the Master and is never written.

---

## 6. End-to-end flow: the guest experience (both reference boards, one runtime)

The two boards differ only in data: template, service modes and features. The runtime merges them into one config-driven flow.

| Step | Screen | Board 1 "Vinii Bistro" | Board 2 "The Windough" | Shown when |
|---|---|---|---|---|
| G01 | Welcome (brand, location, headline, CTA) | 1 | 2 | always |
| G02 | How would you like to order? | 11 (partly) | 3 | more than one service mode |
| G03 | Pre-order date & time slot | – | 11 | Pre-order chosen |
| G04 | Dining with friends? Budget + split | 2 | 7 (table budget) | features.budget |
| G05 | What are you in the mood for? (tiles / wheel) | 3 | 4 | always |
| G06 | Swipe deck (budget ring, ✕ / ♥, swipe right to add, category tabs) or list | 4, 5 | 6, 15 | swipeDeck on / off |
| G07 | Dish detail (swipe up): photos, tags, ingredients, allergens, nutrition, qty | 6 | 5 | always |
| G08 | Added to your order | 7 | – | after adding |
| G09 | Budget overview (ring + recent additions) | 8 | 7 | budget on |
| G10 | Discover: chef's picks, limited today (countdown) | 14 | 14 | features on |
| G11 | Your order (steppers, budget meter, saved for later) | 9 | 7 | always |
| G12 | Review & notes (estimated bill) | 10 | 8, 12 | always |
| G13 | Confirm mode, table or slot → Place order | 11 | 8 | always |
| G14 | Order placed (number, ETA) / pre-order confirmed | 12 | 9, 13 | always |
| G15 | Live tracking (confirmed → kitchen → ready → on the way → served) | 13 | 10 | liveTracking |
| G16 | While waiting: discover more | 14 | 14 | discoverWhileWaiting |
| G17 | Served → Bill (budget summary, split bill, how to pay at the table) → feedback | 15, 16 | 16 | splitBill; feedback only once it can be stored; "ask for the bill" returns as a button once a call-staff function exists |
| G18 | Pay online: the whole bill or "my share", through the payment service (Cashfree), then a receipt | – | – | the gateway offers online payment (not built server-side yet: `docs/PAYMENTS_CASHFREE.md`) |

- **Where it runs:**
  - today, a staff phone handed to a table (`/guest?table=…`, orders marked `placed_by: guest` through the front door);
  - inside Studio's preview (nothing sent, clearly labelled);
  - later, the public website `vinii.app/s/<slug>`. That needs a guest API with a table-session token, never public table writes (R10); the OS already has table sessions and PINs for its QR guest app.
- **Payment:** "Pay bill" asks staff for the bill. The guest runtime takes no money.

---

## 7. Submodules

| Module (OS key) | Submodules | Screens | Capability (roles) |
|---|---|---|---|
| Identity | sign-in, reset, sessions, sign-out here or everywhere | S01–S04, More | everyone |
| Organization | memberships, organization picker, brand colour, min version | S05–S07, More | everyone |
| Orders (`orders`) | outlet switch, inbox tabs, new-order alert and ring, order detail, test order | Orders, Alert, Detail | view: all floor, kitchen and viewer · accept/reject: owner, admin, managers, biller · ready: + kitchen · outlet: owner, admin, managers |
| POS (`pos`) | service type, tables, catalogue, cart, checkout, hold, payment, open orders, hand to guest | Sell, Checkout, Order | sell: floor staff · payment: owner, admin, managers, biller |
| Menu (`menu`) | categories, items, photos, availability, guest details | Menu, Item editor, Categories | view: floor, kitchen · edit: owner, admin, manager (R4 until the database checks roles) |
| Storefront (`menu` → publishing) | look, brand, service, features, categories, highlights, share, versions, preview, publish | Studio, sections, Preview | view and edit: owner, admin, managers, marketing · publish: owner, admin |
| Guest runtime | G01–G18 | guest | guests (through a staff phone today) |

---

## 8. Flutter configuration

- **Project:** `vinii_partner/`, package `vinii_partner`, bundle id `com.proviyaa.vinii_partner`, display name "VINII Partner", version `0.1.0+1`. Platforms: Android, iOS, web.
- **Run:** copy `.env.local.example` to `.env.local` and run `./tool/run_local.sh` (add `-d chrome`, `-d <simulator>` and so on).
  - The launcher accepts only `APP_ENV`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `PARTNER_API_BASE_URL` and `STOREFRONT_BASE_URL`, and **refuses anything else** (a service-role key cannot be compiled in).
  - `VINII_ENV_FILE=.env.localdb` points the app at the local Supabase (docker).
- **Layers:**
  - `config/`: build settings;
  - `domain/`: pure models and maths, including bill, storefront, guest catalog and app definition;
  - `data/`: the `Backend` contracts and `live/` Supabase + partner API;
  - `application/`: session, inbox, ring, guest gateway, per-feature controllers;
  - `presentation/`: screens by feature, theme, shared widgets;
  - `app/`: services scope, routes, router.
- **Navigation:** `go_router` with one redirect per lifecycle stage, and a stateful shell holding one branch per tab. Tabs the definition doesn't allow are unreachable even by deep link.
- **State:** `ChangeNotifier` controllers. Organization-scoped ones are created through `AppScope.feature()` and dropped on switch or sign-out.
- **Look:**
  - staff app: the VINII POS tokens (Inter, brand green `#76EC00` for "accepting"), tinted by the organization's `theme.accent`, in light, dark and automatic modes;
  - guest runtime: three templates (Bistro Night, Artisan Day, Fresh Minimal) with their own fonts and palettes.
- **Permissions:**
  - Android: INTERNET and VIBRATE;
  - iOS: camera and photo library (dish photos).
- **Tests:**
  - domain maths and contracts: bill parity with the OS, storefront JSON, slots, app definition, guest catalog, partner API sample, error words;
  - lifecycle widget tests against an empty test fake;
  - feature widget tests.

---

## 9. Release and over-the-air updates

- **One build per platform serves every restaurant** (release plan principle 1). Branding and modules arrive as data.
- **Dart code updates without a store release:** use **Shorebird** code push, as the OTA comparison recommends. Native changes still need a store release: plugins, permissions, and the Firebase push setup.
- **Version gate:** the organization's `min_app_version` stops an old build at "Update required". It moves to the Master's `apps` table when that exists (R5).
- **Push for a locked phone:** needs
  1. a Firebase project (Android) and an Apple push key (iOS);
  2. `firebase_messaging` in the app;
  3. One Local's server sending FCM or APNs.
  Today the server only sends Expo push tokens, which a Flutter app cannot receive.

---

## 10. Build phases

| Phase | Delivers | Done when | Status |
|---|---|---|---|
| F0 Foundation | lifecycle S01–S07, tabs per definition, More and sign-out, live data layer, bill parity, contract tests | runs against Supabase; lifecycle tests pass | **done**; sign-in, memberships and tabs tried live on the local database copy |
| F1 Orders | inbox, alert and ring, detail, outlet switch | the PRD §5 four checks pass on a real phone with the partner API | **screens done** (14 checks); blocked on the partner server bug (§11) |
| F2 Menu | menu, item editor with photos, categories | an owner adds a dish with a photo and it shows in the POS | **done** (11 checks); the pilot's 35 real dishes load live |
| F3 Studio + guest | Studio sections, preview, publish, guest runtime G01–G17 | a published storefront is handed to a table and an order reaches the kitchen | **screens done** (12 + 18 checks); guest flow tried live in preview; publish waits for the §4.4 tables |
| F4 Sell | tables, cart, checkout, hold, payment | a table order and a payment are recorded once, even with a forced retry | **screens done** (18 checks); placing waits for the §4.1 functions |
| F5 Push & OTA | Firebase push, Shorebird | a locked phone rings within 10 s; a Dart fix ships without a store release | needs accounts |
| F6 Public website | guest API with table session, `vinii.app/s/<slug>` | a guest orders from their own phone by QR | needs the guest API (R10) |

---

## 11. Found while building (needs owners)

1. **One Local partner API cannot sign anyone in against the real database.**
   - `OL-ui/frontend/server/partner.ts` selects `org_users.name` and filters `is_active`, but the table has `full_name` and `status`. It also compares `roles.name` ("Manager") with slugs ("manager").
   - Every partner call returns 500. This affects the Expo partner app too.
   - Fix in One Local: select `full_name, status`, filter `status = 'active'`, and compare `roles.slug`.
2. **Multi-organization (G1).** `current_org_id()` picks any one membership, and staff only see the `org_users` rows of that organization. Until the fix, a two-restaurant manager sees one. The app therefore never offers an organization the database won't open.
3. **Photo uploads** are allowed for any signed-in user into any folder of `item-images`. The app writes under `<organization id>/` so a per-organization storage policy can be added.
4. **`next_org_seq`** is executable by `anon` in the local replica. Check production and revoke it if so.
5. **Supabase Dart client quirk (fixed in the app).** In postgrest 2.9, `maybeSingle()` replaces PostgREST's error code with the HTTP status. The app now recovers the real code, so "table not there yet" is recognised. Any other Dart client on the platform needs the same care.
6. **Public sign-ups are switched on** in production Supabase. Anyone can create a login. Without a membership it only sees "No restaurant yet", but you may want sign-ups off, since admins add staff.

---

## 12. Open questions for the founder

1. Approve the proposed migration: POS front-door functions, storefront tables, G1 and G2 (the architecture session's Q2)? Sell, payments and Publish depend on it.
2. Who fixes One Local's partner sign-in bug (§11.1), and when? Delivery orders depend on it.
3. Retire the Expo "VINII Partner" in `OL-ui/partner/` now that the VINII family is Flutter (D11), or keep it until Flutter push works?
4. Create a Firebase project and Apple push key for locked-phone ringing?
5. Shorebird account for over-the-air updates?
6. Should restaurant **owners** (not only org admins) be able to publish? The app and the proposed tables say yes.
7. Must the phone POS work offline (Q1 in the alignment doc)? If yes, it joins the POS's PowerSync path, which is weeks of work.
8. The storefront's public address: `vinii.app/s/<slug>`, or each organization's own domain (`org_domains`)?
9. **Security:** the Supabase service-role key was pasted into a chat on 28 Sep. Rotate it in the Supabase dashboard. It is not used or stored anywhere in this app.

---

## Sources

- The founder's two reference boards (Vinii Bistro, The Windough) and the OTA comparison image.
- Product Architecture §10, §25, §54, §70–71; viyaa routes §7–9, §29–40; Product Flow §14–15, §31.
- `PRD_VINII_PARTNER_V1.md`, `RELEASE_AND_DISTRIBUTION_PLAN.md`, `PLATFORM_CONTRACT_ALIGNMENT.md`.
- OS migrations 0004–0010 and `apps/web/src/lib/{bill,pos,ops,guest}.ts`.
- One Local partner routes and migrations 0022–0023.
- The local replica database.
- Not reachable this session: the Figma file (the connected account has no edit access) and the NotebookLM notebook (its sign-in has expired).
