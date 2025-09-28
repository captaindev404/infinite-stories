import { createSupabaseServiceClient } from './auth.ts';
import { logger, LogCategory } from './logger.ts';

/**
 * Cache configuration for different content types
 */
export const CACHE_CONFIG = {
  story_prompts: { ttl: 3600 }, // 1 hour
  story_content: { ttl: 86400 }, // 24 hours
  scene_extraction: { ttl: 86400 }, // 24 hours
  audio_files: { ttl: 604800 }, // 7 days
  avatar_images: { ttl: 604800 }, // 7 days
  illustration_images: { ttl: 604800 }, // 7 days
  content_filter: { ttl: 7200 }, // 2 hours
  user_preferences: { ttl: 3600 }, // 1 hour
} as const;

/**
 * Cache key generators
 */
export class CacheKeyGenerator {
  static storyGeneration(heroId: string, event: any, language: string, duration: number): string {
    const eventHash = this.hashObject(event);
    return `story:${heroId}:${eventHash}:${language}:${duration}`;
  }

  static sceneExtraction(storyContent: string, duration: number): string {
    const contentHash = this.hashString(storyContent);
    return `scenes:${contentHash}:${duration}`;
  }

  static audioSynthesis(text: string, voice: string, language: string): string {
    const textHash = this.hashString(text);
    return `audio:${textHash}:${voice}:${language}`;
  }

  static avatarGeneration(heroId: string, prompt: string, size: string, quality: string): string {
    const promptHash = this.hashString(prompt);
    return `avatar:${heroId}:${promptHash}:${size}:${quality}`;
  }

  static sceneIllustration(prompt: string, heroId: string, sceneNumber: number): string {
    const promptHash = this.hashString(prompt);
    return `illustration:${heroId}:${sceneNumber}:${promptHash}`;
  }

  static contentFilter(prompt: string): string {
    const promptHash = this.hashString(prompt);
    return `filter:${promptHash}`;
  }

  static userPreferences(userId: string): string {
    return `prefs:${userId}`;
  }

  /**
   * Simple hash function for objects
   */
  private static hashObject(obj: any): string {
    const str = JSON.stringify(obj, Object.keys(obj).sort());
    return this.hashString(str);
  }

  /**
   * Simple hash function for strings
   */
  private static hashString(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash).toString(36);
  }
}

/**
 * Cache manager class
 */
export class CacheManager {
  private supabase = createSupabaseServiceClient();

  /**
   * Get cached data
   */
  async get<T>(key: string, requestId?: string): Promise<T | null> {
    try {
      const { data, error } = await this.supabase
        .from('api_cache')
        .select('response, expires_at, hit_count')
        .eq('cache_key', key)
        .single();

      if (error || !data) {
        logger.logCache('get', key, false, requestId);
        return null;
      }

      // Check if expired
      const expiresAt = new Date(data.expires_at);
      if (expiresAt < new Date()) {
        logger.logCache('get', key, false, requestId);
        // Clean up expired entry
        await this.delete(key);
        return null;
      }

      // Update hit count and last accessed time
      await this.updateAccessStats(key);

      logger.logCache('get', key, true, requestId);
      return data.response as T;
    } catch (error) {
      logger.error(
        'Cache get error',
        LogCategory.CACHE,
        requestId,
        error as Error,
        { cache_key: key }
      );
      return null;
    }
  }

  /**
   * Set cached data
   */
  async set<T>(
    key: string,
    data: T,
    ttlSeconds: number,
    requestId?: string
  ): Promise<void> {
    try {
      const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

      const { error } = await this.supabase
        .from('api_cache')
        .upsert({
          cache_key: key,
          response: data,
          expires_at: expiresAt.toISOString(),
          hit_count: 0,
          last_accessed: new Date().toISOString()
        });

      if (error) {
        logger.error(
          'Cache set error',
          LogCategory.CACHE,
          requestId,
          error as Error,
          { cache_key: key }
        );
      } else {
        logger.debug(
          'Cache set',
          LogCategory.CACHE,
          requestId,
          { cache_key: key, ttl_seconds: ttlSeconds }
        );
      }
    } catch (error) {
      logger.error(
        'Cache set error',
        LogCategory.CACHE,
        requestId,
        error as Error,
        { cache_key: key }
      );
    }
  }

  /**
   * Delete cached data
   */
  async delete(key: string, requestId?: string): Promise<void> {
    try {
      const { error } = await this.supabase
        .from('api_cache')
        .delete()
        .eq('cache_key', key);

      if (error) {
        logger.error(
          'Cache delete error',
          LogCategory.CACHE,
          requestId,
          error as Error,
          { cache_key: key }
        );
      } else {
        logger.debug(
          'Cache delete',
          LogCategory.CACHE,
          requestId,
          { cache_key: key }
        );
      }
    } catch (error) {
      logger.error(
        'Cache delete error',
        LogCategory.CACHE,
        requestId,
        error as Error,
        { cache_key: key }
      );
    }
  }

