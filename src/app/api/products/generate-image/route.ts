import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthUser } from '@/lib/token';

// Product image generation has been removed — no external AI dependency.
// Products should use uploaded images instead.
export async function POST(request: NextRequest) {
  try {
    const authUserId = await verifyAuthUser(request.headers.get('authorization'));
    if (!authUserId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    return NextResponse.json({
      error: 'Fitur generate gambar produk tidak tersedia. Upload gambar secara manual.',
      suggestion: 'Upload foto produk di halaman Products → Edit Product'
    }, { status: 501 });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Internal server error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
