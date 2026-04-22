import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/supabase';
import { format } from 'date-fns';
import { id } from 'date-fns/locale';
import { verifyAuthUser } from '@/lib/token';
import { rowsToCamelCase, toCamelCase } from '@/lib/supabase-helpers';

function rp(n: number) {
  return 'Rp ' + Math.round(n).toLocaleString('id-ID');
}

function dateRange(period: string) {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  switch (period) {
    case 'hari': case 'today': case 'hari ini':
      return today.toISOString();
    case 'minggu': case 'week': case 'minggu ini': {
      const day = today.getDay();
      const start = new Date(today);
      start.setDate(today.getDate() - (day === 0 ? 6 : day - 1));
      return start.toISOString();
    }
    case 'bulan': case 'month': case 'bulan ini':
      return new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
    default:
      return undefined;
  }
}

// ============ DATA QUERY FUNCTIONS ============

async function handleSalesToday(isSuperAdmin: boolean) {
  const dr = dateRange('hari ini');
  let query = db.from('transactions').select(`
    *, items:transaction_items(*), created_by:users!created_by_id(name, role), customer:customers(name)
  `).eq('type', 'sale').in('status', ['approved', 'paid']);
  if (dr) query = query.gte('transaction_date', dr);
  const { data: sales } = await query.order('transaction_date', { ascending: false }).limit(50);
  const list = sales || [];
  const total = list.reduce((s, t: any) => s + (t.total || 0), 0);
  const paid = list.reduce((s, t: any) => s + (t.paid_amount || 0), 0);

  let text = `📊 **Penjualan Hari Ini**\n`;
  text += `📅 ${format(new Date(), 'EEEE, dd MMMM yyyy', { locale: id })}\n\n`;
  text += `💰 Total: **${rp(total)}**\n`;
  if (isSuperAdmin) {
    const profit = list.reduce((s, t: any) => s + (t.total_profit || 0), 0);
    text += `📈 Profit: **${rp(profit)}**\n`;
  }
  text += `💵 Dibayar: **${rp(paid)}**\n`;
  text += `📝 Transaksi: **${list.length}**\n`;
  if (list.length > 0) {
    text += `\n---\n📝 **Detail:**\n`;
    list.slice(0, 10).forEach((t: any, i: number) => {
      const c = t.customer?.name || 'Umum';
      const ps = t.payment_status === 'paid' ? '✅' : '⏳';
      text += `\n${i + 1}. **${t.invoice_no}** — ${c} | ${rp(t.total)} | ${ps}\n`;
    });
  } else {
    text += `\n_Belum ada transaksi hari ini._`;
  }
  return text;
}

async function handleSalesWeek(isSuperAdmin: boolean) {
  const dr = dateRange('minggu ini');
  let query = db.from('transactions').select('total, total_profit').eq('type', 'sale').in('status', ['approved', 'paid']);
  if (dr) query = query.gte('transaction_date', dr);
  const { data: sales } = await query;
  const list = sales || [];
  const total = list.reduce((s, t: any) => s + (t.total || 0), 0);
  const profit = list.reduce((s, t: any) => s + (t.total_profit || 0), 0);

  let text = `📊 **Penjualan Minggu Ini**\n\n`;
  text += `💰 Total: **${rp(total)}**\n`;
  if (isSuperAdmin) text += `📈 Profit: **${rp(profit)}**\n`;
  text += `📝 Transaksi: **${list.length}**\n`;
  return text;
}

async function handleSalesMonth(isSuperAdmin: boolean) {
  const dr = dateRange('bulan ini');
  let query = db.from('transactions').select('total, total_profit').eq('type', 'sale').in('status', ['approved', 'paid']);
  if (dr) query = query.gte('transaction_date', dr);
  const { data: sales } = await query;
  const list = sales || [];
  const total = list.reduce((s, t: any) => s + (t.total || 0), 0);
  const profit = list.reduce((s, t: any) => s + (t.total_profit || 0), 0);

  let text = `📊 **Penjualan Bulan Ini**\n`;
  text += `📅 ${format(new Date(), 'MMMM yyyy', { locale: id })}\n\n`;
  text += `💰 Total: **${rp(total)}**\n`;
  if (isSuperAdmin) {
    text += `📈 Profit: **${rp(profit)}**\n`;
    text += `📊 Margin: **${total > 0 ? ((profit / total) * 100).toFixed(1) : 0}%**\n`;
  }
  text += `📝 Transaksi: **${list.length}**\n`;
  return text;
}

async function handleSalesPerSales(isSuperAdmin: boolean) {
  const { data: sales } = await db.from('transactions').select(`
    *, created_by:users!created_by_id(name, role)
  `).eq('type', 'sale').in('status', ['approved', 'paid']).order('transaction_date', { ascending: false }).limit(500);

  const bySales = new Map<string, { name: string; total: number; count: number; profit: number }>();
  (sales || []).forEach((t: any) => {
    const cb = t.created_by;
    if (cb?.role === 'sales') {
      const e = bySales.get(t.created_by_id) || { name: cb.name, total: 0, count: 0, profit: 0 };
      e.total += (t.total || 0);
      e.count += 1;
      e.profit += (t.total_profit || 0);
      bySales.set(t.created_by_id, e);
    }
  });
  const ranked = Array.from(bySales.values()).sort((a, b) => b.total - a.total);
  let text = `👥 **Penjualan Per Sales**\n\n`;
  if (ranked.length === 0) return text + '_Tidak ada data._';
  ranked.forEach((s, i) => {
    text += `${i + 1}. **${s.name}**\n`;
    text += `   💰 ${rp(s.total)} | 📝 ${s.count} trx`;
    if (isSuperAdmin) text += ` | 📈 ${rp(s.profit)}`;
    text += `\n\n`;
  });
  return text;
}

