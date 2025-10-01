/**
 * OpenAI Client using the new Response API (/v1/responses)
 *
 * This client provides a clean interface to OpenAI's new Response API with direct HTTP calls.
 * Optimized for GPT-5 models with enhanced reasoning controls and prompt caching.
 * Audio and Image APIs continue using the official SDK as they don't use the Response API.
 */

import OpenAI from "npm:openai@4.67.1";
import type {
  ImagesResponse,
} from "npm:openai@4.67.1";
import { APIError, ErrorCode } from './errors.ts';
import { logger, LogCategory } from './logger.ts';

/**
 * Model configuration - Using latest GPT-5 models
 * Reference: https://context7.com/websites/platform_openai/llms.txt
 */
export const MODELS = {
  CHAT: 'gpt-5',  // GPT-5 Mini for text generation with configurable reasoning
  TTS: 'gpt-4o-mini-tts',  // GPT-4o Mini TTS for high-quality audio synthesis
  IMAGE: 'gpt-5'  // DALL-E 3 for image generation (GPT-5 doesn't support image generation yet)
} as const;

/**
 * GPT-5 Mini configuration parameters for different use cases
 * Reference: https://context7.com/websites/platform_openai/llms.txt?topic=gpt-5-mini
 */
export const GPT5_MINI_CONFIG = {
  story_generation: {
    reasoning_effort: 'low',  // Balanced reasoning for creative storytelling
    text_verbosity: 'low',      // Detailed story content
    temperature: 0.7,
    max_tokens: 50000
  },
  scene_extraction: {
    reasoning_effort: 'low',    // Reduced reasoning to prioritize output tokens
    text_verbosity: 'low',
    temperature: 0.3,
    max_tokens: 50000  // Increased to handle large story content + scenes
  },
  content_filtering: {
    reasoning_effort: 'low', // Fast processing for content safety
    text_verbosity: 'low',
    temperature: 0.2,
    max_tokens: 1000  // Increased from 500 to handle large content filtering
  }
} as const;

// Backwards compatibility alias
export const GPT4O_CONFIG = GPT5_MINI_CONFIG;

/**
 * New Response API message format
 */
export interface ResponseAPIMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/**
 * New Response API request structure
 * Based on GPT-5 documentation: uses single string input, NOT message array
 */
export interface ResponseAPIRequest {
  model: string;
  input: string;  // Single string input, NOT array of messages
  max_output_tokens?: number;
  // Temperature is NOT supported for GPT-5 models
  temperature?: number;
  // GPT-5 specific reasoning configuration
  reasoning?: {
    effort: 'minimal' | 'low' | 'medium' | 'high';
  };
  // GPT-5 specific text configuration - includes format
  text?: {
    verbosity?: 'low' | 'medium' | 'high';
    format?: {
      type: 'text' | 'json_schema';
      name?: string;  // Required for json_schema
      schema?: any;   // Schema directly here, not nested
      strict?: boolean;
    };
  };
  safety_identifier?: string;
  service_tier?: 'auto' | 'default' | 'flex' | 'priority';
  prompt_cache_key?: string;
  store?: boolean;
  metadata?: Record<string, any>;
}

/**
 * New Response API response structure (actual format from API)
 */
export interface ResponseAPIResponse {
  id: string;
  object: string;
  created_at: number;
  status: 'completed' | 'incomplete';
  model: string;
  service_tier?: string;
  incomplete_details?: {
    reason: string;
  };
  output: Array<{
    id: string;
    type: 'reasoning' | 'message';
    status?: string;
    content?: Array<{
      type: 'output_text';
      text: string;
      annotations?: any[];
      logprobs?: any[];
    }>;
    role?: string;
    summary?: any[];
  }>;
  usage: {
    input_tokens: number;
    output_tokens: number;
    total_tokens: number;
    input_tokens_details?: {
      cached_tokens?: number;
    };
    output_tokens_details?: {
      reasoning_tokens?: number;
    };
  };
  reasoning?: {
    effort: string;
    summary?: any;
  };
  text?: {
    format?: {
      type: string;
    };
    verbosity?: string;
  };
  metadata?: Record<string, any>;
  incomplete_details?: {
    reason: string;
  };
}

