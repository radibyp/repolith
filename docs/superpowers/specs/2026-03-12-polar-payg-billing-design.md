# Polar-Only PAYG Billing Design

Date: 2026-03-12
Status: Approved for planning

## Summary

Repolith will replace the current dual-gateway subscription billing system with a single-product, Polar-only PAYG credit system.

Users will buy credits by entering a dollar amount. Polar will collect payment. Repolith will grant credits only from the pre-tax base amount the user entered. AI usage will continue to be accounted in USD with sub-cent precision, and credits will remain a UI abstraction where `1 credit = $0.01`.

The new design removes:

- Stripe
- subscriptions
- pricing tiers
- credit packs
- Polar usage meters
- billing gateway selection logic

The new design keeps:

- welcome credits
- monthly spending limits
- USD-denominated internal accounting
- Polar as the only payment provider

## Goals

- Use one Polar product for all purchases.
- Let the app determine the purchase amount.
- Grant credits from the user-entered pre-tax base amount only.
- Keep financial accounting in USD with precise decimals.
- Make every paid Polar order idempotent through a dedicated purchase-grant table.
- Keep `credit_ledger` as the append-only financial history.
- Handle refunds without pushing balances negative automatically.
- Preserve welcome credits and monthly spending-limit safety caps.

## Non-Goals

- Supporting Stripe in any form
- Supporting subscriptions, recurring billing, or tier entitlements
- Supporting bundles, packs, or multiple credit products
- Using Polar meters or usage-based postpaid billing
- Exposing Polar customer portal flows in the billing UI

## Current State

The repo currently mixes three billing models:

- Stripe metered billing
- Polar checkout via Better Auth
- local credits layered on top of subscription checks

This creates conflicting behavior across:

- [`apps/web/src/lib/auth.ts`](../../../apps/web/src/lib/auth.ts)
- [`apps/web/src/lib/auth-client.ts`](../../../apps/web/src/lib/auth-client.ts)
- [`apps/web/src/lib/billing/usage-limit.ts`](../../../apps/web/src/lib/billing/usage-limit.ts)
- [`apps/web/src/lib/billing/token-usage.ts`](../../../apps/web/src/lib/billing/token-usage.ts)
- [`apps/web/src/lib/billing/spending-limit.ts`](../../../apps/web/src/lib/billing/spending-limit.ts)
- [`apps/web/src/components/settings/tabs/billing-tab.tsx`](../../../apps/web/src/components/settings/tabs/billing-tab.tsx)
- [`apps/web/prisma/schema.prisma`](../../../apps/web/prisma/schema.prisma)

The installed `@polar-sh/better-auth` version does not expose Polar’s ad hoc checkout pricing fields for arbitrary purchase amounts. Because the new billing model requires app-determined purchase amounts, Polar payments must be implemented directly with `@polar-sh/sdk` rather than through the Better Auth billing plugin.

## Core Decisions

### 1. Auth and billing are decoupled

`better-auth` remains the authentication/session system. Billing is implemented through application routes and services, not Better Auth billing plugins.

### 2. Credits are display-only

Internal accounting remains in USD decimal values. Credits are derived for display and input feedback only.

- `1 credit = $0.01`
- `100 credits = $1.00`

### 3. Usage keeps sub-cent precision

AI deductions are stored with precise decimal USD values. Per-request costs are never rounded up to whole cents.

Example:

- balance: `500.00` credits
- request cost: `$0.0023`
- new balance display: `499.77` credits

### 4. Credit grants are based on pre-tax base amount

Credits are granted from the user-entered purchase amount stored in checkout metadata, not from the final charged total.

Example:

- entered amount: `$5.00`
- tax: `$0.50`
- total charged: `$5.50`
- credits granted: `500`

### 5. Monthly spending limit caps usage, not purchasing

The monthly spending limit stops AI usage once the user consumes that much USD value in the current month, even if they still have prepaid credits left.

Unused credits remain in balance and become usable again when the next monthly cycle begins.

## Architecture

### Units

#### `Polar client`

Purpose:
- Create checkout sessions
- Verify the configured Polar environment from the provided token

