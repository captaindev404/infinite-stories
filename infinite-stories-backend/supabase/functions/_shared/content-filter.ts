/**
 * AI-powered content filtering system for child safety
 *
 * This module implements comprehensive content filtering using GPT-5-mini to ensure
 * all generated content is appropriate for children aged 3-12.
 * Uses the Response API for fast, context-aware filtering with minimal reasoning.
 */

import { openai, MODELS, GPT5_MINI_CONFIG } from './openai-client.ts';
import { logger, LogCategory } from './logger.ts';
import { cache, CacheKeyGenerator, CACHE_CONFIG } from './cache.ts';

/**
 * Content filtering result
 */
export interface FilterResult {
  isClean: boolean;
  filteredContent: string;
  warnings: string[];
  changesApplied: string[];
}

/**
 * AI-powered content filter for child safety using GPT-5-mini
 */
export class ContentFilter {
  /**
   * Use GPT-5-mini to analyze and filter content for child safety
   * Uses Response API with minimal reasoning for fast, accurate filtering
   */
  static async filterContent(
    content: string,
    requestId?: string,
    options: { skipOnError?: boolean } = {}
  ): Promise<FilterResult> {
    const cacheKey = CacheKeyGenerator.contentFilter(content);

    // Check if content filtering is disabled via environment variable
    const filteringDisabled = Deno.env.get('DISABLE_CONTENT_FILTERING') === 'true';
    if (filteringDisabled) {
      logger.warn(
        'Content filtering disabled via environment variable',
        LogCategory.OPENAI,
        requestId
      );
      return {
        isClean: true,
        filteredContent: content,
        warnings: ['Content filtering disabled'],
        changesApplied: []
      };
    }

    // Truncate very long content to avoid token limit issues
    const maxContentLength = 15000; // ~3500 tokens at 4 chars/token
    let processContent = content;
    let wasTruncated = false;

    if (content.length > maxContentLength) {
      processContent = content.substring(0, maxContentLength);
      wasTruncated = true;
      logger.warn(
        `Content truncated for filtering (${content.length} -> ${maxContentLength} chars)`,
        LogCategory.OPENAI,
        requestId
      );
    }

    try {
      // Cache disabled for development/debugging
      // const cached = await cache.get<FilterResult>(cacheKey, requestId);
      // if (cached) {
      //   logger.logCache('get', cacheKey, true, requestId);
      //   return cached;
      // }

      logger.info(
        'Starting AI content filtering with GPT-5-mini',
        LogCategory.OPENAI,
        requestId,
        {
          content_length: processContent.length,
          truncated: wasTruncated
        }
      );

      const systemPrompt = `You are a content safety specialist for children's stories. Your job is to analyze content and ensure it's 100% appropriate for children aged 3-12.

CRITICAL SAFETY RULES:
1. NO children should EVER be depicted alone, isolated, or without companionship
2. NO scary, dark, violent, or frightening content
3. NO negative emotions like sadness, crying, fear, or distress
4. ALL content must be bright, positive, and magical
5. ALL characters must have friends, family, or magical companions

Your task:
1. Analyze the provided content for safety issues
2. If issues found, rewrite the content to be completely safe
3. Always ensure children are with companions
4. Always ensure positive, bright atmosphere
5. Replace any negative elements with positive alternatives

Return ONLY a JSON object with this exact structure:
{
  "isClean": boolean,
  "filteredContent": "the safe version of the content",
  "warnings": ["list of any issues found"],
  "changesApplied": ["list of changes made"]
}`;

      const userPrompt = `Please analyze and filter this content for child safety:\n\n${content}`;

      // Get GPT-5-mini configuration for content filtering
      const filteringParams = GPT5_MINI_CONFIG.content_filtering;

      const startTime = Date.now();
      const response = await openai.createChatCompletion({
        model: MODELS.CHAT, // gpt-5-mini
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        max_tokens: filteringParams.max_tokens,
        temperature: filteringParams.temperature,
        reasoning_effort: filteringParams.reasoning_effort,
        text_verbosity: filteringParams.text_verbosity,
        response_format: { type: 'json_object' }
      }, requestId);

      const responseTime = Date.now() - startTime;

      const contentToProcess = response.choices[0].message.content?.trim();
      if (!contentToProcess) {
        throw new Error('No content filtering response generated');
      }

      const result = JSON.parse(contentToProcess) as FilterResult;

      // Cache disabled for development/debugging
      // await cache.set(cacheKey, result, CACHE_CONFIG.content_filter.ttl, requestId);

      logger.info(
        'AI content filtering completed',
        LogCategory.OPENAI,
        requestId,
        {
          is_clean: result.isClean,
          changes_count: result.changesApplied.length,
          warnings_count: result.warnings.length,
          response_time_ms: responseTime,
          reasoning_tokens: response.usage.reasoning_tokens || 0,
          cached_tokens: response.usage.cached_tokens || 0
        }
      );

      // If content was truncated, restore the full content in the result
      if (wasTruncated) {
        result.warnings.push('Content was truncated for filtering');
        result.filteredContent = content; // Use original full content
      }

      return result;
    } catch (error) {
      const errorMessage = (error as Error).message || String(error);

      logger.error(
        'AI content filtering failed',
        LogCategory.OPENAI,
        requestId,
        error as Error,
        { skip_on_error: options.skipOnError }
      );

      // If skipOnError is true, return content as-is without warning
      if (options.skipOnError) {
        logger.info(
          'Skipping failed filter, using original content',
          LogCategory.OPENAI,
          requestId
        );
        return {
          isClean: true,
          filteredContent: content,
          warnings: [],
          changesApplied: []
        };
      }

      // Otherwise return original content with warning
      return {
        isClean: false,
        filteredContent: content,
        warnings: [`Content filtering failed: ${errorMessage}`],
        changesApplied: []
      };
    }
  }

