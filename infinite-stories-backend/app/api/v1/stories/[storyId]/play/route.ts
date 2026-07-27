import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { requireAuth } from '@/lib/auth/session';
import { successResponse, errorResponse, handleApiError } from '@/lib/utils/api-response';

/**
 * POST /api/v1/stories/[storyId]/play
 * Record a playback of the story: increments playCount and stamps lastPlayedAt.
 *
 * The iOS client calls this every time audio playback starts; without it the
 * "listens" metric on story cards and in Reading Journey never moves.
 */
export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ storyId: string }> }
) {
  try {
    const authUser = await requireAuth();
    if (!authUser) {
      return errorResponse('Unauthorized', 'Authentication required', 401);
    }

    const { storyId } = await params;

    const story = await prisma.story.findUnique({
      where: { id: storyId },
      select: { id: true, userId: true },
    });

    if (!story) {
      return errorResponse('NotFound', 'Story not found', 404);
    }

    if (story.userId !== authUser.id) {
      return errorResponse('Forbidden', 'You do not have access to this story', 403);
    }

    const updated = await prisma.story.update({
      where: { id: storyId },
      data: {
        playCount: { increment: 1 },
        lastPlayedAt: new Date(),
      },
      select: { id: true, playCount: true, lastPlayedAt: true },
    });

    return successResponse(updated);
  } catch (error) {
    return handleApiError(error);
  }
}
