# Online payments with Cashfree: what the app does, and what the server must do

**Date:** 2026-10-02 · **Applies to:** the guest payments page in `vinii_partner/` (and, later, the staff POS) · **Status:** the app side is built and shown against a simulated gateway; **nothing here is applied or tried against Cashfree.** Database changes and server code are the founder's to write (migrations are not part of the app work).

**Decision (founder, 2026-10-02):** payment is taken from the payments page, with Cashfree as the gateway. (The platform contract's example still says Razorpay; Cashfree replaces it.)

---

## 1. In plain words

A guest taps **Pay ₹1,512** on the bill. Their payment happens inside Cashfree's own window, not ours. The restaurant's server creates the payment and later learns, from Cashfree directly, whether the money arrived. Only then does the guest's screen say "Payment received" and the order's payment is recorded in the POS.

**The app never holds a secret key and never decides that money arrived.** What the browser reports after the window closes is only a cue to ask the server.

## 2. The flow

```
Guest app                      Server (founder builds)                    Cashfree
─────────                      ───────────────────────                    ────────
Pay ₹756  ───────────────────► pos_start_online_payment
                                 checks the guest/staff session, the amount
                                 ≤ what is due, creates an `online_payments`
                                 row, then:
                                 POST /pg/orders  (secret key lives here) ──► creates the order
                               ◄── payment_session_id, order_id ─────────────
◄── attempt, session id, link
opens Cashfree window (_modal) ──────────────────────────────────────────────► guest pays (UPI etc.)
window closes
asks "paid yet?" ────────────► pos_online_payment_status
                                 reads our row (updated by the webhook);
                                 if still pending, asks Cashfree
                                 GET /pg/orders/{id}  ──────────────────────► status
                               ◄───────────────────────────────────────────
                                              webhook (signed) ◄───────────── PAYMENT_SUCCESS_WEBHOOK
                                 verify signature, dedupe on cf_payment_id,
                                 pos_record_payment(method 'online',
                                   idempotency_key 'cashfree:<cf_payment_id>',
                                   reference <cf_payment_id>)
◄── paid / pending / failed
"Payment received"
```

## 3. What the app already does

- `lib/application/guest_payments.dart`: the two seams (`GuestPayments`, `OnlinePayment`, `PaymentOutcome`, `CheckoutResult`).
- `lib/presentation/guest/guest_payment.dart`: whole bill or "my share of N", the guest's mobile number (Cashfree requires one on every order), the payment window, "confirming with your bank", "waiting for your bank" (never "pay again"), failed, window closed, and the receipt.
- `lib/data/payments/cashfree_checkout_web.dart`: loads Cashfree's script **only when a guest chooses to pay**, then `Cashfree({mode}).checkout({paymentSessionId, redirectTarget: '_modal'})`. Written from Cashfree's guide, **not yet run against their sandbox**. Other builds say plainly that online payment opens in the web version.
- `GuestOrderGateway.payments` is `null` today, so the bill shows no Pay button and tells the guest to let a member of staff know (it has no button to call staff: nothing on the server can be called yet). It becomes a real `GuestPayments` when the functions below exist.

## 4. What the server must provide (proposed; names are the founder's to change)

All writes are idempotent and carry the actor, request id and app in the event `meta` (platform rules D21).

### 4.1 `pos_start_online_payment(p jsonb)`

| `p` key | Meaning |
| --- | --- |
| `organization_id` | The restaurant. The server re-checks the caller's right to it (staff membership, or the table-session token for a guest) |
| `order_ids[]` | The open orders being paid (same table) |
| `amount` | What this person wants to pay now. The server accepts it only if `1 ≤ amount ≤ sum of what is still due` and has at most 2 decimals. A share is just a smaller amount; the rest stays due |
| `idempotency_key` | Same key returns the same attempt (a double tap or retry never makes two) |
| `payer_phone` | 10-digit mobile. Cashfree requires `customer_phone` on every order |

Returns `{ attempt_id, payment_session_id, link_url?, expires_at }`.

What the server does with Cashfree: `POST https://api.cashfree.com/pg/orders` (sandbox: `https://sandbox.cashfree.com/pg/orders`) with headers `x-client-id`, `x-client-secret`, `x-api-version: 2026-01-01`, `x-idempotency-key`, and a body of:

- `order_id`: **new for every attempt**, 3 to 45 characters of letters, digits, `_` and `-` (Cashfree answers 409 `order_already_exists` if an id is reused, whatever happened to the first order).
- `order_amount` (number, ₹1 minimum, 2 decimals), `order_currency: "INR"`.
- `customer_details`: `customer_id` (3 to 50 letters/digits; use a stable value per table session), `customer_phone`.
- `order_meta`: `notify_url` (https, the webhook below), `return_url` (the storefront page, 250 characters at most).
- `order_expiry_time`: now plus about 30 minutes (Cashfree rejects very short expiries; one repository reports a 15-minute minimum, unverified).
- `order_note`: for example the display number of the order.

For the "pay from your own phone" QR, either create a Payment Link (`POST /pg/links`, which returns `link_url` and a QR of it) or use the order's hosted checkout URL. Per-order dynamic UPI QR through the Order Pay API needs Cashfree to enable server-to-server calls and a GST turnover above ₹1 crore, so it is not assumed.

### 4.2 `pos_online_payment_status(p jsonb)`

`p`: `attempt_id`. Returns `{ outcome }` where outcome is `pending`, `paid`, `failed`, `dropped` or `expired`, decided from the row the webhook keeps up to date. If the row is still `pending` and more than a few seconds old, the server asks Cashfree (`GET /pg/orders/{order_id}` and `.../payments`) and updates the row. **Never answer from anything the browser said.**

### 4.3 The webhook (a server endpoint, not a database function)

- Configure in Cashfree: Dashboard, Payment Gateway, Developers, Webhooks (https only in production). Events used: `PAYMENT_SUCCESS_WEBHOOK`, `PAYMENT_FAILED_WEBHOOK`, `PAYMENT_USER_DROPPED_WEBHOOK`.
- **Verify the signature on the raw bytes**, not on re-serialised JSON (170.00 would become 170): `base64( HMAC-SHA256( key = the PG client secret, message = x-webhook-timestamp + raw request body ) )` must equal `x-webhook-signature`. Refuse anything else, and add your own replay window (Cashfree documents none).
- Cashfree delivers at least once and retries until it gets HTTP 200 (by default at 2, 10 and 30 minutes). **De-duplicate on `data.payment.cf_payment_id`.** Answer 200 quickly and do the work after.
- On success: `pos_record_payment` with `method 'online'`, `amount` from Cashfree's `payment_amount` (compare it with the attempt's amount), `idempotency_key = 'cashfree:' || cf_payment_id`, `reference = cf_payment_id`. The `payments.method` check already needs `'online'` added (platform contract §4.1).
- Optional hardening: allow only Cashfree's published server addresses on port 443.

