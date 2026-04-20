# ============================================================
# Razkindo2 ERP - Docker Build
# ============================================================
# CARA 1: Build di device yang kuat (MacBook), lalu transfer
#   - Di MacBook: docker compose build
#   - Save: docker save razkindo2-erp-app:latest | gzip > erp-image.tar.gz
#   - Transfer: scp erp-image.tar.gz root@IP-STB:/tmp/
#   - Di STB: docker load < /tmp/erp-image.tar.gz
#
# CARA 2: Build langsung di STB (butuh koneksi stabil + 2GB)
#   DOCKER_BUILDKIT=1 docker compose up -d --build
# ============================================================

FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json ./
COPY prisma ./prisma

RUN npm install && npx prisma generate

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