Responsibilities:
- Expose a lazily initialized SDK client
- Auto-detect `production` vs `sandbox` without introducing a fourth billing env var

Implementation direction:
- Build `getPolarClient()` around `POLAR_ACCESS_TOKEN`
- Probe the token once against Polar APIs and cache whether the token is valid for production or sandbox
- Reuse the detected environment for subsequent requests

Reason:
- Product requirements say the billing system should require only:
  - `POLAR_ACCESS_TOKEN`
  - `POLAR_WEBHOOK_SECRET`
  - `POLAR_PRODUCT_ID`
- Polar sandbox and production use separate API environments, so environment detection must happen in code if no extra env var is allowed

#### `Checkout service`

Purpose:
- Validate purchase amount
- Create one-off Polar checkout sessions for the single credits product

Responsibilities:
- Normalize and validate purchase input
- Build checkout metadata
- Create a checkout URL through Polar

Interface:
- Used by `POST /api/billing/checkout`

#### `Webhook processor`

Purpose:
- Verify webhook signatures
- Convert Polar payment events into local financial records

Responsibilities:
- Validate the raw request body using Polar webhook verification
- Process `order.paid`
- Process `order.refunded`
- Ignore unrelated webhook types safely

Interface:
- Used by `POST /api/billing/webhooks/polar`

#### `Purchase grant service`

Purpose:
- Be the idempotent source of truth for Polar purchases and refunds

Responsibilities:
- Guarantee each Polar order grants credits at most once
- Track cumulative refund handling
- Record unrecovered refund deficits for admin follow-up

#### `Ledger service`

Purpose:
- Maintain the signed append-only financial journal

Responsibilities:
- Write positive entries for grants
- Write negative entries for usage and refund reversals
- Calculate available balance with expiry-aware FIFO allocation
- Provide transaction history for the billing page

#### `Usage accounting service`

Purpose:
- Record precise AI usage cost
- Enforce monthly safety caps
- Deduct ledger value from user balance

Responsibilities:
- Calculate full usage cost
- Block usage when monthly cap or balance is exhausted
- Write both `usage_log` and negative `credit_ledger` entries atomically

## Database Design

### Remove

#### `User`

Remove:

- `stripeCustomerId`
- `polarCustomerId`

Reason:
- Stripe is removed
- Polar customer mapping can rely on `externalCustomerId = user.id`

#### `Subscription`

Remove the entire model/table.

Reason:
- There is no recurring billing or plan state in the new system

### Keep

#### `SpendingLimit`

Keep the existing table and semantics.

Monthly cap remains a user-configured safety guard.

### Add

#### `PurchaseGrant`

New table acting as the idempotent Polar purchase record.

Required fields:

- `id`
- `userId`
- `polarOrderId` `@unique`
- `polarEventId`
- `polarCheckoutId`
- `paymentAmountUsd`
- `creditsGranted`
- `currency`
- `status`
- `createdAt`
- `refundedAt`
- `metadataJson`

Recommended support fields:

- `refundedBaseAmountUsd`
- `reversedAmountUsd`
- `unrecoveredAmountUsd`
- `lastRefundEventId`
- `updatedAt`

Status values:

- `pending`
- `granted`
- `partially_refunded`
- `refunded`
- `refund_deficit`
- `failed`

Design notes:

- `polarOrderId` is the main idempotency key
- `polarEventId` is sourced from the signed webhook header `webhook-id`
- `creditsGranted` is the display-equivalent amount derived from `paymentAmountUsd * 100`

### Change

#### `CreditLedger`

`credit_ledger` becomes the append-only signed journal for all balance-affecting changes.

Current behavior:
- Mostly grant-oriented rows
- Balance is derived from grants minus aggregated usage

New behavior:
- Every balance change gets its own ledger entry

Recommended fields:

- `id`
- `userId`
- `amount` decimal, signed
- `entryType`
- `description`
- `purchaseGrantId?`
- `usageLogId?`
- `metadataJson?`
- `expiresAt?`
- `createdAt`

Recommended `entryType` values:

