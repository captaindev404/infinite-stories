import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { requireAuth } from '@/lib/auth/session';
import {
  successResponse,
  errorResponse,
  handleApiError,
  validateRequiredFields,
} from '@/lib/utils/api-response';
import { generateStory, extractScenesFromStory } from '@/lib/openai/story-generator';
import { clampPagination } from '@/lib/api/pagination';
import { enforceRateLimit, recordApiUsage } from '@/lib/rate-limit/db-rate-limiter';
import { signStoryUrls, signHeroUrls } from '@/lib/storage/signed-url';
import type { SupportedLanguage } from '@/lib/openai/client';

/**
 * POST /api/stories
 * Generate a new personalized story for a hero
 */
export async function POST(req: NextRequest) {
  const startTime = Date.now();

  try {
    // Check authentication
    const authUser = await requireAuth();
    if (!authUser) {
      return errorResponse('Unauthorized', 'Authentication required', 401);
    }

    // Get full user from database
    const user = await prisma.user.findUnique({
      where: { id: authUser.id },
    });

    if (!user) {
      return errorResponse('NotFound', 'User not found', 404);
    }

    const body = await req.json();

    // Validate required fields
    const validation = validateRequiredFields(body, ['heroId', 'language']);
    if (!validation.valid) {
      return errorResponse(
        'ValidationError',
        `Missing required fields: ${validation.missing?.join(', ')}`,
        400
      );
    }

    // Get the hero
    const hero = await prisma.hero.findUnique({
      where: { id: body.heroId },
      include: {
        visualProfile: true,
      },
    });

    if (!hero) {
      return errorResponse('NotFound', 'Hero not found', 404);
    }

    if (hero.userId !== user.id) {
      return errorResponse('Forbidden', 'You do not have access to this hero', 403);
    }

    // Check rate limit
    await enforceRateLimit(user.id, 'story_generation');

    // Generate the story
    const language = body.language as SupportedLanguage;
    const story = await generateStory({
      heroName: hero.name,
      heroAge: hero.age,
      heroTraits: hero.traits as string[],
      specialAbilities: hero.specialAbilities as string[] | undefined,
      eventType: body.eventType,
      customPrompt: body.customPrompt,
      language,
      maxTokens: body.maxTokens || 2000,
    });

    // Extract scenes for potential illustrations
    const scenes = await extractScenesFromStory(story.content, language);

    // If using a custom event, verify it belongs to the user
    if (body.customEventId) {
      const customEvent = await prisma.customStoryEvent.findUnique({
        where: { id: body.customEventId },
      });

      if (!customEvent) {
        return errorResponse('NotFound', 'Custom event not found', 404);
      }

      if (customEvent.userId !== user.id) {
        return errorResponse('Forbidden', 'You do not have access to this custom event', 403);
      }
    }

    // Create story in database
    const createdStory = await prisma.story.create({
      data: {
        heroId: hero.id,
        userId: user.id,
        title: story.title,
        content: story.content,
        language,
        eventType: body.eventType || null,
        customEventId: body.customEventId || null,
        audioGenerationStatus: 'pending',
        illustrationStatus: scenes.length > 0 ? 'pending' : 'none',
        generationMetadata: {
          prompt: {
            heroName: hero.name,
            heroAge: hero.age,
            heroTraits: hero.traits,
            eventType: body.eventType,
            customPrompt: body.customPrompt,
          },
          scenesExtracted: scenes.length,
        },
      },
    });

    // Update custom event usage tracking if applicable
    if (body.customEventId) {
      await prisma.customStoryEvent.update({
        where: { id: body.customEventId },
        data: {
          usageCount: { increment: 1 },
          lastUsedAt: new Date(),
        },
      });
    }

    // Create scene placeholders for illustrations
    if (scenes.length > 0) {
      await prisma.storyIllustration.createMany({
        data: scenes.map((scene, index) => ({
          storyId: createdStory.id,
          sceneDescription: scene.sceneDescription,
          imageUrl: '', // Will be populated when generated
          imagePrompt: scene.sceneDescription,
          displayOrder: index,
          audioTimestamp: scene.audioTimestamp,
          audioDuration: scene.estimatedDuration,
          generationStatus: 'pending',
        })),
      });

      // Update illustration count
      await prisma.story.update({
        where: { id: createdStory.id },
        data: {
          illustrationCount: scenes.length,
        },
      });
    }

    // Record API usage
    const duration = Date.now() - startTime;
    await recordApiUsage({
      userId: user.id,
      operation: 'story_generation',
      model: 'gpt-4o',
      tokensUsed: 2000, // Estimate - would need actual token count from response
      estimatedCost: 0.03, // Approximate GPT-4o cost
      requestDuration: duration,
      success: true,
    });

    // Update user stats
    await prisma.user.update({
      where: { id: user.id },
      data: {
        totalStoriesGenerated: { increment: 1 },
        lastStoryGeneratedAt: new Date(),
      },
    });

    return successResponse(
      createdStory,
      'Story generated successfully',
      201
    );
  } catch (error) {
    // Record failed API usage
    const duration = Date.now() - startTime;
    const authUser = await requireAuth().catch(() => null);

    if (authUser) {
      await recordApiUsage({
        userId: authUser.id,
        operation: 'story_generation',
        model: 'gpt-4o',
        requestDuration: duration,
        success: false,
        errorMessage: (error as Error).message,
      });
    }

    return handleApiError(error);
  }
}

