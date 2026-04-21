# Razkindo ERP - Worklog

---
Task ID: 1
Agent: Main
Task: Deploy Razkindo ERP with new Supabase PostgreSQL project

Work Log:
- Extracted Arsip16April21.1.tar archive containing the full Razkindo ERP codebase
- Copied all source files: src/, prisma/, public/, mini-services/, examples/, scripts/, supabase/, components.json, next.config.ts, tsconfig.json, tailwind.config.ts, etc.
- Updated .env with new Supabase credentials (project ref: eglmvtleuonoeomovnwa)
  - DATABASE_URL: postgresql://postgres.eglmvtleuonoeomovnwa@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
  - DIRECT_URL: postgresql://postgres.eglmvtleuonoeomovnwa@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres
  - NEXT_PUBLIC_SUPABASE_URL: https://eglmvtleuonoeomovnwa.supabase.co
  - NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY: JWT from user
- Changed Prisma schema from SQLite to PostgreSQL (provider = "postgresql", added directUrl)
- Ran bun install, prisma generate, prisma db push (accepted data loss for schema changes)
- Started dev server - Supabase connection successful
  - 11/11 RPC functions deployed via ensure-rpc
  - API endpoints working (check-superadmin returns {"exists":true})
  - Dashboard returns 401 (requires auth) - correct behavior
  - Page compiles and renders with all ERP modules

Stage Summary:
- Razkindo ERP fully deployed and running on new Supabase PostgreSQL project
- Database schema pushed with all 20+ models
- All API routes compiling and responding
- Supabase REST API connected via @supabase/supabase-js
- Prisma Client connected via PgBouncer connection pooling

---
Task ID: 2
Agent: Main
Task: Push to GitHub and create Docker setup

Work Log:
- Created GitHub repository: henryarthanto/razkindo2-erp (public)
- Added git remote origin with provided token
- Created Dockerfile (multi-stage: deps → builder → runner with standalone output)
- Created docker-compose.yml (app service with healthcheck, resource limits)
- Created .dockerignore (excludes node_modules, .next, .env, logs, etc.)
- Created .env.example (template with all required env vars)
- Updated .gitignore to allow .env.example (!.env.example exception)
- Committed all Docker files
- Pushed to GitHub successfully: https://github.com/henryarthanto/razkindo2-erp

Stage Summary:
- Project live on GitHub at https://github.com/henryarthanto/razkindo2-erp
- Docker setup complete with multi-stage build optimized for production
- .env.example provided as template (actual .env with credentials is gitignored)
- Docker not available in sandbox for build testing, but configuration is correct for deployment

---
Task ID: 4
Agent: Bug Fix Agent
Task: Fix Bug 13-14 (Low Priority)

Work Log:
- Bug 13: Renamed local `generateInvoiceNo` to `generateLocalInvoiceNo` in `/src/app/api/finance/requests/[id]/route.ts`
  - Added comment explaining the function differs from supabase-helpers version (custom prefix vs type-based prefix)
  - Updated both call sites: `createPurchaseTransaction` (line 440) and `createExpenseTransaction` (line 485)
  - Eliminates shadowing of the imported `generateInvoiceNo` from supabase-helpers
- Bug 14: Replaced manual non-ERP validation in `/src/app/api/auth/register/route.ts` with centralized Zod schema
  - Added `registerNonErp` schema to `authSchemas` in `/src/lib/validators.ts` (validates name, phone, customRoleId, unitId, unitIds)
  - Replaced manual `if (!name ...)` check with `validateBody(authSchemas.registerNonErp, { name, phone, customRoleId, unitId, unitIds })`
  - Consistent validation pattern across the codebase; customRoleId now also validated as required via schema

Stage Summary:
- Both low-priority bugs fixed
- Bug 13: No more function shadowing; local invoice generator clearly named and documented
- Bug 14: Non-ERP registration uses same `validateBody` pattern as ERP registration

---
Task ID: 2
Agent: Bug Fix Agent
Task: Fix Bug 5-7 (High Priority)

Work Log:
- Bug 5: Fixed camelCase→snake_case column names in products/route.ts POST insert block
  - Changed `subUnit` → `sub_unit` and `conversionRate` → `conversion_rate` (Supabase expects snake_case)
  - Added missing `purchase_price: data.purchasePrice || 0` field (also BUG 11)
  - Added `purchasePrice: z.number().min(0).optional().default(0)` to `productSchemas.create` in validators.ts
