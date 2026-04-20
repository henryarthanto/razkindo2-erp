# ============================================================
# Razkindo2 ERP - Docker Build (Pre-installed deps)
# ============================================================
# STRATEGI: Install node_modules di HOST dulu, lalu copy ke Docker
#   Keuntungan: Bisa retry npm install kalau koneksi putus
#   Tanpa Docker: npm install gagal = ulang, gampang!
#
# Langkah di MacBook:
#   1. npm install
#   2. npx prisma generate
#   3. docker compose build
#   4. docker save razkindo2-erp-app:latest | gzip > erp-image.tar.gz
#   5. scp erp-image.tar.gz root@IP-STB:/tmp/
#
# Langkah di STB:
#   1. docker load < /tmp/erp-image.tar.gz
#   2. docker compose up -d
# ============================================================

FROM node:20-alpine AS builder
WORKDIR /app

# Copy semua termasuk node_modules dari host
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max-old-space-size=384"
RUN npm run build

# ---- Production ----
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

RUN chown -R nextjs:nodejs /app
USER nextjs

EXPOSE 3000
CMD ["node", "server.js"]
