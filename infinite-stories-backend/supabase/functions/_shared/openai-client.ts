/**
 * OpenAI Client using the official Node.js SDK with GPT-5-mini
 *
 * This client provides a clean interface to OpenAI's APIs using the official SDK.
 * Optimized for GPT-5-mini with configurable reasoning effort and text verbosity.
 */

import OpenAI from "npm:openai@4.67.1";
import type {
  ChatCompletionMessageParam,
  ChatCompletionCreateParamsNonStreaming,
  ChatCompletion,
  ImagesResponse
} from "npm:openai@4.67.1";
import { APIError, ErrorCode } from './errors.ts';
import { logger, LogCategory } from './logger.ts';

/**
 * Model configuration - GPT-5-mini focused
 */
export const MODELS = {
  CHAT: 'gpt-4o',
  TTS: 'tts-1-hd',
  IMAGE: 'dall-e-3'
} as const;

/**
 * GPT-4o configuration parameters for different use cases
 */
export const GPT4O_CONFIG = {
  story_generation: {
    reasoning_effort: 'medium',
    text_verbosity: 'high',
    temperature: 0.7,
    max_tokens: 3000
  },
  scene_extraction: {
    reasoning_effort: 'high',
    text_verbosity: 'medium',
    temperature: 0.3,
    max_tokens: 2000
  },
  content_filtering: {
    reasoning_effort: 'low',
    text_verbosity: 'low',
    temperature: 0.2,
    max_tokens: 500
  }
} as const;

/**
 * Token usage tracking
 */
export interface TokenUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
  reasoning_tokens?: number;
  cached_tokens?: number;
}

/**
 * Chat completion request
 */
export interface ChatCompletionRequest {
  model?: string;
  messages: ChatCompletionMessageParam[];
  max_tokens?: number;
  temperature?: number;
  response_format?: { type: 'json_object' | 'text' };
  reasoning_effort?: 'minimal' | 'low' | 'medium' | 'high';
  text_verbosity?: 'low' | 'medium' | 'high';
  user_id?: string;
}

/**
 * Chat completion response
 */
export interface ChatCompletionResponse {
  id: string;
  choices: Array<{
    message: {
      content: string;
    };
    finish_reason: string;
  }>;
  usage: TokenUsage;
}

/**
 * TTS request interface
 */
export interface TTSRequest {
  model: string;
  input: string;
  voice: string;
  instructions?: string;
  response_format?: string;
  speed?: number;
}

/**
 * Image generation request
 */
export interface ImageGenerationRequest {
  model: string;
  prompt: string;
  n?: number;
  size?: string;
  quality?: string;
  background?: string;
  output_format?: string;
  moderation?: string;
  previous_generation_id?: string;
}

/**
 * OpenAI Client with official SDK
 */
export class OpenAIClient {
  private static instance: OpenAIClient;
  private client: OpenAI;
  private requestCount = 0;

  private constructor() {
    const apiKey = Deno.env.get('OPENAI_API_KEY');

    if (!apiKey) {
      throw new Error('OPENAI_API_KEY environment variable is required');
    }

    this.client = new OpenAI({
      apiKey,
      maxRetries: 3,
      timeout: 30000,
      defaultHeaders: {
        'User-Agent': 'InfiniteStories-Supabase/2.0'
      }
    });

    logger.info('OpenAI Client initialized with GPT-5-mini', LogCategory.API);
  }

  static getInstance(): OpenAIClient {
    if (!OpenAIClient.instance) {
      OpenAIClient.instance = new OpenAIClient();
    }
    return OpenAIClient.instance;
  }

  /**
   * Create chat completion with GPT-5-mini
   */
  async createChatCompletion(
    request: ChatCompletionRequest,
    requestId?: string
  ): Promise<ChatCompletionResponse> {
    const model = request.model || MODELS.CHAT;
    this.requestCount++;

    logger.logOpenAIRequest(model, 'chat_completion', requestId,
      JSON.stringify(request.messages).length);

    const startTime = Date.now();

    try {
      const params: ChatCompletionCreateParamsNonStreaming = {
        model,
        messages: request.messages,
        max_tokens: request.max_tokens || 3000,
        temperature: request.temperature ?? 0.7,
        user: request.user_id,
        ...(request.response_format && { response_format: request.response_format })
      };

      // Add GPT-5-mini specific parameters
      if (model === MODELS.CHAT) {
        (params as any).reasoning_effort = request.reasoning_effort || 'medium';
        (params as any).text_verbosity = request.text_verbosity || 'high';
      }

      const completion = await this.client.chat.completions.create(params);

      const responseTime = Date.now() - startTime;
      const usage: TokenUsage = {
        prompt_tokens: completion.usage?.prompt_tokens || 0,
        completion_tokens: completion.usage?.completion_tokens || 0,
        total_tokens: completion.usage?.total_tokens || 0,
        reasoning_tokens: (completion.usage as any)?.reasoning_tokens || 0,
        cached_tokens: (completion.usage as any)?.cached_tokens || 0
      };

      logger.logOpenAIResponse(true, responseTime, requestId, usage);

      return {
        id: completion.id,
        choices: completion.choices.map(choice => ({
          message: {
            content: choice.message?.content || ''
          },
          finish_reason: choice.finish_reason || 'stop'
        })),
        usage
      };
    } catch (error) {
      const responseTime = Date.now() - startTime;
      logger.logOpenAIResponse(false, responseTime, requestId);
      throw this.parseError(error, requestId);
    }
  }