### 4.4 A table to keep the attempts

`online_payments` (founder to design; this is the shape the functions above assume): `id`, `organization_id`, `attempt_id` (unique), `provider` (`cashfree`), `provider_order_id` (unique), `provider_payment_id`, `order_ids uuid[]`, `amount numeric(10,2)`, `status` (`created`, `pending`, `paid`, `failed`, `dropped`, `expired`), `payer_phone` (keep the minimum; DPDP), `created_at`, `expires_at`, `updated_at`, and the last webhook body for audit. Row security: staff of the organization may read; **only the service role writes**.

## 5. Testing without real money

- Cashfree gives test keys (prefixed `TEST_`) from the merchant dashboard (switch to Test, top right). No KYC is needed for the sandbox; live keys need KYC.
- Test UPI IDs: `testsuccess@gocash` (succeeds), `testfailure@gocash` (fails), `testuserdropped@gocash`, `testexpired@gocash`, `testinsufficientfunds@gocash`.
- Test cards: Visa `4706131211212123`, Mastercard `5105105105105100`, expiry 03/2028, CVV 123, OTP 111000.
- In the app, set production off (the default). Run the browser build over https; production needs the site's domain whitelisted in Cashfree (about 24 hours) and public Contact, Terms and Refund pages.

## 6. Things to know

- **UPI collect (typing a UPI ID) is being switched off by NPCI.** Cashfree blocked it on Android and desktop from 28 Feb 2026 (iOS exempt for now). Do not make it the main path; the hosted checkout offers UPI apps and a QR.
- A new `order_id` per attempt; never reuse one.
- `x-idempotency-key` replays the stored response; the same key with a different body gives 422.
- A second successful payment on the same Cashfree order is refunded automatically.
- **Mobile builds later:** Cashfree's official Flutter package is `flutter_cashfree_pg_sdk` (2.4.0+52 at the time of research). Its web support is unverified, so the browser build uses the script and JavaScript interop described above.
- Not decided, and not built: refunds, tips, who bears Cashfree's fee, and the staff-side "Online" payment method in the POS (the POS payment screen only offers Cash, UPI and Card today).

