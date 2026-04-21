# 🐛 Bug Report & Perbaikan — Razkindo ERP
**Tanggal audit:** 21 April 2026  
**Stack:** Next.js 14 (App Router) · TypeScript · Supabase REST + Prisma RPC · PostgreSQL

---

## Ringkasan Eksekutif

| # | Tingkat | Lokasi | Masalah |
|---|---------|--------|---------|
| 1 | 🔴 KRITIS | `courier/deliver/route.ts` | Parameter RPC salah: `p_amount` → harus `p_delta` |
| 2 | 🔴 KRITIS | `courier/handover/route.ts` | Signature RPC `process_courier_handover` tidak cocok |
| 3 | 🔴 KRITIS | `products/[id]/stock/route.ts` | `increment_unit_stock` dipanggil dengan param yang salah |
| 4 | 🔴 KRITIS | `finance/requests/[id]/route.ts` | `increment_stock_with_hpp` dipanggil dengan `p_cost_per_unit` (harus `p_new_hpp`) |
| 5 | 🟠 TINGGI | `products/route.ts` (POST) | Insert produk pakai camelCase (`subUnit`, `conversionRate`) — Supabase butuh snake_case |
| 6 | 🟠 TINGGI | `pwa/[code]/route.ts` | Kolom `cashback_type` & `cashback_value` tidak ada di tabel `customers` |
| 7 | 🟠 TINGGI | `supabase-helpers.ts` | `toCamelCase(null)` mengembalikan `{}` bukan `null` |
| 8 | 🟡 SEDANG | `transactions/route.ts` | `txTimer.stop()` dipanggil dua kali (di blok biasa + `finally`) |
| 9 | 🟡 SEDANG | `transactions/route.ts` | Select Supabase menggunakan `subUnit` (harus `sub_unit`) |
| 10 | 🟡 SEDANG | `require-auth.ts` | Fungsi `requireAuth` tidak di-export (dead code) |
| 11 | 🟡 SEDANG | `products/route.ts` (POST) | Field `purchasePrice` tidak diset saat insert produk baru |
| 12 | 🟡 SEDANG | `validators.ts` | `authSchemas.resetPassword` & `forgotPassword` tidak sesuai implementasi route |
| 13 | 🟢 RENDAH | `finance/requests/[id]/route.ts` | Fungsi lokal `generateInvoiceNo` membayangi yang di `supabase-helpers.ts` |
| 14 | 🟢 RENDAH | `register/route.ts` | Validasi Zod non-ERP dilakukan manual, tidak pakai `validateBody` |

---

## Detail Bug & Langkah Perbaikan

---

### 🔴 BUG 1 — `courier/deliver/route.ts`: Parameter RPC `p_amount` Salah (Harus `p_delta`)

**File:** `src/app/api/courier/deliver/route.ts`

**Dampak:** Saldo kas kurir tidak pernah berhasil dikreditkan. Semua 3 retry selalu gagal karena `p_delta` bernilai `undefined`, akibatnya `newBalance = NaN`. Kurir tidak bisa melakukan handover.

**Kode bermasalah:**
```ts
// ❌ SALAH
const { data: newBalance, error: ccError } = await db.rpc('atomic_add_courier_cash', {
  p_courier_id: courierId,
  p_unit_id: cashUnitId,
  p_amount: amount,   // ← param salah, handler tidak mengenali ini
});
```

**Handler RPC di `supabase.ts`:**
```ts
async atomic_add_courier_cash(params) {
  const { p_courier_id, p_unit_id, p_delta } = params; // ← butuh p_delta
```

**Perbaikan:**
```ts
// ✅ BENAR
const { data: newBalance, error: ccError } = await db.rpc('atomic_add_courier_cash', {
  p_courier_id: courierId,
  p_unit_id: cashUnitId,
  p_delta: amount,   // ← ganti p_amount menjadi p_delta
});
```

---

### 🔴 BUG 2 — `courier/handover/route.ts`: Signature RPC `process_courier_handover` Tidak Cocok

**File:** `src/app/api/courier/handover/route.ts`

**Dampak:** Endpoint POST `/api/courier/handover` selalu gagal atau menghasilkan data salah. Fitur handover kas kurir ke brankas tidak berfungsi sama sekali.

