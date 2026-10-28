# Boomerang — e-commerce returns

A small returns platform built with Ruby on Rails, PostgreSQL and React + TypeScript.
A customer starts a return, the system checks the retailer's policy, gets a shipping label from a
carrier, follows tracking updates and the retailer refunds once the parcel reaches the warehouse.

The interesting part is what happens when the carrier misbehaves, because real carriers do.

## What it does

**Customer portal** (`/`)
- Find an order with order number + email.
- See which items can be returned and, when not, why (final sale, already returned, window closed,
  country not supported, not delivered yet).
- Choose items, quantities, reasons and a carrier; follow the return from label to refund.

**Retailer dashboard** (`/retailer`)
- All returns with status, tracking and refund amount, filterable by status.
- Return reasons at a glance.
- Refund returns that reached the warehouse; retry labels that failed.

## Failure handling

| Situation | What happens |
|---|---|
| Customer double-clicks "Confirm" or the request is retried | `Idempotency-Key` header: the same key returns the original return, never a second one. A unique index catches the race between two identical requests. |
| Two different requests try to return the last unit | The order row is locked while the policy is checked, so only one wins. |
| Carrier API times out | `CreateLabelJob` retries with backoff (5 attempts), then marks the return `label_failed` with the reason. The retailer can retry it. |
| Carrier created the label but the response was lost | The label request carries our return id as reference, so the retry gets the **same** label back instead of a second shipment. |
| Carrier sends the same webhook twice | Events are stored by `event_id` with a unique index; the duplicate is acknowledged without side effects. |
| Webhooks arrive out of order | Status only moves forward. A late "in transit" after "delivered" is recorded in the timeline but ignored. |
| Forged webhook | HMAC-SHA256 signature check with a constant-time compare. |

The carrier is simulated (`app/services/carrier.rb`) and fails on purpose:
`FAKE_CARRIER_FAILURE_RATE` (default `0.4`) controls how often it times out.

## Stack

- **Backend:** Ruby 4, Rails 8 (API mode), PostgreSQL, Active Job
- **Frontend:** React 19, TypeScript, Vite — built into `public/` and served by Rails
- **Tests:** RSpec — policy rules, idempotency, label retries, lost responses, webhook duplicates and ordering, API auth
- **CI:** GitHub Actions (tests + frontend type check and build)

Active Job runs on the in-process adapter here to keep setup to one command. In production this
would be Sidekiq on Redis or Solid Queue; the job code doesn't change.

## Run it

```bash
bundle install
bin/rails db:setup        # creates the database and demo data
bin/rails server          # http://localhost:3000
```

Frontend development with hot reload (proxies the API to Rails on :3000):

```bash
cd frontend && npm install && npm run dev
```

Demo orders: `NW-1001 / maria@example.com` (returnable), `NW-1002 / tom@example.com` (window closed),
`NW-1003 / lena@example.com` (country not supported), `NW-1004 / ivan@example.com` (not delivered).

## Tests

```bash
bundle exec rspec
```

## API

| Method | Path | |
|---|---|---|
| POST | `/api/orders/lookup` | Order + per-item eligibility |
| POST | `/api/returns` | Create a return (`Idempotency-Key` header required) |
| GET | `/api/returns/:id` | Return status, items and tracking timeline |
| GET | `/api/retailer/returns` | Retailer's returns (`Authorization: Bearer <token>`) |
| GET | `/api/retailer/stats` | Counts by status and reason |
| POST | `/api/retailer/returns/:id/refund` | Refund a return received at the warehouse |
| POST | `/api/retailer/returns/:id/retry_label` | Re-queue a failed label |
| POST | `/webhooks/carrier` | Signed tracking updates from the carrier |
