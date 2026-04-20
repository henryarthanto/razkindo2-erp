#!/bin/bash
# ============================================================
# Razkindo2 ERP - 2-Step Build Script (Hemat Storage)
# Untuk device dengan storage terbatas (TV Box, CasaOS)
#
# Cara kerja:
#   Step 1: Build di container sementara, extract output ke host
#   Step 2: Hapus container & image build (bebaskan space)
#   Step 3: Build image minimal dari output yang sudah di-extract
#
# Hasil: Image production ~150MB (vs ~1.5GB jika build biasa)
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "============================================================"
echo "  🔧 Razkindo2 ERP - 2-Step Build (Low Storage Mode)"
echo "============================================================"
echo ""

# Cek .env
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: File .env tidak ditemukan!${NC}"
    echo "  Jalankan: cp .env.example .env && nano .env"
    exit 1
fi

# Cek space kosong
FREE_MB=$(df -m . | tail -1 | awk '{print $4}')
echo -e "${YELLOW}Storage kosong: ${FREE_MB}MB${NC}"

if [ "$FREE_MB" -lt 1500 ]; then
    echo -e "${RED}WARNING: Storage kurang dari 1.5GB!${NC}"
    echo "  Coba jalankan: docker system prune -a --volumes -f"
    echo ""
    read -p "  Lanjutkan meskipun storage rendah? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Bersihkan Docker cache dulu
echo -e "${YELLOW}[0/3] Membersihkan Docker cache...${NC}"
docker system prune -f 2>/dev/null || true
echo -e "${GREEN}  ✓ Docker cache dibersihkan${NC}"

# ---- Step 1: Build di container sementara ----
echo ""
echo -e "${YELLOW}[1/3] Building aplikasi di container sementara...${NC}"
echo "  (Ini memakan space sementara, akan dibersihkan di step 2)"

DOCKER_BUILDKIT=1 docker build \
    -t razkindo2-build-temp \
    -f Dockerfile \
    .

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Build gagal!${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Build berhasil${NC}"

# ---- Step 2: Extract output & bersihkan ----
echo ""
echo -e "${YELLOW}[2/3] Extract output & bersihkan container build...${NC}"

# Buat folder dist
rm -rf dist
mkdir -p dist/.next

# Extract dari container
CONTAINER_ID=$(docker create razkindo2-build-temp)

docker cp ${CONTAINER_ID}:/app/.next/standalone/. dist/ 2>/dev/null || {
    echo -e "${RED}ERROR: Gagal extract standalone output${NC}"
    echo "  Pastikan next.config.ts memiliki output: 'standalone'"
    docker rm ${CONTAINER_ID} >/dev/null
    exit 1
}

# Copy static files ke tempat yang benar
docker cp ${CONTAINER_ID}:/app/.next/static dist/.next/static 2>/dev/null || true
docker cp ${CONTAINER_ID}:/app/public dist/public 2>/dev/null || mkdir -p dist/public
docker cp ${CONTAINER_ID}:/app/prisma dist/prisma 2>/dev/null || true
docker cp ${CONTAINER_ID}:/app/node_modules/.prisma dist/node_modules/.prisma 2>/dev/null || true
docker cp ${CONTAINER_ID}:/app/node_modules/@prisma dist/node_modules/@prisma 2>/dev/null || true

# Hapus container & image build
docker rm ${CONTAINER_ID} >/dev/null
docker rmi razkindo2-build-temp >/dev/null 2>&1 || true
docker system prune -f >/dev/null 2>&1 || true

echo -e "${GREEN}  ✓ Output di-extract ke dist/"
echo "  ✓ Container build dibersihkan (space dikembalikan)${NC}"

# ---- Step 3: Build image minimal ----
echo ""
echo -e "${YELLOW}[3/3] Building image production minimal...${NC}"

docker build \
    -t razkindo2-erp:latest \
    -f Dockerfile.prod \
    .

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Build image production gagal!${NC}"
    exit 1
fi

# Bersihkan dist folder
rm -rf dist

echo ""
echo -e "${GREEN}============================================================"
echo "  ✅ BUILD BERHASIL!"
echo "============================================================${NC}"
echo ""
echo "  Image size:"
docker images razkindo2-erp:latest --format "  {{.Repository}}:{{.Tag}} - {{.Size}}"
echo ""
echo "  Untuk menjalankan:"
echo -e "  ${GREEN}docker compose up -d${NC}"
echo ""
