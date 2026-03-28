import { NextRequest, NextResponse } from 'next/server';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { GenerateKeywordsSchema, type GenerateKeywordsInput } from '@/lib/api/schemas';

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, GenerateKeywordsSchema, 'story_generation', async (_user, body: GenerateKeywordsInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { event, description } = body;

    const prompt = `Generate 5-8 relevant keywords for this bedtime story event:

Event: ${event}
Description: ${description}

Keywords should be:
- Single words or short phrases (1-3 words)
- Relevant to the story theme
- Child-appropriate
- Helpful for story generation

Return only the keywords separated by commas, nothing else.`;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        messages: [
          {
            role: 'system',
            content: 'You are an expert at identifying relevant keywords for children\'s stories.',
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        temperature: 0.7,
        max_tokens: 50,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      return NextResponse.json(error, { status: response.status });
    }

    const data = await response.json();
    const keywordsText = data.choices[0].message.content;
    const keywords = keywordsText
      .split(',')
      .map((k: string) => k.trim())
      .filter((k: string) => k.length > 0)
      .slice(0, 8);

    return NextResponse.json({ keywords });
  });
}
