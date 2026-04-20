# ============================================================
# Razkindo2 ERP - Single-stage Docker Build (Low Storage)
# Optimized for AML S9xx TV Box / CasaOS with limited storage
# ============================================================

FROM node:20-alpine
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy only what's needed first (for better cache)
COPY package.json ./
COPY prisma ./prisma

# Install dependencies & clean cache in ONE layer to save space
RUN npm install --omit=dev --no-optional && \
    npx prisma generate && \
    npm cache clean --force && \
    rm -rf /tmp/* /root/.npm

# Copy source code
COPY . .

# Build Next.js standalone
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build && \
    rm -rf /root/.npm /tmp/* && \
    rm -rf node_modules && \
    cp -r .next/standalone/node_modules . 2>/dev/null; \
    echo "Build done"

# Production settings
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

EXPOSE 3000

CMD ["node", "server.js"]
