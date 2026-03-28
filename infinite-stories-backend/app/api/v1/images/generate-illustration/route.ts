import { NextRequest, NextResponse } from 'next/server';
import type { ImageGenerationResponse } from '@/types/openai';
import { SanitizationService, ILLUSTRATION_STYLE_GUIDANCE, buildCharacterConsistencyPrompt } from '@/lib/prompts';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { ImageGenerateIllustrationSchema, type ImageGenerateIllustrationInput } from '@/lib/api/schemas';
import { sanitizeAIError } from '@/lib/api/ai-errors';

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, ImageGenerateIllustrationSchema, 'illustration_generation', async (_user, body: ImageGenerateIllustrationInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { prompt, hero, previousGenerationId } = body;

    // Apply centralized sanitization to the scene prompt
    const sanitizationResult = SanitizationService.sanitize(prompt, 'en');
    SanitizationService.logResults(sanitizationResult, 'illustration-route');

    if (sanitizationResult.riskLevel === 'high') {
      return NextResponse.json(
        { error: 'Content safety check failed' },
        { status: 400 }
      );
    }

    // Build character consistency prompt using centralized template
    const heroConsistency = buildCharacterConsistencyPrompt(
      hero.name,
      hero.appearance,
      hero.avatarPrompt,
      hero.primaryTrait,
      hero.secondaryTrait
    );

    // Combine sanitized prompt with centralized style guidance
    const filteredPrompt = `${sanitizationResult.sanitized}\n\n${heroConsistency}\n\n${ILLUSTRATION_STYLE_GUIDANCE}`;

    // Build request body
    const requestBody: any = {
      model: 'gpt-image-1',
      prompt: filteredPrompt,
      n: 1,
      size: '1024x1024',
      quality: 'high',
      background: 'auto',
      output_format: 'png',
      moderation: 'auto',
    };

    // Add previous generation ID for multi-turn consistency
    if (previousGenerationId) {
      requestBody.previous_generation_id = previousGenerationId;
    }

    // Call OpenAI Image Generation API
    const response = await fetch('https://api.openai.com/v1/images/generations', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      return sanitizeAIError(new Error(`OpenAI Image API error: ${response.status}`));
    }

    const data = await response.json();
    const firstImage = data.data[0];

    // Extract generation ID
    const generationId =
      firstImage.generation_id ||
      firstImage.generationId ||
      firstImage.gen_id ||
      firstImage.id ||
      data.generation_id ||
      data.generationId ||
      data.gen_id;

    const result: ImageGenerationResponse = {
      imageData: firstImage.b64_json,
      revisedPrompt: firstImage.revised_prompt,
      generationId: generationId,
    };

    // Include usage info if available
    if (data.usage) {
      return NextResponse.json({
        ...result,
        usage: data.usage,
      });
    }

    return NextResponse.json(result);
  });
}