async function handleStockAll(isSuperAdmin: boolean) {
  const { data: products } = await db.from('products').select('*').eq('is_active', true).order('name').limit(100);
  const list = products || [];
  let text = `📦 **Stok Produk**\n`;
  text += `📋 Total: **${list.length} produk**\n\n`;
  list.forEach((p: any) => {
    const status = p.global_stock === 0 ? '🚫' : p.global_stock <= p.min_stock ? '⚠️' : '✅';
    text += `${status} **${p.name}** — Stok: ${p.global_stock} ${p.unit || 'pcs'} | Jual: ${rp(p.selling_price)}\n`;
  });
  return text;
}

async function handleStockLow() {
  const { data: products } = await db.from('products').select('*').eq('is_active', true).gt('global_stock', 0).limit(500);
  const low = (products || []).filter((p: any) => p.global_stock > 0 && p.global_stock <= (p.min_stock || 0));
  let text = `⚠️ **Stok Rendah**\n\n`;
  if (low.length === 0) return text + '_Semua stok aman!_ ✅\n';
  low.forEach((p: any) => text += `⚠️ **${p.name}** — Stok: **${p.global_stock}** (Min: ${p.min_stock})\n`);
  return text;
}

async function handleCustomersUnpaid() {
  const { data: receivables } = await db.from('receivables').select('*').eq('status', 'active').order('remaining_amount', { ascending: false }).limit(100);
  let text = `📋 **Piutang Aktif**\n`;
  text += `📋 Total: **${(receivables || []).length} piutang**\n\n`;
  if ((receivables || []).length === 0) return text + '_Semua lunas!_ ✅\n';
  (receivables || []).forEach((r: any, i: number) => {
    const overdue = r.overdue_days > 0 ? `🔴 ${r.overdue_days} hari` : '🟢';
    text += `${i + 1}. **${r.customer_name || '-'}** — ${rp(r.remaining_amount)} / ${rp(r.total_amount)} | ${overdue}\n\n`;
  });
  return text;
}

async function handleCustomersSummary() {
  const { count: total } = await db.from('customers').select('*', { count: 'exact', head: true });
  const { data: topCustomers } = await db.from('customers').select('*').order('total_spent', { ascending: false }).limit(10);
  const totalSpent = (topCustomers || []).reduce((s: number, c: any) => s + (c.total_spent || 0), 0);
  let text = `👥 **Konsumen**\n\n`;
  text += `📋 Total: **${total}**\n💰 Total Belanja: **${rp(totalSpent)}**\n\n🏆 **Top:**\n`;
  (topCustomers || []).forEach((c: any, i: number) => {
    text += `${i + 1}. **${c.name}** — ${rp(c.total_spent || 0)} (${c.total_orders || 0} order)\n`;
  });
  return text;
}

// ============ PURE LOGIC FINANCIAL ANALYSIS ============

async function handleHppProfitAnalysis() {
  // Get all sales transactions
  const { data: sales } = await db.from('transactions')
    .select('total, total_hpp, total_profit, paid_amount, hpp_paid, profit_paid, hpp_unpaid, profit_unpaid, payment_status')
    .eq('type', 'sale')
    .in('status', ['approved', 'paid']);

  const list = sales || [];
  const totalSales = list.reduce((s: number, t: any) => s + (t.total || 0), 0);
  const totalHpp = list.reduce((s: number, t: any) => s + (t.total_hpp || 0), 0);
  const totalProfit = list.reduce((s: number, t: any) => s + (t.total_profit || 0), 0);
  const totalPaid = list.reduce((s: number, t: any) => s + (t.paid_amount || 0), 0);
  const hppPaid = list.reduce((s: number, t: any) => s + (t.hpp_paid || 0), 0);
  const profitPaid = list.reduce((s: number, t: any) => s + (t.profit_paid || 0), 0);
  const hppUnpaid = list.reduce((s: number, t: any) => s + (t.hpp_unpaid || 0), 0);
  const profitUnpaid = list.reduce((s: number, t: any) => s + (t.profit_unpaid || 0), 0);
  const unpaidCount = list.filter((t: any) => t.payment_status !== 'paid').length;
  const paidCount = list.filter((t: any) => t.payment_status === 'paid').length;

  const hppRecoveryRate = totalHpp > 0 ? ((hppPaid / totalHpp) * 100).toFixed(1) : '0';
  const profitRealizedRate = totalProfit > 0 ? ((profitPaid / totalProfit) * 100).toFixed(1) : '0';

  let text = `🔍 **Analisis HPP & Profit**\n\n`;
  text += `--- **AKUMULASI DANA** ---\n\n`;
  text += `💰 Total Penjualan: **${rp(totalSales)}** (${list.length} transaksi)\n`;
  text += `💵 Total Dibayar: **${rp(totalPaid)}**\n\n`;

  text += `📊 **HPP (Harga Pokok):**\n`;
  text += `  • Total HPP: **${rp(totalHpp)}**\n`;
  text += `  • ✅ Sudah kembali (di tangan): **${rp(hppPaid)}** (${hppRecoveryRate}%)\n`;
  text += `  • ⏳ Masih tertahan (piutang): **${rp(hppUnpaid)}**\n\n`;

  text += `📈 **Profit (Keuntungan):**\n`;
  text += `  • Total Profit: **${rp(totalProfit)}**\n`;
  text += `  • ✅ Sudah di tangan: **${rp(profitPaid)}** (${profitRealizedRate}%)\n`;
  text += `  • ⏳ Masih tertahan: **${rp(profitUnpaid)}**\n\n`;

  text += `--- **REKOMENDASI** ---\n\n`;
  if (hppUnpaid > totalHpp * 0.3) {
    text += `⚠️ **HPP tertahan ${rp(hppUnpaid)}** (${hppRecoveryRate}% recovery) — Prioritaskan penagihan piutang!\n`;
    text += `  → ${unpaidCount} transaksi belum lunas perlu di-follow up\n`;
  }
  if (profitUnpaid > totalProfit * 0.3) {
    text += `⚠️ **Profit tertahan ${rp(profitUnpaid)}** — Tingkatkan penagihan untuk merealisasikan keuntungan\n`;
  }
  if (totalSales > 0) {
    const margin = ((totalProfit / totalSales) * 100).toFixed(1);
    text += `📊 Margin keseluruhan: **${margin}%**\n`;
    if (parseFloat(margin) < 15) {
      text += `  → Margin di bawah 15%, pertimbangkan menaikkan harga atau menekan HPP\n`;
    }
  }
  text += `✅ Transaksi lunas: ${paidCount} | ⏳ Belum lunas: ${unpaidCount}\n`;
  return text;
}