/**
 * Token usage tracking with enhanced details from new response API
 */
export interface TokenUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
  reasoning_tokens?: number;
  cached_tokens?: number;
  // Additional fields from new response API
  audio_tokens?: number;
  completion_tokens_details?: {
    reasoning_tokens?: number;
    audio_tokens?: number;
    text_tokens?: number;
  };
  prompt_tokens_details?: {
    cached_tokens?: number;
    audio_tokens?: number;
    text_tokens?: number;
  };
}

/**
 * Chat completion request (backward compatible interface)
 */
export interface ChatCompletionRequest {
  model?: string;
  messages: ResponseAPIMessage[];
  max_tokens?: number;
  temperature?: number;
  response_format?: { type: 'json_object' | 'text' };
  reasoning_effort?: 'minimal' | 'low' | 'medium' | 'high';
  text_verbosity?: 'low' | 'medium' | 'high';
  user_id?: string;
  prompt_cache_key?: string;
  service_tier?: 'auto' | 'default' | 'flex' | 'priority';
}

/**
 * Chat completion response (backward compatible interface)
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
 * OpenAI Client with Response API and SDK hybrid approach
 */
export class OpenAIClient {
  private static instance: OpenAIClient;
  private client: OpenAI;
  private apiKey: string;
  private requestCount = 0;
  private responseAPIEndpoint = 'https://api.openai.com/v1/responses';

  private constructor() {
    const apiKey = Deno.env.get('OPENAI_API_KEY');

    if (!apiKey) {
      throw new Error('OPENAI_API_KEY environment variable is required');
    }

    this.apiKey = apiKey;

    // Keep OpenAI client for audio and image APIs
    this.client = new OpenAI({
      apiKey,
      maxRetries: 3,
      timeout: 180000, // 3 minutes - GPT-5-mini can take 2+ minutes for long story generation
      defaultHeaders: {
        'User-Agent': 'InfiniteStories-Supabase/2.0'
      }
    });

    logger.info('OpenAI Client initialized with Response API for chat and SDK for audio/images', LogCategory.API);
  }

  static getInstance(): OpenAIClient {
    if (!OpenAIClient.instance) {
      OpenAIClient.instance = new OpenAIClient();
    }
    return OpenAIClient.instance;
  }

  /**
   * Call the new Response API directly with HTTP
   */
  private async callResponseAPI(
    request: ResponseAPIRequest,
    requestId?: string
  ): Promise<ResponseAPIResponse> {
    const startTime = Date.now();

    try {
      const response = await fetch(this.responseAPIEndpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
          'User-Agent': 'InfiniteStories-Supabase/2.0',
          'OpenAI-Beta': 'responses-api-2024-12' // Enable beta features if needed
        },
        body: JSON.stringify(request),
      });

      if (!response.ok) {
        const errorBody = await response.text();
        let errorData: any;
        try {
          errorData = JSON.parse(errorBody);
        } catch {
          errorData = { message: errorBody };
        }

        // Throw error with status for proper parsing
        const error = new Error(errorData.error?.message || errorData.message || 'Response API request failed');
        (error as any).status = response.status;
        (error as any).headers = response.headers;
        (error as any).error = errorData.error;
        throw error;
      }

      const data = await response.json() as ResponseAPIResponse;
      const responseTime = Date.now() - startTime;

      // Check if response is incomplete
      if (data.status === 'incomplete') {
        const reason = data.incomplete_details?.reason || 'unknown';
        console.error(`Response API returned incomplete response (${reason}):`, JSON.stringify(data, null, 2));

        // If incomplete due to max_output_tokens, throw a specific error
        if (reason === 'max_output_tokens') {
          throw new Error(`Response API hit token limit (max_output_tokens). Consider increasing the limit or reducing the prompt size.`);
        }
        throw new Error(`Response API returned incomplete response: ${reason}`);
      }