## 7. Sources (Cashfree official documentation, read 2026-10-02)

Create order: `https://www.cashfree.com/docs/api-reference/payments/latest/orders/create` · Web checkout: `https://www.cashfree.com/docs/payments/online/web/redirect` · Webhook signature: `https://www.cashfree.com/docs/payments/online/webhooks/signature-verification` · Idempotency: `https://www.cashfree.com/docs/payments/online/webhooks/webhook-indempotency` · Test data: `https://www.cashfree.com/docs/api-reference/payments/data-to-test-integration` · Whitelisting: `https://www.cashfree.com/docs/payments/online/go-live/whitelist` · Flutter: `https://pub.dev/packages/flutter_cashfree_pg_sdk`. The research summary came through a summarising fetcher: spot-check exact numbers before relying on them.

---

## 8. As built (server + database, 2026-10-08)

**Status:** applied to the LOCAL database (migration `0239_pos_online_payments`), server code in `One Local Mobile App /OL-ui/frontend/server/pos-payments.ts`, routes under `app/api/partner/payments/`. Proven only against a **stubbed Cashfree** (`scripts/pos-payments-checks.ts`, 50 checks) and the database test `database/tests/239_pos_online_payments.sql` (71 checks). **Not proven against the live Cashfree sandbox:** it answered 401 "authentication Failed" to the founder's test keys on 2026-10-08 (probably keys for another product or the wrong environment), so no real order was created. The Flutter app is not wired yet.

### 8.1 How the app calls it (differs from sections 4.1 and 4.2 in one way)

The app does **not** call the database functions. It calls the One Local server (`PARTNER_API_BASE_URL`, same base and same `Authorization: Bearer <staff access token>` that `DeliveryInbox` already uses) at the routes below. The server finds the staff member and restaurant from the token (`requirePartnerAuth`; a person with several restaurants gets their earliest membership, as everywhere else), checks the role, then calls the database functions with the service role. So `organization_id` in a body is optional, and if present it must equal the staff member's restaurant (else `403 wrong_organization`). The functions are service-role only and are **not** on the 0299 allowlist.

Roles that may start a payment: `org_owner, org_admin, manager, biller, business_manager, location_manager, finance_manager` (the same people `pos_record_payment` allows; a `captain` is refused with `403 forbidden`). Status may also be read by `accountant, operations_manager`. Refunds: `org_owner, org_admin, manager, business_manager, location_manager, finance_manager`.

### 8.2 HTTP routes

| Route | Purpose |
| --- | --- |
| `POST /api/partner/payments/online` | Start one online payment attempt (design 4.1) |
| `GET /api/partner/payments/online/{attempt_id}` | Ask how it went (design 4.2) |
| `POST /api/partner/payments/online/{attempt_id}/refund` | Refund all or part of a paid attempt |
| `GET /api/partner/payments/return?attempt=...` | The page Cashfree sends the payer's browser back to ("you can close this window"); shows no state |
| `POST /api/payments/webhook` | Cashfree to server, already existing: order ids starting `olp-` and refund ids starting `olpr_` are handled by `pos-payments.ts`. Configure `https://<server>/api/payments/webhook` in the Cashfree dashboard (events `PAYMENT_SUCCESS_WEBHOOK`, `PAYMENT_FAILED_WEBHOOK`, `PAYMENT_USER_DROPPED_WEBHOOK`, `REFUND_STATUS_WEBHOOK`) |

Errors have the usual shape `{ "detail": "<plain words>", "code": "<machine code>", ...extra }`. Money is **rupees with at most 2 decimals** in requests (`amount`) and also given in paise (`amount_minor`) in answers.

### 8.3 Start: `POST /api/partner/payments/online`

Request:

```json
{ "order_ids": ["<uuid>", "..."], "amount": 40.00, "idempotency_key": "<8-120 chars, new per tap-intent, reused on retry>", "payer_phone": "9876543210" }
```