- `welcome_credit`
- `purchase_grant`
- `usage`
- `refund_reversal`
- `manual_adjustment`

Constraints:

- `usageLogId` unique when present
- `purchaseGrantId` indexed
- `userId + createdAt` indexed
- `userId + entryType` indexed

Interpretation:

- positive amount: balance increase
- negative amount: balance decrease

Balance calculation rule:

- replay ledger entries in `createdAt` order
- treat positive entries as value lots
- allocate negative entries against the oldest available lots first
- if a positive lot has `expiresAt` in the past, any unconsumed remainder is unavailable

Reason:

- welcome credits can expire
- purchase credits do not
- balance must remain correct without reintroducing subscription logic

#### `UsageLog`

Repurpose `usage_logs.costUsd` to mean the full precise cost of the AI request.

Remove:

- `creditUsed`
- `stripeReported`
- `polarReported`

Keep:

- `userId`
- `taskType`
- `costUsd`
- `aiCallLogId`
- `createdAt`

Reason:
- There is no external usage reporting anymore
- Monthly cap must reflect total consumed value, including prepaid-credit usage
- Ledger will hold the actual negative balance movement

## Monetary Model

### Canonical units

- Storage unit: USD decimal
- Display unit: credits

### Conversion

- `credits = usd * 100`
- `usd = credits / 100`

### Precision

Use a high-precision decimal type for all monetary storage, including:

- `purchaseGrant.paymentAmountUsd`
- `purchaseGrant.refundedBaseAmountUsd`
- `purchaseGrant.reversedAmountUsd`
- `purchaseGrant.unrecoveredAmountUsd`
- `creditLedger.amount`
- `usageLog.costUsd`

Recommended precision:

- `Decimal` / `numeric` with enough scale for sub-cent AI costs

The current Prisma schema already uses `Decimal(10, 6)` for AI costs. That precision is sufficient for the target behavior and can be kept or slightly widened if needed for consistency.

### Balance computation

Available balance is derived from the ledger, not from a separate cached balance column.

Algorithm:

1. Load ledger rows in chronological order.
2. Treat positive rows as grant lots.
3. Apply each negative row against the oldest remaining positive lots first.
4. After allocation, exclude any unconsumed positive remainder whose `expiresAt` is in the past.
5. Sum the remaining unexpired lot values.

This preserves current welcome-credit expiry behavior while still allowing the ledger to be the canonical financial history.

## Checkout Flow

### User flow

1. User opens Billing page.
2. User enters a USD amount to purchase.
3. UI previews equivalent credits.
4. App creates a Polar checkout session.
5. User completes payment in Polar.
6. Polar sends webhook.
7. App creates or updates a `purchase_grant`.
8. App writes a positive `credit_ledger` entry exactly once.
9. Updated balance appears in Billing history and balance summary.

### Checkout request

Route:

- `POST /api/billing/checkout`

Request body:

- `amountUsd` as user-entered decimal string

Validation:

- must parse to finite USD amount
- must be positive
- must satisfy Polar’s minimum charge rules
- normalize to integer `baseAmountCents`

### Polar checkout creation

Use the single configured product ID:

- `POLAR_PRODUCT_ID`

Create checkout with:

- `products: [POLAR_PRODUCT_ID]`
- `externalCustomerId: user.id`
- `successUrl: /settings?tab=billing&checkout_id={CHECKOUT_ID}`
- `allowDiscountCodes: false`
- `metadata` containing app-owned source-of-truth fields
- ad hoc fixed pricing for the chosen amount

Recommended payload shape:

```ts
await polar.checkouts.create({
	products: [process.env.POLAR_PRODUCT_ID!],
	externalCustomerId: user.id,
	successUrl: `${appUrl}/settings?tab=billing&checkout_id={CHECKOUT_ID}`,
	allowDiscountCodes: false,
	metadata: {
		userId: user.id,
		schemaVersion: 1,
		baseAmountCents,
		paymentAmountUsd: baseAmountCents / 100,
		creditsGranted: baseAmountCents,
		currency: "usd",
	},
	prices: {
		[process.env.POLAR_PRODUCT_ID!]: [
			{
				amountType: "fixed",
				priceCurrency: "usd",
				priceAmount: baseAmountCents,
			},
		],
	},
});
```