/**
 * GET /api/stories
 * List stories for the authenticated user
 */
export async function GET(req: NextRequest) {
  try {
    // Check authentication
    const authUser = await requireAuth();
    if (!authUser) {
      return errorResponse('Unauthorized', 'Authentication required', 401);
    }

    // Get full user from database
    const user = await prisma.user.findUnique({
      where: { id: authUser.id },
    });

    if (!user) {
      return errorResponse('NotFound', 'User not found', 404);
    }

    // Parse query parameters
    const { searchParams } = new URL(req.url);
    const heroId = searchParams.get('heroId');
    const includeIllustrations = searchParams.get('includeIllustrations') === 'true';
    const language = searchParams.get('language');
    const isFavorite = searchParams.get('isFavorite') === 'true';
    const updatedAfter = searchParams.get('updatedAfter'); // ISO8601 timestamp for incremental sync
    const { limit, offset } = clampPagination(searchParams.get('limit'), searchParams.get('offset'));

    // Build where clause
    const where: any = {
      userId: user.id,
    };

    if (heroId) {
      where.heroId = heroId;
    }

    if (language) {
      where.language = language;
    }

    if (isFavorite) {
      where.isFavorite = true;
    }

    // Add incremental sync filter if provided
    if (updatedAfter) {
      try {
        const updatedAfterDate = new Date(updatedAfter);
        where.updatedAt = {
          gt: updatedAfterDate,
        };
      } catch (error) {
        return errorResponse('ValidationError', 'Invalid updatedAfter parameter: must be ISO8601 timestamp', 400);
      }
    }

    // Get stories with filtering and pagination
    const stories = await prisma.story.findMany({
      where,
      include: {
        hero: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
        illustrations: includeIllustrations,
        _count: {
          select: { illustrations: true },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: limit,
      skip: offset,
    });

    // Get total count
    const total = await prisma.story.count({ where });

    // Sign all URLs for secure access
    const signedStories = await Promise.all(
      stories.map(async (story) => {
        const signedStory = await signStoryUrls(story) as typeof story;
        // Sign hero avatar URL if present
        if (signedStory.hero && 'avatarUrl' in signedStory.hero && signedStory.hero.avatarUrl) {
          (signedStory as any).hero = await signHeroUrls(signedStory.hero as any);
        }
        return signedStory;
      })
    );

    return successResponse({
      stories: signedStories,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + limit < total,
      },
    });
  } catch (error) {
    return handleApiError(error);
  }
}