**Kode bermasalah (route memanggil dengan param ini):**
```ts
// ❌ SALAH — param yang dikirim route
await db.rpc('process_courier_handover', {
  p_courier_id: courierId,
  p_unit_id: unitId,
  p_amount: amount,
  p_processed_by_id: authUserId,
  p_notes: notes || null,
});
```

**Handler RPC di `supabase.ts` mengharapkan param berbeda:**
```ts
async process_courier_handover(params) {
  // ← hanya menerima p_handover_id, p_status, p_processed_by_id
  const { p_handover_id, p_status, p_processed_by_id } = params;
  // p_courier_id, p_unit_id, p_amount, p_notes semuanya undefined!
```

**Perbaikan — update handler RPC di `src/lib/supabase.ts`:**
```ts
async process_courier_handover(params) {
  const { p_courier_id, p_unit_id, p_amount, p_processed_by_id, p_notes } = params;
  try {
    // 1. Cari/buat courier_cash record
    const courierCash = await prisma.courierCash.findUnique({
      where: { courierId_unitId: { courierId: p_courier_id, unitId: p_unit_id } },
    });
    if (!courierCash) {
      return { data: null, error: { message: 'Courier cash tidak ditemukan', code: 'PGRST116' } };
    }
    if ((courierCash.balance || 0) < p_amount) {
      return { data: null, error: { message: 'Saldo tidak cukup', code: 'PGRST116' } };
    }

    // 2. Kurangi saldo kurir
    const updatedCash = await prisma.courierCash.update({
      where: { id: courierCash.id },
      data: {
        balance: { decrement: p_amount },
        totalHandover: { increment: p_amount },
      },
    });

    // 3. Cari atau buat brankas aktif untuk unit ini
    let cashBox = await prisma.cashBox.findFirst({
      where: { unitId: p_unit_id, isActive: true },
    });
    if (!cashBox) {
      cashBox = await prisma.cashBox.create({
        data: { name: 'Brankas Kurir', unitId: p_unit_id, balance: 0 },
      });
    }
    await prisma.cashBox.update({
      where: { id: cashBox.id },
      data: { balance: { increment: p_amount } },
    });

    // 4. Buat finance_request
    const financeRequest = await prisma.financeRequest.create({
      data: {
        type: 'courier_deposit',
        requestById: p_courier_id,
        unitId: p_unit_id,
        amount: p_amount,
        description: p_notes || 'Setor kas kurir ke brankas',
        courierId: p_courier_id,
        status: 'pending',
      },
    });

    // 5. Buat courier_handover
    const handover = await prisma.courierHandover.create({
      data: {
        courierCashId: courierCash.id,
        amount: p_amount,
        notes: p_notes,
        status: 'pending',
        financeRequestId: financeRequest.id,
      },
    });

    return {
      data: {
        handover_id: handover.id,
        finance_request_id: financeRequest.id,
        cash_box_id: cashBox.id,
        new_balance: updatedCash.balance,
        cash_box_balance: cashBox.balance + p_amount,
      },
      error: null,
    };
  } catch (error: any) {
    return { data: null, error: { message: error.message, code: 'PGRST116' } };
  }
},
```

---

### 🔴 BUG 3 — `products/[id]/stock/route.ts`: `increment_unit_stock` Dipanggil dengan Param Salah

**File:** `src/app/api/products/[id]/stock/route.ts`

**Dampak:** Penambahan stok produk per-unit selalu gagal karena handler RPC mengharapkan `p_unit_product_id` bukan `p_unit_id` + `p_product_id`.

**Kode bermasalah:**
```ts
// ❌ SALAH
const { data: newStock } = await db.rpc('increment_unit_stock', {
  p_unit_id: unitId,      // ← handler tidak mengenali ini
  p_product_id: id,       // ← handler tidak mengenali ini
  p_qty: quantityInSubUnits
});
```

**Handler RPC di `supabase.ts`:**
```ts
async increment_unit_stock(params) {
  const { p_unit_product_id, p_qty } = params; // ← butuh unit_product_id
```

