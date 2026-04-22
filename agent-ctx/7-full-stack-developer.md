# Task 7 - Fix DeliveriesModule (Pengiriman)

## Agent: full-stack-developer

## Summary
Fixed 6 bugs in the DeliveriesModule that were causing "Pengiriman belum bisa" (Delivery not working).

## Bugs Fixed

### Bug 1 (CRITICAL) — Pending deliveries list too restrictive
**File:** `src/components/erp/DeliveriesModule.tsx`
**Problem:** Filter `status === 'approved' && paymentStatus === 'unpaid'` excluded partially-paid and pre-paid transactions that still need delivery.
**Fix:** Changed to `status !== 'cancelled' && !t.deliveredAt`

### Bug 2 (CRITICAL) — Deliver API blocked already-paid transactions
**File:** `src/app/api/courier/deliver/route.ts`
**Problem:** Threw error "Transaksi sudah lunas" when payment_status === 'paid', preventing delivery of pre-paid transactions.
**Fix:** Removed the payment_status === 'paid' check.

### Bug 3 (CRITICAL) — Courier dashboard pending deliveries query too restrictive
**File:** `src/app/api/courier/dashboard/route.ts`
**Problem:** Used `.eq('status', 'approved').eq('payment_status', 'unpaid')`, excluding partially-paid and pre-paid deliveries.
**Fix:** Changed to `.neq('status', 'cancelled').is('delivered_at', null)`

### Bug 4 (MEDIUM) — Missing 'transfer' payment option
**File:** `src/components/erp/CourierDashboard.tsx`
**Problem:** Courier could only select 'cash' or 'piutang'. Added 'transfer' with proper UI (blue theme, amount input).

### Bug 5 (MEDIUM) — Piutang delivery incorrectly created payment record
**File:** `src/components/erp/CourierDashboard.tsx`
**Problem:** Piutang called `deliverMutation.mutate(true)`, potentially sending payment info. Piutang means no payment — should just complete delivery.
**Fix:** Changed to `deliverMutation.mutate(false)` for piutang, updated mutation logic.

### Bug 6 (MEDIUM) — Missing query invalidation
**File:** `src/components/erp/CourierDashboard.tsx`
**Problem:** After delivery, DeliveriesModule data wasn't refreshed.
**Fix:** Added `queryClient.invalidateQueries({ queryKey: ['transactions-deliveries'] })`.

## Verification
- ESLint: 0 errors, 1 unrelated warning
- Dev server: running without compilation errors
