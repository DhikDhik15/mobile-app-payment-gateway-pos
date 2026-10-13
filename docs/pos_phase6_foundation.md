# Phase 6 — POS Foundation

## A. POS Capability Audit

| Capability     | Status  | Existing API                          | Action                     |
| -------------- | ------- | ------------------------------------- | -------------------------- |
| Authentication | EXISTS  | `/api/v1/auth/*`                      | reuse                      |
| Payment        | EXISTS  | `/api/v1/dashboard/payments*`, `/api/v1/payments` | reuse                 |
| Transactions   | EXISTS  | `/api/v1/dashboard/payments`          | reuse                      |
| Products       | MISSING | none                                  | backend POS phase required |
| Categories     | MISSING | none                                  | backend POS phase required |
| Cart           | MISSING (client foundation added only) | none | deferred domain only |
| Orders         | MISSING | none                                  | backend POS phase required |
| Checkout       | PARTIAL | payment API exists                    | integrate later            |
| Inventory      | MISSING | none                                  | future phase               |
| Receipt        | MISSING | none                                  | future phase               |
| Reports        | PARTIAL | `/api/v1/dashboard/overview`          | reused for today's sales   |

Notes:

- Merchant identity comes from the JWT; the backend scopes all dashboard
  data by the authenticated merchant's `merchant_id`. Flutter never sends a
  merchant ID.
- "Today's Sales" on the POS home is derived from
  `GET /api/v1/dashboard/overview?from=<today>&to=<tomorrow>`
  (`revenue.amount`, `revenue.currency`, payment status counts) — a real
  backend aggregate, not fabricated data.
- "Recent Transactions" reuses `recent_payments` from the same overview
  endpoint and the existing transaction detail flow.

## B. Target checkout flow (future, not implemented)

```text
Cart ↓ Checkout ↓ Create Order ↓ Create Payment ↓ Payment Pending
     ↓ Customer pays ↓ Webhook ↓ Transaction PAID ↓ Receipt
```

The future POS checkout must call the existing payment domain
(`PaymentRepository`); simulation endpoints (`simulate success/failure`)
remain for development/testing only.

## C. Backend gaps (proposed, NOT implemented)

These endpoints do not exist and were intentionally **not** created:

- `POST/GET/PATCH/DELETE /api/v1/products*`
- `POST/GET/PATCH/DELETE /api/v1/categories*`
- Cart/Order/Inventory/Receipt/Report APIs

Proposed future schema: `categories`, `products`, `orders`, `order_items`,
`inventory_movements` — all merchant-scoped, derived from JWT like the
existing `transactions` table.

## D. Flutter changes in Phase 6

- POS home dashboard (`HomePage`): today's sales (real), New Sale shortcut,
  recent transactions (real), feature navigation, developer connection card.
- Feature navigation: Products (placeholder shell, no fake data),
  Transactions (existing), Payments (existing), Settings (real account info).
- New `cart` feature: client-side domain foundation (`Cart`, `CartItem`,
  `CartCubit`) with unit tests. No fake API.
- New `DashboardOverview` data/domain plumbing reusing the shared
  `DioApiClient`.

No backend changes were made. No migrations were touched. No new HTTP
client, router, or state-management framework was introduced.
