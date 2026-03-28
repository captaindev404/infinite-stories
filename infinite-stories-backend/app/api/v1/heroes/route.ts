import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { requireAuth } from '@/lib/auth/session';
import {
  successResponse,
  errorResponse,
  handleApiError,
} from '@/lib/utils/api-response';
import { signHeroUrls, signStoryUrls } from '@/lib/storage/signed-url';
import { withAuthAndValidation, type AuthUser } from '@/lib/api/with-auth';
import { CreateHeroSchema, type CreateHeroInput } from '@/lib/api/schemas';
import { clampPagination } from '@/lib/api/pagination';

/**
 * GET /api/heroes
 * List all heroes for the authenticated user
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
    const includeStories = searchParams.get('includeStories') === 'true';
    const { limit, offset } = clampPagination(searchParams.get('limit'), searchParams.get('offset'));
    const updatedAfter = searchParams.get('updatedAfter'); // ISO8601 timestamp for incremental sync

    // Build where clause
    const whereClause: any = {
      userId: user.id,
    };

    // Add incremental sync filter if provided
    if (updatedAfter) {
      try {
        const updatedAfterDate = new Date(updatedAfter);
        whereClause.updatedAt = {
          gt: updatedAfterDate,
        };
      } catch (error) {
        return errorResponse('ValidationError', 'Invalid updatedAfter parameter: must be ISO8601 timestamp', 400);
      }
    }

    // Get heroes with optional pagination and incremental sync
    const heroes = await prisma.hero.findMany({
      where: whereClause,
      include: {
        visualProfile: true,
        stories: includeStories
          ? {
              orderBy: { createdAt: 'desc' },
              take: 5,
            }
          : false,
        _count: {
          select: { stories: true },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: limit,
      skip: offset,
    });

    // Get total count for pagination (with same filters)
    const total = await prisma.hero.count({
      where: whereClause,
    });

    // Sign all URLs for secure access
    const signedHeroes = await Promise.all(
      heroes.map(async (hero) => {
        const signedHero = await signHeroUrls(hero);
        // Sign story URLs if included
        if (signedHero.stories && Array.isArray(signedHero.stories)) {
          signedHero.stories = await Promise.all(
            signedHero.stories.map((story: any) => signStoryUrls(story))
          );
        }
        return signedHero;
      })
    );

    return successResponse({
      heroes: signedHeroes,
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

/**
 * POST /api/heroes
 * Create a new hero (Zod-validated, mass-assignment safe)
 */
export async function POST(req: NextRequest) {
  return withAuthAndValidation(req, CreateHeroSchema, 'ai_assistant', async (authUser: AuthUser, body: CreateHeroInput) => {
    // Get full user from database
    const user = await prisma.user.findUnique({
      where: { id: authUser.id },
    });

    if (!user) {
      return errorResponse('NotFound', 'User not found', 404);
    }

    // Create the hero with only allowlisted fields
    const hero = await prisma.hero.create({
      data: {
        name: body.name,
        age: body.age,
        traits: body.traits,
        userId: user.id,
        ...(body.hairColor && { hairColor: body.hairColor }),
        ...(body.eyeColor && { eyeColor: body.eyeColor }),
        ...(body.skinTone && { skinTone: body.skinTone }),
        ...(body.height && { height: body.height }),
        ...(body.specialAbilities && { specialAbilities: body.specialAbilities }),
        ...(body.appearance && { appearance: body.appearance }),
        // avatarUrl, avatarPrompt, avatarGenerationId deliberately excluded
      },
      include: {
        visualProfile: true,
      },
    });

    // Sign avatar URL if present
    const signedHero = await signHeroUrls(hero);

    return successResponse(signedHero, 'Hero created successfully', 201);
  });
}
