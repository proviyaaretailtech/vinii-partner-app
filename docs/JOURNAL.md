# Proviyaa (workspace) — Development Journal

## 2026-10-02 — VINII Partner: Storefront CMS in the Master; the phone follows it

**The guest QR menu's colours, buttons, fonts, pictures and text are now set in a CMS in the Master (owners for their own restaurant, the Proviyaa team for any), and both the table QR page and this app's guest mode show the published version.**

- **Why:**
  - The founder asked for a CMS in the Master admin to configure colours, images, text and buttons.
  - The founder also asked that the Supabase address of pictures never be exposed publicly.
- **Structural decisions:**
  - The CMS edits the same storefront record as the phone's Studio. Each editor changes only its own parts, so neither wipes the other.
  - Pictures sit in a private store and are served from the Master's own address.
  - The database change for this (Master migration 0021) was written by this session because no other session was available. It follows the platform contract §4.4, now extended in §4.4.1.
  - Work is on a separate Master branch, `feat/experience-cms`, in its own working copy, so other sessions' work is untouched.
- **What works now:**
  - The Master branch passes its type check, lint and production build.
  - The phone app's guest screens use the CMS look and text; 121 automated checks pass.
  - The app now runs only against the live VinniPos database. The local copy is no longer used, as the founder asked.
  - Local-only test logins exist on One Local's dev database.
- **Left undone:**
  - Migration 0021 is not applied or tried anywhere, so the CMS is read-only for now.
  - Nothing was clicked through in a browser: that needs the migration and a login.
  - The phone shows CMS pictures only once `MEDIA_BASE_URL` is set to the Master's public address.
  - Whether rider tables exist on the live database could not be confirmed. Both the expired access token and the refused service-role route blocked a live check. The 27 Sep snapshot and both repositories have none.
- **Open questions for the founder:**
  1. Approve migration 0021?
  2. What is the Master's public address?
  3. Should Restore bring back only the look, or the whole version?
  4. Refresh the Supabase access token so the rider tables can be checked live?
  5. Remove the test logins and copied access rules from One Local's local database?

## 2026-09-28 — VINII Partner: Flutter app for delivery orders, phone POS and the storefront, on real data only

**Built the restaurant staff app in Flutter. It rings for delivery orders, takes table orders, edits the menu, and lets the restaurant design and preview the swipe-to-order experience from the two reference boards. Everything runs on the real Supabase data, with no sample data.**

- **Why:** The founder asked for one app that accepts delivery orders, works as a phone POS, and lets each restaurant customise its own guest ordering site and menu, serving one or more organizations, from the loading screen through sign-in to sign-out. The founder also said "no demo… I want sanity of data", so the sample restaurants started early in the session were removed.
- **Structural decisions:**
  - **One app serves every restaurant.** The tabs a person sees come from the organization's modules and their role. What a guest sees (dark and gold, or cream and handwritten, budgets, pre-orders) comes from a saved storefront definition. Separate apps or code per client lost because every fix would have to be repeated and each client would get different bugs (release plan, principle 1).
  - **No sample data anywhere.** Screens show the organization's real rows or say plainly that there are none. A never-published storefront starts blank apart from the restaurant's real name, city and colour. The template's example wording is only a hint, never saved.
  - **The phone never writes order, payment or kitchen rows itself.** It sends what was chosen (dish ids and quantities) to the POS's proposed front-door functions, which price, tax and number the order. Until those are approved, Sell and payments say "not available yet" and keep the cart. Writing the rows directly lost because it would create a second, different definition of an order (the architecture session's rules R1–R3).
  - **Every order and payment carries a receipt number (idempotency key)** that is saved on the phone before sending and reused after a crash or retry, so nothing is recorded twice.
  - **The storefront is kept in its own VINII tables, with numbered versions.** It is not kept in the organization settings the Master owns. Until the tables exist, drafts stay on the phone and publishing waits.
  - **Delivery orders go only through One Local's partner API,** which owns them. Bills use a line-for-line copy of the OS bill formula, checked against the OS's own example (₹502 → ₹553).
  - **The guest swipe experience is one self-contained part.** It runs in Studio's live preview, where nothing is sent, and on a staff phone handed to a table, where real orders are marked "placed by guest". Later it becomes the public website.
