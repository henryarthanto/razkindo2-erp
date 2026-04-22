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

---
Task ID: 3
Agent: Main
Task: Fix all remaining bugs and prepare clean deployment

Work Log:
- Verified all 14 documented bugs (BUG 1-14) are already fixed in current codebase
- BUG 1 (courier/deliver p_amount→p_delta): Already fixed - line 171 uses p_delta
- BUG 2 (courier/handover RPC signature): Already fixed - handler accepts p_courier_id, p_unit_id, p_amount, p_processed_by_id, p_notes
- BUG 3 (products/[id]/stock increment_unit_stock): Already fixed - looks up unit_product_id first
- BUG 4 (finance/requests p_cost_per_unit→p_new_hpp): Already fixed - line 386 uses p_new_hpp
- BUG 5 (products POST camelCase→snake_case): Already fixed - uses sub_unit, conversion_rate, purchase_price
- BUG 6 (pwa/[code] cashback columns): Already fixed - fetches from cashback_config table
- BUG 7 (toCamelCase null): Already fixed - returns null instead of {}
- BUG 8 (txTimer.stop twice): Checked - only called in finally blocks
- BUG 9 (subUnit in select): Already fixed - uses sub_unit, conversion_rate in select strings
- BUG 10 (requireAuth export): Already exported
- BUG 11 (purchasePrice): Already included in insert
- BUG 12 (validators auth schemas): Already fixed - uses phone not email
- BUG 13 (generateInvoiceNo shadow): Uses generateLocalInvoiceNo with different prefix
- BUG 14 (register validation): registerNonErp schema already exists
- Verified all RPC functions are handled locally via Prisma (supabase.ts)
- Build successful, lint clean (1 minor warning only)
- Root cause of "semuanya belum" is missing database tables in Supabase

Stage Summary:
- All 14 bugs confirmed fixed in code
- Main deployment issue: database tables not synced (prisma db push needed on STB)
- Build successful - ready for deployment
- User needs to: run prisma db push on STB to create missing tables
