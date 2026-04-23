#!/bin/bash
# ============================================================
# Razkindo2 ERP - Build & Deploy Script (Mac → STB)
# Build on Mac (darwin-arm64), deploy to STB (linux-arm64)
# ============================================================
# CARA PAKAI:
#   ./deploy-to-stb.sh          # Build + deploy
#   ./deploy-to-stb.sh --build-only  # Build saja, tidak deploy
#   ./deploy-to-stb.sh --deploy-only # Deploy saja (harus sudah build)
# ============================================================

set -e

STB_HOST="${STB_HOST:-root@192.168.100.64}"
STB_DIR="${STB_DIR:-/DATA/AppData/razkindo2-erp}"

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
C='\033[0;36m'
N='\033[0m'

echo ""
echo "============================================================"
echo "  Razkindo2 ERP - Build & Deploy (Mac → STB)"
echo "  Target: $STB_HOST:$STB_DIR"
echo "============================================================"
echo ""

# ---- BUILD ----
if [ "$1" != "--deploy-only" ]; then
    echo -e "${Y}[1/3] Building Next.js standalone...${N}"
    
    # Pastikan .env ada
    if [ ! -f ".env" ]; then
        echo -e "${R}  ERROR: File .env tidak ditemukan!${N}"
        echo "  Buat .env dulu atau copy dari .env.example"
        exit 1
    fi

    # Generate Prisma client (dengan binaryTargets untuk linux-arm64)
    echo -e "${Y}  Generating Prisma client...${N}"
    npx prisma generate
    
    # Build Next.js
    echo -e "${Y}  Building Next.js...${N}"
    npm run build
    
    # Copy .env ke standalone
    echo -e "${Y}  Copying .env ke standalone...${N}"
    cp .env .next/standalone/.env
    
    # Copy Prisma ke standalone
    echo -e "${Y}  Copying Prisma schema ke standalone...${N}"
    mkdir -p .next/standalone/prisma
    cp prisma/schema.prisma .next/standalone/prisma/
    
    # Install production deps di standalone
    echo -e "${Y}  Installing production dependencies...${N}"
    cd .next/standalone
    npm install --production 2>&1 || true
    cd ../..
    
    echo -e "${G}  ✓ Build selesai${N}"
else
    echo -e "${Y}[1/3] Skip build (--deploy-only)${N}"
fi

# ---- DEPLOY ----
if [ "$1" != "--build-only" ]; then
    echo ""
    echo -e "${Y}[2/3] Deploying ke STB ($STB_HOST:$STB_DIR)...${N}"
    
    # Cek SSH connection
    echo -e "${Y}  Cek koneksi SSH...${N}"
    ssh -o ConnectTimeout=5 "$STB_HOST" "echo 'OK'" || {
        echo -e "${R}  ERROR: Tidak bisa connect ke $STB_HOST${N}"
        echo "  Pastikan STB bisa di-SSH dari Mac ini"
        exit 1
    }
    
    # Buat direktori di STB
    ssh "$STB_HOST" "mkdir -p $STB_DIR/.next $STB_DIR/public $STB_DIR/prisma $STB_DIR/data/uploads"
    
    # Deploy files
    echo -e "${Y}  Deploying standalone build...${N}"
    scp -r .next/standalone "$STB_HOST:$STB_DIR/.next/"
    
    echo -e "${Y}  Deploying static files...${N}"
    scp -r .next/static "$STB_HOST:$STB_DIR/.next/"
    
    echo -e "${Y}  Deploying public files...${N}"
    scp -r public "$STB_HOST:$STB_DIR/" 2>/dev/null || true
    
    echo -e "${Y}  Deploying Prisma schema...${N}"
    scp -r prisma "$STB_HOST:$STB_DIR/"
    
    echo -e "${Y}  Deploying .env...${N}"
    scp .env "$STB_HOST:$STB_DIR/.env"
    
    echo -e "${G}  ✓ Deploy selesai${N}"
    
    # ---- RESTART SERVICE ----
    echo ""
    echo -e "${Y}[3/3] Restarting services di STB...${N}"
    
    # Generate Prisma client di STB (untuk linux-arm64 binary)
    ssh "$STB_HOST" "cd $STB_DIR && npx prisma generate 2>&1 || echo 'Prisma generate skipped'"
    
    # Push schema ke Supabase
    ssh "$STB_HOST" "cd $STB_DIR && npx prisma db push --accept-data-loss 2>&1 || echo 'DB push skipped (tables may already exist)'"
    
    # Copy generated Prisma client ke standalone
    ssh "$STB_HOST" "cp -r $STB_DIR/node_modules/.prisma $STB_DIR/.next/standalone/node_modules/ 2>/dev/null || true"
    ssh "$STB_HOST" "cp -r $STB_DIR/node_modules/@prisma $STB_DIR/.next/standalone/node_modules/ 2>/dev/null || true"
    
    # Restart systemd service
    ssh "$STB_HOST" "sudo systemctl daemon-reload && sudo systemctl restart razkindo2-erp && sudo systemctl restart razkindo2-event-queue 2>/dev/null || true"
    
    echo -e "${G}  ✓ Services di-restart${N}"
    
    # Cek status
    sleep 3
    echo ""
    echo -e "${Y}  Status services:${N}"
    ssh "$STB_HOST" "sudo systemctl is-active razkindo2-erp && echo '  ✓ razkindo2-erp: RUNNING' || echo '  ✗ razkindo2-erp: FAILED'"
    ssh "$STB_HOST" "sudo systemctl is-active razkindo2-event-queue 2>/dev/null && echo '  ✓ event-queue: RUNNING' || echo '  - event-queue: N/A'"
else
    echo -e "${Y}[2/3][3/3] Skip deploy (--build-only)${N}"
fi

echo ""
echo -e "${G}============================================================"
echo "  SELESAI!"
echo "============================================================${N}"
echo ""
echo "  Aplikasi: http://192.168.100.64:3000"
echo ""
echo "  Cek log di STB:"
echo "    ssh $STB_HOST 'sudo journalctl -u razkindo2-erp -f'"
echo ""
