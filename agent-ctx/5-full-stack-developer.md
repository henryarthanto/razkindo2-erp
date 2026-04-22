# Task 5: Fix SalesTaskManagement (Penugasan/Assignments)

## Agent: full-stack-developer

## Summary
Fixed 7 bugs in the SalesTaskManagement module that were causing the "Penugasan belum bisa" (Assignments not working) issue.

## Bugs Fixed

### Bug 1 (CRITICAL) — latestReport mapping snake_case vs camelCase
- **File**: `src/app/api/sales-tasks/route.ts`
- **Problem**: After `rowsToCamelCase()`, nested report objects had camelCase keys, but the `latestReport` construction accessed `task.reports[0].created_at` and `task.reports[0].reported_by` (snake_case), resulting in always-undefined values
- **Fix**: Changed to use `createdAt` and `reportedBy` (camelCase)

### Bug 2 (HIGH) — Overdue count included completed/cancelled tasks
- **File**: `src/app/api/sales-tasks/route.ts`
- **Fix**: Added `t.status !== 'completed' && t.status !== 'cancelled'` check

### Bug 3 (HIGH) — Reports not sorted, latestReport unreliable
- **File**: `src/app/api/sales-tasks/route.ts`
- **Fix**: Sort reports by createdAt descending before selecting latestReport

### Bug 4 (MEDIUM) — Missing 'visit' type and wrong 'general' label
- **Files**: `SalesTaskManagement.tsx`, `SalesTaskDashboard.tsx` (TypeBadge)
- **Fix**: Added 'visit' = 'Kunjungan', changed 'general' to 'Umum'

### Bug 5 (HIGH) — Inconsistent isOverdue logic
- **Files**: `SalesTaskDashboard.tsx`, `SalesTaskPopup.tsx`
- **Fix**: Unified to end-of-day comparison matching Management component

### Bug 6 (LOW) — Indigo color in popup
- **File**: `SalesTaskPopup.tsx`
- **Fix**: Changed `from-blue-500 to-indigo-600` → `from-teal-500 to-emerald-600`

### Bug 7 (MEDIUM) — Popup not refreshed after task updates
- **File**: `SalesTaskDashboard.tsx`
- **Fix**: Added `invalidateQueries({ queryKey: ['my-tasks-popup'] })` to handlers

## Verification
- ESLint: 0 errors
- Dev server: running without compilation errors
- Supabase tables confirmed present with correct schema
