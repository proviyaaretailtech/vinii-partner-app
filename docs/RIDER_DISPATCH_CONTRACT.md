# Rider dispatch contract: every placed order pings the rider pool

**Date:** 2026-10-02 · **Applies to:** One Local (customer orders), VINII Partner (restaurant), OnLatur Rider (`PRD_ONLATUR_RIDER_V1.md`, `RIDER_APP_E2E_V1.md` in the One Local repo) · **Status:** the shapes the apps will call. **Nothing here is applied, and no migration or server code was written.** Tables, functions and routes are the founder's to write; this page is the exact interface so both sides can be built against it.

**What the founder asked for:** every successfully placed cart order must ping the rider pool so a driver is assigned to fulfil it, and for that we need API endpoints.

## 0. Rules (from the platform contract and the founder's notebook)

- **Apps never call each other.** The customer app, the restaurant app and the rider app each talk only to the server. Order → rider goes through the **dispatch service** on the One Local server (notebook: *Fulfilment Engine: delivery-service, dispatch-service, rider-service, tracking-service*).
- **Dispatch endpoints are server-to-server.** No phone calls them. They are called by the order flow (a database trigger or the order service) the moment an order becomes successful. They carry a service credential, never a user's token.
- **One job per order, forever.** The job's `idempotency_key` is `onelocal:<ol_order_id>:delivery`. Sending the same order twice returns the first job. This is what makes a retried "order placed" safe.
- **Separate states, never one overloaded status** (POS PRD §9): order, kitchen, delivery job, payment and cash custody each keep their own words. Dispatch never writes the order's status and the order flow never writes the job's.
- **The rider sees only what the job needs.** Area before pickup, address after pickup; a first name; the customer's phone only during an active job (RD4) or masked later. No order total except cash to collect. No prices of items.
- **Delivery fee and cash.** `cash_to_collect` is what the customer pays in cash (COD) including the marketplace delivery fee; it is `0` for a paid order. The kitchen's bill never contains the delivery fee (alignment doc, money rule).
- **Never a secret in a payload, a log or an app.** The service credential and the webhook secret live only on the server.

## 1. When "successful" fires

An order is **successful** when:

| Payment mode | Successful when |
| --- | --- |
| Cash on delivery (the pilot) | `ol_orders` row is created and the POS order exists (`pos_place_order` returned) |
| Online (later, Cashfree) | the server has confirmed the payment (`PAYMENT_CONFIRMED`), never the browser's say-so |

Only `service_type = 'delivery'` orders create a job. Dine-in and pickup never do.

**When the riders are pinged (open question 1).** Two choices, one switch (`dispatch_trigger` on the organization, default `placed` as the founder described):

| Value | Job created | Riders offered the job | Trade-off |
| --- | --- | --- | --- |
| `placed` (default) | at success | straight away | fastest delivery; a rejected or timed-out order withdraws the job and the rider's offer |
| `accepted` (PRD RD3) | at success, state `created` | when the restaurant accepts | no wasted rider trips; rider arrives later |

In both cases the job exists from the moment the order is successful, so the rider app and tracking never wonder whether a job exists.

## 2. The dispatch API (order side → rider pool)

Base: the One Local server, `/api/dispatch/*`. Every request:

| Header | Meaning |
| --- | --- |
| `Authorization: Bearer <service token>` | A service credential, role `dispatch_caller`; rejected for any user JWT |
| `X-Request-Id` | Unique per call, copied to every event the call writes |
| `Idempotency-Key` | Required on every `POST`; a repeat returns the first answer |
| `X-Timestamp` and `X-Signature` | `HMAC-SHA256(secret, timestamp + "." + body)`; rejected when more than 5 minutes old |

Tenant: `organization_id` is in the body and checked against the service credential's allowed organizations (R2).

### 2.1 `POST /api/dispatch/jobs`: create the job and ping the pool

The call the order flow makes on every successful delivery order.

```json
{
  "ol_order_id": "uuid",
  "pos_order_id": "uuid",
  "organization_id": "uuid",
  "order_no": "A-1042",
  "kitchen_no": "K-87",
  "payment_mode": "cod",
  "cash_to_collect": 460.00,
  "items": { "count": 4, "temperature": "hot" },
  "prep_minutes": 20,
  "promised_by": "2026-10-02T19:45:00+05:30",
  "pickup": {
    "name": "Mysore Dining Hall",
    "address": "text",
    "lat": 18.4088, "lng": 76.5604,
    "phone": "+91…"
  },
  "drop": {
    "area": "Gandhi Chowk",
    "address": "text, revealed to the rider after pickup",
    "lat": 18.4001, "lng": 76.5702,
    "customer_first_name": "Asha",
    "customer_phone": "+91…"
  },
  "vehicle": "any",
  "dispatch_trigger": "placed"
}
```

