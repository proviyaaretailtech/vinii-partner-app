# Proviyaa (workspace) — Development Journal

## 2026-10-02 — VINII Partner: Veg, non-veg and Jain filters on the guest menu

**The guest menu now has All / Veg / Non-veg / Jain chips under the header, so a party can see only what they eat.**

- **Why:** The founder asked for clear veg / non-veg differentiators and a Jain option, and for the CMS to stay in step.
- **Structural decisions:** Veg and non-veg come from each dish's food type, which the POS already stores (eggs count as non-veg here). The POS has no Jain field, and adding one is a database change, so Jain is a **"Jain" tag** on the dish in the storefront record that Studio and the Master's CMS already share. Alternative, a new database column, lost because migrations are yours and a tag works today. A chip only appears when it actually splits the menu (no Jain chip if no dish is tagged).
- **What works now:** the chips on the menu and the swipe deck, a "Show everything" way out when a filter matches nothing, and a Jain tag chip on dishes. "Jain" is now a suggested tag in the phone's dish editor. The gallery has two dishes tagged Jain.
- **Left undone:** the Master's website must offer "Jain" in its own tag list for owners to pick it (typed tags already work). Dishes are only as Jain as the restaurant says; the app does not check ingredients. Filter text is English only.
- **Open questions for the founder:** should Jain also hide dishes with onion/garlic ingredients automatically, or stay a restaurant decision? Do you want a real food-type value for Jain in the POS later?

## 2026-10-02 — VINII Partner: One order screen, a swipe/menu switch, coupon codes, nearby-order alerts and copy-a-table's-order

**The guest's three near-identical order screens are now one "Your order" screen; guests can flip between swiping and the traditional menu with one tap; coupon codes, "what the tables around you are ordering" alerts and "tables like yours" (preview and copy) are built and shown on pretend data until the server exists. The Specials crash is fixed, and every internal staff login was tested.**

