import { NextRequest, NextResponse } from 'next/server';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { GenerateTitleSchema, type GenerateTitleInput } from '@/lib/api/schemas';

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, GenerateTitleSchema, 'story_generation', async (_user, body: GenerateTitleInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { description, language = 'en' } = body;

    const prompt = `Generate a short, catchy title (3-6 words) for a custom bedtime story event based on this description:

"${description}"

Return only the title, nothing else.`;

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
            content: `You are a creative children's story title generator. Generate titles that are engaging and appropriate for children in ${language}.`,
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        temperature: 0.7,
        max_tokens: 20,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      return NextResponse.json(error, { status: response.status });
    }

    const data = await response.json();
    const title = data.choices[0].message.content.trim();

    return NextResponse.json({ title });
  });
}
