#!/bin/bash
# ============================================================
# Razkindo2 ERP - Mac Build & Deploy to STB
# ============================================================
# Build on Mac (darwin-arm64), deploy standalone to STB (linux-arm64)
#
# CARA PAKAI:
#   ./build-mac.sh           # Build only
#   ./build-mac.sh deploy    # Build + deploy to STB
#   ./build-mac.sh restart   # Deploy + restart service on STB
# ============================================================

set -e

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
C='\033[0;36m'
N='\033[0m'

STB_HOST="root@192.168.100.64"
STB_DIR="/DATA/AppData/razkindo2-erp"
MODE="${1:-build}"

echo ""
echo -e "${C}============================================================"
echo "  Razkindo2 ERP - Mac Build & Deploy"
echo "  Mode: $MODE"
echo -e "============================================================${N}"
echo ""

# ---- STEP 1: PULL LATEST CODE ----
echo -e "${Y}[1/4] Pull latest code dari GitHub...${N}"
git pull origin main || { echo -e "${Y}  git pull skipped (no remote or offline)${N}"; }
echo -e "${G}  ✓ Code up to date${N}"

# ---- STEP 2: INSTALL DEPS ----
echo ""
echo -e "${Y}[2/4] Install dependencies...${N}"
npm install 2>&1 || { echo -e "${R}  npm install gagal!${N}"; exit 1; }
echo -e "${G}  ✓ Dependencies terinstall${N}"

# ---- STEP 3: GENERATE PRISMA CLIENT ----
echo ""
echo -e "${Y}[3/4] Generate Prisma client...${N}"
npx prisma generate 2>&1 || { echo -e "${R}  Prisma generate gagal!${N}"; exit 1; }
echo -e "${G}  ✓ Prisma client generated${N}"

# ---- STEP 4: BUILD ----
echo ""
echo -e "${Y}[4/4] Build standalone...${N}"
echo -e "${Y}  (TypeScript + ESLint checks disabled for faster build)${N}"
NODE_OPTIONS="--max-old-space-size=4096" npm run build 2>&1 || { echo -e "${R}  Build gagal!${N}"; exit 1; }
echo -e "${G}  ✓ Build berhasil${N}"

# ---- CHECK STANDALONE OUTPUT ----
if [ ! -d ".next/standalone" ]; then
    echo -e "${R}  ERROR: .next/standalone tidak ditemukan!${N}"
    echo -e "  Pastikan next.config.ts punya: output: 'standalone'"
    exit 1
fi

echo -e "${G}  ✓ Standalone build siap di .next/standalone/${N}"

