/**
 * Secret Management Module
 * Handles secure access to API keys and configuration
 */

import * as functions from 'firebase-functions';
import * as dotenv from 'dotenv';

// Load .env file in development
if (process.env.NODE_ENV !== 'production') {
  dotenv.config();
}

/**
 * Configuration interface for the application
 */
export interface AppConfig {
  openai: {
    apiKey: string;
    baseUrl: string;
    models: {
      story: string;
      tts: string;
      image: string;
    };
  };
  storage: {
    storyAssets: string;
    heroAvatars: string;
    storyAudio: string;
    storyIllustrations: string;
  };
  rateLimit: {
    storyGeneration: number;
    audioSynthesis: number;
    avatarGeneration: number;
    illustrationGeneration: number;
    windowSeconds: number;
  };
  cache: {
    ttlStory: number;
    ttlAudio: number;
    ttlAvatar: number;
    ttlIllustration: number;
    ttlContentFilter: number;
  };
  content: {
    filterEnabled: boolean;
    filterStoryPrompts: boolean;
    filterStoryOutput: boolean;
    filterScenePrompts: boolean;
    enforceCompanionship: boolean;
    minAge: number;
  };
  monitoring: {
    logLevel: string;
    enablePerformanceLogging: boolean;
    enableApiUsageLogging: boolean;
    enableCostTracking: boolean;
    monthlyBudgetUSD: number;
    alertThresholdPercentage: number;
  };
}

/**
 * Get configuration from environment or Firebase config
 */
function getConfigValue(envKey: string, configPath: string[], defaultValue?: any): any {
  // First check environment variable
  const envValue = process.env[envKey];
  if (envValue !== undefined) {
    return envValue;
  }

  // Then check Firebase config (production)
  try {
    const config = functions.config();
    let value = config;
    for (const key of configPath) {
      value = value?.[key];
    }
    if (value !== undefined) {
      return value;
    }
  } catch (error) {
    // Firebase config not available (likely in development)
  }

  // Return default value
  return defaultValue;
}

/**
 * Parse boolean environment variables
 */
function parseBoolean(value: any, defaultValue: boolean): boolean {
  if (value === undefined || value === null) {
    return defaultValue;
  }
  if (typeof value === 'boolean') {
    return value;
  }
  return value.toString().toLowerCase() === 'true';
}

/**
 * Parse integer environment variables
 */
function parseInteger(value: any, defaultValue: number): number {
  if (value === undefined || value === null) {
    return defaultValue;
  }
  const parsed = parseInt(value.toString(), 10);
  return isNaN(parsed) ? defaultValue : parsed;
}

/**
 * Get complete application configuration
 */
