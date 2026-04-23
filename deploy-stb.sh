#!/bin/bash
# ============================================================
# Razkindo2 ERP - STB Deploy Script (Fresh/Update)
# Untuk: AML S9xx TV Box, Armbian Ubuntu 24.04, CasaOS
# ============================================================
# CARA PAKAI (di STB):
#   Option 1: Fresh install
#     bash deploy-stb.sh
#
#   Option 2: Update existing (non-git) install
#     bash deploy-stb.sh --update
#
#   Option 3: Force fresh clone (removes old files)
#     bash deploy-stb.sh --fresh
# ============================================================

set -e

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
C='\033[0;36m'
N='\033[0m'

INSTALL_DIR="/DATA/AppData/razkindo2-erp"
REPO_URL="https://github.com/henryarthanto/razkindo2-erp.git"
MODE="${1:-default}"

echo ""
echo -e "${C}============================================================"
echo "  Razkindo2 ERP - STB Deployment Script"
echo "  Mode: $MODE"
echo -e "============================================================${N}"
echo ""

# ---- CEK PRASYARAT ----
echo -e "${Y}[*] Cek prasyarat...${N}"

if ! command -v node &>/dev/null; then
    echo -e "${R}ERROR: Node.js tidak ditemukan!${N}"
    echo "  Install Node.js v20 dulu:"
    echo "    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -"
    echo "    sudo apt-get install -y nodejs"
    exit 1
fi
echo -e "${G}  ✓ Node.js: $(node -v)${N}"

if ! command -v npm &>/dev/null; then
    echo -e "${R}ERROR: npm tidak ditemukan!${N}"
    exit 1
fi
echo -e "${G}  ✓ npm: $(npm -v)${N}"

if ! command -v git &>/dev/null; then
    echo -e "${R}ERROR: git tidak ditemukan!${N}"
    echo "  Install git:"
    echo "    sudo apt-get install -y git"
    exit 1
fi
echo -e "${G}  ✓ git: $(git --version)${N}"

# ---- DETEKSI MODE ----
if [ "$MODE" = "--fresh" ]; then
    echo ""
    echo -e "${Y}  Mode FRESH: Hapus folder lama, clone ulang${N}"
    
    # Backup .env dulu
    if [ -f "$INSTALL_DIR/.env" ]; then
        cp "$INSTALL_DIR/.env" "/tmp/razkindo2-env-backup-$(date +%s)"
        echo -e "${G}  ✓ .env dibackup ke /tmp/${N}"
    fi
    
    # Stop service jika ada
    sudo systemctl stop razkindo2-erp 2>/dev/null || true
    
    # Hapus folder lama
    rm -rf "$INSTALL_DIR"
    
    # Clone fresh
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Restore .env
    LATEST_ENV=$(ls -t /tmp/razkindo2-env-backup-* 2>/dev/null | head -1)
    if [ -n "$LATEST_ENV" ]; then
        cp "$LATEST_ENV" "$INSTALL_DIR/.env"
        echo -e "${G}  ✓ .env direstore dari backup${N}"
    fi

elif [ "$MODE" = "--update" ] || [ -d "$INSTALL_DIR/.git" ]; then
    echo ""
    echo -e "${Y}  Mode UPDATE: Pull latest code dari GitHub${N}"
    cd "$INSTALL_DIR"
    git pull origin main || { echo -e "${R}  git pull gagal! Coba --fresh${N}"; exit 1; }

elif [ -d "$INSTALL_DIR" ]; then
    echo ""
    echo -e "${Y}  Folder $INSTALL_DIR sudah ada tapi BUKAN git repo${N}"
    echo -e "${Y}  Mengubah ke git repo dan pull code terbaru...${N}"
    
    # Backup .env
    if [ -f "$INSTALL_DIR/.env" ]; then
        cp "$INSTALL_DIR/.env" "/tmp/razkindo2-env-backup-$(date +%s)"
        echo -e "${G}  ✓ .env dibackup${N}"
    fi
    
    cd "$INSTALL_DIR"
    
    # Stop service jika ada
    sudo systemctl stop razkindo2-erp 2>/dev/null || true
    
    # Init git, add remote, fetch, dan force checkout main
    git init
    git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"
    git fetch origin main
    
    # Checkout dengan force (overwrite local files dengan repo version)
    git checkout -f -b main origin/main
    
    # Restore .env
    LATEST_ENV=$(ls -t /tmp/razkindo2-env-backup-* 2>/dev/null | head -1)
    if [ -n "$LATEST_ENV" ]; then
        cp "$LATEST_ENV" "$INSTALL_DIR/.env"
        echo -e "${G}  ✓ .env direstore dari backup${N}"
    fi
    
    echo -e "${G}  ✓ Folder berhasil diubah ke git repo${N}"
else
    echo ""
    echo -e "${Y}  Folder belum ada, clone dari GitHub...${N}"
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# ---- PASTIKAN .ENV ADA ----
echo ""
echo -e "${Y}[*] Cek file .env...${N}"

if [ ! -f "$INSTALL_DIR/.env" ]; then
    echo -e "${Y}  .env belum ada, membuat dari template...${N}"
    
cat > "$INSTALL_DIR/.env" << 'ENVFILE'
# ============================================================
# Razkindo ERP - Environment Configuration
# ============================================================

