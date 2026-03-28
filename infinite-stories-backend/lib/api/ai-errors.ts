import { NextResponse } from 'next/server';

/**
 * Sanitize an OpenAI API error before returning to the client.
 * Logs the full error server-side; returns only a generic code + message.
 */
export function sanitizeAIError(error: unknown): NextResponse {
  console.error('[AI Error]', error);

  const isRateLimit =
    error instanceof Error &&
    (error.message.includes('429') || error.message.toLowerCase().includes('rate limit'));

  return NextResponse.json(
    {
      code: isRateLimit ? 'RATE_LIMIT' : 'AI_ERROR',
      message: isRateLimit
        ? 'AI service is temporarily busy. Please try again in a moment.'
        : 'An error occurred while generating content. Please try again.',
    },
    { status: isRateLimit ? 429 : 502 },
  );
}
