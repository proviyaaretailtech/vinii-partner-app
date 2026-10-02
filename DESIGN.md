---
name: VINII Guest Storefront
description: A lit room for ordering food. Swipe a dish, watch its price fly into the budget.
colors:
  bistro-night-black: "#0B0B0C"
  bistro-umber-surface: "#17171A"
  bistro-raised-surface: "#222226"
  bistro-hairline-grey: "#2C2C31"
  bistro-candle-white: "#FFFFFF"
  bistro-ash-muted: "#A1A1AA"
  bistro-gold: "#F5B82E"
  bistro-key-light: "#EBB43C"
  bistro-lit-surface: "#211E1C"
  bistro-gold-hairline: "#564A33"
  artisan-flour-cream: "#F6F0E7"
  artisan-linen-surface: "#FFFFFF"
  artisan-crust-surface: "#EFE5D8"
  artisan-crumb-hairline: "#E2D5C4"
  artisan-espresso-ink: "#1E1915"
  artisan-warm-muted: "#7A6E64"
  artisan-espresso-accent: "#2B211B"
  artisan-daylight: "#F2C58B"
  fresh-leaf-accent: "#16A34A"
  success-bistro: "#22C55E"
  danger-bistro: "#EF4444"
  success-artisan: "#3E8E5A"
  danger-artisan: "#D9534F"
typography:
  display:
    fontFamily: "Plus Jakarta Sans, Inter, sans-serif"
    fontSize: "26px"
    fontWeight: 800
    lineHeight: 1.08
    letterSpacing: "-0.8px"
  display-artisan:
    fontFamily: "Playfair Display, Georgia, serif"
    fontSize: "26px"
    fontWeight: 800
    lineHeight: 1.08
    letterSpacing: "0"
  hero-script:
    fontFamily: "Kaushan Script, cursive"
    fontSize: "1.05x of hero size"
    fontWeight: 400
    lineHeight: 1.05
    letterSpacing: "0"
  title:
    fontFamily: "Plus Jakarta Sans, Inter, sans-serif"
    fontSize: "18px"
    fontWeight: 800
    lineHeight: 1.08
  body:
    fontFamily: "Plus Jakarta Sans, Inter, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.4
  body-artisan:
    fontFamily: "DM Sans, Inter, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Plus Jakarta Sans, Inter, sans-serif"
    fontSize: "12.5px"
    fontWeight: 400
    lineHeight: 1.4
  price:
    fontFamily: "Plus Jakarta Sans, Inter, sans-serif"
    fontSize: "22px"
    fontWeight: 800
    fontFeature: "tnum"
rounded:
  button-square: "6px"
  button-rounded: "14px"
  button-pill: "999px"
  field: "16px"
  card: "18px"
  card-large: "22px"
  deck-card: "24px"
  sheet: "28px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "20px"
  column: "480px"
components:
  button-primary:
    backgroundColor: "{colors.bistro-gold}"
    textColor: "{colors.bistro-night-black}"
    typography: "{typography.body}"
    rounded: "{rounded.button-pill}"
    height: "56px"
  button-primary-dense:
    backgroundColor: "{colors.bistro-gold}"
    textColor: "{colors.bistro-night-black}"
    rounded: "{rounded.button-pill}"
    height: "46px"
  button-primary-artisan:
    backgroundColor: "{colors.artisan-espresso-accent}"
    textColor: "{colors.artisan-flour-cream}"
    rounded: "{rounded.button-rounded}"
    height: "56px"
  button-soft:
    backgroundColor: "{colors.bistro-raised-surface}"
    textColor: "{colors.bistro-candle-white}"
    rounded: "{rounded.button-pill}"
    height: "56px"
  card:
    backgroundColor: "{colors.bistro-lit-surface}"
    textColor: "{colors.bistro-candle-white}"
    rounded: "{rounded.card}"
    padding: "20px"
  deck-card:
    backgroundColor: "{colors.bistro-night-black}"
    textColor: "{colors.bistro-candle-white}"
    rounded: "{rounded.deck-card}"
  detail-sheet:
    backgroundColor: "{colors.bistro-lit-surface}"
    textColor: "{colors.bistro-candle-white}"
    rounded: "{rounded.sheet}"
    padding: "20px"
  input-field:
    backgroundColor: "{colors.bistro-raised-surface}"
    textColor: "{colors.bistro-candle-white}"
    rounded: "{rounded.field}"
  logo-chip:
    backgroundColor: "{colors.bistro-gold}"
    textColor: "{colors.bistro-night-black}"
    size: "44px"
