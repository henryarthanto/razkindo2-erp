---
Task ID: 1
Agent: Main
Task: Comprehensive WebSocket fix, Supabase optimization, and bug audit

Work Log:
- Investigated WebSocket/Socket.io architecture: event-queue service on port 3004, ws-dispatch.ts, use-websocket.ts
- Audited 90+ Supabase queries for optimization opportunities
- Found 26 bugs across all severity levels
- Fixed WebSocket presence:update event (server never emitted it)
- Removed hardcoded WS_SECRET fallback from ws-dispatch.ts and event-queue
- Made event-queue URL configurable via EVENT_QUEUE_URL env var
- Fixed NetworkStatusIndicator event listener memory leak
- Removed NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY fallback (security risk)
- Added authentication to migrate-user-units endpoint
- Added authentication to AI chat DELETE endpoint
- Fixed AUTH_SECRET to fail in production if not set
- Fixed login rate limiter unbounded memory growth
- Added missing Prisma indexes (debtId, receivableId, receivedById, paidAt, unitId, type, composite type+paymentStatus)
- Fixed N+1 queries in transaction cancel route (batch-fetched unit_products)
- Updated .env with WS_SECRET and EVENT_QUEUE_URL
- Updated .env.example with new variables
- Removed undocumented socket.io internal API usage in use-websocket.ts
- Pushed Prisma schema to database

Stage Summary:
- WebSocket root cause: event-queue service not running + presence:update never emitted + hardcoded secrets
- All 5 critical bugs fixed
- 7 new Prisma indexes added for query optimization
- N+1 query eliminated in transaction cancel route
- Services verified working (Next.js on 3000, event-queue on 3004)

---
Task ID: 2
Agent: Main
Task: Fix TypeError crash on STB deployment and create clean deployment script

Work Log:
- Analyzed TypeError: Cannot read properties of undefined (reading 'map') crash on STB
- Identified root cause: rowsToCamelCase() in supabase-helpers.ts calls .map() without null guard
- Fixed rowsToCamelCase() to accept null/undefined and return [] defensively
- Added global uncaughtException/unhandledRejection handlers in instrumentation.ts for better crash diagnostics
- Enhanced instrumentation.ts with per-step logging to identify which service fails
- Created scripts/deploy-stb-standalone.sh for automated Mac→STB deployment
- Verified lint passes (only 1 minor warning)
- Verified dev server starts correctly with new instrumentation

Stage Summary:
- rowsToCamelCase() now defensive against null/undefined input (fixes root crash cause)
- Global error handlers added for production stack traces (fixes "ignore-listed frames" issue)
- Deploy script created at scripts/deploy-stb-standalone.sh
- User needs to: git pull on Mac → clean rebuild → re-transfer to STB