async function handleRestockRecommendation() {
  // Get products with stock and recent sales data
  const { data: products } = await db.from('products').select('*').eq('is_active', true).eq('track_stock', true);
  const { data: recentItems } = await db.from('transaction_items')
    .select('product_id, qty, created_at')
    .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString());

  // Calculate velocity per product
  const velocityMap = new Map<string, number>();
  (recentItems || []).forEach((item: any) => {
    const current = velocityMap.get(item.product_id) || 0;
    velocityMap.set(item.product_id, current + (item.qty || 0));
  });

  const productList = (products || []).map((p: any) => {
    const velocity30d = velocityMap.get(p.id) || 0;
    const dailyVelocity = velocity30d / 30;
    const daysOfStock = dailyVelocity > 0 ? Math.round(p.global_stock / dailyVelocity) : 999;
    const needsRestock = p.global_stock <= p.min_stock || daysOfStock < 14;
    const suggestedQty = dailyVelocity > 0 ? Math.max(0, Math.ceil(dailyVelocity * 30 - p.global_stock)) : 0;
    const estimatedCost = suggestedQty * (p.avg_hpp || p.purchase_price || 0);

    return {
      name: p.name,
      unit: p.unit || 'pcs',
      currentStock: p.global_stock,
      minStock: p.min_stock,
      velocity30d,
      dailyVelocity: Math.round(dailyVelocity * 10) / 10,
      daysOfStock,
      needsRestock,
      suggestedQty,
      estimatedCost,
      avgHpp: p.avg_hpp || 0,
    };
  }).filter(p => p.needsRestock || p.suggestedQty > 0)
    .sort((a, b) => a.daysOfStock - b.daysOfStock);

  let text = `🛒 **Saran Restock**\n\n`;
  if (productList.length === 0) {
    text += `_Semua stok masih mencukupi!_ ✅\n`;
    return text;
  }

  let totalEstCost = 0;
  productList.forEach((p, i) => {
    const urgency = p.daysOfStock < 7 ? '🔴' : p.daysOfStock < 14 ? '🟡' : '🟢';
    text += `${urgency} **${p.name}**\n`;
    text += `   Stok: ${p.currentStock} ${p.unit} (Min: ${p.minStock}) | Velocity: ${p.dailyVelocity}/hari\n`;
    text += `   Sisa: ~${p.daysOfStock} hari | Saran beli: **${p.suggestedQty} ${p.unit}** (${rp(p.estimatedCost)})\n\n`;
    totalEstCost += p.estimatedCost;
  });

  text += `---\n💰 **Total estimasi biaya restock: ${rp(totalEstCost)}**\n`;
  return text;
}

async function handleSalesTrend() {
  // Get last 4 months of sales data
  const months: any[] = [];
  for (let i = 3; i >= 0; i--) {
    const start = new Date();
    start.setMonth(start.getMonth() - i, 1);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setMonth(end.getMonth() + 1);

    const { data: sales } = await db.from('transactions')
      .select('total, total_profit')
      .eq('type', 'sale')
      .in('status', ['approved', 'paid'])
      .gte('transaction_date', start.toISOString())
      .lt('transaction_date', end.toISOString());

    const list = sales || [];
    const totalSales = list.reduce((s: number, t: any) => s + (t.total || 0), 0);
    const totalProfit = list.reduce((s: number, t: any) => s + (t.total_profit || 0), 0);

    months.push({
      label: format(start, 'MMMM yyyy', { locale: id }),
      totalSales,
      totalProfit,
      count: list.length,
      margin: totalSales > 0 ? ((totalProfit / totalSales) * 100).toFixed(1) : '0',
    });
  }

  let text = `📊 **Analisa Tren Penjualan (4 Bulan)**\n\n`;
  months.forEach((m, i) => {
    const growth = i > 0 && months[i - 1].totalSales > 0
      ? (((m.totalSales - months[i - 1].totalSales) / months[i - 1].totalSales) * 100).toFixed(1)
      : null;
    const growthIcon = growth === null ? '' : parseFloat(growth) >= 0 ? '▲' : '▼';
    const growthText = growth !== null ? ` (${growthIcon}${Math.abs(parseFloat(growth))}%)` : '';

    text += `📅 **${m.label}**\n`;
    text += `   💰 Sales: ${rp(m.totalSales)} | 📈 Profit: ${rp(m.totalProfit)} | 📝 ${m.count} trx | Margin: ${m.margin}%${growthText}\n\n`;
  });

  // Trend analysis
  const latest = months[months.length - 1];
  const previous = months[months.length - 2];
  text += `---\n🔍 **Analisis:**\n`;
  if (previous && previous.totalSales > 0) {
    const salesChange = ((latest.totalSales - previous.totalSales) / previous.totalSales * 100).toFixed(1);
    const profitChange = ((latest.totalProfit - previous.totalProfit) / previous.totalProfit * 100).toFixed(1);
    if (parseFloat(salesChange) >= 0) {
      text += `📈 Penjualan naik **${salesChange}%** dari bulan sebelumnya\n`;
    } else {
      text += `📉 Penjualan turun **${Math.abs(parseFloat(salesChange))}%** dari bulan sebelumnya\n`;
      text += `  → Perlu evaluasi: apakah faktor musiman, kompetitor, atau internal?\n`;
    }
    if (parseFloat(profitChange) >= 0) {
      text += `📈 Profit naik **${profitChange}%**\n`;
    } else {
      text += `📉 Profit turun **${Math.abs(parseFloat(profitChange))}%** — Cek HPP naik atau diskon berlebihan\n`;
    }
  }
  return text;
}

