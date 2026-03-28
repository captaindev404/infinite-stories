import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { requireAuth } from '@/lib/auth/session';
import {
  successResponse,
  errorResponse,
  handleApiError,
  validateRequiredFields,
} from '@/lib/utils/api-response';
import { clampPagination } from '@/lib/api/pagination';

/**
 * POST /api/v1/analytics/sessions
 * Create a new listening session
 *
 * Request body:
 * - storyId: string (required) - ID of the story being listened to
 * - startedAt: string (optional) - ISO8601 timestamp when listening started (defaults to now)
 * - endedAt: string (optional) - ISO8601 timestamp when listening ended
 * - duration: number (optional) - duration in seconds (auto-calculated if startedAt/endedAt provided)
 * - completed: boolean (optional) - whether the story was listened to completion
 *
 * Response:
 * - 201: Session created successfully
 * - 400: Validation error (missing fields, invalid data)
 * - 401: Unauthorized
 * - 404: Story not found
 * - 429: Rate limit exceeded
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
    const validation = validateRequiredFields(body, ['storyId']);
    if (!validation.valid) {
      return errorResponse(
        'ValidationError',
        `Missing required fields: ${validation.missing?.join(', ')}`,
        400
      );
    }

    // Get the story to validate it exists and get audioDuration
    const story = await prisma.story.findUnique({
      where: { id: body.storyId },
    });

    if (!story) {
      return errorResponse('NotFound', 'Story not found', 404);
    }

    // Verify the story belongs to the user
    if (story.userId !== user.id) {
      return errorResponse('Forbidden', 'You do not have access to this story', 403);
    }

    // Parse and validate timestamps
    let startedAt: Date;
    let endedAt: Date | null = null;
    let duration: number | null = null;
    let completed = body.completed || false;

    // Handle startedAt
    if (body.startedAt) {
      try {
        startedAt = new Date(body.startedAt);
        if (isNaN(startedAt.getTime())) {
          return errorResponse(
            'ValidationError',
            'Invalid startedAt timestamp: must be ISO8601 format',
            400
          );
        }
      } catch (error) {
        return errorResponse(
          'ValidationError',
          'Invalid startedAt timestamp: must be ISO8601 format',
          400
        );
      }
    } else {
      startedAt = new Date();
    }

    // Handle endedAt
    if (body.endedAt) {
      try {
        endedAt = new Date(body.endedAt);
        if (isNaN(endedAt.getTime())) {
          return errorResponse(
            'ValidationError',
            'Invalid endedAt timestamp: must be ISO8601 format',
            400
          );
        }

        // Validate endedAt is after startedAt
        if (endedAt <= startedAt) {
          return errorResponse(
            'ValidationError',
            'endedAt must be after startedAt',
            400
          );
        }
      } catch (error) {
        return errorResponse(
          'ValidationError',
          'Invalid endedAt timestamp: must be ISO8601 format',
          400
        );
      }
    }

    // Calculate or validate duration
    if (body.duration !== undefined && body.duration !== null) {
      // User provided duration
      duration = Math.floor(body.duration);

      // Validate duration is positive
      if (duration < 0) {
        return errorResponse(
          'ValidationError',
          'Duration must be a positive number',
          400
        );
      }
    } else if (endedAt) {
      // Auto-calculate duration from timestamps
      duration = Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000);
    }

    // Apply duration capping: max 1.5x story audioDuration (if available)
    // This prevents abuse and ensures realistic listening time tracking
    if (duration !== null && story.audioDuration) {
      const maxDuration = Math.ceil(story.audioDuration * 1.5);
      if (duration > maxDuration) {
        duration = maxDuration;
      }
    }

    // Validate duration cap if no endedAt but duration provided
    if (duration !== null && duration < 0) {
      return errorResponse(
        'ValidationError',
        'Duration must be a positive number',
        400
      );
    }

    // Create listening session
    const session = await prisma.listeningSession.create({
      data: {
        userId: user.id,
        storyId: story.id,
        startedAt,
        endedAt,
        duration,
        completed,
      },
    });

    // Update story playCount and lastPlayedAt
    await prisma.story.update({
      where: { id: story.id },
      data: {
        playCount: { increment: 1 },
        lastPlayedAt: startedAt,
      },
    });

    // Note: Analytics cache is automatically updated by the database trigger
    // when a completed session with duration is inserted

    return successResponse(
      session,
      'Listening session created successfully',
      201
    );
  } catch (error) {
    return handleApiError(error);
  }
}

/**
 * GET /api/v1/analytics/sessions
 * Get listening sessions for the authenticated user
 *
 * Query parameters:
 * - storyId: string (optional) - filter by story ID
 * - startDate: string (optional) - filter sessions starting on or after this date (ISO8601)
 * - endDate: string (optional) - filter sessions starting on or before this date (ISO8601)
 * - completed: boolean (optional) - filter by completion status
 * - limit: number (optional) - number of results to return (default: 50, max: 100)
 * - offset: number (optional) - offset for pagination (default: 0)
 *
 * Response:
 * - 200: Sessions retrieved successfully
 * - 401: Unauthorized
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
    const storyId = searchParams.get('storyId');
    const startDate = searchParams.get('startDate');
    const endDate = searchParams.get('endDate');
    const completedParam = searchParams.get('completed');
    const { limit, offset } = clampPagination(searchParams.get('limit'), searchParams.get('offset'));

    // Build where clause
    const where: any = {
      userId: user.id,
    };

    if (storyId) {
      // Verify the story belongs to the requesting user (prevent IDOR)
      const story = await prisma.story.findUnique({
        where: { id: storyId },
        select: { userId: true },
      });
      if (!story || story.userId !== user.id) {
        return errorResponse('Forbidden', 'You do not have access to this story', 403);
      }
      where.storyId = storyId;
    }

    if (completedParam !== null) {
      where.completed = completedParam === 'true';
    }

    // Add date range filters
    if (startDate || endDate) {
      where.startedAt = {};

      if (startDate) {
        try {
          const startDateTime = new Date(startDate);
          if (isNaN(startDateTime.getTime())) {
            return errorResponse(
              'ValidationError',
              'Invalid startDate: must be ISO8601 format',
              400
            );
          }
          where.startedAt.gte = startDateTime;
        } catch (error) {
          return errorResponse(
            'ValidationError',
            'Invalid startDate: must be ISO8601 format',
            400
          );
        }
      }

      if (endDate) {
        try {
          const endDateTime = new Date(endDate);
          if (isNaN(endDateTime.getTime())) {
            return errorResponse(
              'ValidationError',
              'Invalid endDate: must be ISO8601 format',
              400
            );
          }
          where.startedAt.lte = endDateTime;
        } catch (error) {
          return errorResponse(
            'ValidationError',
            'Invalid endDate: must be ISO8601 format',
            400
          );
        }
      }
    }

    // Get sessions with pagination
    const sessions = await prisma.listeningSession.findMany({
      where,
      orderBy: {
        startedAt: 'desc',
      },
      take: limit,
      skip: offset,
    });

    // Get total count
    const total = await prisma.listeningSession.count({ where });

    return successResponse({
      sessions,
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
