# 🛠️ Panduan Perbaikan Lengkap — Razkindo ERP
**Update:** 22 April 2026  
**Stack:** Next.js 16.2.4 · TypeScript · Supabase REST + Prisma · PostgreSQL · Socket.io  
**Deployment:** Build Mac (darwin-arm64) → Deploy STB (linux-arm64) via standalone  
**Target:** AML S9xx TV Box (Armbian) di `192.168.100.64:3000`

---

## 📊 Status Deployment Saat Ini

| Komponen | Status | Catatan |
|----------|--------|---------|
| Next.js (port 3000) | ⚠️ Crash loop | `TypeError: Cannot read properties of undefined (reading 'map')` |
| Event-Queue (port 3004) | ✅ Berjalan | systemd service aktif |
| Supabase PostgreSQL | ✅ Online | Remote via pooler |
| Prisma Client | ⚠️ Perlu regen | Schema mismatch di STB |
| Static Files | ✅ OK | JS/CSS bisa diakses (HTTP 200) |
| Systemd Services | ✅ Terdaftar | Auto-restart saat reboot |

---

## 🔴 MASALAH AKTIF: Server Crash TypeError

### Gejala
```
▲ Next.js 16.2.4
✓ Ready in 0ms
TypeError: Cannot read properties of undefined (reading 'map')
    at ignore-listed frames
```
Server start, lalu langsung crash saat request pertama masuk.

### Kemungkinan Penyebab
1. **Prisma client schema mismatch** — client di-build di Mac, schema mungkin berbeda di STB
2. **Instrumentation hook** — `instrumentation.ts` menjalankan `ensureRpcFunctions()` yang mungkin crash
3. **API route pertama** — dashboard/health route yang memanggil `.map()` pada data undefined

### Langkah Debug

```bash
# Di STB, stop service dulu
systemctl stop razkindo2-erp

# Coba jalankan dengan instrumentation disabled
cd /DATA/AppData/razkindo2-erp/.next/standalone
NEXT_DISABLE_INSTRUMENTATION=1 node server.js

# Di terminal lain, buat request:
curl -s http://127.0.0.1:3000/api/health
```

Jika jalan tanpa crash → masalah di instrumentation.  
Jika tetap crash → masalah di API route/page.

```bash
# Coba akses halaman login saja (tidak butuh data)
curl -s http://127.0.0.1:3000/ | grep -o '<title>[^<]*</title>'

# Cek API health (endpoint sederhana)
curl -s http://127.0.0.1:3000/api/health
```

### Solusi Permanen
1. **Rebuild dari Mac dengan kode terbaru** (pastikan `git pull` dulu)
2. **Generate Prisma client di STB** setelah transfer
3. **Pastikan .env lengkap** di STB

---

## 📊 Status Audit Bug (22 April 2026)

| # | Tingkat | Lokasi | Masalah | Status |
|---|---------|--------|---------|--------|
| 1 | 🔴 KRITIS | `courier/deliver/route.ts` | `p_amount` → `p_delta` | ✅ Sudah diperbaikki |
| 2 | 🔴 KRITIS | `courier/handover/route.ts` | Signature RPC `process_courier_handover` | ✅ Sudah diperbaikki |
| 3 | 🔴 KRITIS | `products/[id]/stock/route.ts` | `increment_unit_stock` param salah | ✅ Sudah diperbaikki |
| 4 | 🔴 KRITIS | `finance/requests/[id]/route.ts` | `p_cost_per_unit` → `p_new_hpp` | ✅ Sudah diperbaikki |
| 5 | 🟠 TINGGI | `products/route.ts` (POST) | camelCase di Supabase insert | ✅ Sudah diperbaikki |
| 6 | 🟠 TINGGI | `pwa/[code]/route.ts` | Kolom `cashback_type/value` tidak ada | ✅ Sudah diperbaikki |
| 7 | 🟠 TINGGI | `supabase-helpers.ts` | `toCamelCase(null)` → `{}` bukan `null` | ✅ Sudah diperbaikki |
| 8 | 🟡 SEDANG | `transactions/route.ts` | `txTimer.stop()` dipanggil dua kali | ⚠️ Masih ada |
| 9 | 🟡 SEDANG | `transactions/route.ts` | `subUnit` → `sub_unit` di select | ✅ Sudah diperbaikki |
| 10 | 🟡 SEDANG | `require-auth.ts` | `requireAuth` tidak di-export | ✅ Sudah diperbaikki |
| 11 | 🟡 SEDANG | `products/route.ts` (POST) | `purchasePrice` tidak diset | ✅ Sudah diperbaikki |
| 12 | 🟡 SEDANG | `validators.ts` | Schema `resetPassword/forgotPassword` | ✅ Sudah diperbaikki |
| 13 | 🟢 RENDAH | `finance/requests/[id]/route.ts` | Fungsi `generateInvoiceNo` lokal | ✅ Workaround |
| 14 | 🟢 RENDAH | `register/route.ts` | Validasi non-ERP manual | ✅ Sudah diperbaikki |