      // Extract the message content from the new Response API structure
      const messageOutput = data.output?.find(o => o.type === 'message');
      if (!messageOutput || !messageOutput.content || messageOutput.content.length === 0) {
        console.error('Response API returned unexpected structure:', JSON.stringify(data, null, 2));
        throw new Error('Invalid response structure from Response API - no message content found');
      }

      logger.logOpenAIResponse(true, responseTime, requestId, {
        prompt_tokens: data.usage?.input_tokens || 0,
        completion_tokens: data.usage?.output_tokens || 0,
        total_tokens: data.usage?.total_tokens || 0,
        reasoning_tokens: data.usage?.output_tokens_details?.reasoning_tokens || 0,
        cached_tokens: data.usage?.input_tokens_details?.cached_tokens || 0
      });

      return data;
    } catch (error) {
      const responseTime = Date.now() - startTime;
      logger.logOpenAIResponse(false, responseTime, requestId);
      throw error;
    }
  }

  /**
   * Create chat completion using Response API for GPT-5 or traditional API for others
   */
  async createChatCompletion(
    request: ChatCompletionRequest,
    requestId?: string
  ): Promise<ChatCompletionResponse> {
    const model = request.model || MODELS.CHAT;
    this.requestCount++;

    logger.logOpenAIRequest(model, 'chat_completion', requestId,
      JSON.stringify(request.messages).length);

    try {
      const isGPT5 = model.startsWith('gpt-5');

      // Use Response API for GPT-5 models
      if (isGPT5) {
        return await this.createGPT5Completion(request, requestId);
      }

      // Use traditional Chat Completions API for non-GPT-5 models
      return await this.createTraditionalCompletion(request, requestId);
    } catch (error) {
      throw this.parseError(error, requestId);
    }
  }

  /**
   * Create completion using GPT-5 Response API
   */
  private async createGPT5Completion(
    request: ChatCompletionRequest,
    requestId?: string
  ): Promise<ChatCompletionResponse> {
    const model = request.model || MODELS.CHAT;

    // Convert messages array to single input string for Response API
    const inputString = this.formatMessagesAsString(request.messages);

    // Build Response API request for GPT-5
    const apiRequest: ResponseAPIRequest = {
      model,
      input: inputString,  // Single string, not array
      max_output_tokens: request.max_tokens || 3000,
      ...(request.user_id && { safety_identifier: request.user_id }),
      ...(request.service_tier && { service_tier: request.service_tier }),
      ...(request.prompt_cache_key && { prompt_cache_key: request.prompt_cache_key }),
    };

    // Handle response format for GPT-5 - moved to text.format in Response API
    if (request.response_format) {
      if (!apiRequest.text) {
        apiRequest.text = {};
      }
      if (request.response_format.type === 'json_object') {
        apiRequest.text.format = {
          type: 'json_schema',
          name: 'response',
          schema: {
            type: 'object',
            properties: {},  // Empty properties but valid schema
            additionalProperties: true
          },
          strict: false
        };
      } else {
        apiRequest.text.format = {
          type: request.response_format.type || 'text'
        };
      }
    }

    // Add reasoning configuration for GPT-5
    if (request.reasoning_effort) {
      apiRequest.reasoning = {
        effort: request.reasoning_effort
      };
    }

    // Add text verbosity configuration for GPT-5
    if (request.text_verbosity) {
      if (!apiRequest.text) {
        apiRequest.text = {};
      }
      apiRequest.text.verbosity = request.text_verbosity;
    }

    // Don't include 'usage' or 'rate_limit' as they're not valid for Response API
    // The usage info is returned by default in the response

    // Call the Response API
    const response = await this.callResponseAPI(apiRequest, requestId);

    // Extract the message content from the new Response API structure
    const messageOutput = response.output?.find(o => o.type === 'message');
    const messageContent = messageOutput?.content?.[0]?.text || '';

    // Extract usage with new response format
    const usage: TokenUsage = {
      prompt_tokens: response.usage.input_tokens,
      completion_tokens: response.usage.output_tokens,
      total_tokens: response.usage.total_tokens,
      reasoning_tokens: response.usage.output_tokens_details?.reasoning_tokens,
      cached_tokens: response.usage.input_tokens_details?.cached_tokens,
      completion_tokens_details: {
        reasoning_tokens: response.usage.output_tokens_details?.reasoning_tokens
      },
      prompt_tokens_details: {
        cached_tokens: response.usage.input_tokens_details?.cached_tokens
      }
    };

    // Transform to backward-compatible format
    return {
      id: response.id,
      choices: [{
        message: {
          content: messageContent
        },
        finish_reason: response.status === 'completed' ? 'stop' : 'length'
      }],
      usage
    };
  }

  /**
   * Create completion using traditional Chat Completions API
   */
  private async createTraditionalCompletion(
    request: ChatCompletionRequest,
    requestId?: string
  ): Promise<ChatCompletionResponse> {
    const model = request.model || MODELS.CHAT;
    const startTime = Date.now();

    try {
      // Use the traditional OpenAI SDK for non-GPT-5 models
      const response = await this.client.chat.completions.create({
        model,
        messages: request.messages as any,
        max_tokens: request.max_tokens || 3000,
        temperature: request.temperature,
        response_format: request.response_format as any,
        user: request.user_id,
      });

      const responseTime = Date.now() - startTime;

      // Extract usage
      const usage: TokenUsage = {
        prompt_tokens: response.usage?.prompt_tokens || 0,
        completion_tokens: response.usage?.completion_tokens || 0,
        total_tokens: response.usage?.total_tokens || 0,
      };

      logger.logOpenAIResponse(true, responseTime, requestId, usage);

      // Transform to our format
      return {
        id: response.id,
        choices: response.choices.map(choice => ({
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
      throw error;
    }
  }

  /**
   * Convert messages array to single string for Response API
   */
  private formatMessagesAsString(messages: ResponseAPIMessage[]): string {
    return messages.map(msg => {
      const rolePrefix = msg.role === 'system' ? '[SYSTEM]' :
                        msg.role === 'assistant' ? '[ASSISTANT]' :
                        '[USER]';
      return `${rolePrefix}: ${msg.content}`;
    }).join('\n\n');
  }

  /**
   * Create speech with TTS
   * Using the new response API format
   */
  async createSpeech(
    request: TTSRequest,
    requestId?: string
  ): Promise<ArrayBuffer> {
    this.requestCount++;

    const startTime = Date.now();

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

      // Use the new response API format
      const response = await this.client.audio.speech.create(params);

      const responseTime = Date.now() - startTime;
      logger.logOpenAIResponse(true, responseTime, requestId);

      // Return the audio buffer directly
      return await response.arrayBuffer();
    } catch (error) {
      const responseTime = Date.now() - startTime;
      logger.logOpenAIResponse(false, responseTime, requestId);
      throw this.parseError(error, requestId);
    }
  }

  /**
   * Create streaming chat completion
   */
  async *createChatCompletionStream(
    request: ChatCompletionRequest,
    requestId?: string
  ): AsyncGenerator<{ content: string; finish_reason?: string }, void, unknown> {
    const model = request.model || MODELS.CHAT;
    this.requestCount++;

    logger.logOpenAIRequest(model, 'chat_completion_stream', requestId,
      JSON.stringify(request.messages).length);

    const isGPT5 = model.startsWith('gpt-5');

    try {
      // Use Response API streaming for GPT-5 models
      if (isGPT5) {
        yield* this.createGPT5Stream(request, requestId);
      } else {
        // Use traditional streaming for non-GPT-5 models
        yield* this.createTraditionalStream(request, requestId);
      }
    } catch (error) {
      throw this.parseError(error, requestId);
    }
  }

  /**
   * Create streaming completion using GPT-5 Response API
   */
  private async *createGPT5Stream(
    request: ChatCompletionRequest,
    requestId?: string
  ): AsyncGenerator<{ content: string; finish_reason?: string }, void, unknown> {
    const model = request.model || MODELS.CHAT;
    const startTime = Date.now();

    try {
      // Convert messages to single string for Response API
      const inputString = this.formatMessagesAsString(request.messages);

      // Build Response API request with streaming
      const apiRequest: any = {
        model,
        input: inputString,  // Single string, not array
        max_output_tokens: request.max_tokens || 3000,
        stream: true,
        ...(request.response_format && { response_format: request.response_format }),
        ...(request.user_id && { safety_identifier: request.user_id }),
        ...(request.service_tier && { service_tier: request.service_tier }),
        ...(request.prompt_cache_key && { prompt_cache_key: request.prompt_cache_key }),
      };

      // Add reasoning configuration for GPT-5
      if (request.reasoning_effort) {
        apiRequest.reasoning = {
          effort: request.reasoning_effort
        };
      }

      // Add text verbosity for GPT-5
      if (request.text_verbosity) {
        apiRequest.text = {
          verbosity: request.text_verbosity
        };
      }

      // Make streaming request to Response API
      const response = await fetch(this.responseAPIEndpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
          'User-Agent': 'InfiniteStories-Supabase/2.0',
          'Accept': 'text/event-stream',
          'OpenAI-Beta': 'responses-api-2024-12'
        },
        body: JSON.stringify(apiRequest),
      });

      if (!response.ok) {
        const errorBody = await response.text();
        let errorData: any;
        try {
          errorData = JSON.parse(errorBody);
        } catch {
          errorData = { message: errorBody };
        }
        const error = new Error(errorData.error?.message || errorData.message || 'Stream request failed');
        (error as any).status = response.status;
        throw error;
      }

      const reader = response.body?.getReader();
      if (!reader) {
        throw new Error('No response body available for streaming');
      }

      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6);
            if (data === '[DONE]') {
              break;
            }

            try {
              const chunk = JSON.parse(data);
              const content = chunk.choices?.[0]?.delta?.content || '';
              const finishReason = chunk.choices?.[0]?.finish_reason;

              if (content || finishReason) {
                yield { content, finish_reason: finishReason };
              }
            } catch (e) {
              // Skip invalid JSON chunks
              console.error('Failed to parse streaming chunk:', e);
            }
          }
        }
      }

      const responseTime = Date.now() - startTime;
      logger.logOpenAIResponse(true, responseTime, requestId);
    } catch (error) {
      const responseTime = Date.now() - startTime;
      logger.logOpenAIResponse(false, responseTime, requestId);
      throw error;
    }
  }

  /**
   * Create streaming completion using traditional Chat Completions API
   */
  private async *createTraditionalStream(
    request: ChatCompletionRequest,
    requestId?: string
  ): AsyncGenerator<{ content: string; finish_reason?: string }, void, unknown> {
    const model = request.model || MODELS.CHAT;
    const startTime = Date.now();

    try {
      // Use traditional OpenAI SDK streaming
      const stream = await this.client.chat.completions.create({
        model,
        messages: request.messages as any,
        max_tokens: request.max_tokens || 3000,
        temperature: request.temperature,
        response_format: request.response_format as any,
        user: request.user_id,
        stream: true,
      });

      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || '';
        const finishReason = chunk.choices[0]?.finish_reason;

        if (content || finishReason) {
          yield { content, finish_reason: finishReason };
        }
      }

      const responseTime = Date.now() - startTime;
      logger.logOpenAIResponse(true, responseTime, requestId);
    } catch (error) {
      const responseTime = Date.now() - startTime;
      logger.logOpenAIResponse(false, responseTime, requestId);
      throw error;
    }
  }

  /**
   * Create image
   * Using the new response API format
   */
  async createImage(
    request: ImageGenerationRequest,
    requestId?: string
  ): Promise<ImagesResponse> {
    this.requestCount++;

    const startTime = Date.now();

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

      // Use the new response API format
      const response = await this.client.images.generate(params);

      const responseTime = Date.now() - startTime;

      // Log with proper usage tracking if available
      const usage = response.usage ? {
        prompt_tokens: 0,
        completion_tokens: 0,
        total_tokens: 0
      } : undefined;

      logger.logOpenAIResponse(true, responseTime, requestId, usage);

      return response;
    } catch (error) {
      const responseTime = Date.now() - startTime;
      logger.logOpenAIResponse(false, responseTime, requestId);
      throw this.parseError(error, requestId);
    }
  }

  /**
   * Parse OpenAI SDK errors
   */
  private parseError(error: any, requestId?: string): APIError {
    logger.error('OpenAI API error', LogCategory.OPENAI, requestId, error as Error);

    // Check error status/type by properties instead of instanceof (more reliable in Deno)
    const status = error?.status || error?.statusCode;
    const errorType = error?.type || error?.name || error?.constructor?.name;
    const message = error?.message || String(error);

    // Rate limit error
    if (status === 429 || errorType?.includes('RateLimit')) {
      return new APIError(
        ErrorCode.RATE_LIMITED,
        429,
        'OpenAI rate limit exceeded',
        { service: 'openai' },
        parseInt(error.headers?.['retry-after'] || '60')
      );
    }

    // Authentication error
    if (status === 401 || errorType?.includes('Authentication')) {
      return new APIError(
        ErrorCode.UNAUTHORIZED,
        401,
        'OpenAI authentication failed'
      );
    }

    // Bad request error
    if (status === 400 || errorType?.includes('BadRequest')) {
      if (message?.includes('content_policy')) {
        return new APIError(
          ErrorCode.CONTENT_POLICY_VIOLATION,
          400,
          'Content violates OpenAI policy'
        );
      }

      return new APIError(
        ErrorCode.INVALID_REQUEST,
        400,
        message || 'Invalid request to OpenAI'
      );
    }

    // Timeout error
    if (message?.includes('timed out') || message?.includes('timeout') || errorType?.includes('Timeout')) {
      return new APIError(
        ErrorCode.TIMEOUT,
        408,
        'OpenAI request timed out'
      );
    }

    // Generic OpenAI API error
    if (status || error?.error || errorType?.includes('API')) {
      return new APIError(
        ErrorCode.OPENAI_ERROR,
        status || 500,
        message || 'OpenAI API error'
      );
    }

    // Fallback for unknown errors
    return new APIError(
      ErrorCode.INTERNAL_ERROR,
      500,
      message || 'Unexpected error occurred'
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
 * Cost calculation for OpenAI models
 * Reference: https://openai.com/api/pricing/
 */
export function calculateCost(model: string, usage: TokenUsage): number {
  const pricing: Record<string, { input: number; output: number }> = {
    'gpt-5-mini': { input: 0.0015, output: 0.006 },  // GPT-5 Mini pricing per 1K tokens
    'gpt-5': { input: 0.0025, output: 0.01 },  // GPT-5 pricing per 1K tokens
    'gpt-4o-mini-tts': { input: 0.00015, output: 0.0006 },  // TTS pricing per 1K characters
    // Legacy models for backwards compatibility
  };

  const modelPricing = pricing[model];
  if (!modelPricing) return 0;

  return (usage.prompt_tokens / 1000) * modelPricing.input +
         (usage.completion_tokens / 1000) * modelPricing.output;
}

/**
 * Get optimal parameters for GPT-5 Mini based on use case
 */
export function getOptimalParams(useCase: keyof typeof GPT5_MINI_CONFIG): {
  reasoning_effort: string;
  text_verbosity: string;
  temperature: number;
  max_tokens: number;
} {
  return GPT5_MINI_CONFIG[useCase];
}