Reason for ad hoc fixed pricing:

- The app determines the amount
- There are no packs or tiers
- The same product can be reused for all purchases
- The amount charged matches the entered base amount before tax

## Webhook Design

### Route

- `POST /api/billing/webhooks/polar`

### Verification

Read the raw request body and verify using Polar’s webhook verifier.

Signed headers expected by the SDK:

- `webhook-id`
- `webhook-timestamp`
- `webhook-signature`

The app will store `webhook-id` as `polarEventId`.

### Supported events

Process:

- `order.paid`
- `order.refunded`

Ignore safely:

- all subscription events
- all meter events
- all unrelated product/customer events

### `order.paid` processing

Source data:

- `event.data.id` -> Polar order ID
- `event.data.checkoutId`
- `event.data.metadata`
- `webhook-id` header

Required metadata keys:

- `userId`
- `baseAmountCents`
- `paymentAmountUsd`
- `creditsGranted`
- `currency`
- `schemaVersion`

Transaction logic:

1. Find or create `purchase_grant` by `polarOrderId`.
2. If the grant is already `granted` or already has an associated ledger entry, return success without writing another grant.
3. Otherwise:
   - insert or update `purchase_grant`
   - insert positive `credit_ledger` row with `entryType = purchase_grant`
   - mark grant status `granted`

Ledger amount:

- `baseAmountCents / 100`

Credits granted:

- exactly `baseAmountCents`

### `order.refunded` processing

Refunds must reverse only the prepaid credit portion tied to the original base amount, not taxes.

Use order payload values:

- `event.data.refundedAmount`
- `event.data.refundedTaxAmount`

Refund target formula:

```text
refunded_base_amount_cents =
	min(original_base_amount_cents,
		max(0, event.data.refundedAmount - event.data.refundedTaxAmount))
```

This is cumulative, not delta-based.

Refund delta formula:

```text
refund_delta_usd =
	(refunded_base_amount_cents / 100) - purchase_grant.reversedAmountUsd
```

If `refund_delta_usd <= 0`, the webhook is a retry or already-accounted cumulative refund and should be a no-op.

### Refund application rules

1. Compute current available balance from the ledger.
2. `recoverable_usd = min(current_available_usd, refund_delta_usd)`
3. `unrecovered_usd = refund_delta_usd - recoverable_usd`
4. If `recoverable_usd > 0`, write a negative `credit_ledger` row with `entryType = refund_reversal`
5. Update `purchase_grant`:
   - increment `reversedAmountUsd` by `recoverable_usd`
   - increment `unrecoveredAmountUsd` by `unrecovered_usd`
   - set `refundedBaseAmountUsd` to cumulative target
   - set `refundedAt`
   - set status:
     - `refunded` if fully reversed and no deficit
     - `partially_refunded` if partial
     - `refund_deficit` if `unrecoveredAmountUsd > 0`

### Negative balance policy

The system must not automatically create negative balances during refunds.

If the user already spent the refunded credits:

- reverse only what is still available
- record the unrecovered amount
- flag the grant for admin handling

## Welcome Credits

Welcome credits remain part of the system.

Implementation:

- keep `grantSignupCredits(userId)`
- move signup triggering to Better Auth `databaseHooks.user.create.after`

Reason:

- Billing plugins are removed, so welcome credits can no longer be attached to billing-provider customer creation
- Better Auth core already supports post-user-create hooks

Welcome credits should continue to be written as positive `credit_ledger` entries with:

- `entryType = welcome_credit`
- existing expiry logic retained

## Usage Accounting

### Limit checks

Usage is allowed only if:

- user is billing-exempt, or
- user has positive balance, and
- user has not reached the current month’s spending limit

### Monthly spending-limit calculation

The monthly cap should use current-month consumed AI value:

```text
month_usage_usd = sum(usage_logs.costUsd where createdAt >= monthStartUtc)
```

Month boundary:

- keep current UTC calendar-month semantics to preserve existing behavior

### Usage write path

Each AI request should:

