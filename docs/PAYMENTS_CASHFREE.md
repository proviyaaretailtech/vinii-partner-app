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