- `order_ids`: 1 to 10 open orders of this restaurant; several only if they are at the **same table**. `amount`: `1.00 <= amount <= what is still due on those orders` (total minus every payment already recorded); a share is just a smaller amount. `payer_phone`: Indian mobile, 10 digits (a `+91` prefix and spaces are accepted); Cashfree gets it, **we keep only the last four digits**.
- `idempotency_key` (or the `Idempotency-Key` header): the same key and the same body returns the same attempt and the same live Cashfree order (a double tap or a lost reply never makes two). The same key with a different amount or orders is `422 idempotency_mismatch`. **After a failed, dropped or expired attempt use a NEW key** to try again: the old key only ever gives back that attempt. A new attempt always gets a **new Cashfree order id** (`olp-<32 hex>`).

Answer `200`:

```json
{ "attempt_id": "<uuid>", "status": "pending", "outcome": "pending", "recorded": false,
  "amount": 40, "amount_minor": 4000, "due": 105, "order_ids": ["..."],
  "provider": "cashfree", "provider_order_id": "olp-...", "payment_session_id": "session_...", "link_url": null,
  "environment": "sandbox", "expires_at": "2026-10-08T10:30:00Z", "message": "We are confirming with the bank. Do not pay again.",
  "poll": { "every_ms": 3000, "give_up_after_ms": 300000 }, "replayed": false }
```

Use `payment_session_id` with `Cashfree({mode: environment}).checkout({paymentSessionId, redirectTarget: '_modal'})` as in section 3. It is **never stored** by us; a repeat of the same start while the order is open returns it again. `due` is what was still due before this attempt. `link_url` is always `null` today (see 8.8). A repeat of an attempt that is already finished answers its state with `payment_session_id: null`.

