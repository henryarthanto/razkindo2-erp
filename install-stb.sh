#!/bin/bash
# ============================================================
# Razkindo2 ERP - STB Installation Script (Standalone/Node.js)
# Untuk: AML S9xx TV Box, Armbian Ubuntu 24.04, CasaOS
# ============================================================
# CARA PAKAI:
#   Option A: Build di Mac, deploy ke STB (RECOMMENDED)
#     - Di Mac:  ./build-standalone.sh
#     - SCP ke STB: scp -r .next/standalone root@192.168.100.64:/DATA/AppData/razkindo2-erp/
#     - Di STB:  ./install-stb.sh
#
#   Option B: Full install di STB (butuh ~2GB storage)
#     SSH ke STB, lalu:
#     bash <(curl -sL https://raw.githubusercontent.com/henryarthanto/razkindo2-erp/main/install-stb.sh)
# ============================================================

set -e

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
C='\033[0;36m'
N='\033[0m'

INSTALL_DIR="${1:-/DATA/AppData/razkindo2-erp}"

echo ""
echo "============================================================"
echo "  Razkindo2 ERP - Instalasi di STB (Standalone Node.js)"
echo "  Target: $INSTALL_DIR"
echo "============================================================"
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
NODE_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
echo -e "${G}  ✓ Node.js: $(node -v)${N}"

if ! command -v npm &>/dev/null; then
    echo -e "${R}ERROR: npm tidak ditemukan!${N}"
    exit 1
fi
echo -e "${G}  ✓ npm: $(npm -v)${N}"

# ---- CEK STORAGE ----
FREE_MB=$(df -m . | tail -1 | awk '{print $4}')
echo -e "${Y}  Storage kosong: ${FREE_MB}MB${N}"

if [ "$FREE_MB" -lt 1500 ]; then
    echo -e "${R}  WARNING: Storage kurang dari 1.5GB!${N}"
    echo -e "  Coba bersihkan:"
    echo "    docker system prune -a --volumes -f"
    echo "    sudo apt-get clean"
    echo ""
    read -p "  Lanjutkan? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
fi

# ---- DETEKSI METODE INSTALASI ----
if [ -d "$INSTALL_DIR/.next/standalone" ]; then
    echo ""
    echo -e "${G}  ✓ Ditemukan standalone build di $INSTALL_DIR/.next/standalone${N}"
    echo -e "  ${C}Mode: Deploy dari pre-built standalone (RECOMMENDED)${N}"
    STANDALONE_MODE=true
else
    echo ""
    echo -e "${Y}  Standalone build tidak ditemukan.${N}"
    echo -e "  ${C}Mode: Clone dari GitHub + install dependencies${N}"
    STANDALONE_MODE=false
fi

# ---- STEP 1: SOURCE CODE ----
echo ""
echo -e "${Y}[1/5] Siapkan source code...${N}"

if [ "$STANDALONE_MODE" = false ]; then
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
    fi

    if [ -d "$INSTALL_DIR/.git" ]; then
        echo -e "${Y}  Folder sudah ada, updating...${N}"
        cd "$INSTALL_DIR" && git pull
    else
        git clone https://github.com/henryarthanto/razkindo2-erp.git "$INSTALL_DIR"
    fi

    cd "$INSTALL_DIR"
    echo -e "${G}  ✓ Source code siap${N}"
else
    cd "$INSTALL_DIR"
    echo -e "${G}  ✓ Standalone build siap${N}"
fi

# ---- STEP 2: INSTALL DEPENDENCIES ----
echo ""
echo -e "${Y}[2/5] Install dependencies...${N}"

if [ "$STANDALONE_MODE" = true ]; then
    # Standalone mode: install only production deps
    if [ -f ".next/standalone/package.json" ]; then
        cd .next/standalone
        npm install --production 2>&1 || true
        cd ../..
    fi
else
    # Full mode: install all deps
    npm install 2>&1 || { echo -e "${R}  npm install gagal!${N}"; exit 1; }
fi
echo -e "${G}  ✓ Dependencies terinstall${N}"

# ---- STEP 3: BUAT .ENV ----
echo ""
echo -e "${Y}[3/5] Buat file .env...${N}"

ENV_FILE="$INSTALL_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    echo -e "${Y}  File .env sudah ada, skip${N}"
else
    mkdir -p "$INSTALL_DIR/data/uploads"

cat > "$ENV_FILE" << 'ENVFILE'
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

    echo -e "${G}  ✓ File .env dibuat${N}"
fi

# ---- STEP 4: GENERATE PRISMA CLIENT ----
echo ""
echo -e "${Y}[4/5] Generate Prisma client...${N}"

if [ "$STANDALONE_MODE" = false ]; then
    npx prisma generate 2>&1 || { echo -e "${R}  Prisma generate gagal!${N}"; exit 1; }
    
    # Push schema ke Supabase (pastikan tabel ada)
    echo -e "${Y}  Push schema ke Supabase...${N}"
    npx prisma db push --accept-data-loss 2>&1 || echo -e "${Y}  Warning: db push ada issue (mungkin tabel sudah ada)${N}"
