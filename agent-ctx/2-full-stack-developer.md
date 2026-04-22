# Task 2: Fix Razkindo2 ERP Application — Work Log

## Agent: full-stack-developer
## Date: 2026-04-22

## Summary
Fixed multiple issues in the Razkindo2 ERP application to make it resilient when the direct PostgreSQL connection to Supabase is unavailable.

## Changes Made

### 1. Made `ensure-rpc` Resilient (`src/lib/ensure-rpc.ts`)
- **Problem**: The `ensure-rpc` function tried to connect to PostgreSQL using the `pg` module. When the connection failed (ENETUNREACH), it logged an error but the error message was not helpful. Also, if the `pg` module wasn't installed, the import would crash.
- **Fix**: 
  - Added graceful handling for missing `pg` module (try/catch around dynamic import)
  - Reduced `connectionTimeoutMillis` from 15s to 5s to avoid slow startup
  - Changed the "All connection methods failed" error from `console.error` to `console.warn` with a helpful message explaining that local Prisma-backed RPC handlers will be used instead

### 2. Switched Prisma Schema to SQLite (`prisma/schema.prisma`)
- **Problem**: Prisma schema was configured for PostgreSQL (`provider = "postgresql"`) with remote Supabase connection strings. When the direct DB connection was unavailable, Prisma couldn't connect at all, making the local RPC handlers non-functional.
- **Fix**: 
  - Changed `provider` from `"postgresql"` to `"sqlite"`
  - Removed `directUrl` (not needed for SQLite)
  - Updated `DATABASE_URL` in `.env` to `file:./db/custom.db`
  - Ran `bun run db:push` successfully — all tables created in local SQLite
  - Binary targets already included: `["native", "linux-arm64-openssl-3.0.x", "linux-musl-arm64-openssl-3.0.x", "linux-musl-arm64-openssl-1.1.x", "darwin-arm64"]`

### 3. Fixed `supabase-helpers.ts` (`src/lib/supabase-helpers.ts`)
- **Problem**: `createLog()` and `createEvent()` functions didn't include the `id` field in their Supabase REST API inserts. Since `@default(cuid())` only works at the Prisma client level (not at the database level), inserts via the Supabase REST API would fail without an explicit `id`.
- **Fix**: 
  - Added `id: generateId()` to both `createLog()` and `createEvent()` insert operations
  - Updated `generateId()` documentation to explain the difference between Prisma's CUID defaults and manual ID generation for REST API inserts

### 4. Fixed `instrumentation.ts` Edge Runtime Warning
- **Problem**: `process.on('uncaughtException')` and `process.on('unhandledRejection')` were at the top level of `instrumentation.ts`, which runs in both Node.js and Edge Runtime. These Node.js APIs are not available in the Edge Runtime, causing warnings.
- **Fix**: Moved the `process.on` handlers inside the `register()` function, within the `process.env.NEXT_RUNTIME === 'nodejs'` guard.

## Verification
- `bun run db:push` succeeded — SQLite database created with all required tables
- `bun run lint` passes with only 1 pre-existing warning (unused eslint-disable directive)
- Dev server starts successfully and serves pages with HTTP 200
- ensure-rpc shows improved warning message when PostgreSQL is unavailable
- Local SQLite database at `db/custom.db` is 741KB with all tables (verified via Prisma count queries)

## Files Modified
1. `src/lib/ensure-rpc.ts` — Made resilient to connection failures
2. `prisma/schema.prisma` — Switched from PostgreSQL to SQLite
3. `.env` — Updated DATABASE_URL to local SQLite
4. `src/lib/supabase-helpers.ts` — Added `id: generateId()` to createLog/createEvent
5. `instrumentation.ts` — Moved process.on handlers inside nodejs runtime check