# ---- DEPLOY TO STB ----
if [ "$MODE" = "deploy" ] || [ "$MODE" = "restart" ]; then
    echo ""
    echo -e "${C}============================================================"
    echo "  DEPLOY KE STB: $STB_HOST"
    echo -e "============================================================${N}"
    echo ""

    # Check SSH connectivity
    echo -e "${Y}[*] Cek koneksi SSH ke STB...${N}"
    ssh -o ConnectTimeout=5 -o BatchMode=yes "$STB_HOST" "echo ok" &>/dev/null || {
        echo -e "${R}  ERROR: Tidak bisa SSH ke $STB_HOST${N}"
        echo -e "  Pastikan:"
        echo -e "    1. STB dan Mac di jaringan yang sama"
        echo -e "    2. SSH key sudah di-copy: ssh-copy-id $STB_HOST"
        echo -e "    3. STB bisa di-ping: ping 192.168.100.64"
        exit 1
    }
    echo -e "${G}  ✓ Koneksi SSH OK${N}"

    # Stop service on STB
    echo -e "${Y}  Stopping service di STB...${N}"
    ssh "$STB_HOST" "systemctl stop razkindo2-erp 2>/dev/null || true"
    
    # Deploy standalone build
    echo -e "${Y}  Deploy standalone build...${N}"
    ssh "$STB_HOST" "mkdir -p $STB_DIR/.next"
    scp -r .next/standalone "$STB_HOST:$STB_DIR/.next/"
    scp -r .next/static "$STB_HOST:$STB_DIR/.next/"
    
    # Deploy public folder
    echo -e "${Y}  Deploy public folder...${N}"
    scp -r public "$STB_HOST:$STB_DIR/"
    
    # Deploy prisma schema
    echo -e "${Y}  Deploy prisma schema...${N}"
    ssh "$STB_HOST" "mkdir -p $STB_DIR/prisma"
    scp prisma/schema.prisma "$STB_HOST:$STB_DIR/prisma/"
    
    # Deploy package.json (for prisma generate)
    scp package.json "$STB_HOST:$STB_DIR/"

    # Install production deps on STB (minimal, for prisma)
    echo -e "${Y}  Install production deps di STB...${N}"
    ssh "$STB_HOST" "cd $STB_DIR && npm install --production 2>&1 || true"

    # Generate Prisma client on STB
    echo -e "${Y}  Generate Prisma client di STB...${N}"
    ssh "$STB_HOST" "cd $STB_DIR && npx prisma generate 2>&1 || true"
    
    # Push schema to Supabase from STB
    echo -e "${Y}  Push schema ke Supabase...${N}"
    ssh "$STB_HOST" "cd $STB_DIR && npx prisma db push 2>&1 || true"

    # Ensure .env exists on STB
    echo -e "${Y}  Cek .env di STB...${N}"
    ssh "$STB_HOST" "test -f $STB_DIR/.env && echo '.env OK' || echo 'PERLU .env!'"

    # Setup systemd service if not exists
    echo -e "${Y}  Setup systemd service...${N}"
    ssh "$STB_HOST" << 'REMOTE_SCRIPT'
# Detect correct start command
if [ -f "/DATA/AppData/razkindo2-erp/.next/standalone/server.js" ]; then
    START_CMD="$(which node) /DATA/AppData/razkindo2-erp/.next/standalone/server.js"
else
    START_CMD="$(which node) /DATA/AppData/razkindo2-erp/node_modules/.bin/next start -p 3000"
fi

cat > /etc/systemd/system/razkindo2-erp.service << SVC
[Unit]
Description=Razkindo2 ERP - Next.js Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/DATA/AppData/razkindo2-erp
ExecStart=$START_CMD
Restart=on-failure
RestartSec=5
TimeoutStopSec=10s
Environment=NODE_ENV=production
Environment=PORT=3000
EnvironmentFile=/DATA/AppData/razkindo2-erp/.env

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable razkindo2-erp
REMOTE_SCRIPT

    echo -e "${G}  ✓ Systemd service dikonfigurasi${N}"

    if [ "$MODE" = "restart" ]; then
        echo -e "${Y}  Starting service...${N}"
        ssh "$STB_HOST" "systemctl restart razkindo2-erp"
        sleep 5
        
        # Check status
        echo ""
        ssh "$STB_HOST" << 'CHECK_SCRIPT'
if systemctl is-active --quiet razkindo2-erp; then
    echo -e "\033[0;32m  ✓ razkindo2-erp: RUNNING\033[0m"
else
    echo -e "\033[0;31m  ✗ razkindo2-erp: FAILED\033[0m"
    echo "  Cek log: journalctl -u razkindo2-erp -n 50 --no-pager"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "\033[0;32m  ✓ HTTP 200 - App berjalan!\033[0m"
else
    echo -e "\033[0;31m  ✗ HTTP $HTTP_CODE - App belum siap\033[0m"
fi
CHECK_SCRIPT
    fi

    echo ""
    echo -e "${G}============================================================"
    echo "  DEPLOY SELESAI!"
    echo -e "============================================================${N}"
    echo ""
    echo "  Aplikasi STB: http://192.168.100.64:3000"
    echo ""
    echo "  Perintah STB:"
    echo -e "    ${G}Status:${N}   ssh $STB_HOST 'systemctl status razkindo2-erp'"
    echo -e "    ${G}Log:${N}     ssh $STB_HOST 'journalctl -u razkindo2-erp -f'"
    echo -e "    ${G}Restart:${N} ssh $STB_HOST 'systemctl restart razkindo2-erp'"
    echo ""
fi
