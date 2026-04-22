# 🛠️ Panduan Perbaikan Lengkap — Razkindo ERP
**Tanggal:** 22 April 2026  
**Stack:** Next.js 14 · TypeScript · Supabase REST + Prisma RPC · PostgreSQL · Socket.io  
**Target:** AML S9xx TV Box (STB) dengan CasaOS + Docker

---

## 📊 Status Audit Bug (22 April 2026)

| # | Tingkat | Lokasi | Masalah | Status |
|---|---------|--------|---------|--------|
| 1 | 🔴 KRITIS | `courier/deliver/route.ts` | `p_amount` → `p_delta` | ✅ Sudah diperbaiki |
| 2 | 🔴 KRITIS | `courier/handover/route.ts` | Signature RPC `process_courier_handover` | ✅ Sudah diperbaiki |
| 3 | 🔴 KRITIS | `products/[id]/stock/route.ts` | `increment_unit_stock` param salah | ✅ Sudah diperbaiki |
| 4 | 🔴 KRITIS | `finance/requests/[id]/route.ts` | `p_cost_per_unit` → `p_new_hpp` | ✅ Sudah diperbaiki |
| 5 | 🟠 TINGGI | `products/route.ts` (POST) | camelCase di Supabase insert | ✅ Sudah diperbaiki |
| 6 | 🟠 TINGGI | `pwa/[code]/route.ts` | Kolom `cashback_type/value` tidak ada | ✅ Sudah diperbaiki |
| 7 | 🟠 TINGGI | `supabase-helpers.ts` | `toCamelCase(null)` → `{}` bukan `null` | ✅ Sudah diperbaiki |
| 8 | 🟡 SEDANG | `transactions/route.ts` | `txTimer.stop()` dipanggil dua kali | ⚠️ **Masih ada (path idempoten)** |
| 9 | 🟡 SEDANG | `transactions/route.ts` | `subUnit` → `sub_unit` di select | ✅ Sudah diperbaiki |
| 10 | 🟡 SEDANG | `require-auth.ts` | `requireAuth` tidak di-export | ✅ Sudah diperbaiki |
| 11 | 🟡 SEDANG | `products/route.ts` (POST) | `purchasePrice` tidak diset | ✅ Sudah diperbaiki |
| 12 | 🟡 SEDANG | `validators.ts` | Schema `resetPassword/forgotPassword` | ✅ Sudah diperbaiki |
| 13 | 🟢 RENDAH | `finance/requests/[id]/route.ts` | Fungsi `generateInvoiceNo` lokal | ✅ Workaround (renamed) |
| 14 | 🟢 RENDAH | `register/route.ts` | Validasi non-ERP manual | ✅ Sudah diperbaiki |

---

## 🔧 Perbaikan yang Masih Diperlukan

### ⚠️ BUG 8 — `txTimer.stop()` Dipanggil Dua Kali pada Path Idempoten

**File:** `src/app/api/transactions/route.ts` — sekitar baris 251

**Masalah:** Pada jalur idempoten (transaksi duplikat ditemukan), `txTimer.stop()` dipanggil di dalam blok `if (prevTx)`, kemudian dipanggil lagi di blok `finally`. Ini menyebabkan metrik performa tidak akurat.

**Kode bermasalah (sekitar baris 250):**
```typescript
// ❌ SALAH — stop pertama di dalam blok idempoten
if (prevTx) {
  txTimer.stop();                                    // ← baris ~251
  perfMonitor.incrementCounter('transactions.create_success');
  return NextResponse.json({
    transaction: toCamelCase(prevTx),
    idempotent: true
  });
}

// ...jauh di bawah...
} finally {
  txTimer.stop();  // ← baris ~984 — ini juga dipanggil!
}
```

**Perbaikan — hapus `txTimer.stop()` dari blok idempoten:**
```typescript
// ✅ BENAR — biarkan finally yang selalu stop
if (prevTx) {
  // HAPUS: txTimer.stop();   ← hapus baris ini
  perfMonitor.incrementCounter('transactions.create_success');
  return NextResponse.json({
    transaction: toCamelCase(prevTx),
    idempotent: true
  });
}

// ... finally tetap ada:
} finally {
  txTimer.stop();  // ← satu-satunya tempat stop
  for (const release of releaseLocks) {
    try { release(); } catch {}
  }
}
```

