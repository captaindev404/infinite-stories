import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { getOrCreateUser } from '@/lib/auth/session';
import { successResponse, errorResponse, handleApiError } from '@/lib/utils/api-response';
import { withAuthAndValidation, type AuthUser } from '@/lib/api/with-auth';
import { UpdateCustomEventSchema, type UpdateCustomEventInput } from '@/lib/api/schemas';

/**
 * GET /api/v1/custom-events/[eventId]
 * Get a specific custom event
 */
export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ eventId: string }> }
) {
  try {
    const user = await getOrCreateUser();
    const { eventId } = await params;

    // Get the custom event
    const customEvent = await prisma.customStoryEvent.findUnique({
      where: { id: eventId },
    });

    if (!customEvent) {
      return errorResponse('NotFound', 'Custom event not found', 404);
    }

    // Verify ownership
    if (customEvent.userId !== user.id) {
      return errorResponse('Forbidden', 'You do not have access to this custom event', 403);
    }

    return successResponse(customEvent);
  } catch (error) {
    return handleApiError(error);
  }
}

/**
 * PATCH /api/v1/custom-events/[eventId]
 * Update a custom event (Zod-validated, mass-assignment safe)
 */
export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ eventId: string }> }
) {
  return withAuthAndValidation(req, UpdateCustomEventSchema, 'ai_assistant', async (user: AuthUser, body: UpdateCustomEventInput) => {
    const { eventId } = await params;

    // Get the custom event first to verify ownership
    const existingEvent = await prisma.customStoryEvent.findUnique({
      where: { id: eventId },
    });

    if (!existingEvent) {
      return errorResponse('NotFound', 'Custom event not found', 404);
    }

    if (existingEvent.userId !== user.id) {
      return errorResponse('Forbidden', 'You do not have access to this custom event', 403);
    }

    // Update with only the validated, allowlisted fields
    const updatedEvent = await prisma.customStoryEvent.update({
      where: { id: eventId },
      data: {
        ...(body.title !== undefined && { title: body.title }),
        ...(body.description !== undefined && { description: body.description }),
        ...(body.promptSeed !== undefined && { promptSeed: body.promptSeed }),
        ...(body.category !== undefined && { category: body.category }),
        ...(body.ageRange !== undefined && { ageRange: body.ageRange }),
        ...(body.tone !== undefined && { tone: body.tone }),
        ...(body.keywords !== undefined && { keywords: body.keywords }),
        ...(body.isFavorite !== undefined && { isFavorite: body.isFavorite }),
      },
    });

    return successResponse(updatedEvent, 'Custom event updated successfully');
  });
}

/**
 * DELETE /api/v1/custom-events/[eventId]
 * Delete a custom event
 */
export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ eventId: string }> }
) {
  try {
    const user = await getOrCreateUser();
    const { eventId } = await params;

    // Get the custom event first to verify ownership
    const existingEvent = await prisma.customStoryEvent.findUnique({
      where: { id: eventId },
    });

    if (!existingEvent) {
      return errorResponse('NotFound', 'Custom event not found', 404);
    }

    if (existingEvent.userId !== user.id) {
      return errorResponse('Forbidden', 'You do not have access to this custom event', 403);
    }

    // Delete the custom event (stories will have customEventId set to null due to SetNull cascade)
    await prisma.customStoryEvent.delete({
      where: { id: eventId },
    });

    return successResponse(
      { id: eventId },
      'Custom event deleted successfully'
    );
  } catch (error) {
    return handleApiError(error);
  }
}
