import { NextRequest, NextResponse } from 'next/server';
import { SAFE_REWRITER_SYSTEM_PROMPT } from '@/lib/prompts';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { SanitizePromptSchema, type SanitizePromptInput } from '@/lib/api/schemas';

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, SanitizePromptSchema, 'story_generation', async (_user, body: SanitizePromptInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { prompt } = body;

    // Use centralized system prompt for safety rewriting
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: SAFE_REWRITER_SYSTEM_PROMPT,
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        max_tokens: 500,
        temperature: 0.3,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      return NextResponse.json(error, { status: response.status });
    }

    const data = await response.json();
    const sanitizedPrompt = data.choices[0].message.content.trim();

    // Log the sanitization for debugging
    console.log('Prompt sanitization results:');
    console.log('Original:', prompt.substring(0, 100) + '...');
    console.log('Sanitized:', sanitizedPrompt.substring(0, 100) + '...');
    console.log('Tokens used:', data.usage?.total_tokens || 'unknown');

    return NextResponse.json({
      sanitizedPrompt,
      original: prompt,
      tokensUsed: data.usage?.total_tokens
    });
  });
}
