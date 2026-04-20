#!/bin/bash
# ============================================================
# Razkindo2 ERP - Update Langsung dari STB
# ============================================================
# Cara pakai:
#   cd /DATA/AppData/razkindo2-erp
#   chmod +x update-stb.sh
#   ./update-stb.sh
# ============================================================

set -e

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

echo ""
echo "============================================================"
echo "  Razkindo2 ERP - Update dari STB"
echo "============================================================"
echo ""

cd /DATA/AppData/razkindo2-erp

# ---- Step 1: Git pull ----
echo -e "${Y}[1/4] Update source code...${N}"
git pull || {
    echo -e "${R}  Git pull gagal! Cek koneksi internet${N}"
    exit 1
}
echo -e "${G}  ✓ Source code updated${N}"

# ---- Step 2: npm install di container (bisa retry) ----
echo ""
echo -e "${Y}[2/4] Install dependencies (di Docker container)...${N}"
echo -e "  ${R}Kalau gagal/putus, jalankan lagi script ini - npm akan lanjut dari cache${N}"

docker run --rm \
    -v $(pwd):/app \
    -w /app \
    node:20-alpine \
    sh -c "apk add --no-cache openssl && npm install && npx prisma generate && npm run build"

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${R}BUILD GAGAL! Kemungkinan koneksi putus.${N}"
    echo -e "  ${G}Ulangi: ./update-stb.sh${N}"
    echo -e "  ${G}npm akan lanjut dari cache, tidak download ulang${N}"
    exit 1
fi

echo -e "${G}  ✓ Build berhasil${N}"

# ---- Step 3: Build Docker image (cepat, cuma copy file) ----
echo ""
echo -e "${Y}[3/4] Build Docker image...${N}"
docker compose build

echo -e "${G}  ✓ Image updated${N}"

# ---- Step 4: Restart container ----
echo ""
echo -e "${Y}[4/4] Restart container...${N}"
docker compose down
docker compose up -d

echo ""
echo -e "${G}============================================================"
echo "  ✅ UPDATE BERHASIL!"
echo "============================================================${N}"
echo ""
echo "  Cek: docker compose logs -f"
echo ""