- **What works now:**
  - A staff member can sign in with their POS email and password, reset a forgotten password, and pick their restaurant if they have several.
  - They see only the tabs their role allows. Kitchen staff get Orders, Menu and More.
  - They can switch organization and sign out of this phone or of every device.
  - Tried in a browser against a copy of the database: the pilot manager login found Mysore Dining Hall, loaded its 35 real dishes in the restaurant's own colour, opened Studio's blank storefront, and walked the guest flow (categories → swipe → order → review) on the real menu.
  - The ringing new-order alert (60-second countdown, accept with a prep time, reject with a reason), order detail with slide-to-confirm, Sell with tables, checkout and payment, the menu editor with photos, and all eight Studio sections are built.
  - 101 automated checks pass.
  - The plan, with every flow and screen, is in `docs/PLAN_VINII_PARTNER_FLUTTER.md`.
- **Left undone:**
  - Delivery orders cannot be received yet: One Local's partner server checks staff against columns that do not exist, so every call fails. This is flagged as a separate task.
  - Placing orders, taking payments and publishing wait for the database changes the founder has not approved yet.
  - A restaurant manager who works at two restaurants sees only one until the shared database fix (G1).
  - Ringing on a locked phone needs a Firebase project.
  - Over-the-air updates need a Shorebird account.
  - Nothing was tried on a real phone.
  - The Figma file could not be opened (no edit access for the connected account) and the NotebookLM notebook's sign-in has expired, so neither was consulted.
  - Guest feedback, "ask for the bill" alerts to staff, and per-table QR codes wait for somewhere to store them.
- **Open questions for the founder:**
  1. Approve the proposed database changes (POS order functions, storefront tables, multi-organization fix)?
  2. Who fixes One Local's partner sign-in bug?
  3. Retire the older Expo partner app now that this family is Flutter?
  4. Create a Firebase project and an Apple push key?
  5. Set up a Shorebird account?
  6. May restaurant owners publish, not only org admins?
  7. Must the phone POS work offline?
  8. Should the public storefront address be `vinii.app/s/<name>` or each restaurant's own domain?
  9. Should public sign-ups be switched off in Supabase?
  10. Please rotate the Supabase service-role key. It was pasted into a chat. The app never uses it.

## 2026-09-28 — VINII Partner: Aligned with the Proviyaa platform contract

**Checked the restaurant app and the shared database against the founder's "many apps, one platform" architecture note. Set ten rules for the app, and found eight database and access gaps to fix before real merchants arrive (One Local has already fixed one).** No app code or database was changed.

- **Why:** VINII Partner is the first staff app that would create restaurant orders from a phone. If each app writes orders its own way, the same order means different things in different apps, retries create duplicates, and a kitchen login could change prices. The architecture note asks for one owner per kind of data, one identity per person, and shared contracts between apps.
- **Structural decisions:**
  - **Orders get one front door: database functions owned by the POS** (place order, change status, record payment), and every app calls them. The alternative, each app writing order rows directly, lost because it creates the exact drift the note warns about. The founder plan's separate central API service lost for now: it does not exist, and database functions already give all-or-nothing safety, which is how One Local's delivery orders already work.
  - **Each retryable action carries a unique "receipt number"** (an idempotency key), so a phone that retries after a network drop cannot create a second order.
  - **The storefront gets its own table with saved versions,** instead of sharing the organization settings column the Master uses. Sharing lost because a phone saving its settings could silently undo a Master change.
  - **Existing order event names stay as they are,** each mapped to the platform's standard name (for example, "placed" means "order.created"). Renaming lost because One Local and the POS already read the current names.
  - **The PRD now says Flutter** (it still said React Native), matching the VINII family.