**Server does, in one transaction:**
1. Checks the credential, the signature and the organization.
2. Writes `delivery_jobs` (state `created`), a four-digit delivery OTP (only its hash is stored; the plain code goes to the customer through One Local, never to the rider), and the `delivery.created` event.
3. If `dispatch_trigger = 'placed'`, starts the offer round (2.5). If `accepted`, waits for 2.2.

**Returns `201`** (or `200` with the existing job when the key repeats):

```json
{
  "job_id": "uuid",
  "status": "created",
  "version": 1,
  "offer": { "round": 1, "state": "searching" },
  "eta": null
}
```

**Errors:** `400 invalid_payload` (names the field), `401`, `403 organization_not_allowed`, `409 order_not_deliverable` (not a delivery order, or cancelled), `422 outside_delivery_area`, `422 no_pickup_location` (the restaurant has no address or coordinates yet), `429`. A `5xx` is retried by the caller with the same `Idempotency-Key`.

### 2.2 `POST /api/dispatch/jobs/:job_id/release`

Starts offering the job to riders. Used when `dispatch_trigger = 'accepted'` (the restaurant accepted on the phone) and for operations re-dispatching a stuck job.

Body: `{ "prep_minutes": 20, "expected_version": 1 }`. Returns the job (as 2.3). Does nothing and returns the job if an offer round is already running.

### 2.3 `GET /api/dispatch/jobs/:job_id` (also `?ol_order_id=`)

What One Local's tracking screen and VINII's order detail read.

```json
{
  "job_id": "uuid",
  "ol_order_id": "uuid",
  "status": "assigned",
  "version": 4,
  "offer": { "round": 1, "state": "accepted" },
  "rider": { "first_name": "Ravi", "vehicle": "bike", "lat": 18.40, "lng": 76.56, "seen_at": "ISO" },
  "eta_minutes": 14,
  "timeline": [{ "kind": "delivery.assigned", "at": "ISO" }]
}
```

`rider` is `null` until assigned. No rider phone: calling is the rider app's masked or during-job feature (RD4).

### 2.4 `POST /api/dispatch/jobs/:job_id/cancel`

Body: `{ "reason": "restaurant_rejected | restaurant_timed_out | customer_cancelled | other", "expected_version": 3 }`.

