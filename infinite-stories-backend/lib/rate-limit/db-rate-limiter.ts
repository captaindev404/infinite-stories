import { prisma } from '@/lib/prisma/client';

/**
 * Database-only rate limiting service
 * Simpler alternative to Redis-based rate limiting
 */

export interface RateLimitConfig {
  operation: string;
  maxRequests: number;
  windowMs: number; // Time window in milliseconds
}

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
  limit: number;
}

/**
 * Parse an environment variable as a positive integer, returning fallback if invalid.
 */
function parseEnvInt(key: string, fallback: number): number {
  const val = parseInt(process.env[key] || '', 10);
  if (isNaN(val) || val <= 0) return fallback;
  return val;
}

// Rate limit configurations — defaults are safe; override via env vars per environment
export const RATE_LIMITS: Record<string, RateLimitConfig> = {
  story_generation: {
    operation: 'story_generation',
    maxRequests: parseEnvInt('RATE_LIMIT_STORY_GENERATION', 5),
    windowMs: 60 * 60 * 1000, // 1 hour
  },
  audio_generation: {
    operation: 'audio_generation',
    maxRequests: parseEnvInt('RATE_LIMIT_AUDIO_GENERATION', 10),
    windowMs: 60 * 60 * 1000, // 1 hour
  },
  avatar_generation: {
    operation: 'avatar_generation',
    maxRequests: parseEnvInt('RATE_LIMIT_AVATAR_GENERATION', 3),
    windowMs: 60 * 60 * 1000, // 1 hour
  },
  illustration_generation: {
    operation: 'illustration_generation',
    maxRequests: parseEnvInt('RATE_LIMIT_ILLUSTRATION_GENERATION', 20),
    windowMs: 60 * 60 * 1000, // 1 hour
  },
  ai_assistant: {
    operation: 'ai_assistant',
    maxRequests: parseEnvInt('RATE_LIMIT_AI_ASSISTANT', 30),
    windowMs: 60 * 60 * 1000, // 1 hour
  },
};

/**
 * Check if a user has exceeded the rate limit for an operation
 */
export async function checkRateLimit(
  userId: string,
  operation: keyof typeof RATE_LIMITS
): Promise<RateLimitResult> {
  const config = RATE_LIMITS[operation];

  if (!config) {
    throw new Error(`Unknown operation: ${operation}`);
  }

  // Calculate the time window start
  const windowStart = new Date(Date.now() - config.windowMs);

  // Count requests in the current window
  const requestCount = await prisma.apiUsage.count({
    where: {
      userId,
      operation: config.operation,
      createdAt: {
        gte: windowStart,
      },
    },
  });

  const allowed = requestCount < config.maxRequests;
  const remaining = Math.max(0, config.maxRequests - requestCount);
  const resetAt = new Date(Date.now() + config.windowMs);

  return {
    allowed,
    remaining,
    resetAt,
    limit: config.maxRequests,
  };
}

/**
 * Record an API usage for rate limiting
 */
export async function recordApiUsage(params: {
  userId: string;
  operation: string;
  model: string;
  tokensUsed?: number;
  estimatedCost?: number;
  requestDuration?: number;
  success: boolean;
  errorMessage?: string;
}): Promise<void> {
  await prisma.apiUsage.create({
    data: params,
  });
}

/**
 * Get remaining rate limit for a user across all operations
 */
export async function getRateLimitStatus(userId: string): Promise<
  Record<
    string,
    {
      remaining: number;
      limit: number;
      resetAt: Date;
    }
  >
> {
  const status: Record<string, any> = {};

  for (const [key, config] of Object.entries(RATE_LIMITS)) {
    const result = await checkRateLimit(userId, key as keyof typeof RATE_LIMITS);
    status[key] = {
      remaining: result.remaining,
      limit: result.limit,
      resetAt: result.resetAt,
    };
  }

  return status;
}

/**
 * Middleware helper to enforce rate limits
 */
export async function enforceRateLimit(
  userId: string,
  operation: keyof typeof RATE_LIMITS
): Promise<void> {
  const result = await checkRateLimit(userId, operation);

  if (!result.allowed) {
    const resetTime = result.resetAt.toISOString();
    throw new Error(
      `Rate limit exceeded for ${operation}. Resets at ${resetTime}. Limit: ${result.limit} requests per hour.`
    );
  }
}

/**
 * Clean up old API usage records (run periodically)
 */
export async function cleanupOldUsageRecords(): Promise<number> {
  // Delete records older than 7 days
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  const result = await prisma.apiUsage.deleteMany({
    where: {
      createdAt: {
        lt: sevenDaysAgo,
      },
    },
  });

  return result.count;
}
