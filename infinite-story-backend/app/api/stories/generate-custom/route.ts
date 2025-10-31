import { NextRequest, NextResponse } from 'next/server';
import type { CustomStoryGenerationRequest, StoryGenerationResponse } from '@/types/openai';

export async function POST(request: NextRequest) {
  try {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const body: CustomStoryGenerationRequest = await request.json();
    const { hero, customEvent, targetDuration, language } = body;

    if (!hero || !customEvent || !targetDuration || !language) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    const targetMinutes = Math.floor(targetDuration / 60);
    const traits = `${hero.primaryTrait}, ${hero.secondaryTrait}, ${
      hero.appearance || 'lovable appearance'
    }, ${hero.specialAbility || 'warm heart'}`;

    let prompt = `Create a ${targetMinutes}-minute bedtime story for a child about ${hero.name}, who is ${traits}.

Story context: ${customEvent.promptSeed}`;

    // Add keywords if available
    if (customEvent.keywords && customEvent.keywords.length > 0) {
      prompt += `\n\nPlease include these elements in the story: ${customEvent.keywords.join(', ')}`;
    }

    // Add tone guidance
    prompt += `\n\nThe story should have a ${customEvent.tone.toLowerCase()} tone.`;

    // Add age-appropriate guidance
    prompt += `\nMake sure the story is appropriate for children aged ${customEvent.ageRange}.`;

    prompt += `\n\nIMPORTANT INSTRUCTIONS:
- Write a complete, flowing story without any formatting markers
- Use natural, conversational language suitable for audio narration
- Include dialogue and sound effects naturally in the text
- Avoid special characters or formatting that would sound strange when read aloud
- Make the story engaging and immersive for bedtime listening
- DO NOT include scene markers, titles, or any meta-information
- Just tell the story from beginning to end`;

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
            content: `You are a skilled children's bedtime storyteller who creates engaging, age-appropriate stories in ${language}.`,
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
      const error = await response.json();
      return NextResponse.json(error, { status: response.status });
    }

    const data = await response.json();
    const content = data.choices[0].message.content;

    // Use custom event title
    const title = customEvent.title;

    // Estimate duration
    const wordCount = content.split(/\s+/).length;
    const estimatedDuration = (wordCount / 200.0) * 60.0;

    const result: StoryGenerationResponse = {
      title,
      content: content.trim(),
      estimatedDuration,
      scenes: undefined,
    };

    return NextResponse.json(result);
  } catch (error) {
    console.error('Custom story generation error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