- **Why:** After trying the gallery the founder reported a crash on Specials, asked for a quick switch between the swipe deck and the traditional menu, said Order, Review and Checkout were "all the same screens", that Table 12 must come from the QR code, and asked again for the live-table ideas from the original brief (alerts of what others order, copying a similar table's order) and coupon codes at checkout.
- **Structural decisions:**
  - **One screen instead of three.** Order, review and checkout showed the same dishes and totals three times, costing two taps. The alternative, keeping the boards' separate screens, lost for that reason. The ways of ordering are a switch at the top, and Place order shows the total.
  - **The table is never asked.** It comes from the QR code (or the table staff handed the phone to); without one the guest is told to scan. The old "Table number" row is gone.
  - **Coupons are the server's decision.** The phone sends the code and the cart, the server says what it takes off; the order is checked again when placed. The row appears only when the server offers coupons.
  - **The two table-to-table features show nothing until the server shares anonymous data** (a dish, a quantity, a time, a label the server chose; never a name, phone, note or total). The alternative, the phone reading other tables' orders itself, lost on privacy and security.
  - **No new storefront switches were added**, because the Master's CMS would drop keys it does not know; availability follows the server functions.
  - **The Specials crash** came from the gallery's invented end time ("HH:59:00" instead of "HH:mm"); the parser is now tolerant too.
- **What works now (pretend data in the design gallery; 494 automated checks pass):**
  - A switch at the end of the category strip flips swipe and menu, remembered for the visit.
  - One order screen with the switch of ways to order, notes, coupon, bill, budget and Place order. The traditional menu row no longer overflows with long descriptions.
  - Coupons SAVE10, FLAT50, WELCOME in the gallery: refused with a reason, applied with its own bill line, taken off, re-checked when the cart changes.
  - "Table 7 just ordered Paneer Tikka ×2 · Add" alert on browsing pages; "Tables like yours" cards (round dish pictures, table, total) opening a preview where each dish can be ticked, its quantity set, or added alone.
  - Internal logins tested on the local test database: owner, admin, manager, cashier, captain, kitchen, viewer, no-restaurant, wrong password. Each sees the tabs and items its role allows.
- **Left undone:**
  - **Server pieces (yours):** `guest_nearby_orders`, `guest_similar_table_orders`, `guest_validate_coupon`, and `coupon_code` on `pos_place_order`; shapes and privacy rules are in `docs/GUEST_SERVER_CONTRACT.md`. The Master needs a Coupons page and per-feature switches.
  - Studio's preview shows none of the three.
  - Bill & GST and Table QR codes could only be checked for who can open them: the local test database has no such tables.
  - New texts are English only; real fonts, touch and screen readers were not tried on a device.
- **Open questions for the founder:**
  1. Approve the three server functions, and who writes them?
  2. In alerts, show "Table 7" or "A table near you"?
  3. Should an owner be able to manage the team (today only an admin can)?
  4. Should Studio's preview show these three with a clearly labelled example?

## 2026-10-02 — VINII Partner: Guest ordering redesigned with painted dishes, a payments page and wide-screen layouts

**The guest's swipe-to-order experience now feels alive: every dish is a painted picture lit in a warm room (no more emoji), the swipe deck has depth and the price flies into the budget, success moments celebrate, and it fits a phone, a tablet and a counter screen. A payments page for Cashfree is built and tested against a pretend gateway; it cannot take real money until the server pieces exist.**

- **Why:** The founder said the screens "need more life". The proof was easy to see: a dish without a photo was shown as an emoji (a cheese wedge for Paneer Tikka), category tiles were random colours, success screens were bare black pages, and on a wide screen the app was a narrow strip. The founder also asked for a payments page with Cashfree, one QR code per table, "repeat items for the whole table", and a screen layout that fits every size.
- **Structural decisions:**
  - **Dishes without a photo are painted in code, in 16 kinds** (curry, biryani, tikka, pizza, pasta, noodles, dosa, burger, cake, sweets, drinks, coffee, bread, pastry, snacks, plain plate), lit from the upper left, replacing the emoji. The alternative, waiting for the restaurant to upload photos, lost because many have none yet and the app would look dead until they do. A real photo always wins when a dish has one; the paintings never pretend to be photographs.
  - **The new lighting sits on top of the restaurant's own colours.** It is worked out from whatever palette the storefront (or the Master's CMS) chose, so a restaurant that picks its own colours gets the same light in them. The alternative, changing the base colours, would have made the phone stop matching the Master's preview.
  - **The payments page never holds a secret and never decides that money arrived.** The server creates the payment and later says whether it was paid; what the browser reports after the payment window closes is only a cue to ask. The alternative, trusting the browser, would let anyone claim a bill paid. The whole contract for your server work is in `docs/PAYMENTS_CASHFREE.md`.
  - **A design gallery shows the guest screens on invented data** (dishes and prices copied from your two boards), with no login and no database. It is how screens are checked without touching any restaurant, and it is never part of a shipped build.
  - **Wide screens get two panes, not a stretched phone:** the welcome puts the dishes beside the words, categories show more tiles per row, and the deck keeps the live order beside it. The arrow keys work the deck (left skip, right add, up for details).
  - **The bill no longer has an "Ask for the bill" button.** The app has no way yet to call a member of staff, so the button could only pretend. The bill now says in a plain line what to do ("let a member of staff know you're ready for the bill"), and "Order more" becomes the main button when there is no online payment. The alternative, a button that answers "someone is coming", lost because it promises something the app cannot do. When a "call a waiter" function exists on the server the button can come back.
  - **The payment page's wording stays English-only for now.** The restaurant's own wording and its Hindi and Marathi versions are kept in a list of text keys shared with the Master's website. Adding payment keys on the phone alone would be thrown away the next time anyone saves from the Master's website, so they have to be added there first (see the open questions).
