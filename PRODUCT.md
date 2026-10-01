# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

Web first, confirmed by the founder on 2026-10-02. The code is Flutter (`vinii_partner/`), built for the browser first; the same code can ship as Android and iPhone apps later (needed for ringing on a locked phone). The design must fit every screen size automatically: phone, tablet and a desktop counter screen. Today's screens were built phone-first and have no tablet or desktop layouts.

## Users

Confirmed 2026-10-02: both audiences matter, **the guest first**.

- **The guest at the table (primary).** Seated with friends or family, phone in hand, either their own phone after scanning the table's QR code, or a staff phone handed across. Job: decide what to order together, keep to a budget, order, follow the order, get the bill and pay.
- **Restaurant staff.** Owner and admin (set up the menu, the storefront and the store), manager, cashier (biller), captain (takes orders on the floor), kitchen (marks food ready), viewer (read only). Situation: a busy, noisy service, one hand free, standing, often on a phone, sometimes at a counter tablet or computer. Many have little or no technical knowledge. Jobs: accept and prepare delivery orders, take table orders, bill and take payment, switch dishes on or off, run the shop.
- **The Proviyaa team** edits the same storefront from the Master's CMS. It is not a user of this app.

## Product Purpose

VINII is the restaurant app on the Proviyaa platform. It lets a restaurant (1) accept marketplace delivery orders from One Local, (2) take dine-in, takeaway and pre-orders as a phone and counter POS, (3) manage its menu, and (4) design and run its own guest ordering experience, where guests swipe through dishes instead of reading a static list.

Success: a restaurant runs a full service on it, and a new restaurant or chain is added by configuring it, not by writing custom code. The founder's final test: from one codebase, serve several restaurants and chains with different looks, domains and versions, over one shared platform with every restaurant's data kept apart.

## Positioning

One app serves every restaurant. A restaurant's colours, wording, ordering modes, features and tabs are saved data, not separate code. On top of that sits a guest experience a plain menu page does not offer: swiping dishes right to add and left to skip, a table budget with a live "used" ring, splitting between people, and live order tracking, all on the restaurant's real menu.

## Operating Context

- Indian restaurants. Rupees, GST (SGST plus CGST, default 2.5% each), an optional service charge, rounding to the nearest rupee. Pilot: Mysore Dining Hall (test organization), Latur, cash first.
- Order channels: dine-in at a table, takeaway, pre-order for a later slot, and delivery orders from One Local. Swiggy and Zomato orders are wanted, with a simple ON/OFF for each.
- Delivery orders ring on the staff phone with a 60-second accept window and a prep time chosen on accept. A restaurant can switch "accepting orders" off.
- Guest wording is available in English, Hindi and Marathi.
- Each restaurant or chain should be reached at its own web address (for example a subdomain per restaurant), the same app customised per restaurant from sign-in onwards.
- The staff app must render without a network fetch for its basics; fonts for the staff screens are bundled.

## Capabilities and Constraints

Built and working (against real data only): staff sign-in and role-based tabs; delivery order inbox with ring, accept, reject, ready, out, delivered; phone POS screens (tables, cart, checkout, payment); menu editor with photos; Storefront Studio (eight sections, live preview, versions); the guest flow from welcome to bill, driven by the saved storefront definition; bill arithmetic that matches the OS to the paisa.

Constraints:
- No sample or invented data anywhere. Empty states say plainly that there is nothing yet. A missing database piece shows "Not available yet" with the reason.
- The phone sends intent (dish ids, quantities, table); the server prices, taxes and numbers the order. Every retryable write carries an idempotency key.
- One Local's delivery orders are handled only through its partner server.
- Words shown to restaurant staff must be plain. Never show: runtime, deployment, application contract, feature flag, build variant, tenant, configuration schema. Use: Switch Experience, Choose POS View, Classic POS, Visual Ordering, Kitchen View, Captain View. Settings are ON/OFF switches in business words (Swiggy ON/OFF, Zomato ON/OFF). Store status is Open, Paused or Closed.
- Different experiences (Classic POS, Visual Ordering, Kitchen, Captain) must be views over the same menu, cart, order, table, customer and payment. Switching changes layout, density and interaction, never the underlying data.
- Secrets never enter the app. Payment gateway keys live on the server only.

Wanted by the founder, not built yet (as of 2026-10-02): the Switch Experience control and a Classic POS view; a video that pops up when a dish is long-pressed; "how many people" used to repeat cart items; a live feed of what is being ordered at each table; a service-charge ON/OFF with a prompt to remove it on the final order; a Closed/Paused/Open store control with "close for today"; Swiggy/Zomato switches; customer sign-up and order history; a captain view; per-restaurant domains; offline POS.

Decided 2026-10-02:
- **QR codes:** one QR code per table. A guest scans it and lands in the storefront already set to that table. (Studio's Share section already shows one storefront QR.)
- **Payments:** guests and staff pay from the payments page, with **Cashfree** as the payment gateway. Not built. Gateway payments are recorded through the POS payment function; the platform contract still names Razorpay and needs updating.

Open decisions: how guests are authorised to order from a table QR (a table-session token is required; public table writes are not allowed); whether the guest pays inside the guest flow or staff collect; Cashfree account and test keys; whether the phone POS must work offline; the public storefront address style (`vinii.app/s/<name>` or each restaurant's own domain); whether owners as well as admins may publish.

## Brand Commitments

- Names: **VINII Partner** (the staff app), **VINII** (the guest-facing experience), part of **Proviyaa**.
- The founder's two reference boards (saved in `docs/reference/`) are the binding references for the guest experience: **Vinii Bistro** (`board-1-vinii-bistro.webp`, dark with gold, 16 screens) and **The Windough** (`board-2-the-windough.webp`, warm cream with handwritten headlines, 16 screens). They ship as the templates Bistro Night and Artisan Day; Fresh Minimal is a third template.
- VINII green `#76EC00` marks the accepting state on staff screens (from the approved POS reference).
- Voice: plain, short, no jargon, because staff are not technical.

## Evidence on Hand

- Founder documents: `Sources/Product Architecture .converted.txt`, `Sources/Product Flow .converted.txt`, `Sources/viyaa routes.converted.txt`; plans and decisions in `docs/` (PRD, Flutter plan, platform contract, release plan, journal).
- Real menu: the pilot organization has 35 dishes in 9 categories in the development database. Dish photos exist only if uploaded to its `item-images` bucket; none are stored in this repository.
- Bundled assets: the Inter font and the new-order ring sound. Nothing else.
- Absent, and not to be invented: dish videos, real photography, customer testimonials, restaurant logos, real customer or order data, pricing, and any claim about customers using the product.

## Product Principles

1. **Real or honestly empty.** Show the restaurant's real rows or say there are none. Never fill a gap with a sample.
2. **One app, every restaurant.** Identity is data. No special code for any client.
3. **The guest is never blocked.** The ordering path stays quick and obvious; anything extra must be skippable.
4. **Staff speed beats decoration.** Under service pressure the main action of each screen is large, clear and one tap away.
5. **Plain words.** A restaurant owner with no technical background can operate every control without learning a term.

## Accessibility & Inclusion

- Staff with little or no technical knowledge (stated by the founder): plain labels, no technical terms, one obvious action per screen.
- New delivery orders ring with sound and vibration, per the PRD.
- Guests who read Hindi or Marathi: text must fit when longer, and every guest string falls back to English then the registry default.
