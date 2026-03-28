import { NextRequest, NextResponse } from 'next/server';
import type { ImageGenerationResponse } from '@/types/openai';
import { SanitizationService } from '@/lib/prompts';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { ImageGenerateAvatarSchema, type ImageGenerateAvatarInput } from '@/lib/api/schemas';

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, ImageGenerateAvatarSchema, 'avatar_generation', async (_user, body: ImageGenerateAvatarInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { prompt, size = '1024x1024', quality = 'high', previousGenerationId } = body;

    // Apply centralized sanitization
    const sanitizationResult = SanitizationService.sanitize(prompt, 'en');
    SanitizationService.logResults(sanitizationResult, 'avatar-route');

    if (sanitizationResult.riskLevel === 'high') {
      return NextResponse.json(
        { error: 'Content safety check failed' },
        { status: 400 }
      );
    }

    const filteredPrompt = sanitizationResult.sanitized;

    // Map quality parameter (standard/hd -> low/medium/high for GPT-Image-1)
    let gptImageQuality = quality;
    if (quality === 'standard') gptImageQuality = 'medium';
    if (quality === 'hd') gptImageQuality = 'high';

    // Build request body
    const requestBody: any = {
      model: 'gpt-image-1',
      prompt: filteredPrompt,
      n: 1,
      size: size,
      quality: gptImageQuality,
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
      const error = await response.json();
      return NextResponse.json(error, { status: response.status });
    }

    const data = await response.json();
    const firstImage = data.data[0];

    // Extract generation ID from response
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
