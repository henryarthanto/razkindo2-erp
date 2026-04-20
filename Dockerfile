# ============================================================
# Razkindo2 ERP - Minimal Production Image
# Hanya copy pre-built output, TIDAK ada build di dalam Docker
#
# Langkah di MacBook:
#   1. npm install
#   2. npx prisma generate
#   3. npm run build
#   4. docker compose build
#   5. docker save razkindo2-erp:latest | gzip > erp-image.tar.gz
#   6. scp erp-image.tar.gz root@IP-STB:/tmp/
#
# Langkah di STB:
#   1. docker load < /tmp/erp-image.tar.gz
#   2. docker compose up -d
# ============================================================

FROM node:20-alpine
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy pre-built standalone output dari host
COPY .next/standalone ./
COPY .next/static ./.next/static
COPY public ./public
COPY prisma ./prisma

# Install Linux ARM64 native binaries yang diperlukan runtime
RUN apk add --no-cache openssl && \
    npm install @prisma/client prisma lightningcss-linux-arm64-musl @next/swc-linux-arm64-musl sharp --no-save 2>/dev/null || true

RUN chown -R nextjs:nodejs /app
USER nextjs

EXPOSE 3000
CMD ["node", "server.js"]