async function handleCashFlowAudit() {
  const now = new Date();
  const last7d = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const last30d = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  // Inflow (payments received)
  const { data: payments7d } = await db.from('payments')
    .select('amount, hpp_portion, profit_portion')
    .gte('paid_at', last7d.toISOString());
  const { data: payments30d } = await db.from('payments')
    .select('amount, hpp_portion, profit_portion')
    .gte('paid_at', last30d.toISOString());

  // Outflow (finance requests processed)
  const { data: outflow7d } = await db.from('finance_requests')
    .select('amount, type')
    .eq('status', 'processed')
    .gte('processed_at', last7d.toISOString());
  const { data: outflow30d } = await db.from('finance_requests')
    .select('amount, type')
    .eq('status', 'processed')
    .gte('processed_at', last30d.toISOString());

  const inflow7d = (payments7d || []).reduce((s: number, p: any) => s + (p.amount || 0), 0);
  const inflow30d = (payments30d || []).reduce((s: number, p: any) => s + (p.amount || 0), 0);
  const outflow7dAmount = (outflow7d || []).reduce((s: number, p: any) => s + (p.amount || 0), 0);
  const outflow30dAmount = (outflow30d || []).reduce((s: number, p: any) => s + (p.amount || 0), 0);

  // Check for inconsistencies
  const { data: allTx } = await db.from('transactions')
    .select('id, invoice_no, total, paid_amount, remaining_amount, payment_status')
    .in('status', ['approved', 'paid']);
  const inconsistencies = (allTx || []).filter((t: any) => {
    const expected = Math.round((t.paid_amount || 0) + (t.remaining_amount || 0));
    return Math.abs(expected - (t.total || 0)) > 1;
  });

  let text = `💵 **Audit Arus Kas**\n\n`;
  text += `--- **7 Hari Terakhir** ---\n`;
  text += `📥 Uang masuk: **${rp(inflow7d)}**\n`;
  text += `📤 Uang keluar: **${rp(outflow7dAmount)}**\n`;
  text += `📊 Bersih: **${rp(inflow7d - outflow7dAmount)}**\n\n`;

  text += `--- **30 Hari Terakhir** ---\n`;
  text += `📥 Uang masuk: **${rp(inflow30d)}**\n`;
  text += `📤 Uang keluar: **${rp(outflow30dAmount)}**\n`;
  text += `📊 Bersih: **${rp(inflow30d - outflow30dAmount)}**\n\n`;

  if (inconsistencies.length > 0) {
    text += `🔴 **${inconsistencies.length} inkonsistensi data terdeteksi!**\n`;
    inconsistencies.slice(0, 5).forEach((t: any) => {
      text += `  • ${t.invoice_no}: total ${rp(t.total)} vs paid+remaining ${rp((t.paid_amount || 0) + (t.remaining_amount || 0))}\n`;
    });
    text += `\n⚠️ Segera perbaiki inkonsistensi data di atas.\n`;
  } else {
    text += `✅ Tidak ada inkonsistensi data terdeteksi.\n`;
  }
  return text;
}