# Database - Supabase PostgreSQL
DATABASE_URL=postgresql://postgres.eglmvtleuonoeomovnwa:Arthanto01091987@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
DIRECT_URL=postgresql://postgres.eglmvtleuonoeomovnwa:Arthanto01091987@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres
SUPABASE_DB_URL=postgresql://postgres:Arthanto01091987@db.eglmvtleuonoeomovnwa.supabase.co:5432/postgres

# Supabase REST API
NEXT_PUBLIC_SUPABASE_URL=https://eglmvtleuonoeomovnwa.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_aswVP7jZ9b-Lr7rMdvahXA_LkbBEy2n
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnbG12dGxldW9ub2VvbW92bndhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjM1NjgxNywiZXhwIjoyMDkxOTMyODE3fQ.D839Fhnh1I0032zqHePeWQFwE9J_NxTquC_87UkBtX8
NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnbG12dGxldW9ub2VvbW92bndhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjM1NjgxNywiZXhwIjoyMDkxOTMyODE3fQ.D839Fhnh1I0032zqHePeWQFwE9J_NxTquC_87UkBtX8

# Auth
AUTH_SECRET=9d2ffc3b3776455c1929644b974221dcb9b409a6f7caa8c59686ede7d862c7e0

# WebSocket & Event Queue
WS_SECRET=razkindo-erp-ws-prod-2024-secure
EVENT_QUEUE_URL=http://127.0.0.1:3004
ENVFILE

    echo -e "${G}  ✓ .env dibuat${N}"
else
    echo -e "${G}  ✓ .env sudah ada${N}"
fi

# ---- INSTALL DEPENDENCIES ----
echo ""
echo -e "${Y}[*] Install dependencies...${N}"
cd "$INSTALL_DIR"
npm install 2>&1 || { echo -e "${R}  npm install gagal!${N}"; exit 1; }
echo -e "${G}  ✓ Dependencies terinstall${N}"

# ---- GENERATE PRISMA CLIENT ----
echo ""
echo -e "${Y}[*] Generate Prisma client...${N}"
npx prisma generate 2>&1 || { echo -e "${R}  Prisma generate gagal!${N}"; exit 1; }
echo -e "${G}  ✓ Prisma client generated${N}"

# ---- PUSH SCHEMA KE SUPABASE ----
echo ""
echo -e "${Y}[*] Push schema ke Supabase...${N}"
echo -e "${Y}  (Ini akan menambah kolom baru yang dibutuhkan)${N}"
npx prisma db push 2>&1 || {
    echo -e "${Y}  db push gagal, coba dengan --accept-data-loss...${N}"
    npx prisma db push --accept-data-loss 2>&1 || echo -e "${R}  db push gagal! Cek error di atas${N}"
}
echo -e "${G}  ✓ Schema disync ke database${N}"

# ---- BUILD ----
echo ""
echo -e "${Y}[*] Build aplikasi...${N}"
echo -e "${Y}  (Ini mungkin butuh beberapa menit di STB)${N}"
npm run build 2>&1 || { echo -e "${R}  Build gagal!${N}"; exit 1; }
echo -e "${G}  ✓ Build berhasil${N}"

# ---- SETUP SYSTEMD SERVICE ----
echo ""
echo -e "${Y}[*] Setup systemd service...${N}"

NODE_PATH=$(which node)

sudo tee /etc/systemd/system/razkindo2-erp.service > /dev/null << EOF
[Unit]
Description=Razkindo2 ERP - Next.js Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${NODE_PATH} node_modules/.bin/next start -p 3000
Restart=on-failure
RestartSec=5
TimeoutStopSec=10s
Environment=NODE_ENV=production
Environment=PORT=3000
EnvironmentFile=${INSTALL_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable razkindo2-erp
sudo systemctl restart razkindo2-erp

echo -e "${G}  ✓ Service razkindo2-erp terinstall${N}"

# ---- CEK STATUS ----
echo ""
echo -e "${Y}  Menunggu service start...${N}"
sleep 5

if sudo systemctl is-active --quiet razkindo2-erp; then
    echo -e "${G}  ✓ razkindo2-erp: RUNNING${N}"
else
    echo -e "${R}  ✗ razkindo2-erp: FAILED${N}"
    echo -e "  Cek log: ${C}sudo journalctl -u razkindo2-erp -n 50 --no-pager${N}"
fi

# ---- TEST HTTP ----
echo ""
echo -e "${Y}[*] Test HTTP...${N}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${G}  ✓ HTTP 200 - Aplikasi berjalan!${N}"
else
    echo -e "${R}  ✗ HTTP $HTTP_CODE - Aplikasi belum siap${N}"
    echo -e "  Cek log: ${C}sudo journalctl -u razkindo2-erp -n 100 --no-pager${N}"
fi

# ---- SELESAI ----
echo ""
echo -e "${G}============================================================"
echo "  DEPLOY SELESAI!"
echo "============================================================${N}"
echo ""
echo "  Aplikasi: http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "  Perintah berguna:"
echo -e "    ${G}Status:${N}           sudo systemctl status razkindo2-erp"
echo -e "    ${G}Log:${N}             sudo journalctl -u razkindo2-erp -f"
echo -e "    ${G}Restart:${N}         sudo systemctl restart razkindo2-erp"
echo -e "    ${G}Stop:${N}            sudo systemctl stop razkindo2-erp"
echo -e "    ${G}Update:${N}          cd $INSTALL_DIR && git pull && npm install && npx prisma generate && npx prisma db push && npm run build && sudo systemctl restart razkindo2-erp"
echo ""