**Perbaikan — cari `unit_product_id` terlebih dahulu:**
```ts
// ✅ BENAR
// Cari unitProduct record terlebih dahulu
const { data: unitProductRecord } = await db
  .from('unit_products')
  .select('id')
  .eq('unit_id', unitId)
  .eq('product_id', id)
  .maybeSingle();

if (!unitProductRecord) {
  // Buat record baru jika belum ada
  await db.from('unit_products').insert({
    unit_id: unitId,
    product_id: id,
    stock: quantityInSubUnits
  });
} else {
  const { data: newStock } = await db.rpc('increment_unit_stock', {
    p_unit_product_id: unitProductRecord.id,  // ← pakai unit_product_id
    p_qty: quantityInSubUnits
  });
}
// Selalu recalc global stock setelah perubahan unit stock
await db.rpc('recalc_global_stock', { p_product_id: id });
```

---

### 🔴 BUG 4 — `finance/requests/[id]/route.ts`: `increment_stock_with_hpp` Param Salah (`p_cost_per_unit` → `p_new_hpp`)

**File:** `src/app/api/finance/requests/[id]/route.ts` (fungsi `updateGoodsStatus`)

**Dampak:** Saat barang pembelian diterima (`goods_status = received`), HPP rata-rata produk tidak diupdate. Semua produk akan memakai HPP lama atau 0.

**Kode bermasalah:**
```ts
// ❌ SALAH
const { error: rpcError } = await db.rpc('increment_stock_with_hpp', {
  p_product_id: item.productId,
  p_qty: stockQty,
  p_cost_per_unit: purchaseHpp  // ← nama param salah
});
```

**Handler RPC di `supabase.ts`:**
```ts
async increment_stock_with_hpp(params) {
  const { p_product_id, p_qty, p_new_hpp } = params; // ← butuh p_new_hpp
```

**Perbaikan:**
```ts
// ✅ BENAR
const { error: rpcError } = await db.rpc('increment_stock_with_hpp', {
  p_product_id: item.productId,
  p_qty: stockQty,
  p_new_hpp: purchaseHpp  // ← ganti ke p_new_hpp
});
```

---

### 🟠 BUG 5 — `products/route.ts` (POST): Insert Produk Pakai camelCase (Harus snake_case)

**File:** `src/app/api/products/route.ts`

**Dampak:** Field `subUnit` dan `conversionRate` tidak tersimpan ke database. Kolom `sub_unit` dan `conversion_rate` selalu bernilai NULL/default.

**Kode bermasalah:**
```ts
// ❌ SALAH — Supabase REST butuh snake_case
await db.from('products').insert({
  ...
  subUnit: data.subUnit || null,            // ← salah
  conversionRate: data.conversionRate || 1, // ← salah
  global_stock: data.globalStock || 0,      // ← benar
  avg_hpp: data.avgHpp || 0,               // ← benar
  ...
})
```

**Perbaikan — konsisten gunakan snake_case di semua field:**
```ts
// ✅ BENAR
await db.from('products').insert({
  id: productId,
  name: data.name,
  sku: data.sku,
  description: data.description,
  category: data.category,
  unit: data.unit,
  sub_unit: data.subUnit || null,              // ← snake_case
  conversion_rate: data.conversionRate || 1,   // ← snake_case
  global_stock: data.globalStock || 0,
  avg_hpp: data.avgHpp || 0,
  selling_price: data.sellingPrice || 0,
  purchase_price: data.purchasePrice || 0,     // ← tambahkan ini (BUG 11)
  sell_price_per_sub_unit: data.sellPricePerSubUnit || 0,
  min_stock: data.minStock || 0,
  stock_type: stockType,
  track_stock: data.trackStock !== undefined ? data.trackStock : true,
  image_url: data.imageUrl || null
})
```

---

### 🟠 BUG 6 — `pwa/[code]/route.ts`: Kolom Tidak Ada di Tabel `customers`

**File:** `src/app/api/pwa/[code]/route.ts`

**Dampak:** `cashbackType` dan `cashbackValue` selalu `null` pada response PWA pelanggan. Pelanggan tidak bisa melihat info cashback mereka.

**Kode bermasalah:**
```ts
// ❌ SALAH — kolom ini tidak ada di tabel customers
.select('id, name, phone, address, code, cashback_balance, cashback_type, cashback_value, unit_id, status')
```