  /**
   * Filter story prompts specifically
   * Skips filtering on error since prompts are usually safe
   */
  static async filterStoryPrompt(
    prompt: string,
    requestId?: string
  ): Promise<string> {
    const result = await this.filterContent(prompt, requestId, { skipOnError: true });

    if (!result.isClean && result.warnings.length > 0) {
      logger.warn(
        'Story prompt required filtering',
        LogCategory.STORY,
        requestId,
        { warnings: result.warnings }
      );
    }

    return result.filteredContent;
  }

  /**
   * Filter image generation prompts specifically
   * Adds child-friendly art style hints before filtering
   * Skips filtering on error since enhanced prompts are already safe
   */
  static async filterImagePrompt(
    prompt: string,
    requestId?: string
  ): Promise<string> {
    // Image prompts need extra safety measures - add style hints first
    let enhancedPrompt = prompt;

    // Ensure child-friendly art style
    if (!enhancedPrompt.includes('child-friendly') && !enhancedPrompt.includes('children\'s book')) {
      enhancedPrompt += ' in a child-friendly, colorful children\'s book illustration style';
    }

    // Ensure bright and positive atmosphere
    if (!/(bright|colorful|cheerful|magical|wonderful)/.test(enhancedPrompt)) {
      enhancedPrompt += ' with bright colors and a cheerful, magical atmosphere';
    }

    // Apply AI content filtering to the enhanced prompt (skip on error)
    const result = await this.filterContent(enhancedPrompt, requestId, { skipOnError: true });

    logger.info(
      'Image prompt filtering completed',
      LogCategory.IMAGE,
      requestId,
      {
        original_length: prompt.length,
        filtered_length: result.filteredContent.length,
        changes_applied: result.changesApplied.length
      }
    );

    return result.filteredContent;
  }

  /**
   * Validate final content before delivery
   * Provides quick safety check without full filtering
   */
  static validateFinalContent(content: string): { isValid: boolean; issues: string[] } {
    const issues: string[] = [];
    const lowerContent = content.toLowerCase();

    // Quick safety checks for critical terms that should never appear
    const criticalTerms = [
      'alone', 'lonely', 'scared', 'crying', 'dark', 'scary',
      'fighting', 'violence', 'death', 'blood', 'weapon', 'kill'
    ];

    for (const term of criticalTerms) {
      if (lowerContent.includes(term)) {
        issues.push(`Contains potentially unsafe term: "${term}"`);
      }
    }

    // Check for companionship indicators
    const hasCompanionship = /\b(friends?|companions?|family|together|with\s+\w+)\b/i.test(content);
    if (!hasCompanionship) {
      issues.push('Content lacks companionship elements');
    }

    // Check for positive atmosphere indicators
    const hasPositivity = /\b(bright|colorful|cheerful|happy|magical|wonderful)\b/i.test(content);
    if (!hasPositivity) {
      issues.push('Content lacks positive atmosphere');
    }

    return {
      isValid: issues.length === 0,
      issues
    };
  }
}

/**
 * Export singleton instance
 */
export const contentFilter = ContentFilter;
