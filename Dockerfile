# ============================================================
# Razkindo2 ERP - Production Image
# Pre-built on host, Prisma generated inside Docker
# ============================================================

FROM node:20-alpine AS builder
WORKDIR /app

# Copy prisma schema & generate Linux ARM64 engine
COPY prisma ./prisma
RUN npm init -y && \
    npm install prisma @prisma/client && \
    npx prisma generate && \
    rm -rf /root/.npm

# ---- Production ----
FROM node:20-alpine
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs && \
    apk add --no-cache openssl

# Copy pre-built standalone output dari host
COPY .next/standalone ./
COPY .next/static ./.next/static
COPY public ./public
COPY prisma ./prisma

# Copy Prisma Linux ARM64 engine dari builder
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

RUN chown -R nextjs:nodejs /app
USER nextjs

EXPOSE 3000
CMD ["node", "server.js"]
