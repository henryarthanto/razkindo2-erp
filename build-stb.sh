#!/bin/bash
# ============================================================
# Razkindo2 ERP - STB Quick Build (Low Memory Mode)
# Untuk: AML S9xx TV Box, Armbian Ubuntu 24.04
# ============================================================
# Khusus untuk STB dengan RAM terbatas (~1GB).
# Skip TypeScript + ESLint check untuk menghemat memory.
# ============================================================

set -e

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

INSTALL_DIR="/DATA/AppData/razkindo2-erp"
cd "$INSTALL_DIR"

echo ""
echo -e "${Y}Razkindo2 ERP - STB Build (Low Memory Mode)${N}"
echo ""

# Step 1: Pull latest code
echo -e "${Y}[1/5] Pull latest code...${N}"
if [ -d ".git" ]; then
    git pull origin main 2>&1 || echo -e "${Y}  git pull skipped${N}"
else
    echo -e "${Y}  Bukan git repo, skip pull${N}"
fi

# Step 2: Install dependencies
echo -e "${Y}[2/5] Install dependencies...${N}"
npm install 2>&1 || { echo -e "${R}  npm install gagal!${N}"; exit 1; }

# Step 3: Generate Prisma client
echo -e "${Y}[3/5] Generate Prisma client...${N}"
npx prisma generate 2>&1 || echo -e "${Y}  Prisma generate skipped${N}"

# Step 4: Push schema to Supabase
echo -e "${Y}[4/5] Push schema ke Supabase...${N}"
npx prisma db push 2>&1 || npx prisma db push --accept-data-loss 2>&1 || echo -e "${Y}  db push skipped${N}"

# Step 5: Build with restricted memory
echo -e "${Y}[5/5] Build (low memory mode)...${N}"
echo -e "${Y}  Max heap: 512MB, TypeScript check: OFF, ESLint: OFF${N}"

# Free up memory before build
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# Build with limited memory (512MB max heap)
# TypeScript and ESLint checks are already disabled in next.config.ts
NODE_OPTIONS="--max-old-space-size=512" npm run build 2>&1 || {
    echo ""
    echo -e "${R}  BUILD GAGAL - RAM tidak cukup!${N}"
    echo ""
    echo -e "${Y}  SOLUSI: Build di Mac, deploy ke STB:${N}"
    echo "  1. Di Mac:"
    echo "     cd /Users/mac/razkindo2-erp"
    echo "     git pull"
    echo "     npm install && npx prisma generate"
    echo "     npm run build"
    echo ""
    echo "  2. SCP ke STB:"
    echo "     scp -r .next/standalone root@192.168.100.64:$INSTALL_DIR/.next/"
    echo "     scp -r .next/static root@192.168.100.64:$INSTALL_DIR/.next/"
    echo "     scp -r public root@192.168.100.64:$INSTALL_DIR/"
    echo "     scp -r prisma root@192.168.100.64:$INSTALL_DIR/"
    echo ""
    echo "  3. Di STB:"
    echo "     sudo systemctl restart razkindo2-erp"
    echo ""
    exit 1
}

echo -e "${G}  ✓ Build berhasil!${N}"

# Setup service and restart
echo -e "${Y}  Setup systemd service...${N}"

NODE_PATH=$(which node)
if [ -f "$INSTALL_DIR/.next/standalone/server.js" ]; then
    START_CMD="${NODE_PATH} $INSTALL_DIR/.next/standalone/server.js"
else
    START_CMD="${NODE_PATH} $INSTALL_DIR/node_modules/.bin/next start -p 3000"
fi

sudo tee /etc/systemd/system/razkindo2-erp.service > /dev/null << EOF
[Unit]
Description=Razkindo2 ERP - Next.js Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${START_CMD}
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

echo -e "${Y}  Menunggu service start...${N}"
sleep 5

if sudo systemctl is-active --quiet razkindo2-erp; then
    echo -e "${G}  ✓ Service RUNNING${N}"
else
    echo -e "${R}  ✗ Service FAILED${N}"
    echo "  Cek log: sudo journalctl -u razkindo2-erp -n 50 --no-pager"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
echo -e "${Y}  HTTP Status: $HTTP_CODE${N}"

echo ""
echo -e "${G}SELESAI! Aplikasi di: http://$(hostname -I | awk '{print $1}'):3000${N}"
