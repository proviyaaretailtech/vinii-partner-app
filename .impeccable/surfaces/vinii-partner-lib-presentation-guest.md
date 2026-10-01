---
version: 1
slug: "vinii-partner-lib-presentation-guest"
primary_target: "vinii_partner/lib/presentation/guest"
related_targets: ["vinii_partner/lib/presentation/theme/guest_theme.dart","vinii_partner/lib/presentation/widgets/food_art.dart"]
---

# Guest storefront (swipe-to-order)

Scope: the whole guest flow in `vinii_partner/lib/presentation/guest/`, both pinned worlds (Bistro Night, Artisan Day) and the lighter Fresh Minimal template, from the welcome screen to the bill, plus two new screens inside it: the payments page and the table QR code.

Visitor mode: **Experience** from welcome to the swipe deck and dish detail (the food leads, the interface recedes). **Operate** from the order review onward (order, checkout, tracking, bill, payment): the task and the state outrank expression.

Audience and job: a guest at a table, alone or with friends, on their own phone (after scanning the table's QR code) or a handed-over staff phone. They decide what to order together, keep to a budget, order, watch it come, and pay. Real menu only; no invented dishes, prices, photos or claims.

Constraints that cannot move:
- The founder's two boards are the brief. The worlds keep their palette logic, fonts and component character.
- The restaurant's colours, fonts, button shape and text come from the CMS (`StorefrontTheme`, copy registry). Anything new derives from those fields, never from hard-coded brand colours.
- No sample data in the shipped app. Photos win whenever a dish has one.
- Web first, fitting phone, tablet and a counter screen. Touch targets 44px or larger. Reduced motion honoured.

Memorable moment: swiping a dish right and watching its price fly into the budget ring, which ticks up.

Unresolved: the real dish photography (none exists yet), the dish videos, the Cashfree account and the server pieces for payments and table sessions.

## Direction contract

THESIS: Give the food a face and the room a light. Every dish is lit as if it is already on the table (a real photo when there is one, an authored illustration when there is not, never an emoji), every state change has weight, and the budget, order and bill behave like a living tally. Refuses: emoji standing in for food, rainbow category tiles, dead flat black cards, and a phone column floating in empty space on a wide screen.

OWN-WORLD: Bistro Night is a candle-lit room: umber-tinted blacks (never neutral grey), surfaces that rise by growing lighter and warmer, hairlines drawn from the accent at low strength, a soft key light from the upper left, a fine grain, gold that glints. Artisan Day is a morning bakery: flour-warm creams, espresso ink, window light falling diagonally, drifting flour dust, a handwritten headline that is written on. Dish art is painted in code from one lit family: shared key light, a soft contact shadow, steam or crumbs where the dish earns them. Every tint is derived from the CMS palette fields, so a restaurant's own colours carry through.

STORY: The guest feels welcomed into a lit room, finds a dish worth wanting within two swipes, sees the budget answer every choice, places the order with confidence, watches it progress, and leaves with a bill that matches what they were promised. Nothing blocks the way to ordering.

FIRST VIEWPORT: Phone portrait: a full-bleed lit scene, slow warm light drifting behind a large dish on a stage that takes the upper 55% of the screen; the brand chip top-left; the two-line headline bottom-left with its second line in the accent; the call to action pinned at the bottom. On a wide screen the same welcome becomes two columns: the lit scene and large dish on the left, the ordering column (460px at most) on the right, and from then on the right column keeps the live order and budget in view.

FORM: Refinement of the pinned boards inside the established worlds; no concept roll (an extension of an existing surface). Signature interaction: a three-card swipe deck with depth, where the next card rises as the front card leaves and the price flies into the budget ring.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
