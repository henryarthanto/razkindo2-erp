#!/bin/bash
# ============================================================
# Razkindo2 ERP - STB Installation Script
# Untuk: AML S9xx TV Box dengan CasaOS
# ============================================================
# CARA PAKAI:
#   SSH ke STB, lalu copy-paste perintah ini:
#   bash <(curl -sL https://raw.githubusercontent.com/henryarthanto/razkindo2-erp/main/install-stb.sh)
#
#   ATAU manual:
#   git clone https://github.com/henryarthanto/razkindo2-erp.git
#   cd razkindo2-erp
#   chmod +x install-stb.sh
#   ./install-stb.sh
# ============================================================

set -e

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
C='\033[0;36m'
N='\033[0m'

echo ""
echo "============================================================"
echo "  Razkindo2 ERP - Instalasi di STB (CasaOS)"
echo "============================================================"
echo ""

# ---- CEK PRASYARAT ----
echo -e "${Y}[*] Cek prasyarat...${N}"

if ! command -v docker &>/dev/null; then
    echo -e "${R}ERROR: Docker tidak ditemukan!${N}"
    echo "  Install Docker dulu: CasaOS sudah termasuk Docker"
    exit 1
fi
echo -e "${G}  ✓ Docker: OK${N}"

if ! command -v git &>/dev/null; then
    echo -e "${Y}  Installing git...${N}"
    apk add git 2>/dev/null || apt-get install -y git 2>/dev/null || opkg install git 2>/dev/null || true
fi
echo -e "${G}  ✓ Git: OK${N}"

# ---- CEK STORAGE ----
FREE_MB=$(df -m . | tail -1 | awk '{print $4}')
echo -e "${Y}  Storage kosong: ${FREE_MB}MB${N}"

if [ "$FREE_MB" -lt 2000 ]; then
    echo -e "${R}  WARNING: Storage kurang dari 2GB!${N}"
    echo -e "  Coba bersihkan:"
    echo "    docker system prune -a --volumes -f"
    echo ""
    read -p "  Lanjutkan? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
fi

# ---- CLONE / UPDATE ----
echo ""
echo -e "${Y}[1/4] Download source code...${N}"

if [ -d "razkindo2-erp" ]; then
    echo -e "${Y}  Folder sudah ada, updating...${N}"
    cd razkindo2-erp && git pull && cd ..
else
    git clone https://github.com/henryarthanto/razkindo2-erp.git
fi

cd razkindo2-erp
echo -e "${G}  ✓ Source code siap${N}"

# ---- BERSIHKAN DOCKER CACHE ----
echo ""
echo -e "${Y}[2/4] Bersihkan Docker cache...${N}"
docker system prune -f 2>/dev/null || true
echo -e "${G}  ✓ Cache dibersihkan${N}"

# ---- BUAT .ENV ----
echo ""
echo -e "${Y}[3/4] Buat file .env...${N}"

if [ -f .env ]; then
    echo -e "${Y}  File .env sudah ada, skip${N}"
else
    mkdir -p data/uploads

cat > .env << 'ENVFILE'
# Database - Supabase PostgreSQL
DATABASE_URL=postgresql://postgres.eglmvtleuonoeomovnwa:Arthanto01091987@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
DIRECT_URL=postgresql://postgres.eglmvtleuonoeomovnwa:Arthanto01091987@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres
SUPABASE_DB_URL=postgresql://postgres:Arthanto01091987@db.eglmvtleuonoeomovnwa.supabase.co:5432/postgres
SUPABASE_POOLER_URL=postgresql://postgres.eglmvtleuonoeomovnwa:Arthanto01091987@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres

# Supabase REST API
NEXT_PUBLIC_SUPABASE_URL=https://eglmvtleuonoeomovnwa.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_aswVP7jZ9b-Lr7rMdvahXA_LkbBEy2n
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnbG12dGxldW9ub2VvbW92bndhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjM1NjgxNywiZXhwIjoyMDkxOTMyODE3fQ.D839Fhnh1I0032zqHePeWQFwE9J_NxTquC_87UkBtX8
NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnbG12dGxldW9ub2VvbW92bndhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjM1NjgxNywiZXhwIjoyMDkxOTMyODE3fQ.D839Fhnh1I0032zqHePeWQFwE9J_NxTquC_87UkBtX8

# NextAuth
NEXTAUTH_SECRET=razkindo-erp-secret-key-change-in-production
NEXTAUTH_URL=http://localhost:3000
ENVFILE

    echo -e "${G}  ✓ File .env dibuat${N}"
fi

# Tanya ngrok URL
echo ""
echo -e "${C}  Masukkan URL ngrok jika sudah punya (contoh: https://abc123.ngrok-free.app)${N}"
echo -e "  Tekan Enter untuk skip (bisa edit nanti di .env)"
read -p "  Ngrok URL: " NGROK_URL

if [ -n "$NGROK_URL" ]; then
    NGROK_URL="${NGROK_URL%/}"
    sed -i "s|NEXTAUTH_URL=.*|NEXTAUTH_URL=$NGROK_URL|g" .env
    echo -e "${G}  ✓ NEXTAUTH_URL = $NGROK_URL${N}"
fi

# ---- BUILD & RUN ----
echo ""
echo -e "${Y}[4/4] Build & jalankan Docker...${N}"
echo -e "  ${C}(Build pertama kali memakan 5-10 menit, sabar ya...)${N}"
echo ""

DOCKER_BUILDKIT=1 docker compose up -d --build 2>&1 || {
    echo ""
    echo -e "${R}BUILD GAGAL! Kemungkinan storage tidak cukup.${N}"
    echo ""
    echo -e "Coba langkah ini:"
    echo -e "  ${G}1. Bersihkan semua Docker cache:${N}"
    echo "     docker system prune -a --volumes -f"
    echo ""
    echo -e "  ${G}2. Cek sisa storage:${N}"
    echo "     df -h"
    echo ""
    echo -e "  ${G}3. Build ulang:${N}"
    echo "     DOCKER_BUILDKIT=1 docker compose up -d --build"
    exit 1
}

echo ""
echo -e "${G}============================================================"
echo "  INSTALLASI BERHASIL!"
echo "============================================================${N}"
echo ""
echo "  Aplikasi berjalan di: http://IP-STB-ANDA:3000"
echo ""
echo "  Cek status:"
echo -e "    ${G}docker compose ps${N}"
echo ""
echo "  Lihat log:"
echo -e "    ${G}docker compose logs -f${N}"
echo ""
echo "  Stop:"
echo -e "    ${G}docker compose down${N}"
echo ""
echo "  Restart:"
echo -e "    ${G}docker compose restart${N}"
echo ""
echo "  Update ke versi terbaru:"
echo -e "    ${G}git pull && docker compose up -d --build${N}"
echo ""
echo "============================================================"
echo "  UNTUK NGROK:"
echo "  1. Install ngrok: snap install ngrok"
echo "     atau: download dari https://ngrok.com/download"
echo "  2. Jalankan: ngrok http 3000"
echo "  3. Copy URL ngrok, edit .env:"
echo "     nano .env"
echo "     Ganti NEXTAUTH_URL=https://xxx.ngrok-free.app"
echo "  4. Restart: docker compose restart"
echo "============================================================"
echo ""