---

# Design System: VINII Guest Storefront

Source: the Flutter build in `vinii_partner/lib/presentation/guest/`, `look/`, and `theme/guest_theme.dart`. There is no CSS; tokens live in Dart. Hex values are read from `GuestPalette.from` (the template defaults). The restaurant's CMS may override accent, colours, fonts and button shape, so these are defaults, not brand constants. Values marked derived (key light, lit surface, gold hairline) are computed by `look.dart` and recorded here as the result for the default gold accent.

## Overview

**Creative North Star: "The Lit Room"**

Chosen from the build and the direction contract, not asked. Every screen is a room with one light in it: a key light from the upper left, taken from the restaurant's accent, falling on a dish that looks already served. Bistro Night is a candle-lit room (umber blacks, gold that glints). Artisan Day is a morning bakery (flour cream, espresso ink, window light). Fresh Minimal is the same lighting rules on white and green. The food leads and the interface recedes; from the order review onward, the task and the state outrank expression.

Depth comes from light, not from borders and drop shadows alone. Surfaces rise by growing lighter and warmer, hairlines are drawn from the accent, the stage behind a page has a faint grain and a slow drift of out-of-focus light. Dishes without a photo are painted in code from one lit family (16 families, upper-left key light, soft contact shadow, steam where earned). A real photo always wins.

**Key Characteristics:**
- One light source, derived from the accent, upper left, everywhere.
- Surfaces rise lighter and warmer; never dead flat black or neutral grey cards.
- One signature interaction: the three-card swipe deck, where the added dish's price flies into the budget ring and the ring ticks up.
- Food is a photo or authored illustration, never an emoji.
- Everything the CMS can change (colours, faces, button shape) carries through the same lighting.
- Reduced motion is honoured on every animation: the state change still happens, it stops travelling.

## Colors

Two pinned worlds plus a light template, all in one palette structure: background, surface, surface-alt, border, ink, muted ink, accent, on-accent, success, danger.

