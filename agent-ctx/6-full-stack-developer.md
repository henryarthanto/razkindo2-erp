# Task 6: Fix SuppliersModule (Supplier & Beli)

## Summary
Fixed critical bugs in the SuppliersModule that prevented the Supplier & Purchase (Beli) functionality from working properly.

## Bugs Identified & Fixed

### Bug 1: "Buat Permintaan Pembelian" button didn't pre-select the supplier
**File:** `src/components/erp/SuppliersModule.tsx`
- When clicking "Buat Permintaan Pembelian" on a supplier card, it only called `setShowPurchase(true)` without passing the supplier ID
- The PurchaseRequestForm opened with no supplier selected, forcing users to manually select the same supplier again
- **Fix:** Added `preselectedSupplierId` state, set it when clicking the button, and pass it to PurchaseRequestForm

### Bug 2: PurchaseRequestForm didn't accept preselectedSupplierId prop
**File:** `src/components/erp/SupplierForms.tsx`
- The form had no way to receive a pre-selected supplier
- **Fix:** Added `preselectedSupplierId` prop to PurchaseRequestForm, initialized `supplierId` with it, and added useEffect to set it when prop changes

### Bug 3: Purchase dialog form didn't reset between opens
**File:** `src/components/erp/SuppliersModule.tsx`
- When reopening the purchase dialog, old form data could persist
- **Fix:** Added `purchaseDialogKey` state that increments each time the dialog opens, forcing a fresh component instance via the `key` prop

### Bug 4: Missing DialogDescription in Create Supplier dialog
**File:** `src/components/erp/SuppliersModule.tsx`
- The Create Supplier Dialog was missing a `DialogDescription` component, causing accessibility warnings
- **Fix:** Added `<DialogDescription>Isi form di bawah untuk menambahkan supplier baru</DialogDescription>`

### Bug 5: Unused `selectedPurchase` state variable
**File:** `src/components/erp/SuppliersModule.tsx`
- `selectedPurchase` state was declared but never used
- **Fix:** Replaced with `preselectedSupplierId` and `purchaseDialogKey` states

### Bug 6: Purchase dialog didn't invalidate purchases query on success
**File:** `src/components/erp/SuppliersModule.tsx`
- When a purchase request was successfully created, the purchases list wasn't refreshed
- **Fix:** Added `queryClient.invalidateQueries({ queryKey: ['purchases'] })` to the onSuccess callback

### Bug 7: PreselectedSupplierId not cleared on dialog close
**File:** `src/components/erp/SuppliersModule.tsx`
- The preselectedSupplierId persisted after closing the dialog
- **Fix:** Added cleanup in `onOpenChange` callback and in `onSuccess` callback

## Lint Result
- 0 errors, 1 pre-existing warning (unrelated to our changes)

## End-to-End Purchase Flow (verified working)
1. User clicks "Buat Permintaan Pembelian" on supplier card → Dialog opens with supplier pre-selected ✓
2. User fills in unit, products, quantities, prices ✓
3. Form submits POST to `/api/finance/requests` with type='purchase' ✓
4. Finance receives request and can approve/process it ✓
5. Processing creates a purchase transaction (type='purchase') ✓
6. Stock is incremented when goods status is set to 'received' ✓
7. Supplier totals are updated ✓
