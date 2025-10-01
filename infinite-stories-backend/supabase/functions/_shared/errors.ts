import { createJSONResponse } from './cors.ts';

/**
 * Standard error codes for the API
 */
export enum ErrorCode {
  // Authentication errors
  UNAUTHORIZED = 'UNAUTHORIZED',
  FORBIDDEN = 'FORBIDDEN',
  INVALID_TOKEN = 'INVALID_TOKEN',

  // Request validation errors
  INVALID_REQUEST = 'INVALID_REQUEST',
  MISSING_FIELDS = 'MISSING_FIELDS',
  INVALID_CONTENT = 'INVALID_CONTENT',

  // OpenAI API errors
  RATE_LIMITED = 'RATE_LIMITED', // Only for OpenAI rate limits
  OPENAI_ERROR = 'OPENAI_ERROR',
  CONTENT_POLICY_VIOLATION = 'CONTENT_POLICY_VIOLATION',
  MODEL_UNAVAILABLE = 'MODEL_UNAVAILABLE',

  // Internal errors
  DATABASE_ERROR = 'DATABASE_ERROR',
  STORAGE_ERROR = 'STORAGE_ERROR',
  NETWORK_ERROR = 'NETWORK_ERROR',
  TIMEOUT = 'TIMEOUT',
  INTERNAL_ERROR = 'INTERNAL_ERROR'
}

/**
 * Custom API Error class
 */
export class APIError extends Error {
  constructor(
    public code: ErrorCode,
    public statusCode: number,
    message: string,
    public details?: any,
    public retryAfter?: number
  ) {
    super(message);
    this.name = 'APIError';
  }
}

/**
 * Standard error response format
 */
export interface ErrorResponse {
  error: {
    code: string;
    message: string;
    details?: any;
    retry_after?: number;
  };
  request_id: string;
  timestamp: string;
}

/**
 * Success response wrapper
 */
export interface SuccessResponse<T> {
  success: true;
  data: T;
  meta: {
    request_id: string;
    processing_time: number;
    cached?: boolean;
  };
}

/**
 * Create standardized error response
 */
export function createErrorResponse(
  error: APIError | Error,
  requestId: string
): Response {
  let errorResponse: ErrorResponse;

  if (error instanceof APIError) {
    errorResponse = {
      error: {
        code: error.code,
        message: error.message,
        details: error.details,
        retry_after: error.retryAfter
      },
      request_id: requestId,
      timestamp: new Date().toISOString()
    };

    return createJSONResponse(errorResponse, error.statusCode);
  } else {
    // Handle unexpected errors
    errorResponse = {
      error: {
        code: ErrorCode.INTERNAL_ERROR,
        message: 'An unexpected error occurred'
      },
      request_id: requestId,
      timestamp: new Date().toISOString()
    };

    // Log the actual error for debugging
    console.error(`[${requestId}] Unexpected error:`, error);

    return createJSONResponse(errorResponse, 500);
  }
}

/**
 * Create standardized success response
 */
export function createSuccessResponse<T>(
  data: T,
  requestId: string,
  processingTime: number,
  cached: boolean = false
): Response {
  const response: SuccessResponse<T> = {
    success: true,
    data,
    meta: {
      request_id: requestId,
      processing_time: processingTime,
      cached
    }
  };

  return createJSONResponse(response);
}

/**
 * Validation error helper
 */
export function createValidationError(message: string, details?: any): APIError {
  return new APIError(
    ErrorCode.INVALID_REQUEST,
    400,
    message,
    details
  );
}

/**
 * OpenAI error parser
 */
export function parseOpenAIError(error: any): APIError {
  // Handle OpenAI API errors
  if (error.response?.status === 429) {
    const retryAfter = error.response.headers['retry-after'];
    return new APIError(
      ErrorCode.RATE_LIMITED,
      429,
      'OpenAI rate limit exceeded',
      { service: 'openai' },
      parseInt(retryAfter) || 60
    );
  }

  if (error.response?.data?.error?.type === 'invalid_request_error') {
    if (error.response.data.error.message.includes('content_policy')) {
      return new APIError(
        ErrorCode.CONTENT_POLICY_VIOLATION,
        400,
        'Content violates OpenAI policy',
        { original_error: error.response.data.error.message }
      );
    }
  }

  if (error.response?.status === 503) {
    return new APIError(
      ErrorCode.MODEL_UNAVAILABLE,
      503,
      'OpenAI model temporarily unavailable'
    );
  }

  // Generic OpenAI error
  return new APIError(
    ErrorCode.OPENAI_ERROR,
    error.response?.status || 500,
    error.message || 'OpenAI API error',
    { original_error: error.response?.data }
  );
}

/**
 * Database error parser
 */
export function parseDatabaseError(error: any): APIError {
  // Check for common database errors
  if (error.code === '23505') { // Unique constraint violation
    return new APIError(
      ErrorCode.INVALID_REQUEST,
      400,
      'Resource already exists',
      { constraint: error.constraint }
    );
  }

  if (error.code === '23503') { // Foreign key violation
    return new APIError(
      ErrorCode.INVALID_REQUEST,
      400,
      'Referenced resource does not exist',
      { constraint: error.constraint }
    );
  }

  return new APIError(
    ErrorCode.DATABASE_ERROR,
    500,
    'Database operation failed',
    { original_error: error.message }
  );
}

/**
 * Timeout error helper
 */
export function createTimeoutError(operation: string): APIError {
  return new APIError(
    ErrorCode.TIMEOUT,
    408,
    `Operation timed out: ${operation}`
  );
}

/**
 * Error handler middleware
 */
export async function withErrorHandling<T>(
  requestId: string,
  operation: () => Promise<T>
): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    console.error(`[${requestId}] Error in operation:`, error);

    if (error instanceof APIError) {
      throw error;
    }

    // Handle specific error types
    if (error.name === 'DatabaseError' || error.code) {
      throw parseDatabaseError(error);
    }

    if (error.response?.status) {
      throw parseOpenAIError(error);
    }

    // Generic error
    throw new APIError(
      ErrorCode.INTERNAL_ERROR,
      500,
      'Internal server error',
      { original_message: error.message }
    );
  }
}