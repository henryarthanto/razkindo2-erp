---
Task ID: 1
Agent: Main Agent
Task: Comprehensive WebSocket, Supabase optimization, and bug audit for Razkindo ERP

Work Log:
- Explored entire codebase to understand WebSocket/Socket.io architecture
- Identified WebSocket root cause: XTransformPort pattern requires Caddy gateway, not available on STB
- Fixed use-websocket.ts: Auto-detect environment, fallback from XTransformPort to direct port 3004
- Fixed event-queue/index.ts: Added NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY fallback for correct DB key
- Optimized connection-pool.ts: Reduced pool sizes (tx: 20→10, session: 5→3), made configurable via env vars
- Fixed auth-secret.ts: Multi-path search for standalone mode (cwd, ../, ../../, /DATA/AppData/razkindo2-erp/)
- Created src/lib/paths.ts: Project path resolver for standalone mode compatibility
- Fixed system route auth bugs (BUG-1,2,3,4): Added auth to /api/system/consistency, /api/system/queue-health, restricted /api/health, /api/system-stats
- Fixed .single() → .maybeSingle() on key routes: token.ts, require-auth.ts, setup-schema
- Fixed process.cwd() for standalone mode: setup-schema, payment proof upload, cleanup
- Fixed busy-wait CPU measurement in system-stats: while loop → await setTimeout
- Fixed unbounded user cache in token.ts: Added max size (1000) with LRU-like eviction
- Payments route already had optimistic concurrency protection (.eq('paid_amount', expectedPaidAmount))

Stage Summary:
- 12 files modified with bug fixes and optimizations
- WebSocket now auto-detects environment (XTransformPort vs direct port)
- Database connection pool optimized for low-memory STB
- Auth system hardened for standalone mode
- Critical security fixes on system API routes
- Code passes lint cleanly
