/**
 * Content filtering system for child safety
 *
 * This module implements comprehensive content filtering to ensure all generated
 * content is appropriate for children aged 3-12. It includes both rule-based
 * filtering and AI-powered content analysis.
 */

import { openai, MODELS, getOptimalParams } from './openai-client.ts';
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
 * Comprehensive content filter for child safety
 */
export class ContentFilter {
  /**
   * Master list of problematic terms and their safe replacements
   * Organized by category for better maintenance
   */
  private static readonly UNSAFE_REPLACEMENTS = new Map([
    // CRITICAL: Isolation and loneliness terms
    ['\\balone\\b', 'with friends'],
    ['\\ball alone\\b', 'with magical friends'],
    ['\\bby himself\\b', 'with his friends'],
    ['\\bby herself\\b', 'with her friends'],
    ['\\bby themselves\\b', 'with their companions'],
    ['\\blonely\\b', 'happy with companions'],
    ['\\bisolated\\b', 'surrounded by friendly creatures'],
    ['\\babandoned\\b', 'in a cozy magical place'],
    ['\\bsolitary\\b', 'with cheerful friends'],
    ['\\bsolo\\b', 'with companions'],

    // Dark and scary terms
    ['\\bdark forest\\b', 'bright enchanted garden'],
    ['\\bdark woods\\b', 'sunny magical meadow'],
    ['\\bscary forest\\b', 'magical garden'],
    ['\\bhaunted house\\b', 'magical castle'],
    ['\\babandoned house\\b', 'cozy cottage'],
    ['\\bdark\\b', 'bright'],
    ['\\bscary\\b', 'wonderful'],
    ['\\bfrightening\\b', 'magical'],
    ['\\bterrifying\\b', 'amazing'],
    ['\\bspooky\\b', 'enchanting'],
    ['\\bhaunted\\b', 'magical'],
    ['\\bmysterious\\b', 'delightful'],
    ['\\bshadowy\\b', 'glowing'],
    ['\\bgloomy\\b', 'bright'],
    ['\\beerie\\b', 'cheerful'],
    ['\\bcreepy\\b', 'friendly'],

    // Violence and conflict terms
    ['\\bfighting\\b', 'playing'],
    ['\\bbattle\\b', 'adventure'],
    ['\\bwar\\b', 'peaceful game'],
    ['\\bweapon\\b', 'magical wand'],
    ['\\bsword\\b', 'toy wand'],
    ['\\bswords\\b', 'toy wands'],
    ['\\battacking\\b', 'playing with'],
    ['\\bkilling\\b', 'helping'],
    ['\\bdefeating\\b', 'befriending'],
    ['\\benemy\\b', 'new friend'],
    ['\\benemies\\b', 'new friends'],

    // Negative emotions
    ['\\bsad\\b', 'thoughtful'],
    ['\\bcrying\\b', 'smiling'],
    ['\\btears\\b', 'sparkles'],
    ['\\bupset\\b', 'curious'],
    ['\\bangry\\b', 'determined'],
    ['\\bscared\\b', 'excited'],
    ['\\bafraid\\b', 'brave'],
    ['\\bworried\\b', 'thoughtful'],
    ['\\bfrightened\\b', 'amazed'],
    ['\\bdepressed\\b', 'peaceful'],
    ['\\banxious\\b', 'excited'],

    // Danger and harm
    ['\\bdangerous\\b', 'exciting'],
    ['\\bharmful\\b', 'interesting'],
    ['\\binjured\\b', 'resting'],
    ['\\bhurt\\b', 'surprised'],
    ['\\bpain\\b', 'tickle'],
    ['\\bsick\\b', 'sleepy'],
    ['\\bdead\\b', 'sleeping'],
    ['\\bdying\\b', 'resting'],

    // Inappropriate content
    ['\\bstupid\\b', 'silly'],
    ['\\bidiot\\b', 'funny friend'],
    ['\\bhat\\b', 'dislike'],
    ['\\bsteal\\b', 'borrow'],
    ['\\blie\\b', 'story'],
    ['\\blying\\b', 'storytelling'],

    // Natural disasters and catastrophes
    ['\\bearthquake\\b', 'ground shaking dance'],
    ['\\bflood\\b', 'water play'],
    ['\\bfire\\b', 'warm light'],
    ['\\bstorm\\b', 'rain dance'],
    ['\\btornado\\b', 'spinning wind game'],

    // Body parts that might be inappropriate
    ['\\bbottom\\b', 'seat'],
    ['\\bbutt\\b', 'seat']
  ]);

  /**
   * Phrases that require special handling (order matters - longer phrases first)
   */
  private static readonly PHRASE_REPLACEMENTS = new Map([
    ['standing alone', 'standing with friends'],
    ['sitting alone', 'sitting with companions'],
    ['walking alone', 'walking with friends'],
    ['playing alone', 'playing with friends'],
    ['sleeping alone', 'sleeping peacefully'],
    ['eating alone', 'eating with family'],
    ['going alone', 'going with friends'],
    ['staying alone', 'staying with loved ones'],
    ['living alone', 'living happily'],
    ['working alone', 'working with helpers'],

    ['in the dark', 'in bright light'],
    ['through the darkness', 'through the magical forest'],
    ['into the dark', 'into the bright garden'],

    ['very scared', 'very excited'],
    ['really scared', 'really excited'],
    ['so scared', 'so curious'],
    ['too scared', 'too excited'],

    ['fighting with', 'playing with'],
    ['arguing with', 'talking with'],
    ['yelling at', 'calling to'],
    ['screaming at', 'singing to']
  ]);