**Skema `Customer` di Prisma tidak memiliki field `cashbackType`/`cashbackValue`.** Cashback config ada di tabel `CashbackConfig` yang terpisah.

**Perbaikan — ambil config cashback dari tabel yang benar:**
```ts
// ✅ BENAR — hapus kolom yang tidak ada, ambil dari cashback_config
const { data: customer, error } = await db
  .from('customers')
  .select('id, name, phone, address, code, cashback_balance, unit_id, status')
  .eq('code', code.trim().toUpperCase())
  .eq('status', 'active')
  .single();

if (error || !customer) { /* ... handle error ... */ }

// Ambil cashback config aktif
const { data: cashbackConfig } = await db
  .from('cashback_config')
  .select('type, value, max_cashback, min_order, referral_bonus_type, referral_bonus_value')
  .eq('is_active', true)
  .limit(1)
  .maybeSingle();

// Kembalikan dengan data yang benar
return NextResponse.json({
  customer: {
    id: camel.id,
    name: camel.name,
    phone: camel.phone,
    address: camel.address,
    code: camel.code,
    cashbackBalance: camel.cashbackBalance || 0,
    cashbackType: cashbackConfig?.type || 'percentage',
    cashbackValue: cashbackConfig?.value || 0,
    unitId: camel.unitId,
    referralCount: referralCount || 0,
  },
});
```

---

### 🟠 BUG 7 — `supabase-helpers.ts`: `toCamelCase(null)` Mengembalikan `{}` Bukan `null`

**File:** `src/lib/supabase-helpers.ts`

**Dampak:** Di banyak tempat kode seperti `toCamelCase(transaction.created_by)` akan mengembalikan `{}` alih-alih `null` ketika relasi kosong. Ini menyebabkan UI menampilkan objek kosong bukan null, kondisi `if (!user)` tidak terdeteksi dengan benar.

**Kode bermasalah:**
```ts
// ❌ BERMASALAH
export function toCamelCase<T = Record<string, any>>(row: Record<string, any> | null): T {
  if (!row) return {} as T;  // ← mengembalikan {} bukan null
```

**Perbaikan:**
```ts
// ✅ BENAR — kembalikan null jika input null
export function toCamelCase<T = Record<string, any>>(
  row: Record<string, any> | null
): T | null {
  if (!row) return null;  // ← null-safe
  const result: Record<string, any> = {};
  for (const [key, value] of Object.entries(row)) {
    const camelKey = snakeToCamel(key);
    if (value !== null && typeof value === 'object' && !Array.isArray(value) && !(value instanceof Date)) {
      result[camelKey] = toCamelCase(value);
    } else if (Array.isArray(value)) {
      result[camelKey] = value.map(item =>
        item !== null && typeof item === 'object' ? toCamelCase(item) : item
      );
    } else {
      result[camelKey] = value;
    }
  }
  return result as T;
}
```

> **⚠️ Catatan setelah perubahan ini:** Semua tempat yang sebelumnya melakukan `const x = toCamelCase(something); if (!x)` perlu dicek ulang — sebelumnya selalu lolos karena `{}` adalah truthy.

---

### 🟡 BUG 8 — `transactions/route.ts`: `txTimer.stop()` Dipanggil Dua Kali

**File:** `src/app/api/transactions/route.ts` (fungsi `POST`)

**Dampak:** Metric performa `transaction.create_total` tidak akurat — timer di-stop dua kali pada jalur sukses.

**Kode bermasalah:**
```ts
// ❌ BERMASALAH
txTimer.stop();  // ← pertama kali (di dalam blok try)
perfMonitor.incrementCounter('transactions.create_success');
return NextResponse.json({ transaction }, { headers });

} finally {
  txTimer.stop();  // ← kedua kali (always runs)
  for (const release of releaseLocks) {
    try { release(); } catch {}
  }
}
```

**Perbaikan — hapus `txTimer.stop()` dari dalam blok try, biarkan hanya di `finally`:**
```ts
// ✅ BENAR
// Hapus txTimer.stop() dari dalam blok try sebelum return
perfMonitor.incrementCounter('transactions.create_success');
return NextResponse.json({ transaction }, { headers });

} finally {
  txTimer.stop();  // ← hanya di sini
  for (const release of releaseLocks) {
    try { release(); } catch {}
  }
}
```