### Perbaikan WebSocket & Security (Session Ini)

| # | Lokasi | Perbaikan | Status |
|---|--------|-----------|--------|
| 1 | `mini-services/event-queue/index.ts` | Tambah `presence:update` broadcast | ✅ |
| 2 | `mini-services/event-queue/index.ts` | Tambah WS_SECRET auth middleware | ✅ |
| 3 | `mini-services/event-queue/index.ts` | Hapus NEXT_PUBLIC_ fallback, pakai server key saja | ✅ |
| 4 | `src/lib/ws-dispatch.ts` | Hapus hardcoded secret, baca dari env | ✅ |
| 5 | `src/lib/ws-dispatch.ts` | URL configurable via EVENT_QUEUE_URL | ✅ |
| 6 | `src/hooks/use-websocket.ts` | Hapus undocumented internal API access | ✅ |
| 7 | `src/hooks/use-websocket.ts` | Fix React exhaustive-deps lint error | ✅ |
| 8 | `src/components/error-boundary.tsx` | Fix event listener memory leak | ✅ |
| 9 | `src/lib/supabase-rest.ts` | Hapus NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY fallback | ✅ |
| 10 | `src/lib/auth-secret.ts` | Fail in production jika AUTH_SECRET tidak diset | ✅ |
| 11 | `src/app/api/migrate-user-units/route.ts` | Tambah auth protection | ✅ |
| 12 | `src/app/api/ai/chat/route.ts` | Tambah auth ke DELETE method | ✅ |
| 13 | `src/app/api/auth/login/route.ts` | Fix rate limiter memory leak (max 10000 + cleanup) | ✅ |
| 14 | `prisma/schema.prisma` | 7 index baru (transaction fields) | ✅ |
| 15 | `src/app/api/transactions/[id]/cancel/route.ts` | Fix N+1 query, batch RPC calls | ✅ |

---

## 🖥️ Panduan Deployment STB (Standalone Mode)

### Arsitektur Deployment

```
┌─────────────────────────────────────────────────┐
│  Mac (darwin-arm64)                             │
│  /Users/mac/razkindo2-erp/                     │
│  - npm run build → .next/standalone/           │
│  - scp transfer ke STB                         │
└──────────────┬──────────────────────────────────┘
               │ scp/rsync
               ▼
┌─────────────────────────────────────────────────┐
│  STB (linux-arm64) - 192.168.100.64            │
│  /DATA/AppData/razkindo2-erp/                  │
│  ├── .next/standalone/  (Next.js server)       │
│  │   ├── server.js       → port 3000           │
│  │   ├── .next/static/   (CSS/JS/Fonts)        │
│  │   ├── public/         (Icons/Manifest)       │
│  │   └── .env            (Environment vars)     │
│  ├── mini-services/event-queue/                 │
│  │   ├── index.ts        → port 3004           │
│  │   └── node_modules/   (tsx + socket.io)     │
│  └── prisma/                                    │
│      └── schema.prisma   (untuk prisma generate)│
└─────────────────────────────────────────────────┘
```

### Dua Service yang Harus Berjalan

| Service | Port | Fungsi | Start Command |
|---------|------|--------|---------------|
| Next.js | 3000 | Web app + API routes | `node server.js` |
| Event-Queue | 3004 | WebSocket real-time | `npx tsx index.ts` |

---

### Langkah 1: Di Mac — Build

```bash
cd /Users/mac/razkindo2-erp

# Pastikan kode terbaru
git pull

# Build standalone output
npm run build
```