- **What works now (the first rounds were tried in a browser on the invented data; the final round was drawn offline because the browser preview pane would not open; 345 automated checks pass across the whole app):**
  - A guest sees a lit welcome with the restaurant's own dishes floating and embers rising (the handwritten headline writes itself on the bakery look), then category tiles with a painted dish each, then the swipe deck. Cards behind the front one are visible, the dish slides against the card as it is pulled, and an added dish's price flies into the budget ring, which pulses and counts up.
  - The dish page opens with the picture gliding from the card. Totals count up. Checkout, "Order placed" and "Served" show the dishes ordered. The success moment has confetti, a tick that draws itself, and a firm tap on phones that can give one.
  - Live tracking shows a ring around the actual dish that fills as the kitchen works, lines that fill between steps, and a breathing marker on the step in progress.
  - "For all 2" gives everyone at the table the same dish in one tap; "Order the same again" refills the cart from the last order.
  - Payments page (once a gateway offers it): the whole bill or "my share" of 2 or more people, the mobile number Cashfree requires, "Confirming with your bank", "Waiting for your bank, please don't pay again", failed, window closed, and a receipt; plus a QR code to pay from your own phone.
  - The dish page is a rounded sheet rising over the picture, with ingredients as plain labelled chips (no more letter circles) and the allergen and nutrition lines folded away until asked for.
  - The bill tells the guest what to do when there is no online payment, and a phone number that cannot be right says what to change ("A mobile number starts with 6, 7, 8 or 9").
  - A screen reader meets the front card of the deck as one item, "Paneer Tikka, ₹600, Veg, Bestseller", with "Add to order" and "Skip this dish" as actions and a double tap for the details, so the swipe is not the only way in. Three automated checks cover it.
  - Reduced-motion is honoured everywhere: the same changes happen, without travel.
  - A written design record, `DESIGN.md` at the top of the project (with `.impeccable/design.json` beside it), now describes the guest look: the light, colours, type, shapes, motion and the rules, so later screens stay consistent. Its colours and sizes were read from the code; the handwritten headline and the restaurants' chosen heading faces could not be seen in the final pictures.