1. calculate full precise cost
2. check spending limit against current month usage
3. check available balance
4. in one serializable transaction:
   - write `ai_call_log`
   - write `usage_log` with full `costUsd`
   - write negative `credit_ledger` row with the same precise amount

There is no longer any split between “credit-used” and “postpaid overflow”.

If the user lacks sufficient available balance:

- deny the request before the AI call when possible through `checkUsageLimit`

If a final post-call reconciliation is still needed for safety:

- the write transaction must cap the deducted amount to available balance and fail closed rather than overdrawing

## Billing UI

### Billing page contents

The billing page must show:

- current balance
- equivalent credits display
- purchase amount input
- monthly spending-limit controls
- transaction history
- welcome credit visibility if present

### Remove from UI

- plan name
- subscribe button
- gateway switching
- restore subscription
- subscription status
- portal/invoice/subscription management CTA

### Purchase input behavior

User enters dollars.

The page shows:

- normalized USD amount
- derived credits preview

Example:

- input: `$10.00`
- preview: `1000 credits`

### History behavior

History should come from local data only.

Recommended entries shown:

- purchases
- welcome credits
- usage deductions
- refund reversals
- manual adjustments

Remote Polar subscription or portal state should not be shown because it is outside the new billing model.

## API Surface

### Keep

- `GET /api/billing/balance`
- `GET /api/billing/spending-limit`
- `PATCH /api/billing/spending-limit`
- `POST /api/billing/welcome`

### Add

- `POST /api/billing/checkout`
- `POST /api/billing/webhooks/polar`
- `GET /api/billing/history`

### Remove

- `GET /api/billing/gateway`
- any Stripe billing routes
- any subscription list / upgrade / restore billing flows

## Environment Variables

Required billing env vars:

- `POLAR_ACCESS_TOKEN`
- `POLAR_WEBHOOK_SECRET`
- `POLAR_PRODUCT_ID`

No Stripe env vars remain.

No billing gateway selector env vars remain.

## Migration Plan

### Schema migration

1. Create `purchase_grant`.
2. Add new `credit_ledger` columns:
   - `entryType`
   - `purchaseGrantId`
   - `usageLogId`
   - `metadataJson`
3. Remove obsolete `usage_logs` columns:
   - `creditUsed`
   - `stripeReported`
   - `polarReported`
4. Remove `user` gateway customer ID columns.
5. Remove `subscription` table/model.

### Data backfill

Backfill existing data before dropping old billing fields.

#### Usage logs

Historical monthly-cap correctness requires converting current mixed usage semantics into full-consumption semantics.

Backfill rule:

```text
new_usage_logs.costUsd = old.costUsd + old.creditUsed
```

Reason:

- old `costUsd` represented overflow billed beyond credits
- old `creditUsed` represented prepaid credit consumption
- the new system needs total consumed value

#### Ledger usage rows

Backfill one negative `credit_ledger` row for each historical `usage_log` where `creditUsed > 0`.

Backfill amount:

- `-old.creditUsed`

Backfill metadata:

- reference to original usage log ID
- marker that the row is migration-generated

Existing positive grant rows can remain and be reclassified to the new `entryType` format as appropriate.

### Cleanup order

1. Add new schema
2. Backfill data
3. Switch application code to new reads/writes
4. Remove old fields and dead code

## Error Handling

### Checkout

Reject before Polar call when:

- amount is missing
- amount is malformed
- amount is non-positive
- amount is below enforced minimum

### Webhook verification

If signature verification fails:

- return `400` or `403`
- perform no database writes

### Missing metadata

If a paid order arrives without required app metadata:

- do not grant credits
- record a failed purchase-grant row or structured log with the order ID and webhook ID
- return non-2xx so Polar retries while the issue is investigated

### Idempotent retries

If the same order or refund webhook is delivered again:

- return success after no-op processing

### Refund deficits

If refunded credits are already spent:

- record the unrecovered amount
- do not push the user below zero

## Testing Plan

### Unit tests