**Prisma binaryTargets** sudah dikonfigurasi di `prisma/schema.prisma`:
```prisma
binaryTargets = ["native", "linux-arm64-openssl-3.0.x"]
```

### Langkah 2: Di Mac — Transfer ke STB

Jalankan **satu per satu** (jangan copy semua sekaligus, jangan copy baris yang dimulai `#`):

```bash
# Transfer standalone server
scp -r /Users/mac/razkindo2-erp/.next/standalone root@192.168.100.64:/DATA/AppData/razkindo2-erp/.next/

# Transfer static files (CSS/JS/Fonts)
scp -r /Users/mac/razkindo2-erp/.next/static root@192.168.100.64:/DATA/AppData/razkindo2-erp/.next/standalone/.next/

# Transfer public folder (icons, manifest, sw.js)
scp -r /Users/mac/razkindo2-erp/public root@192.168.100.64:/DATA/AppData/razkindo2-erp/.next/standalone/

# Transfer .env file
scp /Users/mac/razkindo2-erp/.env root@192.168.100.64:/DATA/AppData/razkindo2-erp/.next/standalone/

# Transfer prisma schema (dibutuhkan untuk prisma generate di STB)
scp -r /Users/mac/razkindo2-erp/prisma root@192.168.100.64:/DATA/AppData/razkindo2-erp/

# Transfer mini-services (event-queue)
scp -r /Users/mac/razkindo2-erp/mini-services root@192.168.100.64:/DATA/AppData/razkindo2-erp/
```

**Alternatif cepat dengan rsync** (jika tersedia):
```bash
PROJECT=/Users/mac/razkindo2-erp
STB=root@192.168.100.64
REMOTE=/DATA/AppData/razkindo2-erp

rsync -avz $PROJECT/.next/standalone/ $STB:$REMOTE/.next/standalone/ && \
rsync -avz $PROJECT/.next/static/ $STB:$REMOTE/.next/standalone/.next/static/ && \
rsync -avz $PROJECT/public/ $STB:$REMOTE/.next/standalone/public/ && \
rsync -avz $PROJECT/mini-services/ $STB:$REMOTE/mini-services/ && \
rsync -avz $PROJECT/prisma/ $STB:$REMOTE/prisma/ && \
scp $PROJECT/.env $STB:$REMOTE/.next/standalone/.env
```

### Langkah 3: Di STB — Setup Environment

```bash
ssh root@192.168.100.64
```

```bash
# Pastikan .env punya variabel yang diperlukan
cd /DATA/AppData/razkindo2-erp/.next/standalone

# Tambahkan variabel baru jika belum ada
grep -q WS_SECRET .env || echo 'WS_SECRET=razkindo-erp-ws-prod-2024' >> .env
grep -q EVENT_QUEUE_URL .env || echo 'EVENT_QUEUE_URL=http://127.0.0.1:3004' >> .env
grep -q AUTH_SECRET .env || echo 'AUTH_SECRET=razkindo-erp-auth-secret-change-in-production' >> .env

# Verifikasi .env
cat .env | head -20
```

### Langkah 4: Di STB — Install Dependencies & Prisma

```bash
# Install event-queue dependencies
cd /DATA/AppData/razkindo2-erp/mini-services/event-queue
npm install
npm install tsx

# Install Prisma di standalone
cd /DATA/AppData/razkindo2-erp/.next/standalone
npm install @prisma/client prisma

# Generate Prisma client untuk linux-arm64
npx prisma generate --schema=../../prisma/schema.prisma
```

### Langkah 5: Di STB — Jalankan Services

**Opsi A: Manual (untuk testing)**
```bash
# Start event-queue
cd /DATA/AppData/razkindo2-erp/mini-services/event-queue
WS_SECRET=razkindo-erp-ws-prod-2024 PORT=3004 npx tsx index.ts > /tmp/event-queue.log 2>&1 &

# Start Next.js
cd /DATA/AppData/razkindo2-erp/.next/standalone
node server.js > /tmp/razkindo2.log 2>&1 &
```