**Langkah:**
```bash
# Cari baris exaknya
grep -n "txTimer.stop" src/app/api/transactions/route.ts

# Edit file (gunakan angka baris yang ditemukan di atas)
nano src/app/api/transactions/route.ts
# Hapus baris txTimer.stop() pertama (dalam blok idempoten)
# Simpan dengan Ctrl+O, keluar Ctrl+X
```

---

## 🚀 Peningkatan Logic & Fungsi

### 1. Perbaikan WebSocket / Real-time untuk STB

**File:** `src/hooks/use-websocket.ts`

**Masalah saat ini:**
- `reconnectionAttempts: 10` — terlalu sedikit untuk STB yang sering restart jaringan
- `timeout: 20000` — terlalu cepat untuk koneksi WiFi STB yang lambat
- Tidak ada heartbeat ping kustom untuk mendeteksi koneksi mati

**Perbaikan di `createSocket()`:**
```typescript
// src/hooks/use-websocket.ts
function createSocket(url: string, path: string): Socket {
  const socket = io(url, {
    path,
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: Infinity,        // ✅ Tidak ada batas — STB harus selalu reconnect
    reconnectionDelay: 1000,              // ✅ Mulai dari 1 detik
    reconnectionDelayMax: 30000,          // ✅ Maksimal 30 detik (bukan 10)
    timeout: 30000,                       // ✅ 30 detik untuk STB WiFi lambat
    autoConnect: true,
    // Tambahkan ping untuk deteksi koneksi mati:
    pingInterval: 25000,                  // ✅ Ping tiap 25 detik
    pingTimeout: 60000,                   // ✅ Timeout ping 60 detik
  });
  // ... sisa kode sama
}
```

**Tambahkan SSE fallback untuk data kritis (opsional, advanced):**

Buat file baru `src/hooks/use-sse-fallback.ts`:
```typescript
'use client';
import { useEffect, useRef } from 'react';
import { useAuthStore } from '@/stores/auth-store';

/**
 * SSE (Server-Sent Events) fallback jika WebSocket tidak tersedia.
 * Lebih ringan dari WebSocket, cocok untuk STB dengan jaringan tidak stabil.
 */
export function useSSEFallback(
  isWsConnected: boolean,
  onEvent: (eventType: string, data: any) => void
) {
  const { token } = useAuthStore();
  const esRef = useRef<EventSource | null>(null);

  useEffect(() => {
    // Hanya gunakan SSE jika WebSocket tidak terhubung setelah 10 detik
    if (isWsConnected) {
      esRef.current?.close();
      esRef.current = null;
      return;
    }

    const timer = setTimeout(() => {
      if (!token || esRef.current) return;
      const es = new EventSource(`/api/events/stream?token=${token}`);
      esRef.current = es;

      es.onmessage = (e) => {
        try {
          const { type, data } = JSON.parse(e.data);
          onEvent(type, data);
        } catch {}
      };

      es.onerror = () => {
        es.close();
        esRef.current = null;
      };
    }, 10_000);

    return () => {
      clearTimeout(timer);
      esRef.current?.close();
      esRef.current = null;
    };
  }, [isWsConnected, token, onEvent]);
}
```

---

### 2. Perbaikan Memory Guard untuk STB

**File:** `src/lib/memory-guard.ts`

STB AML S9xx biasanya hanya memiliki 2-4GB RAM. Tambahkan threshold yang lebih agresif:

```typescript
// src/lib/memory-guard.ts — cari dan update nilai threshold
const MEMORY_THRESHOLD_MB = process.env.NODE_ENV === 'production'
  ? 512   // ✅ Lebih rendah di STB (production)
  : 1024; // development

const CRITICAL_THRESHOLD_MB = process.env.NODE_ENV === 'production'
  ? 384   // ✅ Trigger GC lebih agresif di STB
  : 768;

// Tambahkan interval pembersihan cache yang lebih sering:
const CACHE_CLEANUP_INTERVAL_MS = 
  process.env.NODE_ENV === 'production' ? 60_000 : 300_000; // 1 menit di STB
```

---

### 3. Perbaikan Connection Pool untuk STB

**File:** `src/lib/connection-pool.ts`

STB tidak perlu koneksi pool yang besar. Kurangi untuk hemat memori:

```typescript
// Cari dan update nilai pool size
const MAX_POOL_SIZE = process.env.STB_MODE === 'true' ? 3 : 10;
const MIN_POOL_SIZE = process.env.STB_MODE === 'true' ? 1 : 2;
const IDLE_TIMEOUT_MS = process.env.STB_MODE === 'true' 
  ? 30_000   // ✅ 30 detik — lebih agresif tutup koneksi idle di STB
  : 300_000;
```

