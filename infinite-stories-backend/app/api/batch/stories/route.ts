/**
 * Batch Stories Operations API
 *
 * POST /api/batch/stories - Batch create stories
 */

import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/lib/auth/auth';
import { headers } from 'next/headers';
import { prisma } from '@/lib/prisma/client';
import type { PrismaClient } from '@prisma/client';
import { R2_PUBLIC_URL } from '@/lib/storage/r2-client';

export async function POST(request: NextRequest) {
  try {
    const session = await auth.api.getSession({
      headers: await headers()
    });

    if (!session?.user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    const body = await request.json();
    const { stories } = body;

    if (!Array.isArray(stories)) {
      return NextResponse.json(
        { error: 'Invalid request: stories must be an array' },
        { status: 400 }
      );
    }

    if (stories.length > 100) {
      return NextResponse.json(
        { error: 'Batch size too large: maximum 100 stories per request' },
        { status: 400 }
      );
    }

    const results = {
      created: [] as any[],
      failed: [] as any[],
      total: stories.length,
    };

    await prisma.$transaction(async (tx: any) => {
      for (const storyData of stories) {
        try {
          // Verify hero exists and belongs to user
          const hero = await tx.hero.findFirst({
            where: {
              id: storyData.heroId,
              userId: session.user.id,
            },
          });

          if (!hero) {
            throw new Error('Hero not found or unauthorized');
          }

          // Validate audioUrl if provided — must match R2 storage pattern (prevent SSRF)
          let validatedAudioUrl = storyData.audioUrl;
          if (validatedAudioUrl && R2_PUBLIC_URL) {
            if (!validatedAudioUrl.startsWith(R2_PUBLIC_URL)) {
              throw new Error('Invalid audioUrl: must be a valid storage URL');
            }
          }

          const story = await tx.story.create({
            data: {
              heroId: storyData.heroId,
              userId: session.user.id,
              title: storyData.title,
              content: storyData.content,
              eventType: storyData.eventType,
              customEventId: storyData.customEventId,
              language: storyData.language || 'en',
              isFavorite: storyData.isFavorite || false,
              audioUrl: validatedAudioUrl,
              audioDuration: storyData.audioDuration,
            },
          });

          results.created.push({
            localId: storyData.id,
            serverId: story.id,
            title: story.title,
          });

        } catch (error: any) {
          results.failed.push({
            localId: storyData.id,
            title: storyData.title,
            error: error.message,
          });
        }
      }
    });

    return NextResponse.json({
      success: results.failed.length === 0,
      created: results.created.length,
      failed: results.failed.length,
      total: results.total,
      results,
    });

  } catch (error: any) {
    console.error('Batch stories error:', error);
    return NextResponse.json(
      { error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}