**Opsi B: Systemd (rekomendasi untuk produksi)**
```bash
# Buat service file Next.js
cat > /etc/systemd/system/razkindo2-erp.service << 'EOF'
[Unit]
Description=Razkindo2 ERP Next.js
After=network.target razkindo2-event-queue.service

[Service]
Type=simple
WorkingDirectory=/DATA/AppData/razkindo2-erp/.next/standalone
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
EnvironmentFile=/DATA/AppData/razkindo2-erp/.next/standalone/.env

[Install]
WantedBy=multi-user.target
EOF

# Buat service file Event-Queue
cat > /etc/systemd/system/razkindo2-event-queue.service << 'EOF'
[Unit]
Description=Razkindo2 Event Queue WebSocket
After=network.target

[Service]
Type=simple
WorkingDirectory=/DATA/AppData/razkindo2-erp/mini-services/event-queue
ExecStart=/usr/bin/npx tsx index.ts
Restart=always
RestartSec=5
Environment=WS_SECRET=razkindo-erp-ws-prod-2024
Environment=PORT=3004
Environment=SUPABASE_URL=your-supabase-url
Environment=SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

[Install]
WantedBy=multi-user.target
EOF

# Aktifkan dan jalankan
systemctl daemon-reload
systemctl enable razkindo2-erp razkindo2-event-queue
systemctl start razkindo2-event-queue
systemctl start razkindo2-erp
```

### Langkah 6: Verifikasi

```bash
# Cek status service
systemctl status razkindo2-erp
systemctl status razkindo2-event-queue

# Cek port
ss -tlnp | grep -E '3000|3004'

# Test Next.js
curl -s http://127.0.0.1:3000/api/health

# Test Event-Queue (perlu auth header)
curl -s -H "Authorization: Bearer razkindo-erp-ws-prod-2024" http://127.0.0.1:3004/api/health

# Test static files
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/_next/static/chunks/
```

---

## 🔄 Prosedur Update (Mac → STB)

### Update Cepat (Kode Berubah)

```bash
# === DI MAC ===
cd /Users/mac/razkindo2-erp
git pull
npm run build

# Transfer ulang
scp -r .next/standalone root@192.168.100.64:/DATA/AppData/razkindo2-erp/.next/
scp -r .next/static root@192.168.100.64:/DATA/AppData/razkindo2-erp/.next/standalone/.next/
scp -r public root@192.168.100.64:/DATA/AppData/razkindo2-erp/.next/standalone/
scp .env root@192.168.100.64:/DATA/AppData/razkindo2-erp/.next/standalone/

# === DI STB (atau dari Mac via SSH) ===
ssh root@192.168.100.64 "systemctl restart razkindo2-erp"
```

### Update dengan Perubahan Prisma Schema

```bash
# Selain langkah di atas, tambahkan:
scp -r /Users/mac/razkindo2-erp/prisma root@192.168.100.64:/DATA/AppData/razkindo2-erp/

# Di STB:
ssh root@192.168.100.64
cd /DATA/AppData/razkindo2-erp/.next/standalone
npx prisma generate --schema=../../prisma/schema.prisma
systemctl restart razkindo2-erp
```

### Update dengan Perubahan Event-Queue

```bash
scp -r /Users/mac/razkindo2-erp/mini-services root@192.168.100.64:/DATA/AppData/razkindo2-erp/

# Di STB:
cd /DATA/AppData/razkindo2-erp/mini-services/event-queue
npm install
systemctl restart razkindo2-event-queue
```

---

## 🩺 Troubleshooting

### Masalah 1: Port Sudah Dipakai (EADDRINUSE)

```bash
# Cari proses yang pegang port
ss -tlnp | grep 3000

# Kill proses berdasarkan PID
kill <PID>

# Atau kill semua di port 3000
fuser -k 3000/tcp

# Lalu restart service
systemctl restart razkindo2-erp
```

### Masalah 2: Event-Queue Gagal Start (index.js not found)

**Penyebab:** File bernama `index.ts` (TypeScript), Node.js tidak bisa langsung menjalankannya.

**Solusi:** Gunakan `tsx`:
```bash
cd /DATA/AppData/razkindo2-erp/mini-services/event-queue
npm install tsx
npx tsx index.ts
```

### Masalah 3: Prisma Schema Mismatch

