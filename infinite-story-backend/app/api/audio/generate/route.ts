import { NextRequest, NextResponse } from 'next/server';
import type { AudioGenerationRequest } from '@/types/openai';

const VOICE_INSTRUCTIONS: Record<string, string> = {
  coral: 'Speak with a warm, gentle, and nurturing tone perfect for bedtime stories. Use a calm and soothing pace with clear pronunciation. Add subtle emotional expressions to bring characters to life while maintaining a peaceful atmosphere that helps children relax and drift off to sleep.',
  nova: 'Use a friendly, cheerful, and engaging storyteller voice that captivates young listeners. Speak clearly at a moderate pace with gentle enthusiasm. Create distinct character voices while keeping the overall tone calming and suitable for bedtime. Emphasize wonder and magic in the narrative.',
  fable: 'Adopt a wise, comforting grandfather-like tone that makes children feel safe and loved. Use a slower, deliberate pace with warm inflections. Add gentle dramatic pauses for effect and speak as if sharing a treasured tale. Keep the voice soft and reassuring throughout.',
  alloy: 'Speak with a clear, pleasant, and neutral tone that\'s easy for children to understand. Use moderate pacing with good articulation. Add subtle warmth and friendliness while maintaining consistency. Perfect for educational elements in the story.',
  echo: 'Use a soft, dreamy, and ethereal voice that creates a magical atmosphere. Speak gently with a flowing rhythm that mimics the natural cadence of bedtime stories. Add whisper-like qualities for mysterious moments while keeping the overall tone comforting.',
  onyx: 'Deliver the story with a deep, warm, and reassuring voice like a protective parent. Use a slow, steady pace that helps children feel secure. Add gravitas to important moments while maintaining gentleness. Perfect for adventure stories that need to stay calming.',
  shimmer: 'Speak with a bright, melodic, and enchanting voice that sparkles with imagination. Use varied intonation to paint vivid pictures while keeping the energy level appropriate for bedtime. Add musical qualities to dialogue and maintain a soothing undertone throughout.',
};

const LANGUAGE_INSTRUCTIONS: Record<string, string> = {
  en: 'Speak in clear, natural English with proper intonation and expression.',
  es: 'Speak in clear, natural Spanish with proper intonation and expression.',
  fr: 'Speak in clear, natural French with proper intonation and expression.',
  de: 'Speak in clear, natural German with proper intonation and expression.',
  it: 'Speak in clear, natural Italian with proper intonation and expression.',
};

export async function POST(request: NextRequest) {
  try {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const body: AudioGenerationRequest = await request.json();
    const { text, voice, language } = body;

    if (!text || !voice || !language) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    // Build voice instructions
    const baseInstructions = VOICE_INSTRUCTIONS[voice.toLowerCase()] || VOICE_INSTRUCTIONS.coral;
    const languageInstruction = LANGUAGE_INSTRUCTIONS[language] || LANGUAGE_INSTRUCTIONS.en;
    const instructions = `${baseInstructions} ${languageInstruction}`;

    // Call OpenAI TTS API
    const response = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini-tts',
        input: text,
        voice: voice,
        instructions: instructions,
        response_format: 'mp3',
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      return NextResponse.json(error, { status: response.status });
    }

    // Get audio data as buffer
    const audioBuffer = await response.arrayBuffer();
    const audioBase64 = Buffer.from(audioBuffer).toString('base64');

    return NextResponse.json({
      audioData: audioBase64,
      format: 'mp3',
      size: audioBuffer.byteLength,
    });
  } catch (error) {
    console.error('Audio generation error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
