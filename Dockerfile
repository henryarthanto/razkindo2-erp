# ============================================================
# Razkindo2 ERP - Ultra-Optimized Docker Build (Low Storage)
# For AML S9xx TV Box / CasaOS with limited storage
#
# Menggunakan BuildKit cache mounts untuk hemat space:
#   DOCKER_BUILDKIT=1 docker compose up -d --build
# ============================================================

# syntax=docker/dockerfile:1

# ---- Stage 1: Dependencies (cached separately) ----
FROM node:20-alpine AS deps
WORKDIR /app

COPY package.json ./
COPY prisma ./prisma

# Cache mount: npm cache disimpan terpisah, tidak masuk image layer
RUN --mount=type=cache,target=/root/.npm,id=npm-cache \
    npm install && \
    npx prisma generate

# ---- Stage 2: Build ----
FROM node:20-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/prisma ./prisma
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max-old-space-size=512"

RUN npm run build && \
    rm -rf /tmp/*

# ---- Stage 3: Production (Minimal) ----
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Hanya copy yang diperlukan dari standalone output
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
