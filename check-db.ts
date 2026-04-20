import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

console.log('URL:', url?.substring(0, 40) + '...');
console.log('KEY:', key?.substring(0, 25) + '...');
console.log('');

if (!url || !key) {
  console.error('FATAL: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const db = createClient(url, key);

const expectedTables = [
  'users', 'units', 'products', 'unit_products', 'customers',
  'suppliers', 'transactions', 'transaction_items', 'payments',
  'salary_payments', 'bank_accounts', 'cash_boxes', 'finance_requests',
  'fund_transfers', 'company_debts', 'company_debt_payments',
  'receivables', 'receivable_follow_ups', 'sales_targets',
  'sales_tasks', 'sales_task_reports', 'courier_cash', 'courier_handovers',
  'logs', 'events', 'settings', 'password_resets', 'custom_roles'
];

console.log('=== Checking Supabase Database Tables ===\n');

let ok = 0, fail = 0;
for (const table of expectedTables) {
  try {
    const { count, error } = await db
      .from(table)
      .select('*', { count: 'exact', head: true });
    if (error) {
      const msg = error.message || JSON.stringify(error);
      console.log(`  ❌ ${table}: ${msg.substring(0, 100)}`);
      fail++;
    } else {
      console.log(`  ✅ ${table}: ${count} rows`);
      ok++;
    }
  } catch (e: any) {
    console.log(`  ❌ ${table}: ${e.message?.substring(0, 100)}`);
    fail++;
  }
}

console.log(`\n=== Result: ${ok} OK, ${fail} MISSING/ERROR ===`);

// Check critical RPC functions
console.log('\n=== Checking RPC Functions ===');
const rpcs = ['increment_stock_with_hpp', 'atomic_update_balance', 'atomic_update_pool_balance'];
for (const rpc of rpcs) {
  try {
    const { error } = await db.rpc(rpc as any);
    if (error) {
      console.log(`  ❌ ${rpc}: ${error.message?.substring(0, 80)}`);
    } else {
      console.log(`  ✅ ${rpc}: exists`);
    }
  } catch (e: any) {
    console.log(`  ❌ ${rpc}: ${e.message?.substring(0, 80)}`);
  }
}

process.exit(fail > 0 ? 1 : 0);
