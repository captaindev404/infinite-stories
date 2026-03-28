import { NextRequest, NextResponse } from 'next/server';
import type { ImageGenerationResponse } from '@/types/openai';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { ImageGeneratePictogramSchema, type ImageGeneratePictogramInput } from '@/lib/api/schemas';

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, ImageGeneratePictogramSchema, 'illustration_generation', async (_user, body: ImageGeneratePictogramInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { prompt } = body;

    // Enhance prompt for pictogram style
    const pictogramPrompt = `${prompt}

Style: Simple, colorful pictogram/icon style illustration suitable for children. Flat design with bright, cheerful colors. Clear, recognizable shapes. Child-friendly and appropriate for all ages. No text or words. Professional icon design quality. 512x512 pixels.`;

    // Build request body
    const requestBody: any = {
      model: 'gpt-image-1',
      prompt: pictogramPrompt,
      n: 1,
      size: '512x512',
      quality: 'medium',
      background: 'auto',
      output_format: 'png',
      moderation: 'auto',
    };

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

    const result: ImageGenerationResponse = {
      imageData: firstImage.b64_json,
      revisedPrompt: firstImage.revised_prompt,
      generationId: firstImage.generation_id || firstImage.id,
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