  /**
   * Apply basic rule-based content filtering
   */
  static applyBasicFilter(content: string): FilterResult {
    let filteredContent = content;
    const changesApplied: string[] = [];
    const warnings: string[] = [];

    // Apply phrase replacements first (longer patterns)
    for (const [problematic, safe] of this.PHRASE_REPLACEMENTS) {
      const regex = new RegExp(problematic, 'gi');
      if (regex.test(filteredContent)) {
        filteredContent = filteredContent.replace(regex, safe);
        changesApplied.push(`Replaced phrase: "${problematic}" → "${safe}"`);
      }
    }

    // Apply word replacements
    for (const [pattern, replacement] of this.UNSAFE_REPLACEMENTS) {
      const regex = new RegExp(pattern, 'gi');
      if (regex.test(filteredContent)) {
        filteredContent = filteredContent.replace(regex, replacement);
        changesApplied.push(`Replaced term: "${pattern}" → "${replacement}"`);
      }
    }

    // Ensure characters are not alone
    const hasCompanionship = /\b(friends?|companions?|family|together|with\s+\w+|creatures?|helpers?|buddies?)\b/i.test(filteredContent);
    if (!hasCompanionship && /\b(character|hero|child|kid|boy|girl|person)\b/i.test(filteredContent)) {
      // Find a good place to add companionship
      if (filteredContent.endsWith('.')) {
        filteredContent = filteredContent.slice(0, -1) + ' with their loyal friends.';
      } else {
        filteredContent += ' The adventure includes helpful companions and friendly creatures.';
      }
      changesApplied.push('Added companionship element');
    }

    // Ensure positive atmosphere
    const hasPositivity = /\b(bright|colorful|sunny|cheerful|happy|magical|wonderful|amazing|beautiful|delightful)\b/i.test(filteredContent);
    if (!hasPositivity) {
      if (filteredContent.endsWith('.')) {
        filteredContent = filteredContent.slice(0, -1) + ' in a bright, magical world full of wonder.';
      } else {
        filteredContent += ' The world around them sparkles with color and magic.';
      }
      changesApplied.push('Added positive atmosphere');
    }

    // Check for remaining problematic content
    this.detectProblematicContent(filteredContent, warnings);

    return {
      isClean: warnings.length === 0,
      filteredContent,
      warnings,
      changesApplied
    };
  }

  /**
   * Detect potentially problematic content that wasn't caught by rules
   */
  private static detectProblematicContent(content: string, warnings: string[]): void {
    const lowerContent = content.toLowerCase();

    // Check for isolation indicators
    const isolationIndicators = [
      'nobody', 'no one', 'empty', 'deserted', 'abandoned', 'forgotten',
      'lost', 'stranded', 'trapped', 'stuck'
    ];

    for (const indicator of isolationIndicators) {
      if (lowerContent.includes(indicator)) {
        warnings.push(`Potential isolation content: "${indicator}"`);
      }
    }

    // Check for fear/anxiety indicators
    const fearIndicators = [
      'nightmare', 'terror', 'horror', 'panic', 'dread', 'petrified',
      'trembling', 'shaking', 'hiding'
    ];

    for (const indicator of fearIndicators) {
      if (lowerContent.includes(indicator)) {
        warnings.push(`Potential fear content: "${indicator}"`);
      }
    }

    // Check for violence indicators
    const violenceIndicators = [
      'blood', 'violence', 'aggressive', 'hostile', 'threat', 'danger',
      'harm', 'damage', 'destroy', 'kill', 'death'
    ];

    for (const indicator of violenceIndicators) {
      if (lowerContent.includes(indicator)) {
        warnings.push(`Potential violence content: "${indicator}"`);
      }
    }

    // Check for inappropriate language
    const inappropriateLanguage = [
      'stupid', 'idiot', 'dumb', 'hate', 'shut up', 'go away',
      'get lost', 'leave me alone'
    ];

    for (const language of inappropriateLanguage) {
      if (lowerContent.includes(language)) {
        warnings.push(`Inappropriate language: "${language}"`);
      }
    }
  }

