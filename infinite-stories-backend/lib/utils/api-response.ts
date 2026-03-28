import { NextResponse } from 'next/server';

/**
 * Typed error class for authentication failures.
 * Ensures auth errors always map to 401, regardless of message wording.
 */
export class AuthenticationError extends Error {
  constructor(message = 'Authentication required') {
    super(message);
    this.name = 'AuthenticationError';
  }
}

export interface ApiError {
  error: string;
  message: string;
  details?: any;
}

export interface ApiSuccess<T = any> {
  data: T;
  message?: string;
}

/**
 * Standard error response
 */
export function errorResponse(
  error: string,
  message: string,
  status: number = 500,
  details?: any
): NextResponse<ApiError> {
  return NextResponse.json(
    {
      error,
      message,
      ...(details && { details }),
    },
    { status }
  );
}

/**
 * Standard success response
 */
export function successResponse<T>(
  data: T,
  message?: string,
  status: number = 200
): NextResponse<ApiSuccess<T>> {
  return NextResponse.json(
    {
      data,
      ...(message && { message }),
    },
    { status }
  );
}

/**
 * Handle common API errors
 */
export function handleApiError(error: unknown): NextResponse<ApiError> {
  console.error('API Error:', error);

  // Typed authentication errors always return 401
  if (error instanceof AuthenticationError) {
    return errorResponse('Unauthorized', error.message, 401);
  }

  if (error instanceof Error) {
    // Handle specific error types
    if (error.message === 'Unauthorized') {
      return errorResponse('Unauthorized', 'Authentication required', 401);
    }

    if (error.message.includes('Forbidden')) {
      return errorResponse('Forbidden', error.message, 403);
    }

    if (error.message.includes('not found')) {
      return errorResponse('NotFound', error.message, 404);
    }

    if (error.message.includes('Rate limit')) {
      return errorResponse('RateLimitExceeded', error.message, 429);
    }

    // Validation errors
    if (error.message.includes('Invalid') || error.message.includes('required')) {
      return errorResponse('ValidationError', error.message, 400);
    }

    // Generic error — hide internal details in production
    const isProduction = process.env.NODE_ENV === 'production';
    return errorResponse(
      'InternalServerError',
      isProduction ? 'An unexpected error occurred' : error.message,
      500,
    );
  }

  // Unknown error
  return errorResponse(
    'InternalServerError',
    'An unexpected error occurred',
    500
  );
}

/**
 * Validate required fields in request body
 */
export function validateRequiredFields<T extends Record<string, any>>(
  body: T,
  requiredFields: (keyof T)[]
): { valid: boolean; missing?: string[] } {
  const missing = requiredFields.filter((field) => !body[field]);

  if (missing.length > 0) {
    return { valid: false, missing: missing as string[] };
  }

  return { valid: true };
}