async function handleFinancialHealth() {
  // Get comprehensive financial data
  const { data: sales } = await db.from('transactions')
    .select('total, total_hpp, total_profit, paid_amount')
    .eq('type', 'sale')
    .in('status', ['approved', 'paid']);
  const { data: receivables } = await db.from('receivables').select('*').eq('status', 'active');
  const { data: debts } = await db.from('company_debts').select('*').eq('status', 'active').eq('is_active', true);
  const { data: bankAccounts } = await db.from('bank_accounts').select('balance, is_active').eq('is_active', true);
  const { data: cashBoxes } = await db.from('cash_boxes').select('balance, is_active').eq('is_active', true);
  const { data: products } = await db.from('products').select('global_stock, avg_hpp, selling_price, min_stock, track_stock, is_active').eq('is_active', true).eq('track_stock', true);

  const totalSales = (sales || []).reduce((s: number, t: any) => s + (t.total || 0), 0);
  const totalProfit = (sales || []).reduce((s: number, t: any) => s + (t.total_profit || 0), 0);
  const totalPaid = (sales || []).reduce((s: number, t: any) => s + (t.paid_amount || 0), 0);
  const totalReceivables = (receivables || []).reduce((s: number, r: any) => s + (r.remaining_amount || 0), 0);
  const totalDebts = (debts || []).reduce((s: number, d: any) => s + (d.remaining_amount || 0), 0);
  const totalBankBalance = (bankAccounts || []).reduce((s: number, b: any) => s + (b.balance || 0), 0);
  const totalCashBalance = (cashBoxes || []).reduce((s: number, c: any) => s + (c.balance || 0), 0);
  const totalAssetValue = (products || []).reduce((s: number, p: any) => s + ((p.global_stock || 0) * (p.avg_hpp || 0)), 0);
  const lowStockCount = (products || []).filter((p: any) => p.global_stock <= (p.min_stock || 0)).length;
  const overdueReceivables = (receivables || []).filter((r: any) => r.overdue_days > 0);
  const overdueDebts = (debts || []).filter((d: any) => d.due_date && new Date(d.due_date) < new Date());

  // Health scoring
  const collectionRate = totalSales > 0 ? (totalPaid / totalSales * 100) : 100;
  const marginRate = totalSales > 0 ? (totalProfit / totalSales * 100) : 0;
  const liquidityRatio = totalReceivables > 0 ? ((totalBankBalance + totalCashBalance) / totalReceivables) : 999;

  let healthScore = 0;
  if (collectionRate >= 90) healthScore += 30; else if (collectionRate >= 70) healthScore += 20; else healthScore += 10;
  if (marginRate >= 20) healthScore += 25; else if (marginRate >= 10) healthScore += 15; else healthScore += 5;
  if (liquidityRatio >= 1) healthScore += 25; else if (liquidityRatio >= 0.5) healthScore += 15; else healthScore += 5;
  if (overdueReceivables.length <= 2) healthScore += 20; else if (overdueReceivables.length <= 5) healthScore += 10; else healthScore += 0;

  const healthLabel = healthScore >= 80 ? '🟢 Sehat' : healthScore >= 60 ? '🟡 Cukup' : '🔴 Perlu Perhatian';

  let text = `🏥 **Kesehatan Keuangan** — Skor: **${healthScore}/100** ${healthLabel}\n\n`;

  text += `--- **LIQUIDITY** ---\n`;
  text += `🏦 Saldo Bank: **${rp(totalBankBalance)}**\n`;
  text += `💰 Saldo Kas: **${rp(totalCashBalance)}**\n`;
  text += `📋 Piutang: **${rp(totalReceivables)}** (${overdueReceivables.length} overdue)\n`;
  text += `📊 Collection Rate: **${collectionRate.toFixed(1)}%**\n\n`;

  text += `--- **PROFITABILITY** ---\n`;
  text += `💰 Total Sales: **${rp(totalSales)}**\n`;
  text += `📈 Total Profit: **${rp(totalProfit)}**\n`;
  text += `📊 Margin: **${marginRate.toFixed(1)}%**\n\n`;

  text += `--- **SOLVENCY** ---\n`;
  text += `📋 Hutang: **${rp(totalDebts)}** (${overdueDebts.length} overdue)\n`;
  text += `📦 Nilai Aset Stok: **${rp(totalAssetValue)}**\n\n`;

  text += `--- **STOCK HEALTH** ---\n`;
  text += `⚠️ Produk stok rendah: **${lowStockCount}**\n\n`;

  text += `--- **REKOMENDASI** ---\n`;
  if (collectionRate < 80) text += `🔴 Tingkatkan penagihan — collection rate ${collectionRate.toFixed(1)}% masih rendah\n`;
  if (overdueReceivables.length > 0) text += `🔴 ${overdueReceivables.length} piutang overdue perlu segera ditagih\n`;
  if (lowStockCount > 0) text += `🟡 ${lowStockCount} produk perlu restock segera\n`;
  if (marginRate < 15) text += `🟡 Margin ${marginRate.toFixed(1)}% kurang ideal — evaluasi harga jual atau HPP\n`;
  if (overdueDebts.length > 0) text += `🔴 ${overdueDebts.length} hutang overdue perlu segera dibayar\n`;
  if (healthScore >= 80) text += `✅ Keuangan dalam kondisi baik! Pertahankan kinerja.\n`;

  return text;
}

async function handleCustomerPrediction() {
  // Analyze customer purchase patterns
  const { data: customers } = await db.from('customers')
    .select('id, name, total_orders, total_spent, last_transaction_date, status')
    .eq('status', 'active')
    .order('total_spent', { ascending: false })
    .limit(50);

  const { data: recentTx } = await db.from('transactions')
    .select('customer_id, transaction_date, total, items:transaction_items(product_name, qty)')
    .eq('type', 'sale')
    .in('status', ['approved', 'paid'])
    .gte('transaction_date', new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString())
    .order('transaction_date', { ascending: false });

  // Build customer purchase frequency
  const customerActivity = new Map<string, { count: number; lastDate: string; totalSpent: number; products: Map<string, number> }>();
  (recentTx || []).forEach((tx: any) => {
    if (!tx.customer_id) return;
    const existing = customerActivity.get(tx.customer_id) || { count: 0, lastDate: '', totalSpent: 0, products: new Map<string, number>() };
    existing.count++;
    existing.totalSpent += (tx.total || 0);
    if (!existing.lastDate || tx.transaction_date > existing.lastDate) existing.lastDate = tx.transaction_date;
    (tx.items || []).forEach((item: any) => {
      if (item.product_name) {
        existing.products.set(item.product_name, (existing.products.get(item.product_name) || 0) + (item.qty || 0));
      }
    });
    customerActivity.set(tx.customer_id, existing);
  });

  // Predict which customers are likely to order
  const now = new Date();
  const predictions = (customers || []).map((c: any) => {
    const activity = customerActivity.get(c.id);
    if (!activity || activity.count < 2) return null;

    const daysSinceLastOrder = Math.floor((now.getTime() - new Date(c.last_transaction_date || activity.lastDate).getTime()) / (24 * 60 * 60 * 1000));
    const avgDaysBetweenOrders = Math.max(1, Math.floor(90 / activity.count));

    // Predict based on purchase frequency
    const likelyToOrder = daysSinceLastOrder >= avgDaysBetweenOrders * 0.7;
    const topProducts = Array.from(activity.products.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([name]) => name);

    return {
      name: c.name,
      totalOrders: c.total_orders || activity.count,
      totalSpent: c.total_spent || activity.totalSpent,
      daysSinceLastOrder,
      avgDaysBetweenOrders,
      likelyToOrder,
      topProducts,
      urgency: daysSinceLastOrder > avgDaysBetweenOrders * 1.5 ? 'high' : daysSinceLastOrder > avgDaysBetweenOrders ? 'medium' : 'low',
    };
  }).filter(Boolean)
    .filter((p: any) => p.likelyToOrder)
    .sort((a: any, b: any) => {
      const urgencyOrder = { high: 0, medium: 1, low: 2 };
      return (urgencyOrder[a.urgency] || 2) - (urgencyOrder[b.urgency] || 2);
    }) as any[];

  let text = `🎯 **Prediksi Konsumen Akan Order**\n\n`;
  if (predictions.length === 0) {
    text += `_Tidak cukup data untuk prediksi._\n`;
    return text;
  }

  predictions.slice(0, 10).forEach((p: any, i: number) => {
    const urgency = p.urgency === 'high' ? '🔴' : p.urgency === 'medium' ? '🟡' : '🟢';
    text += `${urgency} **${p.name}**\n`;
    text += `   Terakhir order: ${p.daysSinceLastOrder} hari lalu | Rata-rata: setiap ${p.avgDaysBetweenOrders} hari\n`;
    if (p.topProducts.length > 0) {
      text += `   📦 Produk favorit: ${p.topProducts.join(', ')}\n`;
    }
    text += `   💰 Total belanja: ${rp(p.totalSpent)} (${p.totalOrders} order)\n\n`;
  });

  text += `---\n💡 **Rekomendasi:** Hubungi konsumen 🔴 segera untuk follow-up order.\n`;
  return text;
}

