import { createSupabaseServiceClient } from './auth.ts';
import { TokenUsage } from './openai-client.ts';

/**
 * Log levels
 */
export enum LogLevel {
  DEBUG = 'debug',
  INFO = 'info',
  WARN = 'warn',
  ERROR = 'error'
}

/**
 * Log categories for organization
 */
export enum LogCategory {
  AUTH = 'auth',
  API = 'api',
  OPENAI = 'openai',
  STORY = 'story',
  AUDIO = 'audio',
  IMAGE = 'image',
  RATE_LIMIT = 'rate_limit',
  CACHE = 'cache',
  DATABASE = 'database',
  STORAGE = 'storage',
  SYNC = 'sync'
}

/**
 * API usage log entry
 */
export interface APIUsageLog {
  user_id: string;
  story_id?: string;
  function_name: string;
  request_id: string;
  model_used: string;
  tokens_used?: number;
  prompt_tokens?: number;
  completion_tokens?: number;
  cost_estimate?: number;
  status: 'success' | 'failed' | 'rate_limited';
  error_message?: string;
  response_time_ms: number;
  metadata?: Record<string, any>;
}

/**
 * Logger class for centralized logging
 */
export class Logger {
  private supabase = createSupabaseServiceClient();

  /**
   * Format log message with timestamp and context
   */
  private formatMessage(
    level: LogLevel,
    message: string,
    category?: LogCategory,
    requestId?: string,
    context?: Record<string, any>
  ): string {
    const timestamp = new Date().toISOString();
    const requestPart = requestId ? ` [${requestId}]` : '';
    const categoryPart = category ? ` [${category}]` : '';
    const contextPart = context ? ` ${JSON.stringify(context)}` : '';

    return `${timestamp} [${level.toUpperCase()}]${requestPart}${categoryPart} ${message}${contextPart}`;
  }

  /**
   * Log debug message
   */
  debug(
    message: string,
    category?: LogCategory,
    requestId?: string,
    context?: Record<string, any>
  ): void {
    const formatted = this.formatMessage(LogLevel.DEBUG, message, category, requestId, context);
    console.log(formatted);
  }

  /**
   * Log info message
   */
  info(
    message: string,
    category?: LogCategory,
    requestId?: string,
    context?: Record<string, any>
  ): void {
    const formatted = this.formatMessage(LogLevel.INFO, message, category, requestId, context);
    console.log(formatted);
  }

  /**
   * Log warning message
   */
  warn(
    message: string,
    category?: LogCategory,
    requestId?: string,
    context?: Record<string, any>
  ): void {
    const formatted = this.formatMessage(LogLevel.WARN, message, category, requestId, context);
    console.warn(formatted);
  }

  /**
   * Log error message
   */
  error(
    message: string,
    category?: LogCategory,
    requestId?: string,
    error?: Error,
    context?: Record<string, any>
  ): void {
    const errorContext = error ? {
      error_name: error.name,
      error_message: error.message,
      error_stack: error.stack,
      ...context
    } : context;

    const formatted = this.formatMessage(LogLevel.ERROR, message, category, requestId, errorContext);
    console.error(formatted);
  }

  /**
   * Log API request
   */
  logRequest(
    method: string,
    endpoint: string,
    requestId: string,
    userId?: string,
    bodySize?: number
  ): void {
    this.info(
      `${method} ${endpoint}`,
      LogCategory.API,
      requestId,
      {
        user_id: userId,
        body_size: bodySize
      }
    );
  }

  /**
   * Log API response
   */
  logResponse(
    statusCode: number,
    responseTime: number,
    requestId: string,
    dataSize?: number,
    cached?: boolean
  ): void {
    this.info(
      `Response ${statusCode}`,
      LogCategory.API,
      requestId,
      {
        response_time_ms: responseTime,
        data_size: dataSize,
        cached
      }
    );
  }

  /**
   * Log OpenAI API call
   */
  logOpenAIRequest(
    model: string,
    operation: string,
    requestId: string,
    promptTokens?: number
  ): void {
    this.info(
      `OpenAI ${operation} with ${model}`,
      LogCategory.OPENAI,
      requestId,
      {
        model,
        operation,
        prompt_tokens: promptTokens
      }
    );
  }