  /**
   * Use AI to analyze and filter content using GPT-5-mini
   */
  static async applyAIFilter(
    content: string,
    requestId?: string
  ): Promise<FilterResult> {
    const cacheKey = CacheKeyGenerator.contentFilter(content);

    try {
      // Check cache first
      const cached = await cache.get<FilterResult>(cacheKey, requestId);
      if (cached) {
        logger.logCache('get', cacheKey, true, requestId);
        return cached;
      }

      logger.info(
        'Starting AI content filtering',
        LogCategory.OPENAI,
        requestId,
        { content_length: content.length }
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

      // Use GPT-5-mini for content filtering with low reasoning effort for speed
      const filteringParams = getOptimalParams('content_filtering');

      logger.info(
        'Starting AI content filtering with GPT-5-mini',
        LogCategory.OPENAI,
        requestId,
        { content_length: content.length }
      );

      const startTime = Date.now();
      const response = await openai.createChatCompletion({
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        max_tokens: filteringParams.max_tokens,
        temperature: filteringParams.temperature,
        reasoning_effort: filteringParams.reasoning_effort,
        text_verbosity: filteringParams.text_verbosity,
        response_format: { type: 'json_object' },
        user_id: userId
      }, requestId);

      const responseTime = Date.now() - startTime;

      const contentToProcess = response.choices[0].message.content?.trim();
      if (!contentToProcess) {
        throw new Error('No content filtering response generated');
      }

      const result = JSON.parse(contentToProcess) as FilterResult;

      // Cache the result
      await cache.set(cacheKey, result, CACHE_CONFIG.content_filter.ttl, requestId);

      logger.info(
        'AI content filtering completed',
        LogCategory.OPENAI,
        requestId,
        {
          is_clean: result.isClean,
          changes_count: result.changesApplied.length,
          warnings_count: result.warnings.length
        }
      );

      return result;
    } catch (error) {
      logger.error(
        'AI content filtering failed, falling back to basic filter',
        LogCategory.OPENAI,
        requestId,
        error as Error
      );

      // Fallback to basic filtering
      return this.applyBasicFilter(content);
    }
  }

  /**
   * Comprehensive content filtering (combines rule-based and AI filtering)
   */
  static async filterContent(
    content: string,
    useAI: boolean = true,
    requestId?: string
  ): Promise<FilterResult> {
    logger.debug(
      'Starting content filtering',
      LogCategory.OPENAI,
      requestId,
      { content_length: content.length, use_ai: useAI }
    );

    // Always start with basic filtering
    const basicResult = this.applyBasicFilter(content);

    // If basic filtering found issues or if AI is disabled, return basic result
    if (!useAI || !basicResult.isClean) {
      logger.info(
        'Content filtering completed (basic only)',
        LogCategory.OPENAI,
        requestId,
        {
          is_clean: basicResult.isClean,
          changes_count: basicResult.changesApplied.length
        }
      );

      return basicResult;
    }

    // Apply AI filtering to the already-filtered content for additional safety
    try {
      const aiResult = await this.applyAIFilter(basicResult.filteredContent, requestId);

      // Combine results
      const combinedResult: FilterResult = {
        isClean: aiResult.isClean,
        filteredContent: aiResult.filteredContent,
        warnings: [...basicResult.warnings, ...aiResult.warnings],
        changesApplied: [...basicResult.changesApplied, ...aiResult.changesApplied]
      };

      logger.info(
        'Content filtering completed (basic + AI)',
        LogCategory.OPENAI,
        requestId,
        {
          is_clean: combinedResult.isClean,
          total_changes: combinedResult.changesApplied.length
        }
      );

      return combinedResult;
    } catch (error) {
      logger.warn(
        'AI filtering failed, using basic filtering result',
        LogCategory.OPENAI,
        requestId,
        error as Error
      );

      return basicResult;
    }
  }

  /**
   * Filter story prompts specifically
   */
  static async filterStoryPrompt(
    prompt: string,
    requestId?: string
  ): Promise<string> {
    const result = await this.filterContent(prompt, true, requestId);

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
   */
  static async filterImagePrompt(
    prompt: string,
    requestId?: string
  ): Promise<string> {
    // Image prompts need extra safety measures
    let filteredPrompt = prompt;

    // Ensure child-friendly art style
    if (!filteredPrompt.includes('child-friendly') && !filteredPrompt.includes('children\'s book')) {
      filteredPrompt += ' in a child-friendly, colorful children\'s book illustration style';
    }

    // Ensure bright and positive
    if (!/(bright|colorful|cheerful|magical|wonderful)/.test(filteredPrompt)) {
      filteredPrompt += ' with bright colors and a cheerful, magical atmosphere';
    }

    // Apply content filtering
    const result = await this.filterContent(filteredPrompt, true, requestId);

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
   */
  static validateFinalContent(content: string): { isValid: boolean; issues: string[] } {
    const issues: string[] = [];
    const lowerContent = content.toLowerCase();

    // Final safety checks
    const criticalTerms = [
      'alone', 'lonely', 'scared', 'crying', 'dark', 'scary',
      'fighting', 'violence', 'death', 'blood', 'weapon'
    ];

    for (const term of criticalTerms) {
      if (lowerContent.includes(term)) {
        issues.push(`Contains potentially unsafe term: "${term}"`);
      }
    }

    // Check for companionship
    const hasCompanionship = /\b(friends?|companions?|family|together|with\s+\w+)\b/i.test(content);
    if (!hasCompanionship) {
      issues.push('Content lacks companionship elements');
    }

    // Check for positive atmosphere
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