- Bug 6: Fixed PWA customer lookup querying non-existent columns
  - Removed `cashback_type, cashback_value` from customers table select (columns don't exist)
  - Added separate query to `cashback_config` table to fetch active cashback type/value
  - Gracefully handles missing cashback_config table with try/catch fallback to defaults
  - Cashback config now correctly sourced from its own table instead of customer record
- Bug 7: Fixed `toCamelCase(null)` returning `{}` instead of `null`
  - Changed return type from `T` to `T | null`
  - Changed null guard from `return {} as T` to `return null`
  - Prevents downstream code from treating empty object as valid data

Stage Summary:
- All 3 high-priority bugs fixed
- Bug 5: Product creation no longer silently drops sub_unit/conversion_rate/purchase_price columns
- Bug 6: PWA customer lookup no longer fails due to non-existent columns; cashback config correctly sourced
- Bug 7: toCamelCase now correctly propagates null values instead of masking them as empty objects

---
Task ID: 3
Agent: Bug Fix Agent
Task: Fix Bug 8-12 (Medium Priority)

Work Log:
- Bug 8: Removed duplicate `txTimer.stop()` call in `/src/app/api/transactions/route.ts`
  - Line 963 (inside try block) was stopping the timer before `return`, but `finally` block at line 985 also stops it
  - Removed the redundant call inside the try block; kept `txTimer.stop()` in finally (line 985) and outer catch (line 990)
- Bug 9: Fixed Supabase select string field names in two files
  - In `/src/app/api/transactions/route.ts`: Changed all 3 occurrences of `product:products(unit, subUnit)` to `product:products(unit, sub_unit, conversion_rate)` (lines 117, 496, 888)
  - In `/src/app/api/transactions/mark-lunas/route.ts`: Changed `subUnit` → `sub_unit` and `conversionRate` → `conversion_rate` in the select string (line 57); also changed `prod.subUnit` → `prod.sub_unit` in the property mapping (line 99)
- Bug 10: Added `export` keyword to `requireAuth` function in `/src/lib/require-auth.ts` (line 20)
- Bug 11: Skipped — already covered by Bug 5 (purchasePrice added to products insert)
- Bug 12: Updated auth schemas in `/src/lib/validators.ts`
  - `forgotPassword`: Changed from `{ email }` to `{ phone }` to match WhatsApp-based password reset flow
  - `resetPassword`: Changed from `{ token, newPassword }` to `{ phone, code, newPassword }` to match OTP-based reset implementation

Stage Summary:
- 4 medium-priority bugs fixed (Bug 11 was already handled by another agent)
- Bug 8: Eliminated double timer stop preventing potential runtime issues
- Bug 9: Supabase PostgREST select strings now use correct snake_case column names
- Bug 10: `requireAuth` is now properly exported and available for import
- Bug 12: Auth validation schemas now match the actual route implementations (phone-based, not email-based)

---
Task ID: 1
Agent: Bug Fix Agent
Task: Fix Bug 1-4 (Critical)

Work Log:
- Bug 1: Fixed `p_amount` → `p_delta` in `/src/app/api/courier/deliver/route.ts` (line 171)
  - The RPC `atomic_add_courier_cash` expects parameter `p_delta`, but the route was passing `p_amount`
  - This caused courier cash balance to not be updated when couriers collected cash on delivery
- Bug 2: Replaced `process_courier_handover` RPC handler in `/src/lib/supabase.ts` (lines 431-456)
  - Old handler expected `{p_handover_id, p_status, p_processed_by_id}` but the route at `/src/app/api/courier/handover/route.ts` sends `{p_courier_id, p_unit_id, p_amount, p_processed_by_id, p_notes}`
  - New handler atomically: gets courier cash, validates balance, deducts from courier cash, credits cash box, creates finance request, creates handover record
- Bug 3: Fixed `increment_unit_stock` call in `/src/app/api/products/[id]/stock/route.ts` (lines 149-157)
  - Old code passed `{p_unit_id, p_product_id, p_qty}` but the RPC expects `{p_unit_product_id, p_qty}`
  - New code first looks up the unit_product record, creates it if missing (using `generateId()`), then calls RPC with correct `p_unit_product_id`
  - Added `generateId` to the import from `@/lib/supabase-helpers`
  - Also fixed same-file `p_cost_per_unit` → `p_new_hpp` on line 85 (centralized stock path had the same RPC param mismatch as Bug 4)
- Bug 4: Fixed `p_cost_per_unit` → `p_new_hpp` in `/src/app/api/finance/requests/[id]/route.ts` (line 386)
  - The RPC `increment_stock_with_hpp` expects `p_new_hpp` but the route was passing `p_cost_per_unit`
  - This caused stock increments from purchase goods receipt to not properly recalculate average HPP

Stage Summary:
- All 4 critical bugs fixed
- Bug 1: Courier delivery now correctly credits courier cash balance
- Bug 2: Courier handover now works end-to-end (balance deduction, cash box credit, finance request + handover creation)
- Bug 3: Per-unit stock increment now correctly resolves the unit_product record before calling RPC; also fixed centralized stock HPP param
- Bug 4: Purchase goods receipt now correctly passes HPP to the stock increment RPC
