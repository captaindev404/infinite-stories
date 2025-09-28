import { createSupabaseServiceClient } from './auth.ts';
import { APIError, ErrorCode, createRateLimitError } from './errors.ts';

/**
 * Rate limit configurations for different endpoints
 */
export const RATE_LIMITS = {
  story_generation: { requests: 10, window: 3600 }, // 10 per hour
  scene_extraction: { requests: 20, window: 3600 }, // 20 per hour
  audio_synthesis: { requests: 15, window: 3600 }, // 15 per hour
  avatar_generation: { requests: 8, window: 3600 }, // 8 per hour
  illustration_generation: { requests: 25, window: 3600 }, // 25 per hour
  content_filter: { requests: 100, window: 3600 }, // 100 per hour
} as const;

/**
 * Rate limit result
 */
export interface RateLimitResult {
  allowed: boolean;
  requests_made: number;
  retry_after: number;
}

/**
 * Rate limiter class
 */
export class RateLimiter {
  private supabase = createSupabaseServiceClient();

  /**
   * Check rate limit for a user and function
   */
  async checkRateLimit(
    userId: string,
    functionName: keyof typeof RATE_LIMITS,
    requestId?: string
  ): Promise<void> {
    const config = RATE_LIMITS[functionName];
    if (!config) {
      throw new Error(`Unknown function name: ${functionName}`);
    }

    try {
      const { data, error } = await this.supabase.rpc('check_rate_limit', {
        p_user_id: userId,
        p_function_name: functionName,
        p_limit: config.requests,
        p_window_seconds: config.window
      });

      if (error) {
        console.error(`[${requestId}] Rate limit check failed:`, error);
        // Allow the request if rate limit check fails (fail open)
        return;
      }

      const result = data as RateLimitResult[];
      if (result && result.length > 0) {
        const limitResult = result[0];

        if (!limitResult.allowed) {
          if (requestId) {
            console.warn(
              `[${requestId}] Rate limit exceeded for user ${userId}, function ${functionName}: ` +
              `${limitResult.requests_made}/${config.requests} requests in window`
            );
          }

          throw createRateLimitError(limitResult.retry_after);
        }

        if (requestId) {
          console.log(
            `[${requestId}] Rate limit check passed: ` +
            `${limitResult.requests_made}/${config.requests} requests used`
          );
        }
      }
    } catch (error) {
      if (error instanceof APIError) {
        throw error;
      }

      console.error(`[${requestId}] Rate limit check error:`, error);
      // Fail open - allow the request if there's an error checking limits
    }
  }

  /**
   * Increment rate limit counter after successful request
   */
  async incrementRateLimit(
    userId: string,
    functionName: keyof typeof RATE_LIMITS,
    requestId?: string
  ): Promise<void> {
    const config = RATE_LIMITS[functionName];
    if (!config) {
      return;
    }

    try {
      const { error } = await this.supabase.rpc('increment_rate_limit', {
        p_user_id: userId,
        p_function_name: functionName,
        p_window_seconds: config.window
      });

      if (error) {
        console.error(`[${requestId}] Failed to increment rate limit:`, error);
        // Don't throw - this is not critical to the request
      } else if (requestId) {
        console.log(`[${requestId}] Rate limit incremented for ${functionName}`);
      }
    } catch (error) {
      console.error(`[${requestId}] Rate limit increment error:`, error);
      // Don't throw - this is not critical to the request
    }
  }

  /**
   * Get current rate limit status for a user
   */
  async getRateLimitStatus(
    userId: string,
    functionName: keyof typeof RATE_LIMITS
  ): Promise<RateLimitResult | null> {
    const config = RATE_LIMITS[functionName];
    if (!config) {
      return null;
    }

    try {
      const { data, error } = await this.supabase.rpc('check_rate_limit', {
        p_user_id: userId,
        p_function_name: functionName,
        p_limit: config.requests,
        p_window_seconds: config.window
      });

      if (error || !data || data.length === 0) {
        return null;
      }

      return data[0] as RateLimitResult;
    } catch (error) {
      console.error('Rate limit status check error:', error);
      return null;
    }
  }

  /**
   * Get all rate limit statuses for a user
   */
  async getAllRateLimitStatuses(userId: string): Promise<Record<string, RateLimitResult | null>> {
    const statuses: Record<string, RateLimitResult | null> = {};

    const functions = Object.keys(RATE_LIMITS) as (keyof typeof RATE_LIMITS)[];

    await Promise.all(
      functions.map(async (functionName) => {
        statuses[functionName] = await this.getRateLimitStatus(userId, functionName);
      })
    );

    return statuses;
  }

  /**
   * Reset rate limits for a user (admin function)
   */
  async resetRateLimits(userId: string, functionName?: keyof typeof RATE_LIMITS): Promise<void> {
    try {
      let query = this.supabase
        .from('rate_limits')
        .delete()
        .eq('user_id', userId);

      if (functionName) {
        query = query.eq('function_name', functionName);
      }

      const { error } = await query;

      if (error) {
        throw new Error(`Failed to reset rate limits: ${error.message}`);
      }
    } catch (error) {
      console.error('Rate limit reset error:', error);
      throw error;
    }
  }

  /**
   * Clean up old rate limit records (should be run periodically)
   */
  async cleanupOldRecords(): Promise<void> {
    try {
      // Delete records older than 24 hours
      const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);

      const { error } = await this.supabase
        .from('rate_limits')
        .delete()
        .lt('created_at', cutoff.toISOString());

      if (error) {
        console.error('Rate limit cleanup failed:', error);
      } else {
        console.log('Rate limit cleanup completed');
      }
    } catch (error) {
      console.error('Rate limit cleanup error:', error);
    }
  }
}

/**
 * Singleton instance
 */
export const rateLimiter = new RateLimiter();

/**
 * Rate limiting middleware
 */
export async function withRateLimit<T>(
  userId: string,
  functionName: keyof typeof RATE_LIMITS,
  requestId: string,
  operation: () => Promise<T>
): Promise<T> {
  // Check rate limit before processing
  await rateLimiter.checkRateLimit(userId, functionName, requestId);

  try {
    // Execute the operation
    const result = await operation();

    // Increment counter after successful completion
    await rateLimiter.incrementRateLimit(userId, functionName, requestId);

    return result;
  } catch (error) {
    // Don't increment counter on failure
    throw error;
  }
}

/**
 * Batch rate limit check for multiple operations
 */
export async function checkBatchRateLimit(
  userId: string,
  operations: Array<{
    functionName: keyof typeof RATE_LIMITS;
    count: number;
  }>,
  requestId?: string
): Promise<void> {
  const checks = operations.map(async (op) => {
    // For batch operations, check if we have enough quota for all items
    const config = RATE_LIMITS[op.functionName];

    const { data, error } = await rateLimiter.supabase.rpc('check_rate_limit', {
      p_user_id: userId,
      p_function_name: op.functionName,
      p_limit: config.requests,
      p_window_seconds: config.window
    });

    if (error || !data || data.length === 0) {
      return; // Fail open
    }

    const result = data[0] as RateLimitResult;
    const availableQuota = config.requests - result.requests_made;

    if (availableQuota < op.count) {
      throw new APIError(
        ErrorCode.RATE_LIMITED,
        429,
        `Insufficient quota for batch operation: ${op.functionName} needs ${op.count}, available ${availableQuota}`,
        {
          function_name: op.functionName,
          requested: op.count,
          available: availableQuota,
          limit: config.requests
        },
        result.retry_after
      );
    }
  });

  await Promise.all(checks);
}