Errors: `400 bad_request` (malformed ids or phone, orders not at one table), `403 forbidden` (role), `403 wrong_organization`, `404 not_found` (an order is not this restaurant's), `409 order_closed` (an order is already paid or cancelled, or nothing is due), `422 amount_exceeds_due` (extra field `due` in rupees), `422 amount_below_minimum` (under Rs 1), `422 idempotency_mismatch`, `502 gateway_unavailable` (Cashfree could not open the order; the attempt is marked failed, no money taken), `503 online_payments_off` (no Cashfree keys, or `FEATURE_ONLINE_PAYMENTS=off`).

### 8.4 Status: `GET /api/partner/payments/online/{attempt_id}`

Answer `200`: the same object as above (without `payment_session_id`), plus `poll_after_ms` (3000 while `pending`, else `null`) and `retry_ok` (true for `failed`, `dropped`, `expired`: start again with a new key). **`outcome` is the only thing the app should act on:**

| `outcome` | Meaning | `recorded` |
| --- | --- | --- |
| `pending` | Waiting for the bank. Keep polling; never ask the guest to pay again | false |
| `paid` | Money arrived and is booked on the order(s) (`payments` rows, method `online`) | true |
| `failed` | Declined. `failure_code: "declined"` (or `"gateway"` when Cashfree could not open the order) | false |
| `dropped` | The payer closed the window. `failure_code: "dropped"` | false |
| `expired` | The order's time ran out. `failure_code: "expired"` | false |
| `overpaid` | Cashfree took money but the bill had been settled another way meanwhile. It is **not** booked and the server refunds it automatically; show "it will be refunded" | false |

When the stored state is still `pending` and was last checked more than 5 seconds ago, the server asks Cashfree (`GET /pg/orders/{id}` and `/payments`) before answering, so the answer never depends on what the browser said. A `404 not_found` is returned for an attempt of another restaurant.

### 8.5 Refund: `POST /api/partner/payments/online/{attempt_id}/refund`

Request `{ "amount": 15.00, "reason": "guest left early (3-100 chars)", "idempotency_key": "<8-120 chars>" }`. Answer: `{ "attempt_id", "refund_id": "olpr_<24 hex>", "amount", "amount_minor", "status": "pending" | "processed" | "failed", "replayed", "eta_text": "3-5 working days" }`. The refund id is derived from (attempt, key): the same key again returns the same refund and never makes a second one at Cashfree. The sum of refunds that are not failed can never exceed what the attempt paid. Errors: `403 forbidden`, `409 wrong_state` (attempt not paid), `422 refund_exceeds_paid`, `422 idempotency_mismatch`, `502 refund_failed` (Cashfree refused it; the reserved amount is released), `502 gateway_unavailable` (retry with the same key). Final status comes from the `REFUND_STATUS_WEBHOOK` or a later retry of the same call.

### 8.6 Database objects (migration `0239`, all service-role only)

- `payments.method` now also allows `'online'`. `pos_record_payment` still refuses it (staff cannot key in an online payment by hand).
- Table `online_payments` (staff of the organization read it under row security, platform admins read all, only the server writes; no deletes): `attempt_id`, `organization_id`, `provider_order_id` (`olp-...`, unique), `provider_ref` (Cashfree `cf_order_id`), `provider_payment_id` (the paying `cf_payment_id`, unique), `order_ids[]`, `table_id`, `amount`, `status` (`created, pending, paid, failed, dropped, expired, needs_refund`), `failure_code`, `idempotency_key` (unique per organization), `payer_phone_last4`, `started_by`, `payment_group`, `payment_reference_masked`, `recorded_payment_ids[]`, `refunded_minor`, a trimmed `last_event` (no names, phone numbers or UPI ids), and times. Table `online_payment_refunds` for refunds.
- Functions: `pos_start_online_payment(p jsonb)`, `pos_online_payment_status(p jsonb)`, `online_payment_attach(p jsonb)` (created to pending once Cashfree opened the order), `online_payment_apply(p jsonb)` (the single writer for what Cashfree says: webhook or poll), `online_payment_refund_start(p jsonb)`, `online_payment_refund_update(p jsonb)`. The first two take `organization_id` and `actor_user_id` and re-check that the actor is an active member with an allowed role. Errors are `PAY_BAD_REQUEST, PAY_FORBIDDEN, PAY_NOT_FOUND, PAY_ORDER_CLOSED, PAY_AMOUNT_EXCEEDS_DUE, PAY_BELOW_MINIMUM, PAY_IDEMPOTENCY_MISMATCH, PAY_WRONG_STATE, PAY_REFUND_EXCEEDS_PAID`.
- **Booking a success** (`online_payment_apply`, event `success`): the payment amount must equal the attempt amount (else nothing is booked and the webhook log says `amount_mismatch`); it is spread over the attempt's orders in order, oldest first, never beyond each order's due; one `payments` row per order with `method 'online'`, `gateway 'cashfree'`, `gateway_reference` and `reference` = `cf_payment_id`, `idempotency_key 'cashfree:<cf_payment_id>'`, `created_by` = the staff member who started it; one `payment_ledger` capture per row; the order becomes `awaiting_payment` (part paid) or `paid` through the normal status gate with an `order_events` row. A repeat of the same `cf_payment_id` does nothing; a second different payment on an already paid attempt is logged `duplicate_payment` and not booked (Cashfree refunds those itself).
- Webhook log: the existing `payment_webhook_events` (0238) is reused, now with `online_payment_id` and `organization_id` filled; an exact redelivery is logged `duplicate`, a differently worded event for the same `cf_payment_id` books nothing new.

### 8.7 Server pieces

`server/pos-payments.ts` replaces the placeholder. It uses the one Cashfree client (`server/cashfree.ts`, through `server/payment-provider.ts`) and the one webhook verifier (`verifyCashfreeWebhook`); `handleCashfreeWebhook` routes order ids starting `olp-` to `handlePosPaymentEvent` and refund ids starting `olpr_` to `handlePosRefundEvent`. `sweepPosOnlinePayments` (called from the dispatch sweep) re-reads attempts still open after 2 minutes, because a laptop cannot receive webhooks and a webhook can be lost. Money that arrives for a bill that is already settled is refunded automatically (`auto-over-<cf_payment_id>` key); if that refund cannot be made at once the attempt stays `needs_refund` for operations. No keys are logged or stored.

### 8.8 Not done (deliberately)

- **Live Cashfree sandbox round trip** (see status above): needs working test keys.
- `link_url` (a payment link or QR for "pay from your own phone"): needs `POST /pg/links` or Cashfree enabling server-to-server order pay; not built. The hosted checkout (`payment_session_id`) is what works today.
- Smallest payment is Rs 1.00 (Cashfree's minimum). If a bill has less than Rs 1 left, the staff takes it as cash.
- After a refund of a guest payment, the POS order stays `paid` and the `payments` row stays (the table is append-only and has no reversal row type); the refund is recorded in `online_payment_refunds`, the ledger (`refund`, out) and an order event. A "reopen the bill" rule is a founder decision.
- The staff POS payment screen's "Online" button and the guest storefront's use of this are Flutter work (not touched here). A guest (table-session token) caller does not exist yet; today the staff session of the phone handed to the table authorises everything, exactly like `pos_record_payment`.
- Fixtures from `scripts/pos-payments-checks.ts` leave append-only `online_payments` rows under the test organization `zz-pos-pay-checks` in the local development database (its orders are removed by `database/purge_test_orders.sh`).