Tambahkan ke `.env` di STB:
```bash
STB_MODE=true
```

---

### 4. Perbaikan Circuit Breaker untuk Koneksi Supabase yang Putus

**File:** `src/lib/circuit-breaker.ts`

Tambahkan auto-recovery yang lebih cepat untuk STB (koneksi sering putus-sambung):

```typescript
// Cari class CircuitBreaker atau config-nya, update:
const FAILURE_THRESHOLD = 3;          // Buka circuit setelah 3 kegagalan
const SUCCESS_THRESHOLD = 1;          // ✅ Tutup setelah 1 sukses (bukan default 2)
const TIMEOUT_MS = 10_000;            // ✅ Coba lagi setelah 10 detik (bukan 30)
const HALF_OPEN_MAX_CALLS = 1;        // ✅ Hanya 1 test call saat half-open
```

---

### 5. Optimasi Batch untuk Event Queue

**File:** `mini-services/mini-services/event-queue/index.ts`

Event queue sudah bagus, tapi ada satu peningkatan untuk STB dengan CPU terbatas:

```typescript
// Cari BATCH_SIZE dan TICK_MS, update untuk STB:
const BATCH_SIZE = process.env.STB_MODE === 'true' ? 5 : 10;   // Batch lebih kecil
const TICK_MS = process.env.STB_MODE === 'true' ? 100 : 50;     // Tick lebih lambat

// Kurangi batas koneksi per-IP untuk STB (hemat memori):
const MAX_CONNECTIONS_PER_IP = process.env.STB_MODE === 'true' ? 20 : 50;
```

---

### 6. Perbaikan `use-realtime-sync.ts` — Debounce Adaptif

**File:** `src/hooks/use-realtime-sync.ts`

Saat ini debounce tetap 1 detik untuk semua event. Di STB dengan banyak event bersamaan, ini bisa overload:

```typescript
// Ganti konstanta tetap dengan nilai adaptif:
// Hapus:
// const INVALIDATION_DEBOUNCE_MS = 1000;

// Tambahkan fungsi debounce adaptif:
function getDebounceMs(event: string): number {
  // Event kritis: debounce pendek
  if (['erp:transaction_update', 'erp:stock_update'].includes(event)) return 500;
  // Event dashboard: debounce sedang
  if (['erp:payment_update', 'erp:delivery_update'].includes(event)) return 1000;
  // Event non-kritis: debounce panjang
  return 2000;
}

// Ganti di dalam loop:
// const existing = debounceTimers.current.get(keyStr);
// if (existing) clearTimeout(existing);
// debounceTimers.current.set(keyStr, setTimeout(() => {
//   ...
// }, INVALIDATION_DEBOUNCE_MS));  // ← ganti dengan:

debounceTimers.current.set(keyStr, setTimeout(() => {
  debounceTimers.current.delete(keyStr);
  queryClient.invalidateQueries({ queryKey: key });
}, getDebounceMs(event)));  // ← debounce adaptif
```

---

## 🖥️ Panduan Deployment di STB (Lengkap)

### Prasyarat STB

- AML S9xx atau setara dengan minimal 2GB RAM
- CasaOS terinstall (sudah include Docker)
- Koneksi internet (WiFi atau LAN)
- SSH client (PuTTY di Windows, Terminal di Mac/Linux)

### Langkah 1 — Koneksi ke STB

```bash
# Cari IP STB di router atau gunakan:
# (dari STB langsung) hostname -I

ssh root@IP_STB_ANDA
# atau:
ssh casaos@IP_STB_ANDA
```

### Langkah 2 — Persiapan Environment

```bash
# Buat direktori kerja
mkdir -p /DATA/AppData/razkindo2-erp
cd /DATA/AppData

# Clone project (jika belum ada)
git clone https://github.com/henryarthanto/razkindo2-erp.git
cd razkindo2-erp

# ATAU update jika sudah ada:
git pull origin main
```

### Langkah 3 — Buat File .env untuk STB