- amount normalization and validation
- credits conversion helpers
- checkout metadata encoding/decoding
- balance calculation from ledger rows
- monthly cap calculation using full `usage_log.costUsd`
- refund target and delta calculation
- refund deficit handling
- idempotent purchase grant behavior

### Route tests

- `POST /api/billing/checkout` rejects invalid amounts
- `POST /api/billing/checkout` builds the expected Polar checkout payload
- webhook route rejects invalid signatures
- webhook route grants once for repeated `order.paid`
- webhook route applies cumulative refund deltas correctly

### Regression tests

- welcome credits still grant once
- billing page still loads with spending-limit controls
- `checkUsageLimit` blocks on zero balance
- `checkUsageLimit` blocks when monthly cap is reached even with remaining credits
- sub-cent usage deductions reduce balance precisely

### Repo verification

Before implementation is considered done:

- `bun build`
- `bun typecheck`
- `bun test`

## Polar Dashboard Configuration Guide

### 1. Create the single product

In Polar Dashboard:

1. Open the correct Polar organization for the target environment.
2. Go to Products.
3. Create a new product.
4. Name it `Repolith Credits`.
5. Set it as a one-time purchase product.
6. Do not create multiple plans or tiers.
7. Use this product as the only checkout product in the app.

Notes:

- The app will decide the amount at checkout time.
- The product represents “buy account balance”, not a fixed bundle.

### 2. Whether any meters are needed

No meters are needed.

Reason:

- Repolith is not using Polar’s usage-based billing model
- AI usage is accounted locally in `usage_log` and `credit_ledger`
- Polar is only used to collect payments

### 3. Webhook setup

Create one webhook endpoint per environment.

Endpoint path:

- `/api/billing/webhooks/polar`

Store the generated secret in:

- `POLAR_WEBHOOK_SECRET`

The route must receive the raw JSON body unchanged so signature verification succeeds.

### 4. Required webhook events

Subscribe to:

- `order.paid`
- `order.refunded`

Optional but not required for the app:

- none

### 5. How to retrieve product ID

In Polar Dashboard:

1. Open the `Repolith Credits` product.
2. Copy the product ID shown in the product details.
3. Store it in:
   - `POLAR_PRODUCT_ID`

### 6. How to test a payment

For sandbox testing:

1. Use sandbox credentials and sandbox product/webhook resources.
2. Start the app with sandbox billing credentials.
3. Open Billing page.
4. Enter a base amount such as `$5.00`.
5. Complete the Polar checkout with sandbox payment details.
6. Confirm that:
   - webhook is received
   - one `purchase_grant` row is created
   - one positive `credit_ledger` row is created
   - balance increases by `$5.00`
   - UI shows `500` credits added

Then test retry safety:

1. Replay the same paid webhook from Polar
2. Confirm no duplicate ledger grant is written

Then test refund handling:

1. Refund the order in Polar
2. Confirm the app writes one negative `credit_ledger` reversal up to available balance only
3. Confirm any excess is recorded as unrecovered deficit

### 7. Test mode vs production mode setup

Polar sandbox and production are separate environments.

For each environment you need a separate:

- access token
- product
- webhook endpoint secret

Mapping:

- sandbox deployment -> sandbox `POLAR_ACCESS_TOKEN`, sandbox `POLAR_PRODUCT_ID`, sandbox `POLAR_WEBHOOK_SECRET`
- production deployment -> production `POLAR_ACCESS_TOKEN`, production `POLAR_PRODUCT_ID`, production `POLAR_WEBHOOK_SECRET`

Because product requirements limit billing config to three env vars, the app will detect which Polar API environment to use from the supplied token at runtime and cache that result.

Operational rule:

- never mix sandbox and production values in the same deployment

## Implementation Boundaries

The implementation plan should stay focused on one subsystem:

- replacing billing behavior in the existing app

It should not bundle unrelated refactors outside:

- auth unrelated to signup hooks
- non-billing UI redesigns
- extension packages
- AI model pricing logic

## Expected Deliverables After Implementation

The implementation should be able to report:

- files removed
- files modified
- new billing architecture
- database schema changes
- webhook logic explanation
- required environment variables
- Polar dashboard setup instructions for sandbox and production