Moves the job to `cancelled` if it is before `picked_up`, withdraws any live offer (the rider's card closes with "Order cancelled"), and writes `delivery.cancelled`. After pickup it returns `409 already_picked_up` and the order flow raises an exception instead. Called by the order flow when the order is rejected, times out or the customer cancels.

### 2.5 The offer round (server-side, no endpoint)

Per the Rider PRD, V1:

1. Candidates: riders enrolled with this organization, `online`, seen in the last 60 seconds, no live offer and no active job. Store-linked riders first (notebook), then platform riders when they exist.
2. Rank by distance to the pickup. Offer to **one rider at a time**; the offer lives 30 seconds (RD2) and is recorded in `delivery_assignments` (`offered`, then `accepted`, `rejected` or `timed_out`).
3. Push goes to the rider's device (Expo Push, high priority) and the job appears at `GET /rider/offers/current`.
4. First `accept` wins (the `UPDATE ... WHERE status = 'offered'` rule); everyone else's card closes.
5. On reject or timeout, offer to the next rider. After 3 rounds with no taker, write `delivery.exception` (`no_rider`), tell the restaurant's phone, and keep the job `created` for operations to reassign.

## 3. Rider-side endpoints (already specified)

The rider app uses `/api/rider/*` as in `PRD_ONLATUR_RIDER_V1.md` §8 (`offers/current`, `offers/:id/accept`, `reject`, `jobs/:id/step`, `deliver`, `exception`, `heartbeat`, `availability`, `push-token`). Dispatch adds nothing there. One addition is needed so the rider can see what the order side sent:

`GET /api/rider/jobs/:id` returns the job in the rider's view only: restaurant name and area (address after acceptance), customer first name, `drop.area` (full address only from `picked_up`), `cash_to_collect`, `items.count`, `order_no`, `promised_by`, `eta`.

## 4. Events back to the order side

The rider and dispatch services write every change to the **outbox** in the same transaction (`delivery_events`, same envelope as `order_events`: `kind`, `v`, `meta.request_id`, `meta.app`, `meta.actor`). One Local and VINII read them over Realtime today; a signed webhook can replace that later.

| Event (v1) | Meaning | Order side does |
| --- | --- | --- |
| `delivery.created` | Job exists | nothing |
| `delivery.offered` | A rider was pinged | tracking: "Finding a rider" |
| `delivery.assigned` | A rider accepted | tracking: "Rider assigned"; restaurant sees the rider's name |
| `delivery.rejected` / `delivery.timed_out` | One offer failed | nothing (the next rider is offered) |
| `delivery.no_rider` | Three rounds, no taker | restaurant phone alert; operations queue |
| `delivery.arrived_pickup` | Rider at the restaurant | restaurant sees "Rider here" |
| `delivery.picked_up` | Rider confirmed pickup | tracking: "On the way"; calls `pos_mark_handed_over` if the kitchen has not (idempotent) |
| `delivery.arrived_drop` | Rider at the customer | customer shows the 4-digit OTP |
| `delivery.completed` | OTP verified, cash recorded | `pos_set_order_status(delivered)`, then `pos_record_payment` (`cash`, key `onelocal:<id>:cod`) |
| `delivery.exception` | A problem | operations queue |
| `delivery.cancelled` | Job cancelled | tracking and restaurant show it |

**Mapping to the order's own words** (the order flow does this mapping once, in one place, never the apps):

| Job state | One Local `status` | POS status |
| --- | --- | --- |
| `created`, `offered` | unchanged | unchanged |
| `assigned` | unchanged (shows "Rider assigned") | unchanged |
| `picked_up` | `out` | `ready` plus the `out_for_delivery` event |
| `delivered` | `delivered` | `delivered`, then `paid` (cash) |

## 5. Schema exposed (names from the founder's registry; the founder writes the tables)

| Table | One line | Columns the endpoints above rely on |
| --- | --- | --- |
| `delivery_jobs` | The physical task | `id`, `ol_order_id` (unique), `pos_order_id`, `organization_id`, `status`, `version`, `idempotency_key` (unique), `payment_mode`, `cash_to_collect`, `items_count`, `temperature`, `prep_minutes`, `promised_by`, `pickup_*`, `drop_*` (address hidden from riders until `picked_up`), `otp_hash`, `dispatch_trigger`, `created_at`, `updated_at` |
| `delivery_assignments` | Every offer and answer | `job_id`, `rider_id`, `round`, `offered_at`, `expires_at`, `outcome`, `reason` |
| `riders`, `rider_availability`, `push_tokens` | The pool | as in the Rider PRD §7 |
| `delivery_events` | Outbox | `job_id`, `kind`, `v`, `meta`, `created_at` |
| `delivery_proofs`, `delivery_exceptions`, `rider_cash_ledger`, `rider_earnings` | After the job | as in the Rider PRD §7 |
| `org_dispatch_settings` (suggested) | Per restaurant | `organization_id`, `dispatch_trigger` (`placed`/`accepted`), `offer_seconds` (30), `max_rounds` (3) |

All with row-level security on, only the server reading or writing, a comment on every table and column. Job states: `created`, `offered`, `assigned`, `at_pickup`, `picked_up`, `at_drop`, `delivered`, `exception`, `cancelled` (Rider PRD §4).

## 6. What the apps do until it exists

- **VINII Partner** shows no rider information (it has none today) and the ready → out → delivered buttons work as before. When `GET /api/dispatch/jobs` exists, the order detail gains a "Rider" line.
- **One Local** keeps its simulated tracking timer until `delivery.*` events arrive.
- **The order flow** must not fail an order because dispatch is down: it records the order, retries the job creation with the same `Idempotency-Key`, and raises an operations alert after 3 failures. An order without a job is visible in a "needs a rider" list for operations.

## 7. Open questions for the founder

1. **Ping on `placed` or on `accepted`?** You described placed; the Rider PRD proposed accepted (RD3). The contract supports both with one switch. Which is the pilot default?
2. **Where does the order flow live?** A database trigger on `ol_orders` calling an Edge Function, or the One Local API after `ol_create_restaurant_order`? The contract is the same; the retry story differs.
3. **Who owns the rider table?** The Rider PRD ties riders to a restaurant (`riders.organization_id`). For platform riders later it must become many-to-many; decide now or later?
4. **Customer address and phone.** The alignment doc keeps these off the kitchen side (DPDP). This contract sends them to the dispatch service only, and shows the rider an address only after pickup. Confirm that is acceptable.
5. **Rider pay and delivery fee.** `estimated_earning` is shown on the offer card (Rider PRD §5.1) but the rates (RD6) are unset; the job carries none until you set them.
6. **Service credential.** Who issues it, and where does the signing secret live (server environment only)?