async function handleDebtAnalysis() {
  const { data: debts } = await db.from('company_debts').select('*').eq('status', 'active').eq('is_active', true).order('remaining_amount', { ascending: false });
  const { data: receivables } = await db.from('receivables').select('*').eq('status', 'active').order('remaining_amount', { ascending: false });

  let text = `📋 **Analisis Hutang & Piutang**\n\n`;

  // Piutang
  const totalReceivables = (receivables || []).reduce((s: number, r: any) => s + (r.remaining_amount || 0), 0);
  const overdueReceivables = (receivables || []).filter((r: any) => r.overdue_days > 0);
  const totalOverdueReceivables = overdueReceivables.reduce((s: number, r: any) => s + (r.remaining_amount || 0), 0);

  text += `--- **PIUTANG** ---\n`;
  text += `📋 Total Piutang: **${rp(totalReceivables)}** (${(receivables || []).length} piutang)\n`;
  text += `🔴 Overdue: **${rp(totalOverdueReceivables)}** (${overdueReceivables.length} piutang)\n\n`;

  if (overdueReceivables.length > 0) {
    text += `⚠️ **Piutang Overdue:**\n`;
    overdueReceivables.slice(0, 8).forEach((r: any) => {
      text += `  🔴 **${r.customer_name || '-'}** — ${rp(r.remaining_amount)} (${r.overdue_days} hari)\n`;
    });
    text += `\n`;
  }

  // Hutang
  const totalDebts = (debts || []).reduce((s: number, d: any) => s + (d.remaining_amount || 0), 0);
  const overdueDebts = (debts || []).filter((d: any) => d.due_date && new Date(d.due_date) < new Date());

  text += `--- **HUTANG** ---\n`;
  text += `📋 Total Hutang: **${rp(totalDebts)}** (${(debts || []).length} hutang)\n`;
  if (overdueDebts.length > 0) {
    text += `🔴 Overdue: **${overdueDebts.length}** hutang\n`;
    overdueDebts.forEach((d: any) => {
      text += `  🔴 **${d.creditor_name}** — ${rp(d.remaining_amount)}\n`;
    });
  }

  text += `\n--- **REKOMENDASI** ---\n`;
  if (overdueReceivables.length > 0) {
    text += `🔴 Prioritaskan penagihan ${overdueReceivables.length} piutang overdue (total ${rp(totalOverdueReceivables)})\n`;
  }
  if (overdueDebts.length > 0) {
    text += `🔴 Bayar ${overdueDebts.length} hutang overdue segera untuk menghindari penalti\n`;
  }
  if (totalReceivables > totalDebts * 2) {
    text += `📊 Piutang jauh lebih besar dari hutang — fokus penagihan untuk meningkatkan kas\n`;
  }
  return text;
}

async function handleAssetValue() {
  const { data: products } = await db.from('products').select('*').eq('is_active', true);

  const totalAssetValue = (products || []).reduce((s: number, p: any) => s + ((p.global_stock || 0) * (p.avg_hpp || 0)), 0);
  const totalSellingValue = (products || []).reduce((s: number, p: any) => s + ((p.global_stock || 0) * (p.selling_price || 0)), 0);
  const margin = totalAssetValue > 0 ? ((totalSellingValue - totalAssetValue) / totalAssetValue * 100).toFixed(1) : '0';

  // Category breakdown
  const categoryMap = new Map<string, { assetValue: number; sellingValue: number; count: number }>();
  (products || []).forEach((p: any) => {
    const cat = p.category || 'Lainnya';
    const existing = categoryMap.get(cat) || { assetValue: 0, sellingValue: 0, count: 0 };
    existing.assetValue += (p.global_stock || 0) * (p.avg_hpp || 0);
    existing.sellingValue += (p.global_stock || 0) * (p.selling_price || 0);
    existing.count++;
    categoryMap.set(cat, existing);
  });

  let text = `📦 **Nilai Aset Produk**\n\n`;
  text += `💰 Nilai Aset (HPP): **${rp(totalAssetValue)}**\n`;
  text += `📈 Nilai Jual: **${rp(totalSellingValue)}**\n`;
  text += `📊 Potensi Margin: **${margin}%**\n`;
  text += `📝 Total Produk: **${(products || []).length}**\n\n`;

  if (categoryMap.size > 0) {
    text += `--- **Per Kategori** ---\n`;
    Array.from(categoryMap.entries())
      .sort((a, b) => b[1].assetValue - a[1].assetValue)
      .forEach(([cat, data]) => {
        text += `📊 **${cat}**: ${rp(data.assetValue)} (Nilai Jual: ${rp(data.sellingValue)}, ${data.count} produk)\n`;
      });
  }

  // Top 5 most valuable
  const topProducts = (products || [])
    .map((p: any) => ({ name: p.name, assetValue: (p.global_stock || 0) * (p.avg_hpp || 0), stock: p.global_stock, hpp: p.avg_hpp }))
    .sort((a, b) => b.assetValue - a.assetValue)
    .slice(0, 5);

  if (topProducts.length > 0) {
    text += `\n--- **Top 5 Produk Paling Berharga** ---\n`;
    topProducts.forEach((p, i) => {
      text += `${i + 1}. **${p.name}**: ${rp(p.assetValue)} (Stok: ${p.stock}, HPP: ${rp(p.hpp)})\n`;
    });
  }
  return text;
}