  /**
   * Log OpenAI API response
   */
  logOpenAIResponse(
    success: boolean,
    responseTime: number,
    requestId: string,
    usage?: TokenUsage,
    error?: string
  ): void {
    const level = success ? LogLevel.INFO : LogLevel.ERROR;
    const message = success ? 'OpenAI request completed' : 'OpenAI request failed';

    this[level](
      message,
      LogCategory.OPENAI,
      requestId,
      {
        success,
        response_time_ms: responseTime,
        usage,
        error_message: error
      }
    );
  }

  /**
   * Log story generation
   */
  logStoryGeneration(
    phase: string,
    requestId: string,
    context: Record<string, any>
  ): void {
    this.info(
      `Story generation: ${phase}`,
      LogCategory.STORY,
      requestId,
      context
    );
  }

  /**
   * Log audio synthesis
   */
  logAudioSynthesis(
    phase: string,
    requestId: string,
    context: Record<string, any>
  ): void {
    this.info(
      `Audio synthesis: ${phase}`,
      LogCategory.AUDIO,
      requestId,
      context
    );
  }

  /**
   * Log image generation
   */
  logImageGeneration(
    phase: string,
    requestId: string,
    context: Record<string, any>
  ): void {
    this.info(
      `Image generation: ${phase}`,
      LogCategory.IMAGE,
      requestId,
      context
    );
  }

  /**
   * Log rate limiting action
   */
  logRateLimit(
    action: string,
    userId: string,
    functionName: string,
    requestId: string,
    context?: Record<string, any>
  ): void {
    this.info(
      `Rate limit ${action}`,
      LogCategory.RATE_LIMIT,
      requestId,
      {
        user_id: userId,
        function_name: functionName,
        ...context
      }
    );
  }

  /**
   * Log cache operation
   */
  logCache(
    operation: string,
    key: string,
    hit: boolean,
    requestId?: string
  ): void {
    this.info(
      `Cache ${operation}: ${hit ? 'HIT' : 'MISS'}`,
      LogCategory.CACHE,
      requestId,
      {
        cache_key: key,
        cache_hit: hit
      }
    );
  }

  /**
   * Log sync operation
   */
  logSync(
    phase: string,
    requestId: string,
    context: Record<string, any>
  ): void {
    this.info(
      `Sync operation: ${phase}`,
      LogCategory.SYNC,
      requestId,
      context
    );
  }

  /**
   * Log performance metrics
   */
  logPerformance(
    operation: string,
    duration: number,
    requestId: string,
    metadata?: Record<string, any>
  ): void {
    this.info(
      `Performance: ${operation} completed in ${duration}ms`,
      LogCategory.API,
      requestId,
      {
        operation,
        duration_ms: duration,
        ...metadata
      }
    );
  }

  /**
   * Log API usage to database for tracking and billing
   */
  async logAPIUsage(usage: APIUsageLog): Promise<void> {
    try {
      const { error } = await this.supabase
        .from('api_usage')
        .insert(usage);

      if (error) {
        this.error(
          'Failed to log API usage to database',
          LogCategory.DATABASE,
          usage.request_id,
          error
        );
      }
    } catch (error) {
      this.error(
        'Error logging API usage',
        LogCategory.DATABASE,
        usage.request_id,
        error as Error
      );
    }
  }

  /**
   * Create a timer for measuring operation duration
   */
  startTimer(): () => number {
    const start = Date.now();
    return () => Date.now() - start;
  }

  /**
   * Log with automatic performance measurement
   */
  async withPerformanceLogging<T>(
    operation: string,
    requestId: string,
    fn: () => Promise<T>,
    category?: LogCategory
  ): Promise<T> {
    const timer = this.startTimer();

    this.debug(
      `Starting ${operation}`,
      category || LogCategory.API,
      requestId
    );

    try {
      const result = await fn();
      const duration = timer();

      this.logPerformance(operation, duration, requestId);

      return result;
    } catch (error) {
      const duration = timer();

      this.error(
        `${operation} failed after ${duration}ms`,
        category || LogCategory.API,
        requestId,
        error as Error
      );

      throw error;
    }
  }
}

/**
 * Singleton logger instance
 */
export const logger = new Logger();