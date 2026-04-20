#!/bin/bash
# ============================================================
# Razkindo2 ERP - Setup Script for CasaOS + Ngrok
# ============================================================
# Cara pakai:
#   cd /DATA/AppData
#   git clone https://github.com/henryarthanto/razkindo2-erp.git
#   cd razkindo2-erp
#   chmod +x setup.sh
#   ./setup.sh
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "============================================================"
echo "  🔧 Razkindo2 ERP - Setup untuk CasaOS + Ngrok"
echo "============================================================"
echo ""

# Step 1: Buat direktori
echo -e "${YELLOW}[1/4] Membuat direktori...${NC}"
mkdir -p data/uploads
echo -e "${GREEN}  ✓ Direktori data/uploads dibuat${NC}"

# Step 2: Buat file .env
echo -e "${YELLOW}[2/4] Membuat file .env...${NC}"

if [ -f .env ]; then
    echo -e "${YELLOW}  File .env sudah ada, skip${NC}"
else
cat > .env << 'ENVFILE'
# ============================================================
# Razkindo ERP - Environment Configuration
# ============================================================

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

# NextAuth - GANTI NEXTAUTH_URL dengan URL ngrok Anda!
NEXTAUTH_SECRET=razkindo-erp-secret-key-change-in-production
NEXTAUTH_URL=http://localhost:3000
ENVFILE

    echo -e "${GREEN}  ✓ File .env berhasil dibuat${NC}"
fi

# Step 3: Tanya URL ngrok
echo ""
echo -e "${YELLOW}[3/4] Konfigurasi Ngrok URL${NC}"
echo "  Masukkan URL ngrok Anda (contoh: https://abc123.ngrok-free.app)"
echo "  Tekan Enter saja jika belum tahu (bisa diedit nanti di .env)"
echo ""
read -p "  Ngrok URL (atau Enter untuk skip): " NGROK_URL

if [ -n "$NGROK_URL" ]; then
    NGROK_URL="${NGROK_URL%/}"
    sed -i "s|NEXTAUTH_URL=.*|NEXTAUTH_URL=$NGROK_URL|g" .env
    echo -e "${GREEN}  ✓ NEXTAUTH_URL diset ke: $NGROK_URL${NC}"
else
    echo -e "${YELLOW}  ⚠ NEXTAUTH_URL masih http://localhost:3000"
    echo "  Edit file .env nanti setelah dapat URL ngrok${NC}"
fi

# Step 4: Pilih cara build
echo ""
echo -e "${YELLOW}[4/4] Pilih cara menjalankan:${NC}"
echo ""
echo -e "  ${CYAN}A) Pull pre-built image (RECOMMENDED - hemat storage)${NC}"
echo "     Image sudah di-build oleh GitHub, tinggal pull & run"
echo "     Kebutuhan: ~200MB storage"
echo ""
echo -e "  ${CYAN}B) Build lokal dengan build.sh (2-step, hemat storage)${NC}"
echo "     Build di container sementara, extract, buang, buat image kecil"
echo "     Kebutuhan: ~1.5GB storage sementara"
echo ""
echo -e "  ${CYAN}C) Build langsung (docker compose build)${NC}"
echo "     Build biasa, butuh storage ~2GB+"
echo ""
read -p "  Pilihan (A/B/C): " -n 1 -r
echo ""

case $REPLY in
    A|a)
        echo ""
        echo -e "${GREEN}Menjalankan dengan pre-built image...${NC}"
        docker compose up -d
        echo ""
        echo -e "${GREEN}  ✓ Container berjalan!${NC}"
        echo "  Cek: docker compose logs -f"
        ;;
    B|b)
        echo ""
        echo -e "${GREEN}Building dengan build.sh (2-step)...${NC}"
        chmod +x build.sh
        ./build.sh
        # Uncomment build lokal di docker-compose
        sed -i 's|image: ghcr.io/|# image: ghcr.io/|g' docker-compose.yml
        sed -i 's|# build:|build:|g' docker-compose.yml
        sed -i 's|#   context:|  context:|g' docker-compose.yml
        sed -i 's|#   dockerfile:|  dockerfile:|g' docker-compose.yml
        docker compose up -d
        echo ""
        echo -e "${GREEN}  ✓ Container berjalan!${NC}"
        ;;
    C|c)
        echo ""
        echo -e "${GREEN}Building langsung...${NC}"
        # Uncomment build lokal di docker-compose
        sed -i 's|image: ghcr.io/|# image: ghcr.io/|g' docker-compose.yml
        sed -i 's|# build:|build:|g' docker-compose.yml
        sed -i 's|#   context:|  context:|g' docker-compose.yml
        sed -i 's|#   dockerfile:|  dockerfile:|g' docker-compose.yml
        DOCKER_BUILDKIT=1 docker compose up -d --build
        echo ""
        echo -e "${GREEN}  ✓ Container berjalan!${NC}"
        ;;
    *)
        echo ""
        echo "  Skip build. Jalankan manual nanti."
        ;;
esac

echo ""
echo "============================================================"
echo "  ⚡ Jika pakai ngrok, jalankan di terminal terpisah:"
echo "     ngrok http 3000"
echo "  Lalu update NEXTAUTH_URL di .env dengan URL ngrok"
echo "  dan restart: docker compose restart"
echo "============================================================"
echo ""