```bash
# Buat .env khusus STB
cat > .env << 'EOF'
# ============ DATABASE ============
DATABASE_URL=postgresql://postgres.eglmvtleuonoeomovnwa:Arthanto01091987@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
DIRECT_URL=postgresql://postgres.eglmvtleuonoeomovnwa:Arthanto01091987@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres
SUPABASE_DB_URL=postgresql://postgres:Arthanto01091987@db.eglmvtleuonoeomovnwa.supabase.co:5432/postgres

# ============ SUPABASE REST ============
NEXT_PUBLIC_SUPABASE_URL=https://eglmvtleuonoeomovnwa.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnbG12dGxldW9ub2VvbW92bndhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjM1NjgxNywiZXhwIjoyMDkxOTMyODE3fQ.D839Fhnh1I0032zqHePeWQFwE9J_NxTquC_87UkBtX8
NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnbG12dGxldW9ub2VvbW92bndhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjM1NjgxNywiZXhwIjoyMDkxOTMyODE3fQ.D839Fhnh1I0032zqHePeWQFwE9J_NxTquC_87UkBtX8

# ============ AUTH ============
NEXTAUTH_SECRET=razkindo-erp-secret-key-GANTI-INI-DI-PRODUKSI
NEXTAUTH_URL=http://localhost:3000

# ============ WEBSOCKET ============
WS_SECRET=ganti-dengan-secret-random-minimal-32-karakter
EVENT_QUEUE_URL=http://localhost:3004

# ============ STB OPTIMASI ============
STB_MODE=true
NODE_OPTIONS=--max-old-space-size=512
EOF

echo "✓ File .env dibuat"
```

### Langkah 4 — Terapkan Perbaikan Bug 8 (txTimer Double Stop)

```bash
# Cari nomor baris txTimer.stop() pertama
grep -n "txTimer.stop" src/app/api/transactions/route.ts

# Akan muncul seperti:
# 251:          txTimer.stop();
# 984:      txTimer.stop();

# Edit file — hapus baris di posisi ~251 (dalam blok idempoten)
# Ganti angka 251 dengan angka yang muncul di atas
BARIS=$(grep -n "txTimer.stop" src/app/api/transactions/route.ts | head -1 | cut -d: -f1)

# Verifikasi konteks dulu:
sed -n "$((BARIS-3)),$((BARIS+3))p" src/app/api/transactions/route.ts

# Jika konteksnya adalah blok idempoten (ada "idempotent: true" di sekitarnya):
sed -i "${BARIS}d" src/app/api/transactions/route.ts

echo "✓ Bug 8 diperbaiki — txTimer.stop() ganda dihapus"
```

### Langkah 5 — Terapkan Optimasi WebSocket untuk STB

```bash
# Backup file asli
cp src/hooks/use-websocket.ts src/hooks/use-websocket.ts.bak

# Terapkan perubahan reconnection settings
sed -i 's/reconnectionAttempts: 10/reconnectionAttempts: Infinity/' src/hooks/use-websocket.ts
sed -i 's/reconnectionDelay: 2000/reconnectionDelay: 1000/' src/hooks/use-websocket.ts
sed -i 's/reconnectionDelayMax: 10000/reconnectionDelayMax: 30000/' src/hooks/use-websocket.ts
sed -i 's/timeout: 20000/timeout: 30000/' src/hooks/use-websocket.ts

echo "✓ WebSocket dioptimasi untuk STB"
```

### Langkah 6 — Tambahkan STB_MODE ke Event Queue

```bash
# Edit file mini-services event-queue
nano mini-services/mini-services/event-queue/index.ts

# Tambahkan setelah import statements (baris ~30-ish):
# const IS_STB = process.env.STB_MODE === 'true';
# const BATCH_SIZE = IS_STB ? 5 : 10;
# const TICK_MS = IS_STB ? 100 : 50;
# const MAX_CONNECTIONS_PER_IP = IS_STB ? 20 : 50;

# Lalu cari dan ganti nilai BATCH_SIZE, TICK_MS, MAX_CONNECTIONS_PER_IP
# dengan variabel-variabel di atas
```

### Langkah 7 — Build dan Deploy

```bash
# Bersihkan Docker cache dulu (penting untuk STB dengan storage terbatas)
docker system prune -f

# Cek sisa storage
df -h /DATA
# Pastikan minimal 3GB tersedia sebelum build

# Build dan jalankan
DOCKER_BUILDKIT=1 docker compose up -d --build

# Pantau progress (Ctrl+C untuk berhenti pantau, container tetap jalan)
docker compose logs -f --tail=50
```

### Langkah 8 — Verifikasi Setelah Deploy