  /**
   * Create speech with TTS
   */
  async createSpeech(
    request: TTSRequest,
    requestId?: string
  ): Promise<ArrayBuffer> {
    this.requestCount++;

    try {
      logger.logOpenAIRequest(request.model, 'tts', requestId, request.input.length);

      const params: any = {
        model: request.model,
        input: request.input,
        voice: request.voice,
        response_format: request.response_format || 'mp3',
        speed: request.speed || 0.95
      };

      if (request.instructions) {
        params.instructions = request.instructions;
      }

      const response = await this.client.audio.speech.create(params);
      return await response.arrayBuffer();
    } catch (error) {
      throw this.parseError(error, requestId);
    }
  }

  /**
   * Create image
   */
  async createImage(
    request: ImageGenerationRequest,
    requestId?: string
  ): Promise<ImagesResponse> {
    this.requestCount++;

    try {
      logger.logOpenAIRequest(request.model, 'image_generation', requestId, request.prompt.length);

      const params: any = {
        model: request.model,
        prompt: request.prompt,
        n: request.n || 1,
        size: request.size || "1024x1024",
        quality: request.quality || "standard",
        response_format: "b64_json"
      };

      if (request.background) params.background = request.background;
      if (request.output_format) params.output_format = request.output_format;
      if (request.moderation) params.moderation = request.moderation;
      if (request.previous_generation_id) {
        params.previous_generation_id = request.previous_generation_id;
      }

      return await this.client.images.generate(params);
    } catch (error) {
      throw this.parseError(error, requestId);
    }
  }

  /**
   * Parse OpenAI SDK errors
   */
  private parseError(error: any, requestId?: string): APIError {
    logger.error('OpenAI API error', LogCategory.OPENAI, requestId, error as Error);

    if (error instanceof OpenAI.APIError) {
      if (error instanceof OpenAI.RateLimitError) {
        return new APIError(
          ErrorCode.RATE_LIMITED,
          429,
          'OpenAI rate limit exceeded',
          { service: 'openai' },
          parseInt(error.headers?.['retry-after'] || '60')
        );
      }

      if (error instanceof OpenAI.AuthenticationError) {
        return new APIError(
          ErrorCode.UNAUTHORIZED,
          401,
          'OpenAI authentication failed'
        );
      }

      if (error instanceof OpenAI.BadRequestError) {
        if (error.message?.includes('content_policy')) {
          return new APIError(
            ErrorCode.CONTENT_POLICY_VIOLATION,
            400,
            'Content violates OpenAI policy'
          );
        }

        return new APIError(
          ErrorCode.INVALID_REQUEST,
          400,
          error.message || 'Invalid request to OpenAI'
        );
      }

      if (error instanceof OpenAI.APITimeoutError) {
        return new APIError(
          ErrorCode.TIMEOUT,
          408,
          'OpenAI request timed out'
        );
      }

      return new APIError(
        ErrorCode.OPENAI_ERROR,
        error.status || 500,
        error.message || 'OpenAI API error'
      );
    }

    return new APIError(
      ErrorCode.INTERNAL_ERROR,
      500,
      'Unexpected error occurred'
    );
  }

  /**
   * Get request count for monitoring
   */
  getRequestCount(): number {
    return this.requestCount;
  }

  /**
   * Test OpenAI connection
   */
  async testConnection(): Promise<boolean> {
    try {
      await this.client.models.list();
      return true;
    } catch {
      return false;
    }
  }
}

/**
 * Singleton instance
 */
export const openai = OpenAIClient.getInstance();

/**
 * Cost calculation for GPT-5-mini
 */
export function calculateCost(model: string, usage: TokenUsage): number {
  const pricing: Record<string, { input: number; output: number }> = {
    'gpt-4o': { input: 0.00015, output: 0.0006 },
    'tts-1-hd': { input: 0.00015, output: 0.0006 },
  };

  const modelPricing = pricing[model];
  if (!modelPricing) return 0;

  return (usage.prompt_tokens / 1000) * modelPricing.input +
         (usage.completion_tokens / 1000) * modelPricing.output;
}

/**
 * Get optimal parameters for GPT-5-mini based on use case
 */
export function getOptimalParams(useCase: keyof typeof GPT4O_CONFIG): {
  reasoning_effort: string;
  text_verbosity: string;
  temperature: number;
  max_tokens: number;
} {
  return GPT4O_CONFIG[useCase];
}