- **What works now:** One page, `docs/PLATFORM_CONTRACT_ALIGNMENT.md`, sets out which principles were already decided, the rules the app follows, the database gaps with evidence, and the proposed order contract. The session building the app and the session aligning One Local both received the rules and findings. The app session adopted the rules, and the exact calls its code makes are now recorded in that page, so the future database change can match them. One Local's calls were agreed too, so a single database change serves both apps. Delivery fees stay off the restaurant's kitchen bill, and no customer address reaches the kitchen.
- **Left undone:**
  - The database fixes are written up as a proposal only. They belong in the Repo-1- ledger and need approval, so none were applied.
  - The exact order of dine-in steps (billing, awaiting payment, served) was not guessed. The POS owner must confirm it before the database enforces it.
  - Support "act as a merchant" and staff limited to one branch were left to the Master.
  - This folder is not a Git repository, so nothing was committed.
- **Open questions for the founder:** (1) Must the phone POS work offline? If yes, it joins the POS's offline sync, which is weeks of work, not days. (2) Approve one additive database change: a fix for staff in two restaurants, role checks, duplicate protection and the order functions. (3) Should a restaurant owner be able to do everything its admin can? Today the database says no. (4) Are database functions acceptable as the "central API" until traffic justifies a separate service?

## 2026-09-21 — Proviyaa Master (Release & Distribution): Foundation plan for custom client builds and version control

**Wrote the foundation plan for turning a sales requirement into a configured, licensed, self-updating app for each client — without building a separate copy of the app per client.** No code or database was changed.

- **Why:** The sales team needs to promise clients "their own app with only the modules they bought", and the business needs to know which version every client runs, push fixes to the right clients, and force critical updates. The screen designs assumed a separate build per client; that would mean dozens of builds for every fix and different bugs for different clients.
- **Structural decisions:**
  - One version of each app is built once and serves every client; what makes it "custom" is each client's signed settings and licence. The alternative, compiling a separate app per client, lost because it multiplies build, testing and support work and contradicts the founder documents ("Build Once… Configure per organization"; the POS plan says clients "run the same POS application").
  - A client's own app name, icon and store listing (white-label) is the only case that gets its own build, and only as a paid add-on.
  - Nothing is duplicated: clients, branches, modules, staff and plans come from the tables the OS already has. The plan adds only releases, builds, devices, rollouts and issue-to-fix links.
  - Each sales requirement confirmed by Customer Success becomes a setting that remembers which requirement caused it; requirements the product cannot meet go to a product backlog instead of being lost (a known gap in the current OS demo).
  - Updates install only after a shift closes, never lose unsent sales records, and a missed update deadline blocks new shifts but never blocks sending existing records.
- **What works now:** Nothing new runs yet. The team now has one document covering the whole flow (sales requirement → settings → build → install → updates → support), the tables and screens involved, and a phased order of work starting with automatic updates for the Windows POS.
- **Left undone:** The existing OS repository and its live database columns were not inspected — only table names were known. The POS decision record forbids inspecting the database until access is approved, and the repository is not on this machine. The plan marks every table mapping that still needs confirming.
- **Open questions for the founder:** (1) Name: "Proviyaa Commerce OS" (the designs) or Master with a "Release & Distribution" module (the documents)? (2) Approve "one app, many configurations; separate builds only for paid white-label"? (3) Give read access to the OS repository or a structure-only export of the database. (4) Approve a 2-day trial of Windows installer, auto-update and code-signing options, with a small budget. (5) How long may a POS work offline before its licence must refresh (proposed: 7 days)? (6) What should a missed mandatory update block (proposed: new shifts only)? (7) Who must approve releases and settings changes (proposed: two people)? (8) iOS for the POS in version 1 (proposed: no)? (9) Sell white-label as a paid add-on? (10) Who decides which missing features get built, and may sales promise dates (proposed: product owner decides; no dates from sales)? (11) Make the POS code repository private before signing keys are added? (12) May merchant owners add devices and trigger updates themselves? Full detail: `docs/RELEASE_AND_DISTRIBUTION_PLAN.md`.