---

### 🟡 BUG 9 — `transactions/route.ts` & `[id]/route.ts`: Select Supabase Menggunakan `subUnit` (Harus `sub_unit`)

**File:** `src/app/api/transactions/route.ts` dan `src/app/api/transactions/[id]/route.ts`

**Dampak:** Field `subUnit` di nested select `product:products(unit, subUnit)` tidak akan dikenali oleh Supabase PostgREST. Data unit konversi produk tidak tersedia di response item transaksi.

**Kode bermasalah:**
```ts
// ❌ SALAH — camelCase di select string Supabase
items:transaction_items(*, product:products(unit, subUnit))
```

**Perbaikan:**
```ts
// ✅ BENAR — snake_case untuk kolom Supabase
items:transaction_items(*, product:products(unit, sub_unit, conversion_rate))
```

> Lakukan perubahan ini di semua lokasi dimana string select ini digunakan (ada minimal 4 tempat).

---

### 🟡 BUG 10 — `require-auth.ts`: Fungsi `requireAuth` Tidak Di-export (Dead Code)

**File:** `src/lib/require-auth.ts`

**Dampak:** Fungsi `requireAuth` didefinisikan di scope module tapi tidak di-export. Tidak dapat digunakan dari luar. Jika ada route yang mencoba mengimportnya, akan error.

**Kode bermasalah:**
```ts
// ❌ TIDAK DI-EXPORT — tidak bisa digunakan dari luar
async function requireAuth(request: NextRequest): Promise<string | null> {
  return verifyAuthUser(request.headers.get('authorization'));
}
```

**Perbaikan — tambahkan `export`:**
```ts
// ✅ BENAR
export async function requireAuth(request: NextRequest): Promise<string | null> {
  return verifyAuthUser(request.headers.get('authorization'));
}
```

---

### 🟡 BUG 11 — `products/route.ts` (POST): Field `purchasePrice` Tidak Diset Saat Insert

**File:** `src/app/api/products/route.ts`

**Dampak:** Field `purchase_price` (harga beli terakhir) selalu bernilai 0 saat produk baru dibuat, bahkan jika user mengisi nilai. Ini juga berdampak pada kalkulasi HPP fallback.

**Perbaikan — tambahkan `purchase_price` dalam insert (gabung dengan fix BUG 5):**
```ts
// ✅ BENAR — sudah termasuk dalam perbaikan BUG 5
purchase_price: data.purchasePrice || 0,
```

---

### 🟡 BUG 12 — `validators.ts`: Schema Auth Tidak Sesuai Implementasi Route

**File:** `src/lib/validators.ts`

**Dampak:** `authSchemas.resetPassword` mendefinisikan field `token` tapi route `reset-password` menggunakan `phone` + `code`. `authSchemas.forgotPassword` mendefinisikan `email` tapi route menggunakan `phone`. Kedua route mendefinisikan schema lokal sendiri — menyebabkan inkonsistensi.

**Perbaikan — update validators.ts:**
```ts
// ✅ BENAR — sesuaikan dengan implementasi aktual route
export const authSchemas = {
  // ... login & register tidak berubah ...

  /** POST /api/auth/forgot-password */
  forgotPassword: z.object({
    phone: z.string().min(1, 'Nomor telepon diperlukan'),  // ← ganti email → phone
  }),

  /** POST /api/auth/reset-password */
  resetPassword: z.object({
    phone: z.string().min(1, 'Nomor telepon diperlukan'),  // ← ganti token → phone+code
    code: z.string().min(1, 'Kode pemulihan diperlukan'),
    newPassword: z.string().min(6, 'Password minimal 6 karakter'),
  }),
} as const;
```

Setelah itu, hapus definisi schema lokal di kedua route tersebut dan gunakan `authSchemas` dari validators.

---

### 🟢 BUG 13 — `finance/requests/[id]/route.ts`: Fungsi `generateInvoiceNo` Lokal Membayangi Helper

**File:** `src/app/api/finance/requests/[id]/route.ts`

