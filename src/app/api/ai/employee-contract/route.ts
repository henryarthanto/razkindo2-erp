import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/supabase';
import { format } from 'date-fns';
import { id } from 'date-fns/locale';
import { verifyAuthUser } from '@/lib/token';
import { toCamelCase } from '@/lib/supabase-helpers';

export async function POST(request: NextRequest) {
  try {
    const userId = await verifyAuthUser(request.headers.get('authorization'));
    if (!userId) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { employeeName, position, department, salary, startDate, endDate, workHours, workLocation, contractType, probationPeriod } = await request.json();

    // Get company settings
    const { data: settings } = await db.from('settings').select('*');
    const settingsMap: Record<string, any> = {};
    (settings || []).forEach((s: any) => {
      try { settingsMap[s.key] = JSON.parse(s.value); } catch { settingsMap[s.key] = s.value; }
    });

    const company = {
      name: settingsMap.company_name || 'Razkindo Group',
      phone: settingsMap.company_phone || '',
      address: settingsMap.company_address || '',
      email: settingsMap.company_email || '',
      logo: settingsMap.company_logo || '',
    };

    // Find employee by name
    let employee: any = null;
    if (employeeName) {
      const { data: user } = await db
        .from('users')
        .select('*')
        .ilike('name', `%${employeeName}%`)
        .eq('is_active', true)
        .eq('status', 'approved')
        .limit(1)
        .maybeSingle();
      if (user) employee = toCamelCase(user);
    }

    // Generate contract number
    const now = new Date();
    const contractNo = `KK-${format(now, 'yyyyMMdd')}-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`;
    const contractDate = format(now, 'dd MMMM yyyy', { locale: id });

    return NextResponse.json({
      success: true,
      company,
      employee: employee ? {
        id: employee.id,
        name: employee.name,
        email: employee.email,
        phone: employee.phone,
        role: employee.role,
        unitId: employee.unitId,
      } : null,
      contractNo,
      date: contractDate,
      position: position || employee?.role || '',
      department: department || '',
      salary: salary || 0,
      startDate: startDate || format(now, 'yyyy-MM-dd'),
      endDate: endDate || '',
      workHours: workHours || '08:00 - 17:00',
      workLocation: workLocation || company.address,
      contractType: contractType || 'PKWT',
      probationPeriod: probationPeriod || 3,
    });
  } catch (error) {
    console.error('Employee contract error:', error);
    return NextResponse.json({ error: 'Gagal memproses kontrak kerja' }, { status: 500 });
  }
}