**Gejala:**
```
Unknown field `items:transactionItems(*, product` for include statement on model `Transaction`
```

**Solusi:**
```bash
cd /DATA/AppData/razkindo2-erp/.next/standalone
npm install @prisma/client prisma
npx prisma generate --schema=../../prisma/schema.prisma
systemctl restart razkindo2-erp
```

### Masalah 4: TypeError Cannot Read 'map' (CRASH SAAT INI)

**Langkah debug:**
```bash
# Stop service
systemctl stop razkindo2-erp

# Jalankan manual dengan instrumentation disabled
cd /DATA/AppData/razkindo2-erp/.next/standalone
NEXT_DISABLE_INSTRUMENTATION=1 node server.js

# Di terminal lain:
curl -s http://127.0.0.1:3000/api/health
curl -s http://127.0.0.1:3000/ | head -5
```

**Jika tetap crash:**
```bash
# Jalankan dengan source maps dan full stack trace
NODE_OPTIONS='--enable-source-maps --stack-trace-limit=100' node server.js
```

**Kemungkinan fix:**
1. Pastikan `prisma generate` sudah dijalankan di STB
2. Pastikan `.env` punya `AUTH_SECRET` dan `WS_SECRET`
3. Rebuild dari Mac dengan `git pull` + `npm run build` + transfer ulang

### Masalah 5: Dashboard/Module Tidak Load (Blank Page)

**Penyebab:** API routes error, data tidak bisa diambil dari database.

**Debug:**
```bash
# Cek log journal
journalctl -u razkindo2-erp -n 50 --no-pager

# Test API langsung
curl -s http://127.0.0.1:3000/api/dashboard | head -100
curl -s http://127.0.0.1:3000/api/units | head -100
curl -s http://127.0.0.1:3000/api/health | head -100
```

### Masalah 6: WebSocket Timeout / Tidak Real-time

**Cek:**
```bash
# Event-queue jalan?
ss -tlnp | grep 3004

# Log event-queue
journalctl -u razkindo2-event-queue -n 20 --no-pager

# Test health (butuh auth)
curl -s -H "Authorization: Bearer razkindo-erp-ws-prod-2024" http://127.0.0.1:3004/api/health
```

**Pastikan di `.env` STB:**
```
WS_SECRET=razkindo-erp-ws-prod-2024
EVENT_QUEUE_URL=http://127.0.0.1:3004
```

### Masalah 7: npm audit Vulnerability

**Gejala:**
```
3 moderate severity vulnerabilities (prismjs/refractor)
```

**Solusi:** Ini **tidak kritis** — hanya di library syntax highlighting. Abaikan untuk sekarang. Jangan jalankan `npm audit fix --force` karena bisa breaking change.

---

## 🔐 Variabel Environment yang Diperlukan

### Di `.env` STB (`/DATA/AppData/razkindo2-erp/.next/standalone/.env`)

```bash
# ============ DATABASE ============
DATABASE_URL=postgresql://postgres.XXX:PASSWORD@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
DIRECT_URL=postgresql://postgres.XXX:PASSWORD@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres

# ============ SUPABASE REST ============
NEXT_PUBLIC_SUPABASE_URL=https://XXX.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# ============ AUTH ============
AUTH_SECRET=razkindo-erp-auth-secret-change-in-production

# ============ WEBSOCKET ============
WS_SECRET=razkindo-erp-ws-prod-2024
EVENT_QUEUE_URL=http://127.0.0.1:3004

# ============ OPTIMASI STB (opsional) ============
NODE_OPTIONS=--max-old-space-size=512
```

### Di systemd service Event-Queue

```
Environment=WS_SECRET=razkindo-erp-ws-prod-2024
Environment=PORT=3004
Environment=SUPABASE_URL=https://XXX.supabase.co
Environment=SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

---

## 📋 Checklist Deploy Final

```
PRE-DEPLOY (DI MAC):
  ☐ cd /Users/mac/razkindo2-erp && git pull
  ☐ npm run build berhasil tanpa error
  ☐ scp semua file ke STB (standalone, static, public, .env, prisma, mini-services)

SETUP (DI STB):
  ☐ npm install di event-queue
  ☐ npm install tsx di event-queue
  ☐ npm install @prisma/client prisma di standalone
  ☐ npx prisma generate --schema=../../prisma/schema.prisma
  ☐ .env lengkap (WS_SECRET, EVENT_QUEUE_URL, AUTH_SECRET, SUPABASE_SERVICE_ROLE_KEY)
  ☐ systemd service files terpasang

VERIFIKASI:
  ☐ systemctl status razkindo2-erp → Active: active (running)
  ☐ systemctl status razkindo2-event-queue → Active: active (running)
  ☐ curl http://127.0.0.1:3000/api/health → {"status":"ok"}
  ☐ curl -H "Authorization: Bearer ..." http://127.0.0.1:3004/api/health → {"status":"healthy"}
  ☐ Browser: http://192.168.100.64:3000 → Login page muncul
  ☐ Login berhasil → Dashboard load data
  ☐ WebSocket terhubung (cek browser console, tidak ada error)

SETelah DEPLOY:
  ☐ Test buat transaksi → muncul real-time di tab lain
  ☐ Monitor memory: free -h && ps aux | grep node
  ☐ Cek log: journalctl -u razkindo2-erp -f
```

---

## 📈 Monitoring STB

### Cek Resource

```bash
# Memory & CPU
free -h
top -bn1 | head -5

# Disk
df -h /DATA

# Node.js process memory
ps aux | grep node | awk '{sum += $6} END {print "Node.js total RSS:", sum/1024, "MB"}'
```

### Monitor Real-time

```bash
# Log Next.js
journalctl -u razkindo2-erp -f

# Log Event-Queue
journalctl -u razkindo2-event-queue -f

# Queue status
curl -s -H "Authorization: Bearer razkindo-erp-ws-prod-2024" http://127.0.0.1:3004/api/queue/status
```

### Alert Memory Sederhana (Cron)

```bash
cat > /usr/local/bin/check-erp-memory.sh << 'SCRIPT'
#!/bin/bash
MEM_MB=$(ps aux | grep 'node server.js' | grep -v grep | awk '{sum += $6} END {print sum/1024}')
if [ -n "$MEM_MB" ] && [ "$(echo "$MEM_MB > 450" | bc -l)" = "1" ]; then
  echo "$(date): WARNING - Node.js memory: ${MEM_MB}MB" >> /var/log/erp-memory.log
  if [ "$(echo "$MEM_MB > 500" | bc -l)" = "1" ]; then
    systemctl restart razkindo2-erp
    echo "$(date): AUTO-RESTART at ${MEM_MB}MB" >> /var/log/erp-memory.log
  fi
fi
SCRIPT

chmod +x /usr/local/bin/check-erp-memory.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check-erp-memory.sh") | crontab -
```

---

## 🔐 Keamanan Produksi

### Ganti Secret Keys

```bash
# Di STB, generate secret baru
JWT_SECRET=$(openssl rand -hex 32)
WS_SECRET=$(openssl rand -hex 32)

# Update .env
sed -i "s|AUTH_SECRET=.*|AUTH_SECRET=$JWT_SECRET|" /DATA/AppData/razkindo2-erp/.next/standalone/.env
sed -i "s|WS_SECRET=.*|WS_SECRET=$WS_SECRET|" /DATA/AppData/razkindo2-erp/.next/standalone/.env

# Juga update di systemd service event-queue
sed -i "s|Environment=WS_SECRET=.*|Environment=WS_SECRET=$WS_SECRET|" /etc/systemd/system/razkindo2-event-queue.service

systemctl daemon-reload
systemctl restart razkindo2-erp razkindo2-event-queue
```

### Jangan Expose Port 3004 ke Internet

```bash
# Hanya port 3000 yang perlu diakses dari luar
# Port 3004 adalah internal WebSocket antara Next.js dan event-queue

# Jika menggunakan ufw:
ufw deny 3004
ufw allow 3000
```

---

## 📝 Catatan Penting

1. **STB tidak punya git repo** — Jangan jalankan `git pull` di STB. Selalu build di Mac, transfer ke STB.
2. **Node.js v20 di STB** — Tidak bisa jalankan `.ts` langsung, gunakan `npx tsx`.
3. **Prisma harus di-generate di STB** — Binary engine harus cocok dengan platform (linux-arm64).
4. **Kill proses lama sebelum restart** — Gunakan `fuser -k 3000/tcp` atau `kill <PID>`.
5. **Jangan copy baris komentar `#`** ke terminal — Akan error `command not found`.
6. **Jalankan perintah satu per satu** — Jangan paste semua sekaligus.

---

*Dokumen ini diupdate berdasarkan session deployment 22 April 2026. Semua 14 bug lama sudah diperbaiki, 15 perbaikan WebSocket/Security sudah diimplementasi. Masalah aktif: TypeError crash saat server start — sedang di-debug.*
