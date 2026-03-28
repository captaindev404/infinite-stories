import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { getOrCreateUser } from '@/lib/auth/session';
import { successResponse, errorResponse, handleApiError } from '@/lib/utils/api-response';
import { generateAudio, getRecommendedVoice, validateAudioText } from '@/lib/openai/audio-generator';
import { enforceRateLimit, recordApiUsage } from '@/lib/rate-limit/db-rate-limiter';
import { generateSignedUrl } from '@/lib/storage/signed-url';
import type { SupportedLanguage } from '@/lib/openai/client';

/**
 * POST /api/stories/[storyId]/audio
 * Generate audio for a story
 */
export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ storyId: string }> }
) {
  const startTime = Date.now();

  try {
    const user = await getOrCreateUser();
    const { storyId } = await params;
    const body = await req.json();

    // Get the story
    const story = await prisma.story.findUnique({
      where: { id: storyId },
      include: {
        hero: true,
      },
    });

    if (!story) {
      return errorResponse('NotFound', 'Story not found', 404);
    }

    if (story.userId !== user.id) {
      return errorResponse('Forbidden', 'You do not have access to this story', 403);
    }

    // Check if audio already exists and not regenerating
    if (story.audioUrl && story.audioGenerationStatus === 'completed' && !body.regenerate) {
      // Sign the URL for secure access
      const signedAudioUrl = await generateSignedUrl(story.audioUrl);
      return successResponse(
        {
          audioUrl: signedAudioUrl,
          audioDuration: story.audioDuration,
          status: 'completed',
        },
        'Audio already exists for this story'
      );
    }

    // Check rate limit
    await enforceRateLimit(user.id, 'audio_generation');

    // Validate text
    const validation = validateAudioText(story.content);
    if (!validation.valid) {
      return errorResponse('ValidationError', validation.error || 'Invalid text', 400);
    }

    // Update status to processing
    await prisma.story.update({
      where: { id: storyId },
      data: {
        audioGenerationStatus: 'processing',
        audioGenerationError: null,
      },
    });

    // Get recommended voice or use provided voice
    const voice = body.voice || (story.hero ? getRecommendedVoice(
      story.language as SupportedLanguage,
      story.hero.traits as string[]
    ) : undefined);

    // Generate audio
    const audio = await generateAudio({
      text: story.content,
      voice,
      language: story.language as SupportedLanguage,
      userId: user.id,
      storyId: story.id,
    });

    // Update story with audio URL
    const updatedStory = await prisma.story.update({
      where: { id: storyId },
      data: {
        audioUrl: audio.audioUrl,
        audioDuration: audio.duration,
        audioGenerationStatus: 'completed',
      },
    });

    // Record API usage
    const duration = Date.now() - startTime;
    await recordApiUsage({
      userId: user.id,
      operation: 'audio_generation',
      model: 'tts-1',
      estimatedCost: 0.015, // $15 per 1M characters
      requestDuration: duration,
      success: true,
    });

    // Update user stats
    await prisma.user.update({
      where: { id: user.id },
      data: {
        totalAudioGenerated: { increment: 1 },
      },
    });

    // Sign the URL for secure access
    const signedAudioUrl = await generateSignedUrl(audio.audioUrl);

    return successResponse(
      {
        audioUrl: signedAudioUrl,
        audioDuration: audio.duration,
        voice: audio.voice,
        status: 'completed',
      },
      'Audio generated successfully'
    );
  } catch (error) {
    // Log full error server-side, store sanitized message in DB
    console.error('[Audio Generation Error]', error);
    const { storyId } = await params;
    await prisma.story.update({
      where: { id: storyId },
      data: {
        audioGenerationStatus: 'failed',
        audioGenerationError: 'Audio generation failed',
      },
    }).catch(() => {});

    // Record failed API usage
    const duration = Date.now() - startTime;
    const user = await getOrCreateUser().catch(() => null);

    if (user) {
      await recordApiUsage({
        userId: user.id,
        operation: 'audio_generation',
        model: 'tts-1',
        requestDuration: duration,
        success: false,
        errorMessage: (error as Error).message,
      });
    }

    return handleApiError(error);
  }
}

/**
 * GET /api/stories/[storyId]/audio
 * Get audio generation status
 */
export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ storyId: string }> }
) {
  try {
    const user = await getOrCreateUser();
    const { storyId } = await params;

    // Get the story
    const story = await prisma.story.findUnique({
      where: { id: storyId },
      select: {
        id: true,
        userId: true,
        audioUrl: true,
        audioDuration: true,
        audioGenerationStatus: true,
        audioGenerationError: true,
      },
    });

    if (!story) {
      return errorResponse('NotFound', 'Story not found', 404);
    }

    if (story.userId !== user.id) {
      return errorResponse('Forbidden', 'You do not have access to this story', 403);
    }

    // Sign the URL for secure access if it exists
    const signedAudioUrl = story.audioUrl
      ? await generateSignedUrl(story.audioUrl)
      : null;

    return successResponse({
      audioUrl: signedAudioUrl,
      audioDuration: story.audioDuration,
      status: story.audioGenerationStatus,
      error: story.audioGenerationError,
    });
  } catch (error) {
    return handleApiError(error);
  }
}
