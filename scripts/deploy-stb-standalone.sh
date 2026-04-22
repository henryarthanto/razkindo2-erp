#!/bin/bash
# ============================================================
# Razkindo2 ERP - Clean Rebuild & Deploy to STB
# ============================================================
# Build on Mac (darwin-arm64), deploy to STB (linux-arm64)
#
# CARA PAKAI (dari Mac):
#   cd /Users/mac/razkindo2-erp
#   chmod +x scripts/deploy-stb-standalone.sh
#   ./scripts/deploy-stb-standalone.sh
#
# ATAU copy-paste perintah satu per satu
# ============================================================

set -e

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
C='\033[0;36m'
N='\033[0m'

STB_USER="root"
STB_HOST="192.168.100.64"
STB_PATH="/DATA/AppData/razkindo2-erp"
LOCAL_PATH="$(pwd)"

echo ""
echo "============================================================"
echo "  Razkindo2 ERP - Clean Build & Deploy ke STB"
echo "============================================================"
echo ""
echo -e "  Local : ${C}${LOCAL_PATH}${N}"
echo -e "  STB   : ${C}${STB_USER}@${STB_HOST}:${STB_PATH}${N}"
echo ""

# ---- Step 1: Clean build on Mac ----
echo -e "${Y}[1/5] Clean build di Mac...${N}"

echo "  Removing .next directory..."
rm -rf "${LOCAL_PATH}/.next"

echo "  Running npm run build..."
cd "${LOCAL_PATH}" && npm run build

if [ ! -f "${LOCAL_PATH}/.next/standalone/server.js" ]; then
    echo -e "${R}  BUILD GAGAL! standalone/server.js tidak ditemukan${N}"
    exit 1
fi

echo -e "${G}  ✓ Build berhasil${N}"

# ---- Step 2: Stop services on STB ----
echo ""
echo -e "${Y}[2/5] Stop services di STB...${N}"
ssh "${STB_USER}@${STB_HOST}" "
    systemctl stop razkindo2-erp 2>/dev/null || true
    systemctl stop razkindo2-event-queue 2>/dev/null || true
    fuser -k 3000/tcp 2>/dev/null || true
    fuser -k 3004/tcp 2>/dev/null || true
    echo 'Services stopped'
"
echo -e "${G}  ✓ Services stopped${N}"

# ---- Step 3: Transfer files to STB ----
echo ""
echo -e "${Y}[3/5] Transfer files ke STB (ini memakan waktu)...${N}"

# Clean old standalone on STB first
ssh "${STB_USER}@${STB_HOST}" "rm -rf ${STB_PATH}/.next/standalone"

# Transfer standalone build
echo "  Transfer .next/standalone/..."
rsync -az --delete "${LOCAL_PATH}/.next/standalone/" "${STB_USER}@${STB_HOST}:${STB_PATH}/.next/standalone/"

# Transfer static files (must be inside standalone)
echo "  Transfer .next/static/..."
rsync -az --delete "${LOCAL_PATH}/.next/static/" "${STB_USER}@${STB_HOST}:${STB_PATH}/.next/standalone/.next/static/"

# Transfer public folder
echo "  Transfer public/..."
rsync -az --delete "${LOCAL_PATH}/public/" "${STB_USER}@${STB_HOST}:${STB_PATH}/.next/standalone/public/"

# Transfer prisma schema & migrations
echo "  Transfer prisma/..."
rsync -az "${LOCAL_PATH}/prisma/" "${STB_USER}@${STB_HOST}:${STB_PATH}/prisma/"

# Transfer mini-services (event-queue)
echo "  Transfer mini-services/..."
rsync -az "${LOCAL_PATH}/mini-services/" "${STB_USER}@${STB_HOST}:${STB_PATH}/mini-services/"

# Transfer package.json for prisma generate
echo "  Transfer package.json..."
scp "${LOCAL_PATH}/package.json" "${STB_USER}@${STB_HOST}:${STB_PATH}/package.json"

echo -e "${G}  ✓ Transfer selesai${N}"

# ---- Step 4: Setup on STB ----
echo ""
echo -e "${Y}[4/5] Setup Prisma & .env di STB...${N}"
ssh "${STB_USER}@${STB_HOST}" "
    cd ${STB_PATH}

    # Ensure .env exists in standalone directory
    if [ ! -f .next/standalone/.env ]; then
        if [ -f .env ]; then
            cp .env .next/standalone/.env
            echo 'Copied .env to standalone directory'
        else
            echo 'WARNING: .env not found! You need to create it manually'
        fi
    fi

    # Generate Prisma client for linux-arm64
    echo 'Generating Prisma client for linux-arm64...'
    cd ${STB_PATH}
    npx prisma generate --schema=prisma/schema.prisma 2>&1

    echo 'Setup complete'
"
echo -e "${G}  ✓ Setup selesai${N}"

# ---- Step 5: Start services on STB ----
echo ""
echo -e "${Y}[5/5] Start services di STB...${N}"
ssh "${STB_USER}@${STB_HOST}" "
    systemctl start razkindo2-event-queue
    sleep 2
    systemctl start razkindo2-erp
    sleep 3

    echo ''
    echo '=== STATUS ==='
    systemctl is-active razkindo2-erp || echo 'razkindo2-erp: FAILED'
    systemctl is-active razkindo2-event-queue || echo 'razkindo2-event-queue: FAILED'
    echo ''
    echo '=== RECENT LOGS ==='
    journalctl -u razkindo2-erp --no-pager -n 20
"
echo ""
echo -e "${G}============================================================"
echo "  DEPLOY SELESAI!"
echo "============================================================${N}"
echo ""
echo -e "  Akses: ${C}http://${STB_HOST}:3000${N}"
echo ""
echo -e "  Cek log:"
echo -e "    ${G}ssh ${STB_USER}@${STB_HOST} 'journalctl -u razkindo2-erp -f'${N}"
echo ""
echo -e "  Jika error, cek log lengkap:"
echo -e "    ${G}ssh ${STB_USER}@${STB_HOST} 'journalctl -u razkindo2-erp --no-pager -n 50'${N}"
echo ""
