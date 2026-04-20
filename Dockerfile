# ============================================================
# Razkindo2 ERP - Docker Build (Low Storage STB)
# Untuk AML S9xx TV Box / CasaOS
# Build: DOCKER_BUILDKIT=1 docker compose up -d --build
# ============================================================

# syntax=docker/dockerfile:1

FROM node:20-alpine AS builder
WORKDIR /app

# Copy package files dulu (layer caching)
COPY package.json ./
COPY prisma ./prisma

# Install deps + prisma generate + cleanup dalam 1 layer
RUN --mount=type=cache,target=/root/.npm \
    npm install && \
    npx prisma generate && \
    rm -rf /root/.npm/_cacache

# Copy source
COPY . .

# Build + cleanup dalam 1 layer
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

# Copy hanya file production dari standalone
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