**Dampak:** Fungsi lokal `generateInvoiceNo` di file ini berbeda implementasinya dari `generateInvoiceNo` di `supabase-helpers.ts`, menyebabkan format invoice tidak konsisten antar modul.

**Perbaikan — hapus fungsi lokal dan gunakan import dari helpers:**
```ts
// ✅ BENAR
import { ..., generateInvoiceNo } from '@/lib/supabase-helpers';

// Hapus fungsi lokal ini:
// async function generateInvoiceNo(type: string, prefix: string): Promise<string> { ... }
```

> Perhatikan bahwa signature berbeda: helper pakai `(type, count)` sedangkan lokal pakai `(type, prefix)`. Perlu adjust pemanggil di `createPurchaseTransaction` dan `createExpenseTransaction`.

---

### 🟢 BUG 14 — `register/route.ts`: Validasi Non-ERP Dilakukan Manual Tanpa `validateBody`

**File:** `src/app/api/auth/register/route.ts`

**Dampak:** Registrasi non-ERP employee (`customRoleId` branch) tidak memvalidasi input dengan Zod. Field seperti `name` hanya dicek secara manual. Rentan terhadap data tidak valid yang masuk ke database.

**Perbaikan — tambahkan schema Zod untuk non-ERP dan gunakan `validateBody`:**
```ts
// ✅ BENAR — tambahkan ke validators.ts
registerNonErp: z.object({
  name: z.string().min(1, 'Nama wajib diisi'),
  phone: z.string().optional(),
  customRoleId: z.string().min(1, 'Custom role diperlukan'),
  unitId: z.string().optional(),
  unitIds: z.array(z.string()).optional(),
}),

// Di register/route.ts, ganti validasi manual dengan:
const nonErpValidation = validateBody(authSchemas.registerNonErp, body);
if (!nonErpValidation.success) {
  return NextResponse.json({ error: nonErpValidation.error }, { status: 400 });
}
```

---

## Daftar Semua API Endpoints

