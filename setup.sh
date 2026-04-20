#!/bin/bash
# ============================================================
# Razkindo2 ERP - Setup Script for CasaOS + Ngrok
# ============================================================
# Cara pakai:
#   git clone https://github.com/henryarthanto/razkindo2-erp.git
#   cd razkindo2-erp
#   chmod +x setup.sh
#   ./setup.sh
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "============================================================"
echo "  🔧 Razkindo2 ERP - Setup untuk CasaOS + Ngrok"
echo "============================================================"
echo ""

# Step 1: Buat direktori jika belum ada
echo -e "${YELLOW}[1/4] Membuat direktori...${NC}"
mkdir -p data/uploads
echo -e "${GREEN}  ✓ Direktori data/uploads dibuat${NC}"

# Step 2: Buat file .env
echo -e "${YELLOW}[2/4] Membuat file .env...${NC}"

# Cek apakah .env sudah ada
if [ -f .env ]; then
    echo -e "${RED}  ⚠ File .env sudah ada!${NC}"
    read -p "  Timpa dengan yang baru? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "  Skip membuat .env"
    else
        create_env=true
    fi
else
    create_env=true
fi

if [ "$create_env" = true ]; then
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
echo "  Jika Anda menggunakan ngrok, masukkan URL ngrok Anda."
echo "  Contoh: https://abc123.ngrok-free.app"
echo "  Tekan Enter saja jika belum tahu (bisa diedit nanti di .env)"
echo ""
read -p "  Ngrok URL (atau Enter untuk skip): " NGROK_URL

if [ -n "$NGROK_URL" ]; then
    # Hapus trailing slash
    NGROK_URL="${NGROK_URL%/}"
    sed -i "s|NEXTAUTH_URL=.*|NEXTAUTH_URL=$NGROK_URL|g" .env
    echo -e "${GREEN}  ✓ NEXTAUTH_URL diset ke: $NGROK_URL${NC}"
else
    echo -e "${YELLOW}  ⚠ NEXTAUTH_URL masih http://localhost:3000"
    echo "  Edit file .env nanti setelah dapat URL ngrok${NC}"
fi

# Step 4: Build & Run
echo ""
echo -e "${YELLOW}[4/4] Siap menjalankan Docker!${NC}"
echo ""
echo "  Untuk memulai, jalankan:"
echo ""
echo -e "  ${GREEN}docker compose up -d --build${NC}"
echo ""
echo "  Untuk melihat log:"
echo -e "  ${GREEN}docker compose logs -f${NC}"
echo ""
echo "  Untuk stop:"
echo -e "  ${GREEN}docker compose down${NC}"
echo ""
echo "============================================================"
echo "  ⚡ Jika pakai ngrok, jalankan di terminal terpisah:"
echo "     ngrok http 3000"
echo "  Lalu update NEXTAUTH_URL di .env dengan URL ngrok"
echo "  dan restart: docker compose restart"
echo "============================================================"
echo ""
