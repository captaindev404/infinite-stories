import { NextRequest, NextResponse } from 'next/server';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { SuggestSimilarEventsSchema, type SuggestSimilarEventsInput } from '@/lib/api/schemas';
import { sanitizeAIError } from '@/lib/api/ai-errors';
import { wrapUserInput, UNTRUSTED_INPUT_INSTRUCTION } from '@/lib/api/prompt-safety';

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, SuggestSimilarEventsSchema, 'story_generation', async (_user, body: SuggestSimilarEventsInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { description } = body;

    const prompt = `Based on this story event description, suggest 3 similar but distinct bedtime story event ideas:

${wrapUserInput(description)}

Each suggestion should be:
- Different from the original but thematically related
- Appropriate for children's bedtime stories
- Brief (5-8 words each)

Return only the 3 suggestions separated by | characters, nothing else.`;

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
            content: `${UNTRUSTED_INPUT_INSTRUCTION}\n\nYou are a creative children's story consultant who suggests related story ideas.`,
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        temperature: 0.7,
        max_tokens: 60,
      }),
    });

    if (!response.ok) {
      return sanitizeAIError(new Error(`OpenAI API error: ${response.status}`));
    }

    const data = await response.json();
    const suggestionsText = data.choices[0].message.content;
    const suggestions = suggestionsText
      .split('|')
      .map((s: string) => s.trim())
      .filter((s: string) => s.length > 0)
      .slice(0, 3);

    return NextResponse.json({ suggestions });
  });
}