| Method | Endpoint | Auth | Role |
|--------|----------|------|------|
| POST | `/api/auth/login` | ❌ | — |
| POST | `/api/auth/register` | ❌ | — |
| POST | `/api/auth/logout` | ✅ | any |
| GET | `/api/auth/me` | ✅ | any |
| POST | `/api/auth/change-password` | ✅ | any |
| POST | `/api/auth/forgot-password` | ❌ | — |
| POST | `/api/auth/reset-password` | ❌ | — |
| GET | `/api/auth/check-superadmin` | ❌ | — |
| GET/POST | `/api/transactions` | ✅ | varies |
| GET/PATCH | `/api/transactions/[id]` | ✅ | varies |
| POST | `/api/transactions/[id]/approve` | ✅ | super_admin, keuangan |
| POST | `/api/transactions/[id]/cancel` | ✅ | super_admin, keuangan |
| POST | `/api/transactions/mark-lunas` | ✅ | super_admin, keuangan |
| GET/POST | `/api/payments` | ✅ | any |
| GET/POST/PUT | `/api/payment/[invoiceNo]` | mixed | — |
| POST | `/api/payment/[invoiceNo]/proof` | ❌ | — |
| POST | `/api/payment/cleanup` | ✅ | super_admin |
| GET/POST | `/api/products` | ✅ | varies |
| GET/PUT/DELETE | `/api/products/[id]` | ✅ | varies |
| POST | `/api/products/[id]/stock` | ✅ | super_admin, keuangan, gudang |
| GET | `/api/products/stock-movements` | ✅ | any |
| GET | `/api/products/asset-value` | ✅ | super_admin, keuangan |
| GET/POST | `/api/customers` | ✅ | any |
| GET/PUT/DELETE | `/api/customers/[id]` | ✅ | any |
| POST | `/api/customers/[id]/follow-up` | ✅ | any |
| POST | `/api/customers/[id]/lost` | ✅ | any |
| GET | `/api/customers/lost` | ✅ | any |
| POST | `/api/customers/recycle` | ✅ | any |
| GET/POST | `/api/suppliers` | ✅ | any |
| GET/PUT/DELETE | `/api/suppliers/[id]` | ✅ | any |
| GET/POST | `/api/users` | ✅ | super_admin |
| GET/PUT/DELETE | `/api/users/[id]` | ✅ | super_admin |
| POST | `/api/users/[id]/approve` | ✅ | super_admin |
| GET | `/api/users/activity` | ✅ | super_admin |
| GET/POST | `/api/finance/requests` | ✅ | super_admin, keuangan |
| GET/PUT | `/api/finance/requests/[id]` | ✅ | super_admin, keuangan |
| GET/POST | `/api/finance/bank-accounts` | ✅ | super_admin, keuangan |
| GET/PUT/DELETE | `/api/finance/bank-accounts/[id]` | ✅ | super_admin, keuangan |
| POST | `/api/finance/bank-accounts/[id]/deposit` | ✅ | super_admin, keuangan |
| GET/POST | `/api/finance/cash-boxes` | ✅ | super_admin, keuangan |
| GET/PUT/DELETE | `/api/finance/cash-boxes/[id]` | ✅ | super_admin, keuangan |
| POST | `/api/finance/cash-boxes/[id]/deposit` | ✅ | super_admin, keuangan |
| GET | `/api/finance/cash-flow` | ✅ | super_admin, keuangan |
| GET/POST | `/api/finance/debts` | ✅ | super_admin, keuangan |
| GET/PUT/DELETE | `/api/finance/debts/[id]` | ✅ | super_admin, keuangan |
| POST | `/api/finance/debts/[id]/payment` | ✅ | super_admin, keuangan |
| GET | `/api/finance/pools` | ✅ | super_admin, keuangan |
| GET/POST | `/api/finance/receivables` | ✅ | super_admin, keuangan |
| GET/PUT | `/api/finance/receivables/[id]` | ✅ | super_admin, keuangan |
| POST | `/api/finance/receivables/[id]/follow-up` | ✅ | any |
| POST | `/api/finance/receivables/sync` | ✅ | super_admin, keuangan |
| GET/POST | `/api/finance/transfers` | ✅ | super_admin, keuangan |
| GET/DELETE | `/api/finance/transfers/[id]` | ✅ | super_admin, keuangan |
| PATCH | `/api/courier/deliver` | ✅ | kurir, super_admin |
| GET/POST | `/api/courier/handover` | ✅ | kurir, super_admin, keuangan |
| GET | `/api/courier/dashboard` | ✅ | kurir, super_admin |
| GET | `/api/courier/cash-summary` | ✅ | super_admin, keuangan |
| GET/POST | `/api/salaries` | ✅ | super_admin, keuangan |
| GET/PUT/DELETE | `/api/salaries/[id]` | ✅ | super_admin, keuangan |
| POST | `/api/salaries/[id]/pay` | ✅ | super_admin, keuangan |
| GET/POST | `/api/sales/targets` | ✅ | super_admin |
| GET/PUT/DELETE | `/api/sales/targets/[id]` | ✅ | super_admin |
| GET | `/api/sales/dashboard` | ✅ | super_admin, sales |
| GET/POST | `/api/sales-tasks` | ✅ | super_admin |
| GET/PUT/DELETE | `/api/sales-tasks/[id]` | ✅ | super_admin, sales |
| POST | `/api/sales-tasks/[id]/report` | ✅ | sales |
| GET | `/api/dashboard` | ✅ | any |
| GET | `/api/dashboard/metrics` | ✅ | super_admin, keuangan |
| GET | `/api/reports` | ✅ | super_admin, keuangan |
| GET | `/api/pwa/[code]` | ❌ | — |
| GET | `/api/pwa/[code]/orders` | ❌ | — |
| GET | `/api/pwa/[code]/products` | ❌ | — |
| GET | `/api/pwa/[code]/invoice/[invoiceNo]` | ❌ | — |
| POST | `/api/pwa/[code]/upload-proof` | ❌ | — |
| GET | `/api/pwa/[code]/cashback` | ❌ | — |
| POST | `/api/pwa/[code]/cashback/withdraw` | ❌ | — |
| GET | `/api/pwa/[code]/referrals` | ❌ | — |
| GET | `/api/pwa/manifest` | ❌ | — |
| GET | `/api/pwa/icon` | ❌ | — |
| GET/PUT | `/api/cashback/config` | ✅ | super_admin |
| GET | `/api/cashback/withdrawals` | ✅ | super_admin, keuangan |
| PUT | `/api/cashback/withdrawals/[id]` | ✅ | super_admin, keuangan |
| GET/POST | `/api/referrals` | ✅ | any |
| GET/PUT | `/api/referrals/[id]` | ✅ | any |
| GET/POST | `/api/units` | ✅ | super_admin |
| GET/PUT/DELETE | `/api/units/[id]` | ✅ | super_admin |
| GET/POST | `/api/custom-roles` | ✅ | super_admin |
| GET/PUT/DELETE | `/api/custom-roles/[id]` | ✅ | super_admin |
| GET/PUT | `/api/settings` | ✅ | super_admin |
| GET/PUT | `/api/settings/[key]` | ✅ | super_admin |
| GET/POST | `/api/push/subscribe` | ✅ | any |
| POST | `/api/push/unsubscribe` | ✅ | any |
| GET | `/api/push/status` | ✅ | any |
| GET/POST | `/api/events` | ✅ | any |
| POST | `/api/events/read` | ✅ | any |
| GET | `/api/logs` | ✅ | super_admin |
| GET/POST | `/api/whatsapp/config` | ✅ | super_admin |
| GET | `/api/whatsapp/groups` | ✅ | super_admin |
| GET/PUT | `/api/whatsapp/message-template` | ✅ | super_admin |
| POST | `/api/whatsapp/send` | ✅ | super_admin |
| GET | `/api/health` | ❌ | — |
| GET | `/api/health/ready` | ❌ | — |
| GET | `/api/system/info` | ✅ | super_admin |
| GET | `/api/system/queue-health` | ✅ | super_admin |
| POST | `/api/system/backup` | ✅ | super_admin |
| POST | `/api/system/restore` | ✅ | super_admin |
| POST | `/api/system/reset` | ✅ | super_admin |
| GET | `/api/system/consistency` | ✅ | super_admin |
| GET | `/api/pwa-orders/pending` | ✅ | super_admin, keuangan |
| GET | `/api/pwa-orders/approved-unpaid` | ✅ | super_admin, keuangan |
| POST | `/api/pwa-orders/approve` | ✅ | super_admin, keuangan |
| GET | `/api/superadmin/monitoring` | ✅ | super_admin |
| POST | `/api/superadmin/monitoring/reassign` | ✅ | super_admin |
| GET | `/api/storage` | ✅ | super_admin |
| GET | `/api/storage/supabase-quota` | ✅ | super_admin |
| GET | `/api/storage/table-data` | ✅ | super_admin |