```bash
# 1. Cek semua container berjalan
docker compose ps

# Output yang diharapkan:
# NAME                 STATUS          PORTS
# razkindo-erp         Up X minutes    0.0.0.0:3000->3000/tcp
# razkindo-event-queue Up X minutes    0.0.0.0:3004->3004/tcp

# 2. Test API health
curl http://localhost:3000/api/health
# Harus return: {"status":"ok",...}

# 3. Test WebSocket service
curl http://localhost:3004/api/health
# Harus return: {"status":"healthy",...}

# 4. Test endpoint kritis yang sebelumnya buggy:
# (ganti TOKEN dengan token login yang valid)
TOKEN="Bearer eyJ..."

# Test stok produk
curl -H "Authorization: $TOKEN" http://localhost:3000/api/products | jq '.products | length'

# Test dashboard kurir
curl -H "Authorization: $TOKEN" "http://localhost:3000/api/courier/dashboard" | jq '.summary'
```

---

## 🔄 Prosedur Update Rutin

### Update Cepat (Hanya Code, Tanpa Rebuild Docker)

```bash
cd /DATA/AppData/razkindo2-erp

# 1. Ambil perubahan terbaru
git pull origin main

# 2. Rebuild Next.js di dalam container yang sudah ada
docker compose exec erp npm run build

# 3. Restart container
docker compose restart erp

echo "✓ Update selesai tanpa rebuild Docker penuh"
```

### Update Penuh (Dependency Berubah)

```bash
cd /DATA/AppData/razkindo2-erp

git pull origin main

# Bersihkan image lama
docker compose down
docker image prune -f

# Build ulang
DOCKER_BUILDKIT=1 docker compose up -d --build

echo "✓ Update penuh selesai"
```

---

## 🩺 Troubleshooting STB

### Masalah 1: Container Crash karena Out of Memory

```bash
# Cek memory usage
docker stats --no-stream

# Jika razkindo-erp > 400MB, tambahkan limit di docker-compose.yml:
# services:
#   erp:
#     mem_limit: 512m
#     memswap_limit: 512m

# Restart dengan limit baru
docker compose down && docker compose up -d
```

### Masalah 2: WebSocket Tidak Tersambung

```bash
# Cek apakah event-queue berjalan
docker compose ps | grep event-queue

# Cek log event-queue
docker compose logs event-queue --tail=20

# Cek port 3004 terbuka
ss -tlnp | grep 3004
# atau:
netstat -tlnp | grep 3004

# Jika port tidak terbuka, restart:
docker compose restart event-queue
```

### Masalah 3: Database Timeout / Connection Pool Habis

```bash
# Cek log error database
docker compose logs erp 2>&1 | grep -i "timeout\|connection\|pool" | tail -20

# Pastikan DATABASE_URL menggunakan pgbouncer (pooler):
grep DATABASE_URL .env
# Harus ada: pooler.supabase.com:6543 dan pgbouncer=true

# Jika tidak ada, edit .env dan tambahkan ?pgbouncer=true di ujung DATABASE_URL
nano .env
docker compose restart erp
```

### Masalah 4: Build Gagal karena Storage Penuh

```bash
# Cek storage
df -h /DATA

# Bersihkan semua Docker artefak tidak terpakai:
docker system prune -a --volumes -f

# Hapus image lama
docker image ls
docker image rm $(docker image ls -q --filter "dangling=true") 2>/dev/null || true

# Coba build ulang
DOCKER_BUILDKIT=1 docker compose up -d --build
```

### Masalah 5: Transaksi Tidak Real-time (Perlu Refresh Manual)

```bash
# Ini biasanya karena WebSocket terputus tapi tidak reconnect

# 1. Cek log event-queue untuk error
docker compose logs event-queue --tail=30

# 2. Cek env variable
grep -E "WS_SECRET|EVENT_QUEUE_URL" .env

# 3. Jika WS_SECRET tidak ada, tambahkan:
echo "WS_SECRET=$(openssl rand -hex 32)" >> .env
docker compose restart
```

---

## 📋 Checklist Deploy Final

