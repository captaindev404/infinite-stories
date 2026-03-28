import { NextRequest, NextResponse } from 'next/server';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { EnhancePromptSchema, type EnhancePromptInput } from '@/lib/api/schemas';
import { sanitizeAIError } from '@/lib/api/ai-errors';
import { wrapUserInput, UNTRUSTED_INPUT_INSTRUCTION } from '@/lib/api/prompt-safety';

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, EnhancePromptSchema, 'story_generation', async (_user, body: EnhancePromptInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { title, description, category, ageRange, tone } = body;

    const prompt = `Enhance this bedtime story event into a detailed, engaging story prompt:

Title: ${wrapUserInput(title)}
Description: ${wrapUserInput(description)}
Category: ${wrapUserInput(category || 'General')}
Age Range: ${wrapUserInput(ageRange || '4-10')}
Tone: ${wrapUserInput(tone || 'Peaceful')}

Create a rich, detailed story prompt that a storyteller can use to generate an engaging bedtime story. Include:
- Setting details
- Character motivations
- Key story beats
- Emotional arc
- Sensory details

Keep it under 150 words. Focus on creating a vivid, engaging narrative framework.`;

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
            content: `${UNTRUSTED_INPUT_INSTRUCTION}\n\nYou are an expert at crafting detailed story prompts for children's bedtime stories.`,
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        temperature: 0.7,
        max_tokens: 150,
      }),
    });

    if (!response.ok) {
      return sanitizeAIError(new Error(`OpenAI API error: ${response.status}`));
    }

    const data = await response.json();
    const enhancedPrompt = data.choices[0].message.content.trim();

    return NextResponse.json({ enhancedPrompt });
  });
}
