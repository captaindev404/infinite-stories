/**
 * Shared utilities for Infinite Stories Edge Functions
 *
 * This module exports all the core utilities needed by the Edge Functions:
 * - Authentication and authorization
 * - CORS handling
 * - Error handling and standardized responses
 * - OpenAI client with official SDK and gpt-4o
 * - Rate limiting
 * - Logging and monitoring
 * - Request validation
 * - Caching
 * - Content filtering
 */

// Authentication and CORS
export * from './auth.ts';
export * from './cors.ts';

// Error handling
export * from './errors.ts';

// OpenAI client with gpt-4o
export * from './openai-client.ts';

// Rate limiting
export * from './rate-limiter.ts';

// Logging
export * from './logger.ts';

// Validation
export * from './validation.ts';

// Caching
export * from './cache.ts';

// Content filtering
export * from './content-filter.ts';

/**
 * Common Edge Function wrapper that handles CORS, auth, rate limiting, and error handling
 */
export async function withEdgeFunctionWrapper<T>(
  req: Request,
  functionName: keyof import('./rate-limiter.ts').RATE_LIMITS,
  handler: (params: {
    userId: string;
    supabase: ReturnType<typeof import('./auth.ts').createSupabaseClient>;
    req: Request;
    requestId: string;
  }) => Promise<T>
): Promise<Response> {
  const requestId = crypto.randomUUID();
  const startTime = Date.now();

  const { handleCORS } = await import('./cors.ts');
  const { withAuth } = await import('./auth.ts');
  const { withRateLimit } = await import('./rate-limiter.ts');
  const { withErrorHandling, createSuccessResponse, createErrorResponse } = await import('./errors.ts');
  const { logger } = await import('./logger.ts');

  try {
    // Handle CORS preflight
    const corsResponse = handleCORS(req);
    if (corsResponse) return corsResponse;

    // Log request
    logger.logRequest(req.method, req.url, requestId);

    const result = await withErrorHandling(requestId, async () => {
      return await withAuth(req, async ({ userId, supabase }) => {
        return await withRateLimit(userId, functionName, requestId, async () => {
          return await handler({ userId, supabase, req, requestId });
        });
      });
    });

    const processingTime = Date.now() - startTime;
    logger.logResponse(200, processingTime, requestId);

    return createSuccessResponse(result, requestId, processingTime);
  } catch (error) {
    const processingTime = Date.now() - startTime;
    logger.logResponse(error.statusCode || 500, processingTime, requestId);

    return createErrorResponse(error, requestId);
  }
}