export function getConfig(): AppConfig {
  return {
    openai: {
      apiKey: getConfigValue('OPENAI_API_KEY', ['openai', 'key'], ''),
      baseUrl: getConfigValue('OPENAI_API_BASE_URL', ['openai', 'base_url'], 'https://api.openai.com/v1'),
      models: {
        story: getConfigValue('OPENAI_MODEL_STORY', ['openai', 'model_story'], 'gpt-4o'),
        tts: getConfigValue('OPENAI_MODEL_TTS', ['openai', 'model_tts'], 'gpt-4o-mini-tts'),
        image: getConfigValue('OPENAI_MODEL_IMAGE', ['openai', 'model_image'], 'dall-e-3'),
      },
    },
    storage: {
      storyAssets: getConfigValue('STORAGE_BUCKET_STORY_ASSETS', ['storage', 'story_assets'], 'story-assets'),
      heroAvatars: getConfigValue('STORAGE_BUCKET_HERO_AVATARS', ['storage', 'hero_avatars'], 'hero-avatars'),
      storyAudio: getConfigValue('STORAGE_BUCKET_STORY_AUDIO', ['storage', 'story_audio'], 'story-audio'),
      storyIllustrations: getConfigValue('STORAGE_BUCKET_STORY_ILLUSTRATIONS', ['storage', 'story_illustrations'], 'story-illustrations'),
    },
    rateLimit: {
      storyGeneration: parseInteger(getConfigValue('RATE_LIMIT_STORY_GENERATION', ['ratelimit', 'story_generation'], 10), 10),
      audioSynthesis: parseInteger(getConfigValue('RATE_LIMIT_AUDIO_SYNTHESIS', ['ratelimit', 'audio_synthesis'], 15), 15),
      avatarGeneration: parseInteger(getConfigValue('RATE_LIMIT_AVATAR_GENERATION', ['ratelimit', 'avatar_generation'], 8), 8),
      illustrationGeneration: parseInteger(getConfigValue('RATE_LIMIT_ILLUSTRATION_GENERATION', ['ratelimit', 'illustration_generation'], 25), 25),
      windowSeconds: parseInteger(getConfigValue('RATE_LIMIT_WINDOW_SECONDS', ['ratelimit', 'window_seconds'], 3600), 3600),
    },
    cache: {
      ttlStory: parseInteger(getConfigValue('CACHE_TTL_STORY_CONTENT', ['cache', 'ttl_story'], 86400), 86400),
      ttlAudio: parseInteger(getConfigValue('CACHE_TTL_AUDIO_FILES', ['cache', 'ttl_audio'], 604800), 604800),
      ttlAvatar: parseInteger(getConfigValue('CACHE_TTL_AVATAR_IMAGES', ['cache', 'ttl_avatar'], 604800), 604800),
      ttlIllustration: parseInteger(getConfigValue('CACHE_TTL_ILLUSTRATION_IMAGES', ['cache', 'ttl_illustration'], 604800), 604800),
      ttlContentFilter: parseInteger(getConfigValue('CACHE_TTL_CONTENT_FILTER', ['cache', 'ttl_content_filter'], 7200), 7200),
    },
    content: {
      filterEnabled: parseBoolean(getConfigValue('ENABLE_AI_CONTENT_FILTERING', ['content', 'filter_enabled'], true), true),
      filterStoryPrompts: parseBoolean(getConfigValue('FILTER_STORY_PROMPTS', ['content', 'filter_story_prompts'], true), true),
      filterStoryOutput: parseBoolean(getConfigValue('FILTER_STORY_OUTPUT', ['content', 'filter_story_output'], true), true),
      filterScenePrompts: parseBoolean(getConfigValue('FILTER_SCENE_PROMPTS', ['content', 'filter_scene_prompts'], true), true),
      enforceCompanionship: parseBoolean(getConfigValue('ENFORCE_CHILD_COMPANIONSHIP', ['content', 'enforce_companionship'], true), true),
      minAge: parseInteger(getConfigValue('MIN_AGE_FOR_CONTENT', ['content', 'min_age'], 3), 3),
    },
    monitoring: {
      logLevel: getConfigValue('LOG_LEVEL', ['monitoring', 'log_level'], 'info'),
      enablePerformanceLogging: parseBoolean(getConfigValue('ENABLE_PERFORMANCE_LOGGING', ['monitoring', 'enable_performance_logging'], true), true),
      enableApiUsageLogging: parseBoolean(getConfigValue('ENABLE_API_USAGE_LOGGING', ['monitoring', 'enable_api_usage_logging'], true), true),
      enableCostTracking: parseBoolean(getConfigValue('ENABLE_COST_TRACKING', ['monitoring', 'enable_cost_tracking'], true), true),
      monthlyBudgetUSD: parseInteger(getConfigValue('MONTHLY_BUDGET_USD', ['monitoring', 'budget_usd'], 1000), 1000),
      alertThresholdPercentage: parseInteger(getConfigValue('ALERT_THRESHOLD_PERCENTAGE', ['monitoring', 'alert_threshold'], 80), 80),
    },
  };
}

/**
 * Validate that required secrets are configured
 */
export function validateSecrets(): { valid: boolean; errors: string[] } {
  const config = getConfig();
  const errors: string[] = [];

  // Check OpenAI API Key
  if (!config.openai.apiKey || config.openai.apiKey === 'YOUR_ACTUAL_API_KEY_HERE') {
    errors.push('OpenAI API key is not configured. Set OPENAI_API_KEY environment variable or use firebase functions:config:set');
  }

  // Check if API key format is valid (basic check)
  if (config.openai.apiKey && !config.openai.apiKey.startsWith('sk-')) {
    errors.push('OpenAI API key format appears invalid. Should start with "sk-"');
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Get OpenAI configuration for making API calls
 */
export function getOpenAIConfig() {
  const config = getConfig();

  if (!config.openai.apiKey) {
    throw new Error('OpenAI API key not configured');
  }

  return {
    apiKey: config.openai.apiKey,
    baseURL: config.openai.baseUrl,
    models: config.openai.models,
  };
}

/**
 * Log configuration status (without exposing secrets)
 */
export function logConfigStatus(): void {
  const config = getConfig();
  const validation = validateSecrets();

  console.log('Configuration Status:', {
    environment: process.env.NODE_ENV || 'development',
    openaiConfigured: !!config.openai.apiKey && config.openai.apiKey !== 'YOUR_ACTUAL_API_KEY_HERE',
    openaiKeyPrefix: config.openai.apiKey ? config.openai.apiKey.substring(0, 7) + '...' : 'not set',
    storageConfigured: !!config.storage.storyAssets,
    contentFilteringEnabled: config.content.filterEnabled,
    rateLimitsConfigured: config.rateLimit.storyGeneration > 0,
    monitoringEnabled: config.monitoring.enableApiUsageLogging,
    validationStatus: validation.valid ? 'valid' : 'invalid',
    validationErrors: validation.errors,
  });
}

/**
 * Middleware to ensure secrets are configured before processing requests
 */
export function requireSecrets(req: any, res: any, next: () => void): void {
  const validation = validateSecrets();

  if (!validation.valid) {
    console.error('Secret validation failed:', validation.errors);
    res.status(500).json({
      error: 'Internal configuration error',
      details: process.env.NODE_ENV === 'development' ? validation.errors : undefined,
    });
    return;
  }

  next();
}