// ============ DATA INTENT DETECTION ============

function isDataQuery(msg: string, isSuperAdmin: boolean): string | null {
  const q = msg.toLowerCase().trim();
  if (!isSuperAdmin && q.match(/penjualan.*(profit|laba|untung|hpp|margin|keuntungan)/)) return 'restricted';
  if (q.match(/penjualan.*(hari|today|hari ini)/) || q.match(/omset.*(hari|today)/)) return 'sales_today';
  if (q.match(/penjualan.*(minggu|week)/)) return 'sales_week';
  if (q.match(/penjualan.*(bulan|month)/)) return 'sales_month';
  if (q.match(/penjualan.*(sales|per sales)/)) return 'sales_per_sales';
  if (q.match(/sales.*(terbaik|top|terlaris)/)) return 'sales_per_sales';
  if (q.match(/penjualan.*(profit|laba|untung)/)) return 'sales_month';
  if (q.match(/stok.*(rendah|menipis|low)/)) return 'stock_low';
  if (q.match(/stok.*(habis|kosong)/)) return 'stock_all';
  if (q.match(/stok|stock/)) return 'stock_all';
  if (q.match(/belum bayar|piutang/) && q.match(/konsumen|customer|siapa/)) return 'customers_unpaid';
  if (q.match(/total piutang|jumlah piutang/)) return 'customers_unpaid';
  if (q.match(/konsumen|customer|pelanggan/) && q.match(/ringkasan|summary|jumlah/)) return 'customers_summary';
  if (q.match(/penawaran|quotation|quote/)) return 'quotation';
  if (q.match(/mou|perjanjian|kerjasama|nota kesepahaman/)) return 'mou';
  if (q.match(/kontrak|kerja\s*karyawan|contract|perjanjian\s*kerja/)) return 'employee_contract';
  return null;
}

// ============ FINANCIAL INTENT DETECTION ============

function isFinancialAnalysis(msg: string): string | null {
  const q = msg.toLowerCase();
  if (q.match(/hpp|harga\s*pokok|biaya\s*produksi/)) return 'hpp_profit';
  if (q.match(/profit\s*(di\s*tangan|terkumpul|sudah|yang)|laba\s*(di\s*tangan|terkumpul)/)) return 'hpp_profit';
  if (q.match(/uang\s*(yang|sudah)\s*(di\s*tangan|terkumpul|tersedia)/)) return 'hpp_profit';
  if (q.match(/saran\s*(beli|restock|pengadaan)/)) return 'restock';
  if (q.match(/rekomendasi\s*(beli|restock|stok|pengadaan)/)) return 'restock';
  if (q.match(/apa\s*(yang|saja)\s*(harus|perlu|sebaiknya)\s*di\s*(beli|restock|adakan)/)) return 'restock';
  if (q.match(/tren\s*(penjualan|sales|omset)/)) return 'sales_trend';
  if (q.match(/analisa\s*(penjualan|keuangan|bisnis|financial)/)) return 'sales_trend';
  if (q.match(/analisis\s*(penjualan|keuangan|bisnis|financial)/)) return 'sales_trend';
  if (q.match(/prediksi|predict|forecast/) && q.match(/konsumen|customer|pelanggan/)) return 'customer_prediction';
  if (q.match(/kemungkinan.*(konsumen|customer|pelanggan).*(beli|order|pesan)/)) return 'customer_prediction';
  if (q.match(/uang\s*masuk|arus\s*kas|cash\s*flow/)) return 'cash_flow_audit';
  if (q.match(/selisih|discrepancy|ketidaksesuaian/)) return 'cash_flow_audit';
  if (q.match(/audit|telusuri|investigasi/)) return 'cash_flow_audit';
  if (q.match(/keuangan\s*(sehat|baik|buruk|kondisi)/)) return 'financial_health';
  if (q.match(/kesehatan\s*(keuangan|bisnis|financial)/)) return 'financial_health';
  if (q.match(/hutang|debt|piutang\s*(total|ringkasan|analisis)/)) return 'debt_analysis';
  if (q.match(/aset|asset\s*(value|nilai)/)) return 'asset_value';
  return null;
}

