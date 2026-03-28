import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { successResponse, errorResponse } from '@/lib/utils/api-response';

/**
 * GET /api/v1/health
 * Health check endpoint for uptime monitoring
 */
export async function GET(req: NextRequest) {
  try {
    // Check database connectivity
    await prisma.$queryRaw`SELECT 1`;

    // Check environment variables (log missing ones server-side only)
    const requiredEnvVars = [
      'DATABASE_URL',
      'BETTER_AUTH_SECRET',
      'OPENAI_API_KEY',
      'R2_BUCKET_NAME',
    ];

    const missingEnvVars = requiredEnvVars.filter((v: string) => !process.env[v]);

    if (missingEnvVars.length > 0) {
      // Log specifics server-side only — never expose env var names to clients
      console.error(`Health check: missing environment variables: ${missingEnvVars.join(', ')}`);
      return errorResponse(
        'ServiceUnavailable',
        'Service is unhealthy',
        503
      );
    }

    return successResponse({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: 'connected',
      version: '1.0.0',
    });
  } catch (error) {
    console.error('Health check failed:', (error as Error).message);
    return errorResponse(
      'ServiceUnavailable',
      'Health check failed',
      503
    );
  }
}