```
PRE-DEPLOY:
  ☐ git pull berhasil (tidak ada conflict)
  ☐ .env lengkap (DATABASE_URL, WS_SECRET, EVENT_QUEUE_URL ada)
  ☐ Storage tersedia > 3GB (cek: df -h /DATA)
  ☐ Bug 8 diperbaiki (txTimer.stop ganda dihapus)

BUILD:
  ☐ docker system prune -f (bersihkan cache)
  ☐ docker compose up -d --build (tidak error)
  ☐ docker compose ps (semua container "Up")

POST-DEPLOY:
  ☐ /api/health → {"status":"ok"}
  ☐ /api/health/ready → 200 OK
  ☐ Event queue health → http://localhost:3004/api/health
  ☐ Login berhasil di browser
  ☐ WebSocket terhubung (lihat console browser, tidak ada error WS)
  ☐ Buat transaksi test → muncul real-time di tab lain

MONITORING (opsional):
  ☐ Pantau memory: docker stats --no-stream
  ☐ Pantau log: docker compose logs -f --tail=30
  ☐ Cek queue health: curl localhost:3004/api/queue/status
```

---

## 🔐 Keamanan (Penting untuk Produksi)

### Ganti Secret Keys

```bash
# Generate JWT secret baru
JWT_SECRET=$(openssl rand -hex 32)
WS_SECRET=$(openssl rand -hex 32)

# Update .env
sed -i "s|NEXTAUTH_SECRET=.*|NEXTAUTH_SECRET=$JWT_SECRET|" .env
sed -i "s|WS_SECRET=.*|WS_SECRET=$WS_SECRET|" .env

docker compose restart erp event-queue
echo "✓ Secret keys diperbarui"
```

### Jangan Expose Port 3004 ke Internet

```bash
# Port 3004 (WebSocket internal) tidak boleh diakses dari luar
# Pastikan firewall menutupnya:
# (jika menggunakan ufw):
ufw deny 3004
ufw allow 3000
ufw enable

echo "✓ Port 3004 diblokir dari luar, port 3000 terbuka"
```

---

## 📈 Monitoring Performa

### Dashboard Real-time via CLI

```bash
# Monitor semua container setiap 2 detik
watch -n 2 'docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"'

# Monitor queue event
watch -n 5 'curl -s http://localhost:3004/api/queue/status | python3 -m json.tool 2>/dev/null || curl -s http://localhost:3004/api/queue/status'

# Cek uptime container
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.RunningFor}}"
```

### Alert Memory Sederhana

```bash
# Buat script monitor (jalankan di cron setiap 5 menit):
cat > /usr/local/bin/check-erp-memory.sh << 'EOF'
#!/bin/bash
MEM=$(docker stats --no-stream --format "{{.MemPerc}}" razkindo-erp 2>/dev/null | tr -d '%')
if [ -n "$MEM" ] && [ "$(echo "$MEM > 80" | bc -l)" = "1" ]; then
  echo "$(date): WARNING - ERP memory usage: ${MEM}%" >> /var/log/erp-memory.log
  # Opsional: restart otomatis jika > 90%
  if [ "$(echo "$MEM > 90" | bc -l)" = "1" ]; then
    docker compose -f /DATA/AppData/razkindo2-erp/docker-compose.yml restart erp
    echo "$(date): AUTO-RESTART triggered at ${MEM}%" >> /var/log/erp-memory.log
  fi
fi
EOF

chmod +x /usr/local/bin/check-erp-memory.sh

# Tambahkan ke cron (cek tiap 5 menit):
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check-erp-memory.sh") | crontab -
echo "✓ Memory monitor aktif"
```

---

## 📝 Ringkasan Perubahan yang Harus Dilakukan Sekarang

**Prioritas TINGGI (wajib sebelum produksi):**
1. ✅ Bug 8: Hapus `txTimer.stop()` duplikat di `transactions/route.ts` baris ~251
2. ✅ Tambahkan `STB_MODE=true` dan `WS_SECRET` ke `.env`
3. ✅ Update reconnection settings WebSocket (`reconnectionAttempts: Infinity`)

**Prioritas SEDANG (disarankan):**
4. Update memory threshold di `memory-guard.ts` (512MB untuk STB)
5. Kurangi connection pool size untuk STB
6. Tambahkan debounce adaptif di `use-realtime-sync.ts`

**Prioritas RENDAH (opsional):**
7. Implementasi SSE fallback jika WebSocket tidak tersedia
8. Setup monitoring memory otomatis dengan cron

---

*Dokumen ini dibuat berdasarkan audit kode tanggal 22 April 2026. Semua 14 bug dari laporan 21 April telah diverifikasi — 13 sudah diperbaiki, 1 masih ada (Bug 8) dan langkah perbaikannya ada di dokumen ini.*