// ============ MAIN HANDLER ============

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { message, history } = body;

    let isSuperAdmin = false;
    const userId = await verifyAuthUser(request.headers.get('authorization'));
    if (userId) {
      const { data: authUser } = await db.from('users').select('role, is_active, status').eq('id', userId).single();
      isSuperAdmin = authUser?.role === 'super_admin' && authUser?.is_active && authUser?.status === 'approved';
    }

    if (!message || typeof message !== 'string' || !message.trim()) {
      return NextResponse.json({ error: 'Pesan wajib diisi' }, { status: 400 });
    }

    // 1. Check for data query intents first (quick responses)
    const dataIntent = isDataQuery(message, isSuperAdmin);
    let reply: string;

    switch (dataIntent) {
      case 'restricted':
        reply = '🔒 Info HPP/profit hanya untuk Super Admin.';
        return NextResponse.json({ success: true, reply });
      case 'sales_today':
        reply = await handleSalesToday(isSuperAdmin);
        return NextResponse.json({ success: true, reply });
      case 'sales_week':
        reply = await handleSalesWeek(isSuperAdmin);
        return NextResponse.json({ success: true, reply });
      case 'sales_month':
        reply = await handleSalesMonth(isSuperAdmin);
        return NextResponse.json({ success: true, reply });
      case 'sales_per_sales':
        reply = await handleSalesPerSales(isSuperAdmin);
        return NextResponse.json({ success: true, reply });
      case 'stock_all':
        reply = await handleStockAll(isSuperAdmin);
        return NextResponse.json({ success: true, reply });
      case 'stock_low':
        reply = await handleStockLow();
        return NextResponse.json({ success: true, reply });
      case 'customers_unpaid':
        reply = await handleCustomersUnpaid();
        return NextResponse.json({ success: true, reply });
      case 'customers_summary':
        reply = await handleCustomersSummary();
        return NextResponse.json({ success: true, reply });
      case 'quotation': {
        const custName = message.replace(/.*penawaran\s+(untuk|kepada)?\s*/i, '').trim();
        reply = JSON.stringify({ action: 'open_quotation', customerName: custName || '' });
        return NextResponse.json({ success: true, reply, isQuotation: true });
      }
      case 'mou': {
        const partnerName = message.replace(/.*(mou|perjanjian|kerjasama|nota kesepahaman)\s+(dengan|untuk|kepada)?\s*/i, '').trim();
        reply = JSON.stringify({ action: 'open_mou', partnerName: partnerName || '' });
        return NextResponse.json({ success: true, reply, isMou: true });
      }
      case 'employee_contract': {
        const empName = message.replace(/.*(kontrak|kerja|contract|perjanjian)\s+(karyawan|kerja)?\s*(untuk|kepada|dengan)?\s*/i, '').trim();
        reply = JSON.stringify({ action: 'open_employee_contract', employeeName: empName || '' });
        return NextResponse.json({ success: true, reply, isEmployeeContract: true });
      }
    }

    // 2. Check for financial analysis queries (require auth + super_admin)
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized — login untuk menggunakan chat' }, { status: 401 });
    }

    const financialIntent = isFinancialAnalysis(message);
    if (isSuperAdmin && financialIntent) {
      let isFinancial = true;
      switch (financialIntent) {
        case 'hpp_profit':
          reply = await handleHppProfitAnalysis();
          return NextResponse.json({ success: true, reply, isFinancial });
        case 'restock':
          reply = await handleRestockRecommendation();
          return NextResponse.json({ success: true, reply, isFinancial });
        case 'sales_trend':
          reply = await handleSalesTrend();
          return NextResponse.json({ success: true, reply, isFinancial });
        case 'customer_prediction':
          reply = await handleCustomerPrediction();
          return NextResponse.json({ success: true, reply, isFinancial });
        case 'cash_flow_audit':
          reply = await handleCashFlowAudit();
          return NextResponse.json({ success: true, reply, isFinancial });
        case 'financial_health':
          reply = await handleFinancialHealth();
          return NextResponse.json({ success: true, reply, isFinancial });
        case 'debt_analysis':
          reply = await handleDebtAnalysis();
          return NextResponse.json({ success: true, reply, isFinancial });
        case 'asset_value':
          reply = await handleAssetValue();
          return NextResponse.json({ success: true, reply, isFinancial });
      }
    }

    // 3. General conversation fallback — pure logic-based response
    reply = generateSmartResponse(message, isSuperAdmin);
    return NextResponse.json({ success: true, reply });
  } catch (error) {
    console.error('AI Chat error:', error);
    return NextResponse.json({ error: 'Gagal menganalisis data' }, { status: 500 });
  }
}

// ============ SMART RESPONSE GENERATOR ============

function generateSmartResponse(message: string, isSuperAdmin: boolean): string {
  const q = message.toLowerCase().trim();

  // Greeting
  if (q.match(/^(hai|halo|hello|hi|selamat|hey)/)) {
    return `Halo! 👋 Saya **Asisten Razkindo ERP**.\n\nSaya bisa membantu:\n• 💰 Data penjualan (hari/minggu/bulan)\n• 📦 Stok produk & saran restock\n• 📋 Piutang & konsumen\n• 📝 Buat penawaran / MOU\n• 📄 Buat kontrak kerja karyawan\n${isSuperAdmin ? '• 🔍 Analisis HPP & profit\n• 🏥 Cek kesehatan keuangan\n• 🎯 Prediksi konsumen\n• 💵 Audit arus kas\n' : ''}Klik tombol cepat atau tanya langsung!`;
  }

  // Help
  if (q.match(/^(help|bantuan|bantu|bisa apa|menu|fitur)/)) {
    return `📋 **Menu Bantuan**\n\n**Data Cepat:**\n• "penjualan hari ini" / "bulan ini"\n• "stok produk" / "stok rendah"\n• "piutang" / "konsumen"\n• "penjualan per sales"\n\n**Dokumen:**\n• "buat penawaran untuk [nama]"\n• "buat mou dengan [nama]"\n• "buat kontrak kerja karyawan [nama]"\n${isSuperAdmin ? '\n**Analisis Keuangan:**\n• "cek HPP & profit"\n• "saran restock"\n• "analisa penjualan"\n• "prediksi konsumen"\n• "audit uang masuk"\n• "kesehatan keuangan"\n• "analisis hutang & piutang"\n• "nilai aset"' : ''}`;
  }

  // Default
  return `Maaf, saya tidak mengerti pertanyaan tersebut. 😅\n\nCoba tanyakan:\n• "penjualan hari ini"\n• "stok produk"\n• "buat penawaran"\n• "buat mou"\n• "buat kontrak kerja"\n${isSuperAdmin ? '• "cek HPP & profit"\n• "kesehatan keuangan"\n' : ''}\nKetik **"help"** untuk melihat semua fitur.`;
}

export async function DELETE(request: NextRequest) {
  const userId = await verifyAuthUser(request.headers.get('authorization'));
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  return NextResponse.json({ success: true });
}