### Primary
- **Bistro Gold** (#F5B82E): the Bistro accent; primary buttons, the logo chip, the price on the detail sheet, selected tab underline, the second line of the headline.
- **Espresso Accent** (#2B211B): the Artisan default accent; primary buttons on cream. Too dark to be light, so the key light falls back to Daylight. Signals on cream (tracking progress, the step in progress) do not use espresso: they use the key light darkened by `readable()`, which comes out an amber-brown.
- **Leaf Green** (#16A34A): the Fresh Minimal default accent.

### Secondary
- **Key Light** (#EBB43C, derived): the accent softened (saturation x0.9, lightness 0.58 dark / 0.62 light) so it reads as light, not paint. Feeds the stage glow, lit surfaces and hairlines.
- **Daylight** (#F2C58B): the key light on light pages when the accent is near-black or grey (luminance under 0.12, or saturation under 0.08). On dark pages the fallback is #E9B36B. The scene is never lit in brown.

### Neutral
- **Night Black** (#0B0B0C): Bistro page background. Warm in effect once the stage glow and grain sit on it.
- **Umber Surface** (#17171A), **Raised Surface** (#222226), **Hairline Grey** (#2C2C31): Bistro surface, alt surface and border before accent tinting.
- **Lit Surface** (#211E1C, derived) and **Gold Hairline** (#564A33, derived): surface and border after the accent is mixed in (4.5% and 22%).
- **Candle White** (#FFFFFF) ink and **Ash** (#A1A1AA) muted ink on Bistro.
- **Flour Cream** (#F6F0E7), **Linen** (#FFFFFF), **Crust** (#EFE5D8), **Crumb Hairline** (#E2D5C4): Artisan background, surface, alt surface, border.
- **Espresso Ink** (#1E1915) and **Warm Muted** (#7A6E64): Artisan text.
- **Success** (#22C55E Bistro, #3E8E5A Artisan, #16A34A Fresh) and **Danger** (#EF4444, #D9534F, #DC2626): status and the add/skip actions; the "Add to order" button on the detail sheet uses success green, not the accent.

### Named Rules
**The Light From The Accent Rule.** Every glow, tint and hairline is computed from the accent through `keyLight`. No hard-coded brand colour enters the guest runtime; a restaurant's own colours get the same lighting.

**The Rising Surface Rule.** Surfaces get lighter and warmer as they rise (`surfaceLit` mixes 4.5% to 5% of key light into the surface). No flat black cards.

**The Hairline From The Accent Rule.** Borders are `hairline`, the neutral border mixed 22% (dark) or 30% (light) toward the key light. Never a neutral grey stroke on a lit surface.

**The Readable Rule.** Accent used as text goes through `readable()`: darkened on light pages, lightened on dark, only until it reaches 4.5:1 against the background, and unchanged if already readable. Legibility adjusts the colour; the colour is never kept at the cost of legibility.

**The Night Hero Rule.** The welcome hero is always set on night (the dark template's background, or the light template's ink) so a white headline reads. The Artisan welcome is therefore dark brown, not cream.

## Typography

**Display Font:** Plus Jakarta Sans (Bistro), Playfair Display (Artisan), Outfit (Fresh); fallback Inter.
**Body Font:** Plus Jakarta Sans (Bistro), DM Sans (Artisan), Outfit (Fresh); fallback Inter.
**Script Font:** Kaushan Script, heading only, the Artisan welcome headline; written on once.

**Character:** Heavy, tightly tracked sans headings (w800, -0.8 letter spacing) against quiet body copy, or a serif/handwritten headline on Artisan. A face chosen in the CMS sets every heading. Script faces are never body text and are never faux-bolded; the code sets them at their one weight.

### Hierarchy
- **Hero** (display, 1.05x for script, 1.05 to 1.08 line height): the welcome headline, white on the night scene; second line in the accent on Bistro.
- **Display** (800, 22 to 26px, 1.08, -0.8): screen titles ("All dishes"), dish name on the deck card, ADD / SKIP stamps.
- **Title** (700 to 800, 18px): section titles (Ingredients, Discover more), sheet headings.
- **Body** (400, 14 to 16px, 1.4): descriptions, tracking text. Buttons are 700 at 16px (14.5px dense).
- **Label** (400, 12.5px): taglines, hints, secondary meta.
- **Price** (800, tabular figures): always bold with tabular figures so totals do not jiggle; counts up with `CountUp`.

### Named Rules
**The Tabular Money Rule.** Every rupee amount is w800 with tabular figures.

**The One Weight Script Rule.** A script face is set at w400 only, in headings only.

## Layout

Phone-first column, capped at 480px (`GuestColumn`, `GuestPage.maxWidth`), centred with page padding of 20px. The bottom action area is padded 20 / 8 / 20 / 12 and never wider than 480. Sections use an 8px base rhythm (8, 12, 20).

The wide layout starts at 900px of screen width (checked in welcome, categories and deck). The welcome becomes two columns: the lit scene and large dish on the left, the ordering column (460px at most) on the right. From then on the right column keeps the live order and budget in view (the order panel with ring, lines, estimated total, and a full-width continue button). Category pages widen to 1040px (grid) or 640px (wheel). On a wide screen the deck stays a single column of reduced width with keyboard hints under the buttons (Left skip, Right add, Up details). A phone column must not float in empty space on a wide screen.

Touch targets are 44px or larger; buttons are 56px (46px dense).

## Elevation & Depth

Hybrid: tonal layering first (surfaces lighter and warmer as they rise), tinted two-layer shadows second, and a painted stage behind everything. Shadows are warm brown on light pages and black on dark ones, always with a real offset; none are glow-only.

### Shadow Vocabulary
- **Lift level 1** (two layers: dark page `0 16px 30px black@0.55` + `0 2px 6px black@0.35`; light page `0 16px 30px #3A2410@0.14` + `0 2px 6px #3A2410@0.10`): deck cards, payment panels.
- **Lift level 0.6 / 0.7**: categories tiles and mode cards. Offset, blur and alpha all scale with the level.
- **Stage** (not a shadow): radial key light 40% (dark) or 34% (light) at upper left, a weaker bounce from the lower right, five drifting soft discs, a vignette (black at 55% dark, #3A2410 at 10% light), and a 96px grain tile repeated.

### Named Rules
**The Tinted Shadow Rule.** Shadows have an offset and a soft blur, tinted to the room. Never a glow in place of a shadow, never neutral grey.

**The Quiet Stage Rule.** The stage drifts at about 15 frames a second, stops entirely under reduced motion, and appears as a still picture on ordinary pages (intensity 0.25 to 0.5).

## Shapes

Rounded and soft; nothing sharp except at the owner's request. Button shape is a CMS choice: pill (999, Bistro default), rounded (14, Artisan and Fresh default), or square (6). Outline buttons (accent stroke, 1.8px) are a CMS option. Field radius 16, cards 18 to 22, deck card 24, the detail sheet 28 at the top corners. Chips are pills. Circular controls (skip, add, back, favourite, close) are round buttons on a dark scrim over the picture. Progress is a ring (budget, tracking) with a thin accent arc.

## Components

### Buttons
- **Shape:** per CMS: pill 999 / rounded 14 / square 6.
- **Primary:** accent fill with `onAccent` text (`readableOn` the accent); 56px high, 46px dense; 16px w700 label; optional trailing arrow, 20px icon. Outline variant is a 1.8px accent stroke.
- **Success:** success-green fill, white text; used for add-to-order and confirmations.
- **Soft / Outline:** alt-surface fill with ink text; transparent with border at 1.4px.
- **States:** disabled at 60% opacity; busy shows a 20px spinner; pressed scales to 0.97 with a light haptic; mouse hover may grow (`hoverScale`). Tap fires `selectionClick`.

### Cards / Containers
- Corner 18 to 22px, `surfaceLit` or the `sheen` gradient (surface mixed 8 to 9% toward key light at the upper left), accent-drawn hairline, `lift()` for raised cards. Flat page sections never nest a card in a card.

### Inputs / Fields
- Filled with alt surface, radius 16, no border stroke, muted hint. Sliders have a 6px track in accent over alt surface.

### Navigation
- **Top bar:** circular back button, logo chip, small brand name over a bold screen title, circular action buttons. 
- **Category strip:** text tabs, the selected one in full ink with a short accent underline.
- **Bottom bar:** one primary action pinned to the bottom, in the 480px column.

### Swipe deck (signature)
Three cards with depth; the next card rises as the front card leaves. Dragging past 28% of width or a fling above 900px/s commits. ADD (green) or SKIP (red) stamps appear on the card at 26px with 3px tracking. The card carries photo or painted dish, badges (Bestseller, Chef Special), name, a short description, price, and a Details handle. On add the price flies into the budget ring (`fly.dart`), which pulses (1 to 1.045 over 360ms) and counts up.

### Browse switch
Two icons in one pill at the end of the category strip: swipe cards and menu rows. The chosen one is filled with the accent; each icon is a 44 × 36 target in a pill with 3px padding and radius 22. The choice lasts the visit. It is absent when the restaurant has turned the deck off (the menu is then the only view).

### Traditional menu (block menu)
A picture block 104 × 116 on the left; on the right the name with its veg mark, two lines of description, tag pills, the price and an Add pill that becomes a stepper. A row is at least as tall as its picture and grows with its words, so a long description never overflows it.

### Your order (one screen)
Order, review and checkout are one screen, in this order: a switch for the ways of ordering (only those the restaurant offers), the dishes with steppers, the table as a quiet line, a note for the kitchen, a coupon row when the server takes coupons, the estimated bill, the table budget, and the Place order button with the total in its label. The table is never asked: it comes from the QR code, and without one the guest is told to scan it.

### Mode switch
A segmented control with 4px padding and radius 18; its segments are 44px high with radius 14, the chosen one filled with the accent.

### Coupon row
One card, three states: a quiet "Have a coupon code?" row; a field with an Apply button (the server's reason in the danger colour underneath when a code does not apply); and "CODE applied" with what it saves and a Remove button. The bill gives the discount its own line, named "Coupon CODE". The phone never works the discount out: the server does.

### Item detail sheet
A 28px-radius sheet rising over the picture, lit (`surfaceLit`) on a dark page and the page colour on a light one, so it rises off the picture instead of sitting as a flat slab. Its rounded top is drawn on the picture's own sliver (a viewport paints the first sliver over the next), the picture is clipped so its parallax never covers the title, and the sheet runs to the bottom bar however short the words are. Price in the accent, badges, ingredient chips (a tone dot and the name, never letters standing in for pictures), collapsible allergen and nutrition rows, and a pinned bar with a quantity stepper and the add button showing the running price.

### Budget ring
A circular progress with the percent inside, "used" caption in success green until the warning state, and a plain sentence beneath ("You're well within your budget").

### Painted dish art
`food_art.dart` / `dish_art.dart` draw 16 families lit from the upper left with a contact shadow and optional steam. Used wherever a photo is missing, including as a thumbnail in order lines and tracking.

## Do's and Don'ts

### Do:
- **Do** derive every tint, glow, hairline and shadow from the accent through `keyLight`; never hard-code a brand colour.
- **Do** run accent-as-text through `readable()` (4.5:1 minimum).
- **Do** keep touch targets at 44px or larger; primary buttons 56px.
- **Do** use a photo when the dish has one; otherwise the painted dish art.
- **Do** use the motion vocabulary: 140 / 280 / 460 / 760ms, arrive curve (0.16, 1, 0.3, 1), exits quicker than entrances (0.7, 0, 0.84, 0), stagger 45ms per item capped at 270ms.
- **Do** honour reduced motion on every animation, loop and travel.
- **Do** set prices bold with tabular figures.
- **Do** keep one signature interaction (the swipe deck and the price flying into the budget) and let everything else stay quiet.
- **Do** go two-pane at 900px and above, with the live order in the right column.
- **Do** take what the QR code already knows (the table) from the QR code, and say it once as a quiet line.

### Don't:
- **Don't** use emoji as food or as icons; use photos, painted art and the Material icon set.
- **Don't** add kickers or eyebrow labels over titles.
- **Don't** nest cards inside cards.
- **Don't** use glow-only shadows or hard offset shadows; use the tinted two-layer `lift()`.
- **Don't** use gradient text.
- **Don't** use rainbow category tiles or dead flat black cards.
- **Don't** float a phone column in empty space on a wide screen.
- **Don't** ask the guest to type or pick a table, or to confirm the same order on three screens in a row.
- **Don't** faux-bold a script face or use one as body text.
- **Don't** make the staff app inherit this look: the staff app (`staff_theme.dart`, `ViniiTokens`) is a separate, plainer Operate-mode system with its own tokens and the VINII green (#76EC00) accepting state. It is not documented here.

<!-- Not canonized: tracked uppercase brand wordmark on the welcome (letterSpacing 3) and the ADD / SKIP stamps are carried by the build as functional labels, not as a rule for new labels. -->