---

## Prioritas Urutan Perbaikan

```
FASE 1 — Segera (Kritis, fitur tidak berfungsi):
  1. BUG 1  → courier/deliver: ganti p_amount → p_delta
  2. BUG 2  → courier/handover: rewrite handler RPC process_courier_handover
  3. BUG 3  → products/[id]/stock: cari unit_product_id sebelum RPC
  4. BUG 4  → finance/requests/[id]: ganti p_cost_per_unit → p_new_hpp

FASE 2 — Segera (Data tidak tersimpan benar):
  5. BUG 5  → products POST: semua field ke snake_case + tambah purchase_price
  6. BUG 6  → pwa/[code]: ambil cashback dari cashback_config
  7. BUG 7  → supabase-helpers: toCamelCase return null bukan {}

FASE 3 — Menengah (Inkonsistensi & minor issues):
  8. BUG 8  → transactions POST: hapus txTimer.stop() ganda
  9. BUG 9  → transactions: ganti subUnit → sub_unit di select string
 10. BUG 10 → require-auth: export requireAuth
 11. BUG 11 → products POST: tambah purchasePrice (sudah di FASE 2)
 12. BUG 12 → validators: sinkronkan schema reset/forgot password

FASE 4 — Opsional (Code quality):
 13. BUG 13 → finance/requests: hapus fungsi generateInvoiceNo lokal
 14. BUG 14 → register: pakai validateBody untuk non-ERP
```

---

*Laporan ini dibuat berdasarkan analisis statis penuh atas 270 file TypeScript, 130+ route handler, dan schema Prisma/Supabase pada tanggal 21 April 2026.*
