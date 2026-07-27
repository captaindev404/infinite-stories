import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { requireAuth } from '@/lib/auth/session';
import { successResponse, errorResponse, handleApiError } from '@/lib/utils/api-response';

/**
 * DELETE /api/v1/user/account
 * Permanently delete the authenticated user's account and all associated data.
 *
 * Required by App Store Review Guideline 5.1.1(v): an app that supports account
 * creation must also let the user initiate account deletion from within the app.
 *
 * Heroes, custom events, sessions and accounts cascade off User. Story,
 * ApiUsage, ListeningSession and UserAnalyticsCache only carry a bare `userId`
 * column with no foreign key, so they are removed explicitly first.
 */
export async function DELETE(_req: NextRequest) {
  try {
    const authUser = await requireAuth();
    if (!authUser) {
      return errorResponse('Unauthorized', 'Authentication required', 401);
    }

    const user = await prisma.user.findUnique({
      where: { id: authUser.id },
    });

    if (!user) {
      return errorResponse('NotFound', 'User not found', 404);
    }

    await prisma.$transaction([
      // Rows keyed by userId without a cascading foreign key.
      prisma.listeningSession.deleteMany({ where: { userId: user.id } }),
      prisma.userAnalyticsCache.deleteMany({ where: { userId: user.id } }),
      prisma.apiUsage.deleteMany({ where: { userId: user.id } }),
      prisma.story.deleteMany({ where: { userId: user.id } }),
      // Cascades to heroes, visual profiles, custom events, sessions, accounts.
      prisma.user.delete({ where: { id: user.id } }),
    ]);

    // 200 with a JSON body rather than 204: the iOS client decodes every
    // response, and an empty body fails to decode into EmptyResponse.
    return successResponse({ deleted: true }, 'Account deleted');
  } catch (error) {
    return handleApiError(error);
  }
}