- **Left undone:**
  - **Real payments.** The Cashfree checkout code has never run against Cashfree: there is no account or test key yet, and the server functions are not written (they are yours). Until then the bill shows no Pay button and tells the guest to let a member of staff know.
  - **The guest's own website and the table QR landing.** A guest scanning a table's code is not yet taken into the storefront; the guest experience still runs only on a staff phone handed over, or in Studio's preview. That needs the guest API with a table-session token (rule R10), which does not exist.
  - **Dish photos and the long-press video.** No dish has a photo or a video yet; the long-press video from your original list is not built.
  - **The Master's storefront preview** does not show the new lighting or the painted dishes; it was not changed.
  - **Three paintings are weaker** than the rest: the croissant, the pasta and the pizza toppings.
  - **The final pictures were drawn offline, in a plain font.** The browser preview pane would not open in the last round, so the final guest screens were checked as pictures drawn by the test tool (`tool/gallery/guest_review_test.dart`, phone and wide screen, dark and cream), where headings show in Inter. The handwritten bakery headline and the restaurants' chosen heading faces were seen in the earlier browser pictures, not in the final build.
  - **Hindi and Marathi on the payment page, the deck buttons and their screen-reader labels.** They are English text in the code, like most of the guest screens. They cannot be translated until the text keys exist in the Master's registry (an open question below).
  - **A real "call staff" or "ask for the bill" action.** Deliberately removed (see the decisions); it needs a server function.
  - The design tool's own files (about 14 MB, mostly one program file) are not committed.
  - The design review (two rounds, by the design toolkit's reviewer) ended with fixes applied but no third look at the last small batch: the dark dish-page sheet, the bill note, the deck's button shadows, the cream page's top shade and the phone-number messages. Those were checked by drawing them again, not by the reviewer.
- **Open questions for the founder:**
  1. Cashfree: create an account and share test keys (kept only on the server), and write the functions in `docs/PAYMENTS_CASHFREE.md`?
  2. Should the guest pay inside the guest flow, as built, or only staff collect at the table?
  3. Do you want the Master's CMS preview updated to show the lighting and painted dishes, so the Master and the phone match?
  4. Should the next step be the guest's own website at the restaurant's web address (this needs the table-session token), or dish photos and the long-press video?
  5. Should the 14 MB design tool folder be committed, or stay on this computer only?
  6. Shall the payment page's text keys (page title, "Whole bill", "My share", the mobile-number lines, "Payment received" and the rest) be added to the Master's shared text list (`apps/web/src/lib/storefront-copy.ts`) with the same English defaults? Only then can a restaurant write its Hindi and Marathi versions, and only then can the phone offer them.
  7. Do you want a "call a waiter" function on the server, so the bill can offer a real "ask for the bill" button again?

## 2026-10-02 — VINII Partner: Staff screens for bill settings, service charge, store status, team and table QR codes

**Built the restaurant-side screens that were still missing: Bill & GST settings, removing the service charge at the final order, an Open / Paused / Closed store control, the Team list, table QR codes, and a faster sales and payment flow with split payment. They run and are tested on made-up data; the parts that need new database functions say "Not available yet" until the founder applies them.**

- **Why:**
  - GST rates, the service charge and the details printed on a bill were fixed in the system. An owner could not change them, and a manager could not take the service charge off when a guest asked at the end of the meal.
  - A restaurant could pause orders but not close for the day.
  - Owners could not see who is on the team or what each role may do, and had no QR code to print for a table.
  - Taking a table order and the payment was slow on a phone and cramped on a counter computer, and a bill could not be paid part cash, part UPI.
- **Structural decisions:**
  - **Who-may-do-what is enforced in the app for now.** The database today checks that a person belongs to the restaurant, not what their role is. The phone hides or disables any button the role must not use, but the database itself would still accept the action. Waiting for the database to check roles would have held back every screen. This is written into the platform contract (gap G2) with the rule the founder's migration should add.
  - **No database change was made or applied.** Three pieces need new database functions, which are the founder's to write: taking the service charge off a bill already placed (`pos_adjust_bill`), giving a table its QR code or replacing it (`pos_issue_table_qr`), and two extra options when placing an order (`waive_service_charge` and `waive_reason`). The exact shapes are in section 4.5 of `docs/PLATFORM_CONTRACT_ALIGNMENT.md`. Each screen is finished and shows "Not available yet" until its function exists.
  - **"Closed for today" is stored as "not accepting until 9 AM".** One Local's connection knows only open, or paused until a time, so closing for the day is saved as paused until 9 AM (today if that is still ahead, otherwise tomorrow). The alternative, a real closed value, would need a change on One Local's side. The catch: a pause that someone sets to end at exactly 9:00 AM will also read as Closed.
  - **The service charge is added before GST, and removing it applies to one bill only.** The person who removes it is recorded by name, with an optional reason. Switching the service charge OFF in settings saves 0% and remembers the last percentage, so ON brings it back.
  - **Table sheets are real printable PDFs, not screenshots.** That meant adding three small, widely used libraries: `pdf` (builds the sheet), `printing` (opens the print window) and `web` (downloads one table's picture in a browser). The QR library was already there. Printing a screenshot lost because it comes out blurry at print size.
  - **On wide screens (counter computer, tablet) Sell, Payment and Bill & GST show two panes:** the menu beside the ticket, and the form beside a live example of a bill.
- **What works now:** (tried on a test setup with invented data; 345 automated checks pass)
  - An owner or admin opens More, Bill & GST, and sets GST (0, 5, 12, 18 or their own rate, shown as CGST plus SGST), the GSTIN, the service charge ON or OFF and its percentage, and rounding to the nearest rupee. They also set the legal name, address, phone, FSSAI number and footer note printed on bills. A live example shows what ₹1,000 of food comes to. Save lights up only when something changed and is valid. Managers and billers can look but not change.
  - An owner, admin or manager can remove the service charge at the final order, in Sell checkout and on an open order, after a confirmation that says how much less the guest pays. It then shows struck through with "Removed" and an "Add back" button. At payment, a gentle one-time question offers the removal once per order.
  - The store control reads Open, Paused or Closed today, always with a word and an icon, never colour alone. Owners, admins and managers can switch sales channels (Swiggy, Zomato and the rest) ON or OFF from More.
  - Team: a list with initials, role and status; a role filter; search once there are more than eight people. An admin can change a role or suspend and reactivate someone. Nobody can change themselves, and the last active admin can never be removed. Everyone else sees the list read-only. Invitations are still sent from the VINII control panel, and the screen says so.
  - Table QR codes: tables grouped by area, a code for each, "Preview", copy link, save as a picture (in a browser), and print all (an A4 sheet, three table cards across). A table with no code says "No code yet".
  - Sell and payment: dish tiles with picture, price and veg mark; search and category chips; a cart bar that stays in place; steppers and notes; a table picker; a clear totals card; Cash, UPI and Card; cash shortcuts (50, 100, 200, 500) with change due; a split across two methods that must add up exactly; a calm "paid" moment. No online payment option is shown.
  - Also fixed: on a very short window the Orders screen no longer overflows.
- **Left undone:**
  - The three database functions above, deliberately (migrations are the founder's job). Until they exist, removing the service charge from a placed order and issuing or replacing a table code show "Not available yet". A service charge removed before placing may still be added by the server; the payment screen then shows what the server really charged.
  - Nothing was seen in a real browser at the end. The browser preview pane stayed hidden, so the final screens were checked by drawing them offline with the real fonts and icons (phone and desktop sizes, light and dark, each role) and by a web build that started. The picture download and the print window were not tried in a browser.
  - Bill settings, sales channels and team status are saved by writing straight to the shared tables. None of it was tried against a real database, so whether the database allows the very first save (it has to create the settings row) is unconfirmed.
  - The online payment gateway and the rider app were not touched. The guest screens and the dish pictures are other sessions' work and are not covered here.
- **Open questions for the founder:**
  1. Approve section 4.5 of the platform contract (the two new functions and the two new options when placing an order)?
  2. May a biller remove a service charge? The app says no: owner, admin and manager only.
  3. Is "Closed for today means off until 9 AM" acceptable, or should One Local gain a real closed state?
  4. Does anything other than the Master's Channels page read the channel ON/OFF switch? If Swiggy and Zomato orders are not filtered by it, the phone's switch is accurate but changes nothing for those orders.
  5. Should every role see the Team list, as the database allows today?

## 2026-10-02 — VINII Partner: Product record and founder decisions captured before the design pass

**Wrote the one-page product record the design toolkit (Impeccable) needs, saved the two reference boards into the project, and recorded four founder decisions. No app screens were changed.**

- **Why:** The founder said the screens "need more life" and asked for the design toolkit to redesign the app. The toolkit will not design without a written record of who the product is for and what it must keep, so the design work starts from the founder's words and not from guesses. The same session also checked the product against the founder's full requirement list; that audit was given in the conversation and is not yet a saved document.
- **Structural decisions:**
  - **Web first.** The app is designed for the browser first and must fit phone, tablet and a counter computer. The same code can still become Android and iPhone apps later. Designing phone-only lost because the founder's brief says "web first" and "fit all screen sizes". Today's screens are phone-only.
  - **Guest first, then staff.** The swipe-to-order experience for guests is the first design target; the staff screens follow.
  - **One QR code per table.** A guest scans it and lands in the storefront already set to their table.
  - **Payments through the payments page, with Cashfree as the gateway.** The app never holds the gateway's secret keys; the server creates the payment and records the result.
- **What works now:** The product record is in `PRODUCT.md`. The two boards are in `docs/reference/` (`board-1-vinii-bistro.webp`, `board-2-the-windough.webp`). Impeccable is installed in the project's `.claude/` folder (the founder ran its installer).
- **Left undone:**
  - The design pass itself. Next step: a critique of the guest flow, then colour, motion and layout work.
  - Service-charge ON/OFF with a "remove at final order" prompt, and the Open / Paused / Closed store control. Paused, not dropped; nothing was changed.
  - Cashfree payments and table QR codes. Both need server pieces that are not in this project: creating the payment, receiving the result, and storing a safe table-session token.
  - A saved version of the audit against the founder's requirement list.
  - The installed design tool (about 14 MB, mostly one program file) is not committed.
- **Open questions for the founder:**
  1. Do you have a Cashfree account, and may we use its test keys on the development server only?
  2. Does the guest pay inside the guest flow, or does staff collect at the table?
  3. Should the 14 MB design tool folder be committed to the project, or stay on this computer only?
  4. The platform contract still names Razorpay for online payments; may it be changed to Cashfree?
  5. The last entry says the app now runs only on the live VinniPos database. To see the screens while redesigning, I need either a test login there or permission to use the local test database. Which?

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