  /**
   * Clear cache by pattern
   */
  async clearByPattern(pattern: string, requestId?: string): Promise<number> {
    try {
      const { data, error } = await this.supabase
        .from('api_cache')
        .delete()
        .like('cache_key', pattern)
        .select('cache_key');

      if (error) {
        logger.error(
          'Cache clear by pattern error',
          LogCategory.CACHE,
          requestId,
          error as Error,
          { pattern }
        );
        return 0;
      }

      const deletedCount = data?.length || 0;
      logger.info(
        `Cache cleared by pattern: ${deletedCount} entries`,
        LogCategory.CACHE,
        requestId,
        { pattern, deleted_count: deletedCount }
      );

      return deletedCount;
    } catch (error) {
      logger.error(
        'Cache clear by pattern error',
        LogCategory.CACHE,
        requestId,
        error as Error,
        { pattern }
      );
      return 0;
    }
  }

  /**
   * Update cache access statistics
   */
  private async updateAccessStats(key: string): Promise<void> {
    try {
      await this.supabase
        .from('api_cache')
        .update({
          hit_count: this.supabase.raw('hit_count + 1'),
          last_accessed: new Date().toISOString()
        })
        .eq('cache_key', key);
    } catch (error) {
      // Non-critical error, just log it
      console.error('Failed to update cache stats:', error);
    }
  }

  /**
   * Get cache statistics
   */
  async getStats(): Promise<{
    total_entries: number;
    total_hits: number;
    memory_usage_mb: number;
  }> {
    try {
      const { data, error } = await this.supabase
        .from('api_cache')
        .select('hit_count, response')
        .gt('expires_at', new Date().toISOString());

      if (error || !data) {
        return { total_entries: 0, total_hits: 0, memory_usage_mb: 0 };
      }

      const totalEntries = data.length;
      const totalHits = data.reduce((sum, entry) => sum + (entry.hit_count || 0), 0);

      // Estimate memory usage (rough calculation)
      const memoryUsageBytes = data.reduce((sum, entry) => {
        return sum + JSON.stringify(entry.response).length;
      }, 0);

      const memoryUsageMB = memoryUsageBytes / (1024 * 1024);

      return {
        total_entries: totalEntries,
        total_hits: totalHits,
        memory_usage_mb: Math.round(memoryUsageMB * 100) / 100
      };
    } catch (error) {
      console.error('Failed to get cache stats:', error);
      return { total_entries: 0, total_hits: 0, memory_usage_mb: 0 };
    }
  }

  /**
   * Clean up expired cache entries
   */
  async cleanupExpired(): Promise<number> {
    try {
      const { data, error } = await this.supabase
        .from('api_cache')
        .delete()
        .lt('expires_at', new Date().toISOString())
        .select('cache_key');

      if (error) {
        logger.error('Cache cleanup error', LogCategory.CACHE, undefined, error as Error);
        return 0;
      }

      const deletedCount = data?.length || 0;
      if (deletedCount > 0) {
        logger.info(
          `Cache cleanup: removed ${deletedCount} expired entries`,
          LogCategory.CACHE
        );
      }

      return deletedCount;
    } catch (error) {
      logger.error('Cache cleanup error', LogCategory.CACHE, undefined, error as Error);
      return 0;
    }
  }
}

/**
 * Singleton cache manager
 */
export const cache = new CacheManager();

/**
 * Cache middleware for wrapping operations
 */
export async function withCache<T>(
  cacheKey: string,
  ttlSeconds: number,
  operation: () => Promise<T>,
  requestId?: string
): Promise<{ data: T; cached: boolean }> {
  // Try to get from cache first
  const cached = await cache.get<T>(cacheKey, requestId);
  if (cached !== null) {
    return { data: cached, cached: true };
  }

  // Execute operation
  const result = await operation();

  // Cache the result (fire and forget)
  cache.set(cacheKey, result, ttlSeconds, requestId).catch(error => {
    logger.error(
      'Failed to cache result',
      LogCategory.CACHE,
      requestId,
      error,
      { cache_key: cacheKey }
    );
  });

  return { data: result, cached: false };
}

/**
 * Cache invalidation helpers
 */
export class CacheInvalidator {
  static async invalidateUserStories(userId: string): Promise<void> {
    await cache.clearByPattern(`story:${userId}%`);
    await cache.clearByPattern(`scenes:${userId}%`);
    await cache.clearByPattern(`audio:${userId}%`);
  }

  static async invalidateHeroData(heroId: string): Promise<void> {
    await cache.clearByPattern(`story:${heroId}%`);
    await cache.clearByPattern(`avatar:${heroId}%`);
    await cache.clearByPattern(`illustration:${heroId}%`);
  }

  static async invalidateStoryData(storyId: string): Promise<void> {
    await cache.clearByPattern(`%:${storyId}:%`);
  }
}