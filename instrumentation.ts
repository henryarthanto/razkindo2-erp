// =====================================================================
// Next.js Instrumentation Hook
//
// Runs once when the Next.js server starts (Node.js runtime only).
// Initializes server-side services: MemoryGuard, ConsistencyScheduler,
// and PerformanceMonitor.
// =====================================================================

// Global uncaught error handler — provides full stack traces in production
// where Next.js otherwise shows "ignore-listed frames"
process.on('uncaughtException', (error) => {
  console.error('[FATAL] Uncaught Exception:', error);
  console.error('[FATAL] Stack:', error.stack);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('[FATAL] Unhandled Rejection at:', promise, 'reason:', reason);
  if (reason instanceof Error) {
    console.error('[FATAL] Stack:', reason.stack);
  }
});

export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    console.log('[Instrumentation] Starting server-side initialization...');

    // Initialize memory monitoring
    try {
      await import('./src/lib/memory-init');
      console.log('[Instrumentation] MemoryGuard initialized.');
    } catch (e: any) {
      console.warn('[Instrumentation] MemoryGuard init skipped:', e.message?.substring(0, 120));
    }

    // Initialize periodic consistency checking
    try {
      const { startConsistencyScheduler } = await import('./src/lib/consistency-scheduler');
      startConsistencyScheduler(6 * 60 * 60 * 1000); // Every 6 hours
      console.log('[Instrumentation] Consistency scheduler initialized.');
    } catch (e: any) {
      console.warn('[Instrumentation] Consistency scheduler init skipped:', e.message?.substring(0, 120));
    }

    // Initialize performance monitor (singleton is created on first import)
    try {
      const { perfMonitor } = await import('./src/lib/performance-monitor');
      perfMonitor.setGauge('server.startup', 1);
      console.log('[Instrumentation] PerformanceMonitor initialized.');
    } catch (e: any) {
      console.warn('[Instrumentation] PerformanceMonitor init skipped:', e.message?.substring(0, 120));
    }

    // Ensure critical RPC functions exist in the database
    try {
      const { ensureRpcFunctions } = await import('./src/lib/ensure-rpc');
      await ensureRpcFunctions();
    } catch (e: any) {
      console.warn('[Instrumentation] RPC setup skipped:', e.message?.substring(0, 120));
    }

    console.log('[Instrumentation] Server-side services initialized.');
  }
}
