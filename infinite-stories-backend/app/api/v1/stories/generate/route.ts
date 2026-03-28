import { NextRequest, NextResponse } from 'next/server';
import type { StoryGenerationResponse } from '@/types/openai';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { StoryGenerateSchema, type StoryGenerateInput } from '@/lib/api/schemas';
import { sanitizeAIError } from '@/lib/api/ai-errors';
import { wrapUserInput, UNTRUSTED_INPUT_INSTRUCTION } from '@/lib/api/prompt-safety';

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, StoryGenerateSchema, 'story_generation', async (_user, body: StoryGenerateInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { hero, event, targetDuration, language } = body;

    // Build story generation prompt
    const targetMinutes = Math.floor(targetDuration / 60);
    const traits = `${hero.primaryTrait}, ${hero.secondaryTrait}, ${
      hero.appearance || 'lovable appearance'
    }, ${hero.specialAbility || 'warm heart'}`;

    const prompt = `Create a ${targetMinutes}-minute bedtime story for a child about ${wrapUserInput(hero.name)}, who is ${wrapUserInput(traits)}.

Story context: ${wrapUserInput(event.promptSeed)}

IMPORTANT INSTRUCTIONS:
- Write a complete, flowing story without any formatting markers
- Use natural, conversational language suitable for audio narration
- Include dialogue and sound effects naturally in the text
- Avoid special characters or formatting that would sound strange when read aloud
- Make the story engaging and immersive for bedtime listening
- DO NOT include scene markers, titles, or any meta-information
- Just tell the story from beginning to end`;

    // Call OpenAI Chat Completions API
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
            content: `${UNTRUSTED_INPUT_INSTRUCTION}\n\nYou are a skilled children's bedtime storyteller who creates engaging, age-appropriate stories in ${language}.`,
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        max_tokens: 2000,
        temperature: 0.8,
      }),
    });

    if (!response.ok) {
      return sanitizeAIError(new Error(`OpenAI API error: ${response.status}`));
    }

    const data = await response.json();
    const content = data.choices[0].message.content;

    // Generate title
    const title = `${hero.name} and the ${event.rawValue}`;

    // Estimate duration (200 words per minute)
    const wordCount = content.split(/\s+/).length;
    const estimatedDuration = (wordCount / 200.0) * 60.0;

    const result: StoryGenerationResponse = {
      title,
      content: content.trim(),
      estimatedDuration,
      scenes: undefined, // Scenes extracted separately
    };

    return NextResponse.json(result);
  });
}
