# Development Mock Order Refund Design

## Problem

Orders paid through the development-only mock payment endpoint are stored with
the real payment type (`weixin` or `alipay`). The admin refund flow therefore
calls the real payment provider. The failing order has no provider transaction
number, and the local environment has no WeChat merchant configuration, so the
refund fails with `微信申请退款失败`.

## Scope

- Support refunds for development mock WeChat and Alipay order payments.
- Keep real WeChat, Alipay, and balance refund behavior unchanged.
- Repair the currently failing local mock order.
- Add focused unit and end-to-end regression coverage.
- Do not change the admin user interface or production payment configuration.

## Design

### Mock Payment Marker

When the development mock payment service marks an order as paid, it also sets
`out_trade_no` to a deterministic marker with the prefix `devmock`. The value
uses the database order ID and stays within the existing 32-character column.

The marker is written only by the mock payment service, which is already
restricted to the `dev` Spring profile and the
`crmeb.payment.dev-mock-pay.enabled` feature flag.

### Refund Routing

The order refund service treats an order as a mock payment only when all of the
following conditions are true:

1. The active Spring profile is `dev`.
2. `crmeb.payment.dev-mock-pay.enabled` is true in the admin service.
3. The order's `out_trade_no` starts with the mock marker prefix.

For a matching mock order, the service skips the WeChat or Alipay refund API.
It immediately records the order as refunded, stores the refund amount, and
submits the existing refund post-processing task. It does not credit the user's
balance because the original mock payment represented an external payment.

All non-matching orders continue through the existing provider-specific refund
flow. Production profiles cannot enter the mock branch even if data is
incorrectly marked.

### Existing Local Order

The currently failing order
`order68555179277398143945396` is a confirmed mock WeChat payment and has a
blank `out_trade_no`. After the code is deployed locally, its `out_trade_no`
will be updated to the same mock marker format before retrying the refund.

## Error Handling

- Existing checks for unpaid, processing, already-refunded, zero-value, and
  excessive refunds remain unchanged.
- Failure to persist the refund or enqueue post-processing remains a business
  error.
- Provider exceptions remain provider-specific failures for real payments.
- Duplicate refund attempts remain rejected by the existing refund status
  checks.

## Verification

- Unit test: mock payment writes the marker for WeChat and Alipay orders.
- Unit test: a marked mock order in enabled `dev` mode skips the provider,
  completes immediately, and enqueues post-processing.
- Unit test: an unmarked WeChat order still calls the provider and enters the
  processing state.
- Unit test: the mock marker does not bypass providers outside `dev`.
- End-to-end test: create, mock-pay, and refund a WeChat order through the
  admin API; verify success and the final refund state.
- End-to-end test: repeat for Alipay and verify duplicate refund rejection.
- Regression: run the affected backend test modules and the focused payment
  end-to-end spec.