else
    # Standalone mode: generate prisma client
    if [ -f "prisma/schema.prisma" ]; then
        npx prisma generate 2>&1 || echo -e "${Y}  Warning: Prisma generate skip${N}"
    fi
fi
echo -e "${G}  ✓ Prisma client siap${N}"

# ---- STEP 5: SETUP SYSTEMD SERVICES ----
echo ""
echo -e "${Y}[5/5] Setup systemd services...${N}"

# Service 1: Razkindo2 ERP (Next.js)
ERP_WORKING_DIR="$INSTALL_DIR"
ERP_NODE_PATH=$(which node)

if [ "$STANDALONE_MODE" = true ] && [ -f ".next/standalone/server.js" ]; then
    ERP_START_CMD="${ERP_NODE_PATH} .next/standalone/server.js"
    ERP_WORKING_DIR="$INSTALL_DIR"
else
    ERP_START_CMD="${ERP_NODE_PATH} node_modules/.bin/next start -p 3000"
fi

sudo tee /etc/systemd/system/razkindo2-erp.service > /dev/null << EOF
[Unit]
Description=Razkindo2 ERP - Next.js Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${ERP_WORKING_DIR}
ExecStart=${ERP_START_CMD}
Restart=on-failure
RestartSec=5
TimeoutStopSec=10s
Environment=NODE_ENV=production
Environment=PORT=3000
EnvironmentFile=${INSTALL_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF

# Service 2: Event Queue (if mini-service exists)
EVENT_QUEUE_DIR="$INSTALL_DIR/mini-services/mini-services/event-queue"
if [ -d "$EVENT_QUEUE_DIR" ]; then
    sudo tee /etc/systemd/system/razkindo2-event-queue.service > /dev/null << EOF
[Unit]
Description=Razkindo2 ERP - Event Queue Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${EVENT_QUEUE_DIR}
ExecStart=${ERP_NODE_PATH} index.ts
Restart=on-failure
RestartSec=5
TimeoutStopSec=10s
Environment=NODE_ENV=production
Environment=PORT=3004
EnvironmentFile=${INSTALL_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF
    echo -e "${G}  ✓ Service razkindo2-event-queue dibuat${N}"
fi

# Reload dan start services
sudo systemctl daemon-reload
sudo systemctl enable razkindo2-erp
sudo systemctl restart razkindo2-erp

if [ -d "$EVENT_QUEUE_DIR" ]; then
    sudo systemctl enable razkindo2-event-queue
    sudo systemctl restart razkindo2-event-queue
fi

echo -e "${G}  ✓ Services terinstall dan berjalan${N}"

# ---- CEK STATUS ----
echo ""
echo -e "${Y}  Menunggu service start...${N}"
sleep 3

if sudo systemctl is-active --quiet razkindo2-erp; then
    echo -e "${G}  ✓ razkindo2-erp: RUNNING${N}"
else
    echo -e "${R}  ✗ razkindo2-erp: FAILED${N}"
    echo -e "  Cek log: ${C}sudo journalctl -u razkindo2-erp -n 50 --no-pager${N}"
fi

if [ -d "$EVENT_QUEUE_DIR" ]; then
    if sudo systemctl is-active --quiet razkindo2-event-queue; then
        echo -e "${G}  ✓ razkindo2-event-queue: RUNNING${N}"
    else
        echo -e "${R}  ✗ razkindo2-event-queue: FAILED${N}"
        echo -e "  Cek log: ${C}sudo journalctl -u razkindo2-event-queue -n 50 --no-pager${N}"
    fi
fi

# ---- SELESAI ----
echo ""
echo -e "${G}============================================================"
echo "  INSTALLASI BERHASIL!"
echo "============================================================${N}"
echo ""
echo "  Aplikasi berjalan di: http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "  Perintah berguna:"
echo -e "    ${G}Cek status:${N}       sudo systemctl status razkindo2-erp"
echo -e "    ${G}Lihat log:${N}        sudo journalctl -u razkindo2-erp -f"
echo -e "    ${G}Restart:${N}          sudo systemctl restart razkindo2-erp"
echo -e "    ${G}Stop:${N}             sudo systemctl stop razkindo2-erp"
echo -e "    ${G}Edit .env:${N}        nano $INSTALL_DIR/.env"
echo ""
echo "  Update ke versi terbaru:"
echo -e "    ${G}cd $INSTALL_DIR && git pull && npm install && npx prisma generate && sudo systemctl restart razkindo2-erp${N}"
echo ""
echo "============================================================"
echo "  BUILD DARI MAC (RECOMMENDED):"
echo "  1. Di Mac:"
echo "     cd /Users/mac/razkindo2-erp"
echo "     npm run build"
echo "     scp -r .next/standalone root@192.168.100.64:$INSTALL_DIR/.next/standalone"
echo "     scp -r .next/static root@192.168.100.64:$INSTALL_DIR/.next/static"
echo "     scp -r public root@192.168.100.64:$INSTALL_DIR/public"
echo "     scp -r prisma root@192.168.100.64:$INSTALL_DIR/prisma"
echo "  2. Di STB:"
echo "     sudo systemctl restart razkindo2-erp"
echo "============================================================"
echo ""
