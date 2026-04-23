import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthUser } from '@/lib/token';

// TTS (Text-to-Speech) has been removed — no external AI dependency.
// This endpoint returns a placeholder response.
export async function POST(request: NextRequest) {
  try {
    const authUserId = await verifyAuthUser(request.headers.get('authorization'));
    if (!authUserId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    return NextResponse.json({
      error: 'Fitur TTS tidak tersedia. Gunakan text-to-speech bawaan browser.',
      suggestion: 'Gunakan Web Speech API: window.speechSynthesis.speak(new SpeechSynthesisUtterance(text))'
    }, { status: 501 });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Internal server error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
